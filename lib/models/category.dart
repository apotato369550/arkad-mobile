import 'package:flutter/material.dart';

const List<String> defaultIncomeCategories = [
  'Salary',
  'Wage',
  'Allowance',
  'Bonus',
  'Gift',
  'Savings',
];

const List<String> defaultExpenseCategories = [
  'Groceries',
  'Dining',
  'Subscriptions',
  'Transport',
  'Housing',
  'Utilities',
  'Entertainment',
  'Health',
  'Travel',
  'General',
];

/// See STYLE_GUIDE.md § Dashboard components — recommended category icon mapping.
IconData iconForCategory(String category) {
  switch (category) {
    case 'Salary':
      return Icons.work_outline;
    case 'Wage':
      return Icons.schedule_outlined;
    case 'Allowance':
      return Icons.account_balance_wallet_outlined;
    case 'Bonus':
      return Icons.card_giftcard_outlined;
    case 'Gift':
      return Icons.redeem_outlined;
    case 'Savings':
      return Icons.savings_outlined;
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
    case 'Utilities':
      return Icons.bolt_outlined;
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
