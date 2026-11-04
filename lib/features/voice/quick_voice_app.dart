import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/db/app_database.dart';
import '../../data/models/expense.dart';
import 'parser/expense_parser.dart';
import 'speech_controller.dart';

/// Lightweight UI launched by the "Log Expense" Quick Settings tile, shown
/// on top of the lock screen by QuickVoiceActivity (transparent window).
/// Flow: listen → parse → save → vibrate → short confirmation → close.
class QuickVoiceApp extends StatelessWidget {
  const QuickVoiceApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        color: Colors.transparent,
        home: const QuickVoiceScreen(),
      );
}

class QuickVoiceScreen extends StatefulWidget {
  const QuickVoiceScreen({super.key});

  @override
  State<QuickVoiceScreen> createState() => _QuickVoiceScreenState();
}

class _QuickVoiceScreenState extends State<QuickVoiceScreen> {
  final _speech = SpeechController();
  List<Expense>? _saved;
  String _heard = '';
  Timer? _closeTimer;
  int _countdown = 4;
  String? _saveError;
  List<Expense> _pending = const [];

  @override
  void initState() {
    super.initState();
    _speech.onFinal = _onFinal;
    HapticFeedback.selectionClick();
    _speech.start();
  }

  @override
  void dispose() {
    _closeTimer?.cancel();
    _speech.dispose();
    super.dispose();
  }

  void _onFinal(String text) {
    final parsed = ExpenseParser().parse(text);
    _heard = text;
    if (parsed.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _saved = const []);
      return;
    }
    _save(parsed);
  }

  Future<void> _save(List<Expense> parsed) async {
    _pending = parsed;
    setState(() => _saveError = null);
    final saved = <Expense>[];
    try {
      for (final e in parsed) {
        final id = await AppDatabase.instance.insert(e);
        saved.add(e.copyWith(id: id));
      }
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _saveError = '$e');
      return;
    }
    // Success pattern: two short pulses.
    HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 120));
    HapticFeedback.mediumImpact();
    if (!mounted) return;
    setState(() => _saved = saved);
    _closeTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        _close();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  Future<void> _undo() async {
    _closeTimer?.cancel();
    for (final e in _saved ?? const <Expense>[]) {
      if (e.id != null) await AppDatabase.instance.delete(e.id!);
    }
    HapticFeedback.lightImpact();
    _close();
  }

  void _retry() {
    _closeTimer?.cancel();
    setState(() {
      _saved = null;
      _saveError = null;
      _countdown = 4;
    });
    _speech.start();
  }

  Future<void> _close() async {
    await _speech.cancel();
    await AppDatabase.instance.close();
    await SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.55),
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _close,
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {}, // swallow taps on the card
              child: Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                decoration: BoxDecoration(
                  color: AppColors.darkSurface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: AppColors.darkOutline),
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: _saveError != null
                      ? _errorView(t, cs)
                      : (_saved == null ? _listening(t, cs) : _result(t, cs)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorView(TextTheme t, ColorScheme cs) => Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, color: cs.error, size: 40),
        const SizedBox(height: 8),
        Text('Could not save', style: t.titleLarge),
        const SizedBox(height: 4),
        Text(_saveError!, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _close, child: const Text('Close'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: () => _save(_pending), child: const Text('Retry save'))),
        ]),
      ]);

  Widget _listening(TextTheme t, ColorScheme cs) => ListenableBuilder(
        listenable: _speech,
        builder: (context, _) {
          final listening = _speech.status == VoiceStatus.listening;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Row(children: [
              Text('Log expense', style: t.titleLarge),
              const Spacer(),
              IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded), tooltip: 'Close'),
            ]),
            MicOrb(
              listening: listening,
              level: _speech.level,
              size: 96,
              onTap: listening ? _speech.stop : _retry,
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Text(
                _speech.error ??
                    (_speech.transcript.isEmpty
                        ? (listening ? 'Listening… pauses are fine' : 'Starting…')
                        : '“${_speech.transcript}”'),
                textAlign: TextAlign.center,
                style: _speech.error != null ? t.bodyMedium?.copyWith(color: cs.error) : t.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
          ]);
        },
      );

  Widget _result(TextTheme t, ColorScheme cs) {
    final list = _saved!;
    if (list.isEmpty) {
      return Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.error_outline_rounded, color: cs.error, size: 40),
        const SizedBox(height: 8),
        Text('No amount heard', style: t.titleLarge),
        const SizedBox(height: 4),
        Text('“$_heard”', textAlign: TextAlign.center, style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: _close, child: const Text('Close'))),
          const SizedBox(width: 12),
          Expanded(child: FilledButton(onPressed: _retry, child: const Text('Try again'))),
        ]),
      ]);
    }
    final total = list.fold<double>(0, (s, e) => s + e.amount);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.mint, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Text('Saved ${list.length} · ${inr(total)}',
              style: t.titleLarge?.copyWith(fontFeatures: tabular)),
        ),
      ]),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.4),
        child: ListView(shrinkWrap: true, children: [for (final e in list) ExpenseTile(e)]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _undo, child: const Text('Undo'))),
        const SizedBox(width: 12),
        Expanded(child: FilledButton(onPressed: _close, child: Text('Done ($_countdown)'))),
      ]),
    ]);
  }
}
