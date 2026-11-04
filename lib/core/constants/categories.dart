import 'package:flutter/material.dart';

/// Categories exactly as used in the "Expenses" tab of the spreadsheet.
const List<String> kCategories = [
  'Transportation',
  'Housing',
  'Misc',
  'Medical',
  'Entertainment',
  'Utilities',
  'Bike',
  'Personal',
  'Investment',
];

const List<String> kPaymentMethods = ['UPI', 'Cash', 'Card'];
const List<String> kTypes = ['Need', 'Want'];

/// Default Need/Want classification per category.
const Map<String, String> kCategoryDefaultType = {
  'Transportation': 'Need',
  'Housing': 'Need',
  'Misc': 'Want',
  'Medical': 'Need',
  'Entertainment': 'Want',
  'Utilities': 'Need',
  'Bike': 'Need',
  'Personal': 'Need',
  'Investment': 'Need',
};

class CategoryStyle {
  final Color color;
  final IconData icon;
  const CategoryStyle(this.color, this.icon);
}

const Map<String, CategoryStyle> kCategoryStyles = {
  'Transportation': CategoryStyle(Color(0xFF4F8EF7), Icons.directions_transit_rounded),
  'Housing': CategoryStyle(Color(0xFF22B07D), Icons.home_rounded),
  'Misc': CategoryStyle(Color(0xFFF5A524), Icons.local_cafe_rounded),
  'Medical': CategoryStyle(Color(0xFFEF5D6B), Icons.medical_services_rounded),
  'Entertainment': CategoryStyle(Color(0xFFB065F0), Icons.movie_rounded),
  'Utilities': CategoryStyle(Color(0xFF2EC4D6), Icons.bolt_rounded),
  'Bike': CategoryStyle(Color(0xFFFF7A45), Icons.two_wheeler_rounded),
  'Personal': CategoryStyle(Color(0xFFE86BB5), Icons.face_retouching_natural_rounded),
  'Investment': CategoryStyle(Color(0xFF8BC34A), Icons.trending_up_rounded),
};

CategoryStyle styleFor(String category) =>
    kCategoryStyles[category] ?? const CategoryStyle(Color(0xFF9E9E9E), Icons.receipt_long_rounded);

const Color kNeedColor = Color(0xFF4F8EF7);
const Color kWantColor = Color(0xFFF5A524);

IconData paymentIcon(String method) => switch (method) {
      'Cash' => Icons.payments_rounded,
      'Card' => Icons.credit_card_rounded,
      _ => Icons.qr_code_2_rounded,
    };
