import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/constants/categories.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/common.dart';
import '../../data/repositories/expense_providers.dart';
import '../expenses/expense_form_sheet.dart';
import '../voice/voice_capture_sheet.dart';
import 'widgets/charts.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.onSeeAll});
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final expenses = ref.watch(expensesProvider);
    final scope = ref.watch(dashboardScopeProvider);
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      bottom: false,
      child: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load data\n$e')),
        data: (s) {
          final all = expenses.value ?? const [];
          return RefreshIndicator(
            onRefresh: () => ref.read(expensesProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(DateFormat('EEEE, d MMMM').format(DateTime.now()),
                        style: t.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 2),
                    Text('Expense Dashboard', style: t.headlineMedium),
                  ]),
                ),
                _HeroCard(stats: s),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: _StatTile(label: 'This Week', value: inrCompact(s.week), icon: Icons.date_range_rounded, color: AppColors.mint)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatTile(label: 'This Year', value: inrCompact(s.year), icon: Icons.calendar_month_rounded, color: const Color(0xFF4F8EF7))),
                ]),
                const SizedBox(height: 12),
                _TopCategoryTile(category: s.topCategory, amount: s.topCategoryAmount, yearTotal: s.year),
                if (all.isEmpty) ...[
                  const SizedBox(height: 24),
                  EmptyState(
                    icon: Icons.mic_rounded,
                    title: 'Log your first expense',
                    message: 'Tap the mic and say something like\n"I spent 40 rupees on tea and 300 on a book".',
                    action: FilledButton.icon(
                      onPressed: () => showVoiceCapture(context),
                      icon: const Icon(Icons.mic_rounded),
                      label: const Text('Start speaking'),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  SectionHeader('Breakdown', trailing: _ScopePicker(scope: scope)),
                  CategoryDonutCard(byCategory: s.byCategory),
                  const SizedBox(height: 12),
                  NeedWantCard(byType: s.byType),
                  const SizedBox(height: 24),
                  const SectionHeader('Monthly spending'),
                  MonthlyBarCard(monthly: s.monthly),
                  const SizedBox(height: 24),
                  SectionHeader('Recent', trailing: TextButton(onPressed: onSeeAll, child: const Text('See all'))),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(children: [
                        for (final e in all.take(5))
                          ExpenseTile(e, showDate: true, onTap: () => showExpenseForm(context, initial: e)),
                      ]),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});
  final SpendingStats stats;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final delta = stats.lastMonth == 0 ? null : (stats.month - stats.lastMonth) / stats.lastMonth * 100;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.radius + 4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C6CF6), Color(0xFF4A3CC9), Color(0xFF2B2380)],
        ),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('Total Spending This Month',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: t.bodyMedium?.copyWith(color: Colors.white70)),
          ),
          const SizedBox(width: 8),
          if (delta != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(delta > 0 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: Colors.white),
                const SizedBox(width: 2),
                Text('${delta.abs().toStringAsFixed(0)}%',
                    style: t.labelSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
              ]),
            ),
        ]),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(inr(stats.month),
              style: t.displaySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w800, fontFeatures: tabular)),
        ),
        if (stats.lastMonth > 0)
          Text('Last month ${inr(stats.lastMonth)}', style: t.bodySmall?.copyWith(color: Colors.white70)),
        const SizedBox(height: 16),
        SizedBox(height: 56, child: WeekSparkBars(daily: stats.daily)),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 34,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text('Total Spending $label',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: t.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular)),
          ),
        ]),
      ),
    );
  }
}

class _TopCategoryTile extends StatelessWidget {
  const _TopCategoryTile({required this.category, required this.amount, required this.yearTotal});
  final String? category;
  final double amount;
  final double yearTotal;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final share = yearTotal == 0 ? 0.0 : amount / yearTotal;
    final color = category == null ? cs.outline : styleFor(category!).color;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          category == null
              ? const CategoryAvatar('-', size: 48)
              : CategoryAvatar(category!, size: 48),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Highest Spending Category', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(category ?? '—', style: t.titleLarge),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: share,
                  minHeight: 6,
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.15),
                ),
              ),
            ]),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(inrCompact(amount), style: t.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontFeatures: tabular)),
            Text('${(share * 100).toStringAsFixed(0)}% of year', style: t.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          ]),
        ]),
      ),
    );
  }
}

class _ScopePicker extends ConsumerWidget {
  const _ScopePicker({required this.scope});
  final DateRangeFilter scope;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const options = [DateRangeFilter.thisWeek, DateRangeFilter.thisMonth, DateRangeFilter.thisYear, DateRangeFilter.allTime];
    return PopupMenuButton<DateRangeFilter>(
      initialValue: scope,
      onSelected: ref.read(dashboardScopeProvider.notifier).set,
      itemBuilder: (_) => [for (final o in options) PopupMenuItem(value: o, child: Text(o.label))],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(scope.label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(width: 4),
          const Icon(Icons.expand_more_rounded, size: 18),
        ]),
      ),
    );
  }
}
