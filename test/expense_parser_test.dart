import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/features/voice/parser/expense_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final parser = ExpenseParser(clock: () => DateTime(2026, 11, 4, 21, 30));

  String row(Expense e) =>
      '${e.amount.toStringAsFixed(0)}|${e.description}|${e.category}|${e.paymentMethod}|${e.type}';

  List<String> p(String s) => parser.parse(s).map(row).toList();

  test('spec example: three expenses in one breath', () {
    expect(
      p('I have spent 40 rs on tea and i bought the book for 300rs and i also spent on the petrol and there i have spent 210 rs'),
      ['40|Tea|Misc|UPI|Want', '300|Book|Investment|UPI|Need', '210|Petrol|Bike|UPI|Need'],
    );
  });

  test('rupee symbol, cash and card per item', () {
    expect(
      p('₹120 for lunch by cash, metro ticket 45 rupees and 900 on a table using card'),
      ['120|Lunch|Misc|Cash|Want', '45|Metro ticket|Transportation|UPI|Need', '900|Table|Utilities|Card|Need'],
    );
  });

  test('trailing payment applies to every item', () {
    expect(
      p('tea 15 rs and snacks 30 rs, paid everything in cash'),
      ['15|Tea|Misc|Cash|Want', '30|Snacks|Misc|Cash|Want'],
    );
  });

  test('number words and descriptions with prepositions', () {
    expect(
      p('booked the cab for parents from hotel to home for one hundred and eighty four rupees'),
      ['184|Cab for parents from hotel to home|Transportation|UPI|Need'],
    );
    expect(p('paid two thousand rupees rent'), ['2000|Rent|Housing|UPI|Need']);
  });

  test('multiple amounts in one clause', () {
    expect(p('tea 20 coffee 35'), ['20|Tea|Misc|UPI|Want', '35|Coffee|Misc|UPI|Want']);
  });

  test('longest keyword wins and amount glue removed', () {
    expect(p('otts and the table lamp 1,105 rs'), ['1105|Otts table lamp|Investment|UPI|Need']);
    expect(p('movie ticket 418'), ['418|Movie ticket|Entertainment|UPI|Want']);
  });

  test('item mentioned after amount in the next clause', () {
    expect(p('i spent 40 rs and it was on tea and 300 for a book'),
        ['40|Tea|Misc|UPI|Want', '300|Book|Investment|UPI|Need']);
  });

  test('yesterday sets the date', () {
    final e = parser.parse('yesterday medicine for mom 30 rs').single;
    expect(e.date, DateTime(2026, 11, 3));
    expect(row(e), '30|Medicine for mom|Medical|UPI|Need');
  });

  test('unknown item falls back to Misc and empty input yields nothing', () {
    expect(p('spent 99 on stickers'), ['99|Stickers|Misc|UPI|Want']);
    expect(p('hello there'), isEmpty);
    expect(p(''), isEmpty);
  });

  test('formats Google / Samsung speech typically returns', () {
    expect(p('I spent ₹40 on tea and ₹300 on a book'),
        ['40|Tea|Misc|UPI|Want', '300|Book|Investment|UPI|Need']);
    expect(p('₹40 tea ₹210 petrol'), ['40|Tea|Misc|UPI|Want', '210|Petrol|Bike|UPI|Need']);
    expect(p('Rs. 150 for lunch'), ['150|Lunch|Misc|UPI|Want']);
    expect(p('Spent 250 rupees on groceries.'), ['250|Groceries|Housing|UPI|Need']);
  });

  test('amounts the speech engine splits or spells out', () {
    expect(p('510 rs on lunch'), ['510|Lunch|Misc|UPI|Want']);
    expect(p('5 10 rs on lunch'), ['510|Lunch|Misc|UPI|Want']);
    expect(p('5:10 rupees lunch'), ['510|Lunch|Misc|UPI|Want']);
    expect(p('5 1 0 rupees for lunch'), ['510|Lunch|Misc|UPI|Want']);
    expect(p('five ten rupees on lunch'), ['510|Lunch|Misc|UPI|Want']);
    expect(p('five hundred ten rupees on lunch'), ['510|Lunch|Misc|UPI|Want']);
    expect(p('five hundred and ten rupees lunch'), ['510|Lunch|Misc|UPI|Want']);
    expect(p('twelve fifty rupees for shoes'), ['1250|Shoes|Personal|UPI|Need']);
    expect(p('one twenty five rs tea'), ['125|Tea|Misc|UPI|Want']);
    expect(p('twenty five rupees tea'), ['25|Tea|Misc|UPI|Want']);
    expect(p('two thousand five hundred rupees rent'), ['2500|Rent|Housing|UPI|Need']);
    expect(p('bought 2 books for 300 rs'), ['300|Books|Investment|UPI|Need']);
  });
}
