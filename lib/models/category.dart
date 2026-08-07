import 'package:flutter/material.dart';

const List<String> defaultIncomeCategories = ['Income'];

const List<String> defaultExpenseCategories = [
  'Groceries',
  'Dining',
  'Subscriptions',
  'Transport',
  'Housing',
  'Entertainment',
  'Health',
  'Travel',
  'General',
];

/// See STYLE_GUIDE.md § Dashboard components — recommended category icon mapping.
IconData iconForCategory(String category) {
  switch (category) {
    case 'Income':
      return Icons.arrow_downward;
    case 'Groceries':
      return Icons.shopping_basket_outlined;
    case 'Dining':
      return Icons.restaurant_outlined;
    case 'Subscriptions':
      return Icons.repeat;
    case 'Transport':
      return Icons.directions_car_outlined;
    case 'Housing':
      return Icons.home_outlined;
    case 'Entertainment':
      return Icons.movie_outlined;
    case 'Health':
      return Icons.local_hospital_outlined;
    case 'Travel':
      return Icons.flight_outlined;
    default:
      return Icons.credit_card_outlined;
  }
}
