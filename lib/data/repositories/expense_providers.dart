import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../db/app_database.dart';
import '../models/expense.dart';

/// All expenses, newest first. Small personal datasets fit comfortably in
/// memory, so filtering and aggregation happen in Dart.
final expensesProvider =
    AsyncNotifierProvider<ExpensesNotifier, List<Expense>>(ExpensesNotifier.new);

class ExpensesNotifier extends AsyncNotifier<List<Expense>> {
  AppDatabase get _db => AppDatabase.instance;

  @override
  Future<List<Expense>> build() => _db.all();

  Future<void> refresh() async => state = AsyncData(await _db.all());

  Future<void> add(Expense e) async {
    await _db.insert(e);
    await refresh();
  }

  Future<void> addAll(List<Expense> list) async {
    await _db.insertAll(list);
    await refresh();
  }

  Future<void> save(Expense e) async {
    await _db.update(e);
    await refresh();
  }

  Future<void> remove(int id) async {
    await _db.delete(id);
    await refresh();
  }

  Future<void> clear() async {
    await _db.deleteAll();
    await refresh();
  }
}

// ------------------------------------------------------------------ filters

/// Same choices as the "Filter Type" dropdown on the sheet's "Expense View".
enum DateRangeFilter { today, thisWeek, thisMonth, thisYear, allTime, custom }

extension DateRangeFilterLabel on DateRangeFilter {
  String get label => switch (this) {
        DateRangeFilter.today => 'Today',
        DateRangeFilter.thisWeek => 'This Week',
        DateRangeFilter.thisMonth => 'This Month',
        DateRangeFilter.thisYear => 'This Year',
        DateRangeFilter.allTime => 'All Time',
        DateRangeFilter.custom => 'Custom',
      };
}

@immutable
class ExpenseFilter {
  final DateRangeFilter range;
  final DateTimeRange? custom;
  final Set<String> categories;
  final String? type;
  final String? payment;
  final String query;

  const ExpenseFilter({
    this.range = DateRangeFilter.thisMonth,
    this.custom,
    this.categories = const {},
    this.type,
    this.payment,
    this.query = '',
  });

  ExpenseFilter copyWith({
    DateRangeFilter? range,
    DateTimeRange? custom,
    Set<String>? categories,
    String? Function()? type,
    String? Function()? payment,
    String? query,
  }) =>
      ExpenseFilter(
        range: range ?? this.range,
        custom: custom ?? this.custom,
        categories: categories ?? this.categories,
        type: type != null ? type() : this.type,
        payment: payment != null ? payment() : this.payment,
        query: query ?? this.query,
      );

  bool get hasExtraFilters => categories.isNotEmpty || type != null || payment != null;

  (DateTime, DateTime) bounds(DateTime now) {
    final today = dateOnly(now);
    return switch (range) {
      DateRangeFilter.today => (today, today),
      DateRangeFilter.thisWeek => (startOfWeek(today), startOfWeek(today).add(const Duration(days: 6))),
      DateRangeFilter.thisMonth => (DateTime(now.year, now.month, 1), DateTime(now.year, now.month + 1, 0)),
      DateRangeFilter.thisYear => (DateTime(now.year, 1, 1), DateTime(now.year, 12, 31)),
      DateRangeFilter.allTime => (DateTime(2000), DateTime(2100, 12, 31)),
      DateRangeFilter.custom => custom == null
          ? (DateTime(2000), DateTime(2100, 12, 31))
          : (dateOnly(custom!.start), dateOnly(custom!.end)),
    };
  }

  bool matches(Expense e, (DateTime, DateTime) b) {
    if (e.date.isBefore(b.$1) || e.date.isAfter(b.$2)) return false;
    if (categories.isNotEmpty && !categories.contains(e.category)) return false;
    if (type != null && e.type != type) return false;
    if (payment != null && e.paymentMethod != payment) return false;
    if (query.isNotEmpty && !e.description.toLowerCase().contains(query.toLowerCase())) return false;
    return true;
  }
}

final expenseFilterProvider = NotifierProvider<ExpenseFilterNotifier, ExpenseFilter>(ExpenseFilterNotifier.new);

class ExpenseFilterNotifier extends Notifier<ExpenseFilter> {
  @override
  ExpenseFilter build() => const ExpenseFilter();
  void set(ExpenseFilter f) => state = f;
}

final filteredExpensesProvider = Provider<AsyncValue<List<Expense>>>((ref) {
  final filter = ref.watch(expenseFilterProvider);
  return ref.watch(expensesProvider).whenData((list) {
    final b = filter.bounds(DateTime.now());
    return list.where((e) => filter.matches(e, b)).toList();
  });
});

// ---------------------------------------------------------------- analytics

class SpendingStats {
  final double week;
  final double month;
  final double year;
  final double lastMonth;
  final String? topCategory;
  final double topCategoryAmount;
  final Map<String, double> byCategory;
  final Map<String, double> byType;
  final List<(DateTime, double)> monthly; // last 6 months, oldest first
  final List<(DateTime, double)> daily; // last 7 days, oldest first

  const SpendingStats({
    required this.week,
    required this.month,
    required this.year,
    required this.lastMonth,
    required this.topCategory,
    required this.topCategoryAmount,
    required this.byCategory,
    required this.byType,
    required this.monthly,
    required this.daily,
  });

  /// [scope] restricts the category / Need-Want breakdown, like the
  /// sheet's dashboard filters.
  factory SpendingStats.from(List<Expense> all, DateRangeFilter scope, DateTime now) {
    final today = dateOnly(now);
    final weekStart = startOfWeek(today);
    double week = 0, month = 0, year = 0, lastMonth = 0;
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);

    final scopeBounds = ExpenseFilter(range: scope).bounds(now);
    final byCategory = <String, double>{};
    final byType = <String, double>{'Need': 0, 'Want': 0};
    final yearByCategory = <String, double>{};

    final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
    final monthly = {for (final m in months) m: 0.0};
    final days = [for (var i = 6; i >= 0; i--) today.subtract(Duration(days: i))];
    final daily = {for (final d in days) d: 0.0};

    for (final e in all) {
      final d = e.date;
      if (d.year == now.year) {
        year += e.amount;
        yearByCategory.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
        if (d.month == now.month) month += e.amount;
      }
      if (d.year == lastMonthStart.year && d.month == lastMonthStart.month) lastMonth += e.amount;
      if (!d.isBefore(weekStart) && !d.isAfter(today)) week += e.amount;
      final mk = DateTime(d.year, d.month, 1);
      if (monthly.containsKey(mk)) monthly[mk] = monthly[mk]! + e.amount;
      if (daily.containsKey(d)) daily[d] = daily[d]! + e.amount;
      if (!d.isBefore(scopeBounds.$1) && !d.isAfter(scopeBounds.$2)) {
        byCategory.update(e.category, (v) => v + e.amount, ifAbsent: () => e.amount);
        byType.update(e.type, (v) => v + e.amount, ifAbsent: () => e.amount);
      }
    }

    // "Highest Spending Category" on the sheet is computed for the year.
    final topEntry = yearByCategory.entries.fold<MapEntry<String, double>?>(
        null, (best, e) => best == null || e.value > best.value ? e : best);

    final sortedCat = Map.fromEntries(byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value)));

    return SpendingStats(
      week: week,
      month: month,
      year: year,
      lastMonth: lastMonth,
      topCategory: topEntry?.key,
      topCategoryAmount: topEntry?.value ?? 0,
      byCategory: sortedCat,
      byType: byType,
      monthly: monthly.entries.map((e) => (e.key, e.value)).toList(),
      daily: daily.entries.map((e) => (e.key, e.value)).toList(),
    );
  }
}

final dashboardScopeProvider = NotifierProvider<DashboardScopeNotifier, DateRangeFilter>(DashboardScopeNotifier.new);

class DashboardScopeNotifier extends Notifier<DateRangeFilter> {
  @override
  DateRangeFilter build() => DateRangeFilter.thisMonth;
  void set(DateRangeFilter f) => state = f;
}

final statsProvider = Provider<AsyncValue<SpendingStats>>((ref) {
  final scope = ref.watch(dashboardScopeProvider);
  return ref.watch(expensesProvider).whenData((l) => SpendingStats.from(l, scope, DateTime.now()));
});
