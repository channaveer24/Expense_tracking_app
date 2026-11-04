import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/expense_providers.dart';
import 'expense_form_sheet.dart';

class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(expenseFilterProvider);
    final data = ref.watch(filteredExpensesProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    void setFilter(ExpenseFilter f) => ref.read(expenseFilterProvider.notifier).set(f);

    return SafeArea(
      bottom: false,
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          child: Row(children: [
            Expanded(child: Text('Expenses', style: t.headlineMedium)),
            IconButton.filledTonal(
              tooltip: 'Filters',
              onPressed: () => _showFilterSheet(context, ref),
              icon: Badge(
                isLabelVisible: filter.hasExtraFilters,
                smallSize: 8,
                child: const Icon(Icons.tune_rounded),
              ),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            onChanged: (v) => setFilter(filter.copyWith(query: v)),
            decoration: const InputDecoration(
              hintText: 'Search description',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            children: [
              for (final r in DateRangeFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(r == DateRangeFilter.custom && filter.custom != null && filter.range == r
                        ? '${DateFormat('d MMM').format(filter.custom!.start)} – ${DateFormat('d MMM').format(filter.custom!.end)}'
                        : r.label),
                    selected: filter.range == r,
                    onSelected: (_) async {
                      if (r == DateRangeFilter.custom) {
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                          initialDateRange: filter.custom,
                        );
                        if (picked == null) return;
                        setFilter(filter.copyWith(range: r, custom: picked));
                      } else {
                        setFilter(filter.copyWith(range: r));
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        if (filter.hasExtraFilters)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              children: [
                for (final c in filter.categories)
                  _ActiveChip(c, () => setFilter(filter.copyWith(categories: {...filter.categories}..remove(c)))),
                if (filter.type != null) _ActiveChip(filter.type!, () => setFilter(filter.copyWith(type: () => null))),
                if (filter.payment != null)
                  _ActiveChip(filter.payment!, () => setFilter(filter.copyWith(payment: () => null))),
              ],
            ),
          ),
        Expanded(
          child: data.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              final total = list.fold<double>(0, (s, e) => s + e.amount);
              if (list.isEmpty) {
                return const Center(
                  child: SingleChildScrollView(
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Nothing here',
                      message: 'No expenses match these filters.\nTry another date range or tap the mic to add one.',
                    ),
                  ),
                );
              }
              final groups = <DateTime, List<Expense>>{};
              for (final e in list) {
                groups.putIfAbsent(e.date, () => []).add(e);
              }
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(children: [
                      Text('${list.length} expense${list.length == 1 ? '' : 's'}', style: t.bodyMedium),
                      const Spacer(),
                      Text(inr(total),
                          style: t.titleLarge?.copyWith(
                              color: cs.primary, fontWeight: FontWeight.w800, fontFeatures: tabular)),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  for (final g in groups.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
                      child: Row(children: [
                        Text(dayLabel(g.key), style: t.labelLarge?.copyWith(color: cs.onSurfaceVariant)),
                        const Spacer(),
                        Text(inr(g.value.fold<double>(0, (s, e) => s + e.amount)),
                            style: t.labelLarge?.copyWith(color: cs.onSurfaceVariant, fontFeatures: tabular)),
                      ]),
                    ),
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(children: [
                        for (final e in g.value) _SwipeTile(e),
                      ]),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ]),
    );
  }

  void _showFilterSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final f = ref.watch(expenseFilterProvider);
        final n = ref.read(expenseFilterProvider.notifier);
        final t = Theme.of(context).textTheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text('Filters', style: t.titleLarge)),
              TextButton(
                onPressed: () => n.set(ExpenseFilter(range: f.range, custom: f.custom, query: f.query)),
                child: const Text('Reset'),
              ),
            ]),
            const SizedBox(height: 12),
            Text('Category', style: t.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in kCategories)
                FilterChip(
                  avatar: Icon(styleFor(c).icon, size: 18, color: styleFor(c).color),
                  label: Text(c),
                  selected: f.categories.contains(c),
                  selectedColor: styleFor(c).color.withValues(alpha: 0.22),
                  onSelected: (on) => n.set(f.copyWith(
                      categories: on ? ({...f.categories, c}) : ({...f.categories}..remove(c)))),
                ),
            ]),
            const SizedBox(height: 20),
            Text('Need / Want', style: t.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final ty in kTypes)
                ChoiceChip(
                  label: Text(ty),
                  selected: f.type == ty,
                  onSelected: (on) => n.set(f.copyWith(type: () => on ? ty : null)),
                ),
            ]),
            const SizedBox(height: 20),
            Text('Payment method', style: t.labelLarge),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (final p in kPaymentMethods)
                ChoiceChip(
                  avatar: Icon(paymentIcon(p), size: 18),
                  label: Text(p),
                  selected: f.payment == p,
                  onSelected: (on) => n.set(f.copyWith(payment: () => on ? p : null)),
                ),
            ]),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Show results')),
            ),
          ]),
        );
      }),
    );
  }
}

class _ActiveChip extends StatelessWidget {
  const _ActiveChip(this.label, this.onRemove);
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: InputChip(label: Text(label), onDeleted: onRemove, visualDensity: VisualDensity.compact),
      );
}

class _SwipeTile extends ConsumerWidget {
  const _SwipeTile(this.e);
  final Expense e;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(e.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: cs.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          Icon(Icons.delete_rounded, color: Colors.white),
          SizedBox(width: 8),
          Text('Delete', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ]),
      ),
      onDismissed: (_) async {
        HapticFeedback.mediumImpact();
        final notifier = ref.read(expensesProvider.notifier);
        final messenger = ScaffoldMessenger.of(context);
        await notifier.remove(e.id!);
        messenger.showSnackBar(SnackBar(
          content: Text('Deleted "${e.description}"'),
          action: SnackBarAction(label: 'Undo', onPressed: () => notifier.add(e.copyWith())),
        ));
      },
      child: ExpenseTile(e, onTap: () => showExpenseForm(context, initial: e)),
    );
  }
}
