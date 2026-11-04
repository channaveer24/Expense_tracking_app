/// One row of the "Expenses" sheet:
/// Date | Amount | Description | Category | Payment Method | Type
class Expense {
  final int? id;
  final DateTime date;
  final double amount;
  final String description;
  final String category;
  final String paymentMethod;
  final String type;

  const Expense({
    this.id,
    required this.date,
    required this.amount,
    required this.description,
    required this.category,
    this.paymentMethod = 'UPI',
    required this.type,
  });

  Expense copyWith({
    int? id,
    DateTime? date,
    double? amount,
    String? description,
    String? category,
    String? paymentMethod,
    String? type,
  }) =>
      Expense(
        id: id ?? this.id,
        date: date ?? this.date,
        amount: amount ?? this.amount,
        description: description ?? this.description,
        category: category ?? this.category,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        type: type ?? this.type,
      );

  /// Dates are stored as YYYY-MM-DD text.
  static String dateToDb(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static DateTime dateFromDb(String s) {
    final p = s.split('-').map(int.parse).toList();
    return DateTime(p[0], p[1], p[2]);
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'date': dateToDb(date),
        'amount': amount,
        'description': description,
        'category': category,
        'payment_method': paymentMethod,
        'type': type,
      };

  factory Expense.fromMap(Map<String, Object?> m) => Expense(
        id: m['id'] as int?,
        date: dateFromDb(m['date'] as String),
        amount: (m['amount'] as num).toDouble(),
        description: m['description'] as String,
        category: m['category'] as String,
        paymentMethod: m['payment_method'] as String,
        type: m['type'] as String,
      );

  @override
  String toString() =>
      'Expense(${dateToDb(date)}, $amount, "$description", $category, $paymentMethod, $type)';
}
