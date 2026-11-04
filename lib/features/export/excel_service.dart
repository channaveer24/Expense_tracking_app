import 'dart:io';

import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/categories.dart';
import '../../data/models/expense.dart';
import '../../data/repositories/expense_providers.dart';

/// Builds an .xlsx with the same layout as "Expense Tracker.xlsx":
///   • "Expenses"  – Date | Amount | Description | Category | Payment Method | Type
///   • "Dashboard" – week / month / year totals, highest category,
///                   category + Need/Want breakdown and monthly totals.
class ExcelService {
  static const headers = ['Date', 'Amount', 'Description', 'Category', 'Payment Method', 'Type'];

  static List<int> build(List<Expense> expenses, {DateTime? now}) {
    now ??= DateTime.now();
    final excel = Excel.createExcel();
    final defaultSheet = excel.getDefaultSheet()!;
    excel.rename(defaultSheet, 'Dashboard');

    // Oldest first like the sheet; ties keep entry order (List.sort is not stable).
    final indexed = expenses.indexed.toList()
      ..sort((a, b) {
        final c = a.$2.date.compareTo(b.$2.date);
        if (c != 0) return c;
        final ids = (a.$2.id ?? 0).compareTo(b.$2.id ?? 0);
        return ids != 0 ? ids : a.$1.compareTo(b.$1);
      });
    final rows = [for (final (_, e) in indexed) e];

    _expensesSheet(excel['Expenses'], rows);
    _dashboardSheet(excel['Dashboard'], rows, now);
    excel.setDefaultSheet('Dashboard');
    return excel.encode()!;
  }

  static final _headerStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('FFFFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('FF1F3A5F'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );
  static final _dateStyle = CellStyle(numberFormat: NumFormat.custom(formatCode: 'dd-mmm-yyyy'));
  static final _amountStyle = CellStyle(numberFormat: NumFormat.custom(formatCode: '"₹"#,##0.00'));
  static final _bandStyle = CellStyle(
    backgroundColorHex: ExcelColor.fromHexString('FFF2F6FB'),
    numberFormat: NumFormat.standard_0,
  );

  static void _expensesSheet(Sheet s, List<Expense> rows) {
    s.appendRow(headers.map(TextCellValue.new).toList());
    for (var c = 0; c < headers.length; c++) {
      s.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0)).cellStyle = _headerStyle;
    }
    for (var i = 0; i < rows.length; i++) {
      final e = rows[i];
      final r = i + 1;
      s.updateCell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: r), DateCellValue.fromDateTime(e.date),
          cellStyle: _dateStyle);
      s.updateCell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: r), DoubleCellValue(e.amount),
          cellStyle: _amountStyle);
      final band = i.isOdd ? _bandStyle : null;
      s.updateCell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: r), TextCellValue(e.description),
          cellStyle: band);
      s.updateCell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: r), TextCellValue(e.category),
          cellStyle: band);
      s.updateCell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: r), TextCellValue(e.paymentMethod),
          cellStyle: band);
      s.updateCell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: r), TextCellValue(e.type),
          cellStyle: band);
    }
    const widths = [14.0, 12.0, 44.0, 16.0, 16.0, 10.0];
    for (var c = 0; c < widths.length; c++) {
      s.setColumnWidth(c, widths[c]);
    }
  }

  static void _dashboardSheet(Sheet s, List<Expense> rows, DateTime now) {
    final stats = SpendingStats.from(rows, DateRangeFilter.thisYear, now);
    final title = CellStyle(bold: true, fontSize: 18, fontColorHex: ExcelColor.fromHexString('FF1F3A5F'));
    final label = CellStyle(bold: true, fontColorHex: ExcelColor.fromHexString('FF5B6B7F'));
    final big = CellStyle(
        bold: true, fontSize: 14, numberFormat: NumFormat.custom(formatCode: '"₹"#,##0'));

    void put(int col, int row, CellValue v, [CellStyle? st]) =>
        s.updateCell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row), v, cellStyle: st);

    put(1, 1, TextCellValue('Personal Expense Dashboard'), title);
    put(1, 2, TextCellValue('Generated ${DateFormat('d MMM yyyy, h:mm a').format(now)}'), label);

    put(1, 4, TextCellValue('Total Spending This Week'), label);
    put(4, 4, TextCellValue('Total Spending This Month'), label);
    put(7, 4, TextCellValue('Total Spending This Year'), label);
    put(10, 4, TextCellValue('Highest Spending Category'), label);
    put(1, 5, DoubleCellValue(stats.week), big);
    put(4, 5, DoubleCellValue(stats.month), big);
    put(7, 5, DoubleCellValue(stats.year), big);
    put(10, 5, TextCellValue(stats.topCategory ?? '-'), CellStyle(bold: true, fontSize: 14));

    // Category breakdown (this year)
    var r = 8;
    put(1, r, TextCellValue('Category (this year)'), _headerStyle);
    put(2, r, TextCellValue('Total'), _headerStyle);
    for (final e in stats.byCategory.entries) {
      r++;
      put(1, r, TextCellValue(e.key));
      put(2, r, DoubleCellValue(e.value), _amountStyle);
    }

    // Need vs Want
    var r2 = 8;
    put(4, r2, TextCellValue('Type (this year)'), _headerStyle);
    put(5, r2, TextCellValue('Total'), _headerStyle);
    for (final t in kTypes) {
      r2++;
      put(4, r2, TextCellValue(t));
      put(5, r2, DoubleCellValue(stats.byType[t] ?? 0), _amountStyle);
    }

    // Monthly totals (every month that has data)
    final monthly = <DateTime, double>{};
    for (final e in rows) {
      final k = DateTime(e.date.year, e.date.month);
      monthly.update(k, (v) => v + e.amount, ifAbsent: () => e.amount);
    }
    var r3 = 8;
    put(7, r3, TextCellValue('Month'), _headerStyle);
    put(8, r3, TextCellValue('Total'), _headerStyle);
    for (final k in monthly.keys.toList()..sort()) {
      r3++;
      put(7, r3, TextCellValue(DateFormat('MMM yyyy').format(k)));
      put(8, r3, DoubleCellValue(monthly[k]!), _amountStyle);
    }

    for (final c in [1, 4, 7, 10]) {
      s.setColumnWidth(c, 26);
    }
    for (final c in [2, 5, 8]) {
      s.setColumnWidth(c, 14);
    }
  }

  /// Writes the workbook to app storage and opens the Android share sheet
  /// (save to Drive / Files, send on WhatsApp, e-mail…).
  static Future<File> exportAndShare(List<Expense> expenses) async {
    final bytes = build(expenses);
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateFormat('yyyy-MM-dd_HHmm').format(DateTime.now());
    final file = File('${dir.path}/Expense_Tracker_$stamp.xlsx');
    await file.writeAsBytes(bytes, flush: true);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
      subject: 'Expense Tracker export',
    ));
    return file;
  }

  // ------------------------------------------------------------------ import

  /// Lets the user pick their existing "Expense Tracker.xlsx" and reads the
  /// "Expenses" tab (or the first sheet with a Date/Amount header).
  static Future<List<Expense>?> pickAndParse() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['xlsx']);
    if (file == null) return null;
    return parseWorkbook(await file.xFile.readAsBytes());
  }

  static List<Expense> parseWorkbook(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    Sheet? sheet = excel.tables['Expenses'];
    sheet ??= excel.tables.values.where((t) {
      final h = t.rows.isEmpty ? const [] : t.rows.first.map((c) => _text(c?.value).toLowerCase()).toList();
      return h.contains('date') && h.contains('amount');
    }).firstOrNull;
    if (sheet == null || sheet.rows.isEmpty) return const [];

    final header = sheet.rows.first.map((c) => _text(c?.value).toLowerCase().trim()).toList();
    int col(String name, int fallback) {
      final i = header.indexOf(name);
      return i >= 0 ? i : fallback;
    }

    final cDate = col('date', 0), cAmt = col('amount', 1), cDesc = col('description', 2);
    final cCat = col('category', 3), cPay = col('payment method', 4), cType = col('type', 5);

    final out = <Expense>[];
    for (final row in sheet.rows.skip(1)) {
      CellValue? at(int i) => i < row.length ? row[i]?.value : null;
      final date = _date(at(cDate));
      final amount = _num(at(cAmt));
      if (date == null || amount == null || amount <= 0) continue;
      var category = _text(at(cCat)).trim();
      if (!kCategories.contains(category)) {
        category = kCategories.firstWhere((c) => c.toLowerCase() == category.toLowerCase(), orElse: () => 'Misc');
      }
      var type = _text(at(cType)).trim();
      if (!kTypes.contains(type)) type = kCategoryDefaultType[category] ?? 'Need';
      var pay = _text(at(cPay)).trim();
      if (pay.isEmpty) pay = 'UPI';
      out.add(Expense(
        date: date,
        amount: amount,
        description: _text(at(cDesc)).trim().isEmpty ? category : _text(at(cDesc)).trim(),
        category: category,
        paymentMethod: pay,
        type: type,
      ));
    }
    return out;
  }

  static String _text(CellValue? v) => switch (v) {
        null => '',
        TextCellValue() => v.value.toString(),
        _ => v.toString(),
      };

  static double? _num(CellValue? v) => switch (v) {
        IntCellValue() => v.value.toDouble(),
        DoubleCellValue() => v.value,
        TextCellValue() => double.tryParse(v.value.toString().replaceAll(RegExp(r'[^0-9.]'), '')),
        _ => null,
      };

  static DateTime? _date(CellValue? v) => switch (v) {
        DateCellValue() => DateTime(v.year, v.month, v.day),
        DateTimeCellValue() => DateTime(v.year, v.month, v.day),
        // Excel serial date (days since 1899-12-30)
        IntCellValue() => DateTime(1899, 12, 30).add(Duration(days: v.value)),
        DoubleCellValue() => DateTime(1899, 12, 30).add(Duration(days: v.value.floor())),
        TextCellValue() => DateTime.tryParse(v.value.toString().trim()),
        _ => null,
      };
}
