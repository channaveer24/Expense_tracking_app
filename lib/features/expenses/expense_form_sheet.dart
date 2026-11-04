import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/categories.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/expense_providers.dart';

/// Add / edit one expense. Returns the edited [Expense] when [persist] is
/// false (used to tweak voice results before saving).
Future<Expense?> showExpenseForm(BuildContext context, {Expense? initial, bool persist = true}) =>
    showModalBottomSheet<Expense>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => ExpenseFormSheet(initial: initial, persist: persist),
    );

class ExpenseFormSheet extends ConsumerStatefulWidget {
  const ExpenseFormSheet({super.key, this.initial, this.persist = true});
  final Expense? initial;
  final bool persist;

  @override
  ConsumerState<ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends ConsumerState<ExpenseFormSheet> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
      text: widget.initial == null
          ? ''
          : widget.initial!.amount == widget.initial!.amount.roundToDouble()
              ? widget.initial!.amount.toStringAsFixed(0)
              : widget.initial!.amount.toString());
  late final _desc = TextEditingController(text: widget.initial?.description ?? '');
  late DateTime _date = widget.initial?.date ?? DateTime.now();
  late String _category = widget.initial?.category ?? 'Misc';
  late String _payment = widget.initial?.paymentMethod ?? 'UPI';
  late String _type = widget.initial?.type ?? 'Want';
  bool _typeTouched = false;

  bool get _isEdit => widget.initial?.id != null;

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final e = Expense(
      id: widget.initial?.id,
      date: DateTime(_date.year, _date.month, _date.day),
      amount: double.parse(_amount.text.trim()),
      description: _desc.text.trim().isEmpty ? _category : _desc.text.trim(),
      category: _category,
      paymentMethod: _payment,
      type: _type,
    );
    if (widget.persist) {
      final n = ref.read(expensesProvider.notifier);
      _isEdit ? await n.save(e) : await n.add(e);
      HapticFeedback.lightImpact();
    }
    if (mounted) Navigator.pop(context, e);
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Delete expense?'),
        content: Text('"${widget.initial!.description}" will be removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(c).colorScheme.error),
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(expensesProvider.notifier).remove(widget.initial!.id!);
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Form(
          key: _form,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Expanded(
                  child: Text(_isEdit ? 'Edit expense' : (widget.persist ? 'New expense' : 'Review expense'),
                      style: t.titleLarge)),
              if (_isEdit)
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _delete,
                  icon: Icon(Icons.delete_outline_rounded, color: cs.error),
                ),
            ]),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amount,
              autofocus: widget.initial == null,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
              style: t.headlineMedium,
              decoration: const InputDecoration(prefixText: '₹ ', hintText: '0', labelText: 'Amount'),
              validator: (v) {
                final n = double.tryParse(v?.trim() ?? '');
                return n == null || n <= 0 ? 'Enter an amount' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Description', hintText: 'e.g. Tea, Petrol, Metro ticket'),
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Date', suffixIcon: Icon(Icons.calendar_today_rounded)),
                child: Text(DateFormat('EEE, d MMM yyyy').format(_date)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Category', style: t.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in kCategories)
                ChoiceChip(
                  avatar: Icon(styleFor(c).icon, size: 18, color: styleFor(c).color),
                  label: Text(c),
                  selected: _category == c,
                  selectedColor: styleFor(c).color.withValues(alpha: 0.22),
                  onSelected: (_) => setState(() {
                    _category = c;
                    if (!_typeTouched) _type = kCategoryDefaultType[c] ?? _type;
                  }),
                ),
            ]),
            const SizedBox(height: 20),
            Text('Type', style: t.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'Need', label: Text('Need')),
                ButtonSegment(value: 'Want', label: Text('Want')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _typeTouched = true;
              }),
            ),
            const SizedBox(height: 20),
            Text('Payment method', style: t.labelLarge),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                for (final p in kPaymentMethods)
                  ButtonSegment(value: p, label: Text(p), icon: Icon(paymentIcon(p), size: 18)),
              ],
              selected: {_payment},
              onSelectionChanged: (s) => setState(() => _payment = s.first),
            ),
            const SizedBox(height: 28),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check_rounded),
              label: Text(_isEdit || !widget.persist ? 'Save changes' : 'Add expense'),
            ),
          ]),
        ),
      ),
    );
  }
}
