import 'package:intl/intl.dart';

final _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
final _inrDecimals = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
final _compact = NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1);

String inr(num v) => v == v.roundToDouble() ? _inr.format(v) : _inrDecimals.format(v);
String inrCompact(num v) => v.abs() < 10000 ? _inr.format(v) : _compact.format(v);

String dayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  if (d.year == now.year) return DateFormat('EEE, d MMM').format(d);
  return DateFormat('d MMM yyyy').format(d);
}

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// Monday of the week containing [d] (matches ISOWEEKNUM in the sheet).
DateTime startOfWeek(DateTime d) => dateOnly(d).subtract(Duration(days: d.weekday - 1));
