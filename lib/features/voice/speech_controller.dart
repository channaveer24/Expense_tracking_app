import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceStatus { idle, initialising, listening, done, error }

/// Continuous dictation on top of Android's speech recogniser.
///
/// Android ends a recognition session after roughly one second of silence
/// and ignores requests for a longer pause. To let people pause and think
/// mid-sentence, every time Android ends a session we keep its text and
/// immediately start a new one. The utterance only ends after
/// [silenceToStop] without any speech (longer before the first word), or
/// when the user taps the mic.
class SpeechController extends ChangeNotifier {
  SpeechController({
    this.silenceToStop = const Duration(milliseconds: 3500),
    this.waitForFirstWord = const Duration(seconds: 6),
    this.maxLength = const Duration(seconds: 60),
  });

  final Duration silenceToStop;
  final Duration waitForFirstWord;
  final Duration maxLength;

  final SpeechToText _stt = SpeechToText();

  VoiceStatus status = VoiceStatus.idle;

  /// Everything heard so far in this utterance (committed + live partial).
  String transcript = '';
  String? error;
  double level = 0; // 0..1 microphone level for the pulse animation

  /// Called once with the full sentence when listening ends.
  void Function(String text)? onFinal;

  String? _localeId;
  String _committed = '';
  String _partial = '';
  bool _session = false;
  bool _finishing = false; // still accepting the last session's final words
  bool _heardAnything = false;
  DateTime _lastVoice = DateTime.now();
  DateTime _startedAt = DateTime.now();
  Timer? _watchdog;
  bool _restartScheduled = false;
  int _consecutiveErrors = 0;

  Future<bool> _init() async {
    final ok = await _stt.initialize(
      onError: _onError,
      onStatus: _onStatus,
      finalTimeout: const Duration(milliseconds: 800),
    );
    if (ok && _localeId == null) {
      try {
        // Indian English hears "rupees" and numbers like "five ten" far
        // better than en_US. Engines spell it en_IN, en-IN or en_in.
        String norm(String id) => id.replaceAll('-', '_').toLowerCase();
        final locales = await _stt.locales();
        final indian = locales.where((l) => norm(l.localeId) == 'en_in').firstOrNull;
        _localeId = indian?.localeId ?? (await _stt.systemLocale())?.localeId;
      } catch (_) {}
    }
    return ok;
  }

  Future<void> start() async {
    _committed = '';
    _partial = '';
    transcript = '';
    error = null;
    _heardAnything = false;
    _consecutiveErrors = 0;
    status = VoiceStatus.initialising;
    notifyListeners();

    bool ok;
    try {
      ok = await _init();
    } catch (_) {
      ok = false;
    }
    if (!ok) {
      status = VoiceStatus.error;
      error = 'Speech recognition unavailable. Allow the microphone permission and make sure '
          'Google speech services are installed.';
      notifyListeners();
      return;
    }

    _session = true;
    _startedAt = DateTime.now();
    _lastVoice = _startedAt;
    status = VoiceStatus.listening;
    notifyListeners();
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    await _listenOnce();
  }

  /// Ends listening now and delivers what was heard (mic button tap).
  Future<void> stop() => _finish();

  Future<void> cancel() async {
    _session = false;
    _watchdog?.cancel();
    try {
      await _stt.cancel();
    } catch (_) {}
    status = VoiceStatus.idle;
    level = 0;
    notifyListeners();
  }

  // ------------------------------------------------------------- internals

  Future<void> _listenOnce() async {
    if (!_session) return;
    _restartScheduled = false;
    try {
      await _stt.listen(
        onResult: _onResult,
        onSoundLevelChange: _onLevel,
        listenOptions: SpeechListenOptions(
          localeId: _localeId,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
          listenFor: maxLength,
        ),
      );
    } catch (_) {
      _scheduleRestart(const Duration(milliseconds: 300));
    }
  }

  void _scheduleRestart([Duration delay = const Duration(milliseconds: 60)]) {
    if (!_session || _restartScheduled) return;
    _restartScheduled = true;
    Timer(delay, () {
      if (_session && !_stt.isListening) {
        _listenOnce();
      } else {
        _restartScheduled = false;
      }
    });
  }

  void _onResult(SpeechRecognitionResult r) {
    if (!_session && !_finishing) return;
    final words = r.recognizedWords.trim();
    if (words.isNotEmpty) {
      _lastVoice = DateTime.now();
      _heardAnything = true;
      _consecutiveErrors = 0;
    }
    if (r.finalResult) {
      if (words.isNotEmpty) _committed = _join(_committed, words);
      _partial = '';
    } else {
      _partial = words;
    }
    transcript = _join(_committed, _partial);
    notifyListeners();
  }

  void _onLevel(double l) {
    // Android reports roughly -2..10 dB.
    level = ((l + 2) / 12).clamp(0.0, 1.0);
    // Clearly audible voice keeps the session alive even before words
    // are recognised.
    if (_session && l > 6) _lastVoice = DateTime.now();
    notifyListeners();
  }

  void _onStatus(String s) {
    // Android ended its ~1 s-silence session: keep listening.
    if (_session && (s == 'done' || s == 'notListening')) _scheduleRestart();
  }

  void _onError(SpeechRecognitionError e) {
    if (!_session) return;
    switch (e.errorMsg) {
      case 'error_permission':
      case 'error_insufficient_permissions':
        _fail('Microphone permission denied.');
      case 'error_network':
      case 'error_network_timeout':
      case 'error_server_disconnected':
      case 'error_language_unavailable':
      case 'error_language_not_supported':
        if (_committed.isEmpty && _partial.isEmpty) {
          _fail('Offline speech pack missing. Open Settings > Improve voice accuracy.');
        } else {
          _finish();
        }
      default:
        // error_no_match / error_speech_timeout / error_busy / error_client:
        // the user paused. Keep listening until the silence limit.
        _consecutiveErrors++;
        if (_consecutiveErrors > 12) {
          _finish();
        } else {
          _scheduleRestart(const Duration(milliseconds: 150));
        }
    }
  }

  void _tick() {
    if (!_session) return;
    final now = DateTime.now();
    final quietFor = now.difference(_lastVoice);
    final limit = _heardAnything ? silenceToStop : waitForFirstWord;
    if (quietFor >= limit || now.difference(_startedAt) >= maxLength) _finish();
  }

  Future<void> _finish() async {
    if (!_session) return;
    _session = false;
    _finishing = true;
    _watchdog?.cancel();
    try {
      await _stt.stop();
    } catch (_) {}
    // Give Android a moment to hand over the final words of the last session.
    await Future.delayed(const Duration(milliseconds: 400));
    _finishing = false;
    final text = _join(_committed, _partial).trim();
    level = 0;
    if (text.isEmpty) {
      status = VoiceStatus.error;
      error = "Didn't catch that. Tap the mic and try again.";
      notifyListeners();
      return;
    }
    transcript = text;
    status = VoiceStatus.done;
    notifyListeners();
    onFinal?.call(text);
  }

  void _fail(String message) {
    _session = false;
    _watchdog?.cancel();
    _stt.cancel().catchError((_) {});
    status = VoiceStatus.error;
    level = 0;
    error = message;
    notifyListeners();
  }

  static String _join(String a, String b) => a.isEmpty ? b : (b.isEmpty ? a : '$a $b');

  @override
  void dispose() {
    _session = false;
    _watchdog?.cancel();
    _stt.cancel().catchError((_) {});
    super.dispose();
  }
}
