import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/data/repositories/expense_providers.dart';
import 'package:expense_tracker/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory replacement for the SQLite-backed notifier.
class FakeExpenses extends ExpensesNotifier {
  FakeExpenses(this.seed);
  final List<Expense> seed;

  @override
  Future<List<Expense>> build() async => seed;
  @override
  Future<void> refresh() async {}
  @override
  Future<List<Expense>> addAll(List<Expense> list) async {
    var next = 1000 + state.value!.length;
    final saved = [for (final e in list) e.copyWith(id: next++)];
    state = AsyncData([...saved, ...state.value!]);
    return saved;
  }
  @override
  Future<void> remove(int id) async => state = AsyncData(state.value!.where((e) => e.id != id).toList());
}

/// Realistic data spread over the last six months (descriptions from the sheet).
List<Expense> sampleData(DateTime now) {
  const items = [
    (184.0, 'Cab for parents', 'Transportation', 'Need'),
    (29.0, 'Bought curd', 'Housing', 'Need'),
    (40.0, 'Tea and snacks', 'Misc', 'Want'),
    (320.0, 'Metro ticket', 'Transportation', 'Need'),
    (30.0, 'Medicine for mom', 'Medical', 'Need'),
    (418.0, 'Movie ticket', 'Entertainment', 'Want'),
    (900.0, 'Bought table', 'Utilities', 'Need'),
    (100.0, 'Petrol', 'Bike', 'Need'),
    (20.0, 'Tooth brush', 'Personal', 'Need'),
    (1105.0, 'OTTs and table lamp', 'Investment', 'Need'),
    (63.0, 'Vegetables', 'Housing', 'Need'),
    (38.0, 'Coffee', 'Misc', 'Want'),
  ];
  final out = <Expense>[];
  var id = 1;
  for (var d = 0; d < 170; d += 2) {
    final it = items[(d ~/ 2) % items.length];
    out.add(Expense(
      id: id++,
      date: DateTime(now.year, now.month, now.day).subtract(Duration(days: d)),
      amount: it.$1 * (1 + (d % 5) / 10),
      description: it.$2,
      category: it.$3,
      paymentMethod: d % 7 == 0 ? 'Cash' : 'UPI',
      type: it.$4,
    ));
  }
  for (var m = 0; m < 6; m++) {
    out.add(Expense(
      id: id++,
      date: DateTime(now.year, now.month - m, 6),
      amount: 8000,
      description: 'Home rent',
      category: 'Housing',
      type: 'Need',
    ));
  }
  out.sort((a, b) => b.date.compareTo(a.date));
  return out;
}

Widget app(List<Expense> data) => ProviderScope(
      overrides: [expensesProvider.overrideWith(() => FakeExpenses(data))],
      child: const ExpenseTrackerApp(),
    );

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first.physicalSize = const Size(1080, 2340);
    binding.platformDispatcher.views.first.devicePixelRatio = 2.75;
  });

  testWidgets('dashboard, expenses and settings render without layout errors', (tester) async {
    await tester.pumpWidget(app(sampleData(DateTime.now())));
    await tester.pumpAndSettle();
    expect(find.text('Expense Dashboard'), findsOneWidget);
    expect(find.text('Highest Spending Category'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Monthly spending'), 300,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    expect(find.text('Monthly spending'), findsOneWidget);

    await tester.tap(find.text('Expenses').last);
    await tester.pumpAndSettle();
    expect(find.text('This Month'), findsOneWidget);

    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Export to Excel'), findsOneWidget);
  });

  testWidgets('empty state shows the voice call-to-action', (tester) async {
    await tester.pumpWidget(app(const []));
    await tester.pumpAndSettle();
    expect(find.text('Log your first expense'), findsOneWidget);
  });

  testWidgets('typed sentence is saved immediately as three expenses', (tester) async {
    await tester.pumpWidget(app(const []));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Log by voice'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Type instead'));
    // A focused TextField blinks its cursor forever, so pump fixed frames.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.enterText(find.byType(TextField),
        'I have spent 40 rs on tea and i bought the book for 300rs and i also spent on the petrol and there i have spent 210 rs');
    await tester.tap(find.text('Save'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Saved straight away – no extra confirmation step.
    expect(find.textContaining('Saved 3 expenses · ₹550'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
  });
}
