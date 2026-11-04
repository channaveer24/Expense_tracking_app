import '../../../data/models/expense.dart';
import 'expense_parser.dart';

/// One way of reading what was said.
class Interpretation {
  Interpretation(this.transcript, this.expenses);
  final String transcript;
  final List<Expense> expenses;

  List<double> get amounts => [for (final e in expenses) e.amount];
  double get total => expenses.fold(0, (s, e) => s + e.amount);
}

/// Android returns up to 10 alternative transcripts for one utterance
/// ("510 rs tea", "5000 rs tea", "50 10 rs tea"...). Parses all of them and
/// keeps one interpretation per distinct set of amounts, best guess first.
///
/// If more than one comes back, the speech engine was not sure about the
/// numbers and the user should pick, instead of us silently saving a wrong
/// amount.
List<Interpretation> interpret(ExpenseParser parser, List<String> transcripts, {int max = 4}) {
  final out = <Interpretation>[];
  final seen = <String>{};
  for (final t in transcripts) {
    if (t.trim().isEmpty) continue;
    final parsed = parser.parse(t);
    if (parsed.isEmpty) continue;
    final key = parsed.map((e) => e.amount.toStringAsFixed(2)).join('|');
    if (!seen.add(key)) continue;
    // Alternatives that found a different number of items are usually just
    // worse transcripts; only offer ones that disagree on the amounts.
    if (out.isNotEmpty && parsed.length != out.first.expenses.length) continue;
    out.add(Interpretation(t, parsed));
    if (out.length >= max) break;
  }
  return out;
}
