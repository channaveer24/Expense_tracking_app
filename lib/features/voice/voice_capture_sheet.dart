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
  List<Expense>? _results;
  String _heard = '';

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

  void _handleText(String text) {
    final parsed = _parser.parse(text);
    HapticFeedback.mediumImpact();
    setState(() {
      _heard = text;
      _results = parsed;
    });
  }

  Future<void> _save() async {
    final list = _results ?? const [];
    if (list.isEmpty) return;
    await ref.read(expensesProvider.notifier).addAll(list);
    HapticFeedback.heavyImpact();
    if (!mounted) return;
    final total = list.fold<double>(0, (s, e) => s + e.amount);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Saved ${list.length} expense${list.length == 1 ? '' : 's'} · ${inr(total)}'),
    ));
  }

  void _retry() {
    setState(() {
      _results = null;
      _heard = '';
      _typing = false;
    });
    _speech.start();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
        child: AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: _results != null ? _resultsView(t, cs) : _captureView(t, cs),
        ),
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
              'e.g. "40 rs on tea and 300 for a book, 210 on petrol by cash"',
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
                    onPressed: _retry,
                    icon: const Icon(Icons.mic_none_rounded),
                    label: const Text('Speak'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _text.text.trim().isEmpty ? null : _handleText(_text.text),
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Parse'),
                  ),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }

  Widget _resultsView(TextTheme t, ColorScheme cs) {
    final list = _results!;
    final total = list.fold<double>(0, (s, e) => s + e.amount);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(list.isEmpty ? 'No amounts found' : 'Found ${list.length} expense${list.length == 1 ? '' : 's'}',
              style: t.titleLarge),
          const SizedBox(height: 6),
          Text('“$_heard”', style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
        ]),
      ),
      if (list.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Text('Say the amount with the item, e.g. "50 rupees for coffee".',
              style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
        )
      else
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: list.length,
            itemBuilder: (context, i) => Dismissible(
              key: ObjectKey(list[i]),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 24),
                child: Icon(Icons.close_rounded, color: cs.error),
              ),
              onDismissed: (_) => setState(() => list.removeAt(i)),
              child: ExpenseTile(
                list[i],
                showDate: true,
                onTap: () async {
                  final edited = await showExpenseForm(context, initial: list[i], persist: false);
                  if (edited != null) setState(() => list[i] = edited);
                },
              ),
            ),
          ),
        ),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(children: [
          if (list.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Text('Tap to edit · swipe to remove', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                const Spacer(),
                Text('Total ', style: t.bodyMedium),
                Text(inr(total), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular)),
              ]),
            ),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: list.isEmpty ? null : _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(list.length > 1 ? 'Save all' : 'Save'),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }
}
