import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_to_text.dart';

enum VoiceStatus { idle, initialising, listening, done, error }

/// Thin wrapper around `speech_to_text` (Android's on-device recogniser).
/// Works offline once the "English (India)" offline pack is downloaded in
/// Android Settings → Google → Voice → Offline speech recognition.
class SpeechController extends ChangeNotifier {
  final SpeechToText _stt = SpeechToText();

  VoiceStatus status = VoiceStatus.idle;
  String transcript = '';
  String? error;
  double level = 0; // 0..1 microphone level for the pulse animation
  String? _localeId;
  /// Best transcript first, then Android's alternatives (up to 10).
  List<String> alternatives = const [];

  /// Called once per utterance with every transcript Android offered,
  /// best guess first.
  void Function(List<String> transcripts)? onFinal;
  bool _finalDelivered = false;

  Future<bool> _init() async {
    final ok = await _stt.initialize(
      onError: _onError,
      onStatus: _onStatus,
      finalTimeout: const Duration(milliseconds: 1200),
    );
    if (ok && _localeId == null) {
      try {
        final locales = await _stt.locales();
        // Indian English hears "rupees", "five ten", Indian names of items
        // far better than en_US. Engines spell it en_IN, en-IN or en_in.
        String norm(String id) => id.replaceAll('-', '_').toLowerCase();
        final indian = locales.where((l) => norm(l.localeId) == 'en_in').firstOrNull;
        _localeId = indian?.localeId ?? (await _stt.systemLocale())?.localeId;
      } catch (_) {}
    }
    return ok;
  }

  Future<void> start() async {
    transcript = '';
    alternatives = const [];
    error = null;
    _finalDelivered = false;
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
    status = VoiceStatus.listening;
    notifyListeners();
    await _stt.listen(
      onResult: (r) {
        transcript = r.recognizedWords;
        if (r.finalResult) {
          alternatives = [
            for (final a in r.alternates)
              if (a.recognizedWords.trim().isNotEmpty) a.recognizedWords,
          ];
        }
        notifyListeners();
        if (r.finalResult) _deliver();
      },
      onSoundLevelChange: (l) {
        // Android reports roughly -2..10 dB
        level = ((l + 2) / 12).clamp(0.0, 1.0);
        notifyListeners();
      },
      listenOptions: SpeechListenOptions(
        localeId: _localeId,
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.dictation,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 45),
      ),
    );
  }

  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (_) {}
    status = VoiceStatus.idle;
    notifyListeners();
  }

  void _deliver() {
    if (_finalDelivered) return;
    _finalDelivered = true;
    status = VoiceStatus.done;
    level = 0;
    notifyListeners();
    final all = <String>[transcript, ...alternatives.where((a) => a != transcript)];
    onFinal?.call(all);
  }

  void _onStatus(String s) {
    if ((s == 'done' || s == 'notListening') && status == VoiceStatus.listening) {
      // Some devices end without a finalResult flag – deliver what we have.
      Timer(const Duration(milliseconds: 400), () {
        if (status == VoiceStatus.listening) {
          if (transcript.trim().isEmpty) {
            status = VoiceStatus.error;
            error = "Didn't catch that. Tap the mic and try again.";
            notifyListeners();
          } else {
            _deliver();
          }
        }
      });
    }
  }

  void _onError(SpeechRecognitionError e) {
    if (_finalDelivered) return;
    if (transcript.trim().isNotEmpty) {
      _deliver();
      return;
    }
    status = VoiceStatus.error;
    level = 0;
    error = switch (e.errorMsg) {
      'error_no_match' || 'error_speech_timeout' => "Didn't catch that. Tap the mic and try again.",
      'error_network' || 'error_network_timeout' || 'error_server_disconnected' =>
        'Offline speech pack missing. Download "English (India)" in Google voice settings.',
      'error_permission' || 'error_insufficient_permissions' => 'Microphone permission denied.',
      _ => 'Speech error: ${e.errorMsg}',
    };
    notifyListeners();
  }

  @override
  void dispose() {
    _stt.cancel().catchError((_) {});
    super.dispose();
  }
}
