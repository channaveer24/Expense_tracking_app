import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/expense_providers.dart';
import '../expenses/expense_form_sheet.dart';
import 'parser/expense_parser.dart';
import 'speech_controller.dart';

Future<void> showVoiceCapture(BuildContext context, {bool typing = false}) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => VoiceCaptureSheet(startTyping: typing),
    );

/// Speak -> saved. Listening continues through short pauses and ends after
/// ~3.5 s of silence; the expenses are saved straight away and shown with
/// Undo and tap-to-edit.
class VoiceCaptureSheet extends ConsumerStatefulWidget {
  const VoiceCaptureSheet({super.key, this.startTyping = false});
  final bool startTyping;

  @override
  ConsumerState<VoiceCaptureSheet> createState() => _VoiceCaptureSheetState();
}

class _VoiceCaptureSheetState extends ConsumerState<VoiceCaptureSheet> {
  final _speech = SpeechController();
  final _parser = ExpenseParser();
  final _text = TextEditingController();
  late bool _typing = widget.startTyping;

  /// null = still capturing; empty = nothing understood; else saved rows.
  List<Expense>? _saved;
  String _heard = '';
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _speech.onFinal = _handleText;
    if (!_typing) _speech.start();
  }

  @override
  void dispose() {
    _speech.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _handleText(String text) async {
    final parsed = _parser.parse(text);
    setState(() {
      _heard = text;
      _saveError = null;
    });
    if (parsed.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() => _saved = const []);
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await ref.read(expensesProvider.notifier).addAll(parsed);
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _saved = saved);
    } catch (e) {
      HapticFeedback.heavyImpact();
      if (mounted) setState(() => _saveError = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _undoAll() async {
    final n = ref.read(expensesProvider.notifier);
    for (final e in _saved ?? const <Expense>[]) {
      if (e.id != null) await n.remove(e.id!);
    }
    HapticFeedback.lightImpact();
    if (!mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed.')));
  }

  Future<void> _edit(int i) async {
    final list = _saved!;
    await showExpenseForm(context, initial: list[i]);
    // Re-read: the row may have been edited or deleted in the form.
    final current = ref.read(expensesProvider).value ?? const <Expense>[];
    final fresh = current.where((e) => e.id == list[i].id).firstOrNull;
    if (!mounted) return;
    setState(() => fresh == null ? list.removeAt(i) : list[i] = fresh);
  }

  void _again() {
    setState(() {
      _saved = null;
      _saveError = null;
      _heard = '';
      _typing = false;
    });
    _speech.start();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final Widget body;
    if (_saveError != null) {
      body = _errorView(t, cs);
    } else if (_saving) {
      body = const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()));
    } else if (_saved != null) {
      body = _savedView(t, cs);
    } else {
      body = _captureView(t, cs);
    }
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: AnimatedSize(duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic, child: body),
      ),
    );
  }

  Widget _captureView(TextTheme t, ColorScheme cs) {
    return ListenableBuilder(
      listenable: _speech,
      builder: (context, _) {
        final listening = _speech.status == VoiceStatus.listening;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_typing ? 'Type what you spent' : (listening ? 'Listening…' : 'Tap the mic and speak'),
                style: t.titleLarge),
            const SizedBox(height: 6),
            Text(
              _typing
                  ? 'e.g. "40 rs on tea and 300 for a book, 210 on petrol by cash"'
                  : 'Take your time, pauses are fine. It stops after a few seconds of silence, or tap the mic when done.',
              textAlign: TextAlign.center,
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            if (!_typing) ...[
              MicOrb(
                listening: listening,
                level: _speech.level,
                onTap: listening ? _speech.stop : _speech.start,
              ),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 56),
                child: Text(
                  _speech.error ?? (_speech.transcript.isEmpty ? ' ' : '“${_speech.transcript}”'),
                  textAlign: TextAlign.center,
                  style: _speech.error != null
                      ? t.bodyMedium?.copyWith(color: cs.error)
                      : t.titleMedium?.copyWith(height: 1.4),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () {
                  _speech.cancel();
                  setState(() => _typing = true);
                },
                icon: const Icon(Icons.keyboard_alt_outlined),
                label: const Text('Type instead'),
              ),
            ] else ...[
              TextField(
                controller: _text,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                textInputAction: TextInputAction.done,
                onSubmitted: (v) => v.trim().isEmpty ? null : _handleText(v),
                decoration: const InputDecoration(hintText: 'spent 40 rs on tea and 120 on lunch by cash'),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _again,
                    icon: const Icon(Icons.mic_none_rounded),
                    label: const Text('Speak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _text.text.trim().isEmpty ? null : _handleText(_text.text),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Save'),
                  ),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }

  Widget _errorView(TextTheme t, ColorScheme cs) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.error_outline_rounded, color: cs.error, size: 40),
          const SizedBox(height: 8),
          Text('Could not save', style: t.titleLarge),
          const SizedBox(height: 4),
          Text(_saveError!, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))),
            const SizedBox(width: 12),
            Expanded(child: FilledButton(onPressed: () => _handleText(_heard), child: const Text('Retry save'))),
          ]),
        ]),
      );

  Widget _savedView(TextTheme t, ColorScheme cs) {
    final list = _saved!;
    final total = list.fold<double>(0, (s, e) => s + e.amount);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(list.isEmpty ? Icons.help_outline_rounded : Icons.check_circle_rounded,
                color: list.isEmpty ? cs.error : AppColors.mint, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                list.isEmpty
                    ? 'No amount heard'
                    : 'Saved ${list.length} expense${list.length == 1 ? '' : 's'} · ${inr(total)}',
                style: t.titleLarge?.copyWith(fontFeatures: tabular),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text('“$_heard”', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
        ]),
      ),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text('Say the amount with the item, e.g. "50 rupees for coffee".',
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        )
      else
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: list.length,
            itemBuilder: (context, i) => ExpenseTile(list[i], showDate: true, onTap: () => _edit(i)),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(children: [
          if (list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text('Wrong? Tap a row to fix it.',
                  style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: list.isEmpty ? _again : _undoAll,
                icon: Icon(list.isEmpty ? Icons.mic_rounded : Icons.undo_rounded),
                label: Text(list.isEmpty ? 'Try again' : 'Undo'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: list.isEmpty ? () => Navigator.pop(context) : _again,
                icon: Icon(list.isEmpty ? Icons.close_rounded : Icons.add_rounded),
                label: Text(list.isEmpty ? 'Close' : 'Add more'),
              ),
            ),
          ]),
          if (list.isNotEmpty)
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ]),
      ),
    ]);
  }
}
