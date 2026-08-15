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

/// Icon keys available for category icons — one per file in
/// `assets/extracted/tinted/{green,red}/icon_<key>.png`. See
/// STYLE_GUIDE.md § Category management.
const List<String> categoryIconKeys = [
  'income',
  'cash',
  'wallet',
  'savings_1',
  'savings_2',
  'rewards',
  'goals',
  'coin',
  'groceries',
  'dining',
  'subscriptions',
  'transport',
  'housing',
  'bills_up',
  'credit_cards',
  'debts_1',
  'debts_2',
  'investments',
  'stocks',
  'crypto',
  'balance',
  'trend',
  'analysis',
  'taxes',
  'receipts',
  'transfer',
  'transactions',
  'categories',
  'advisor',
  'profile',
  'security',
  'settings',
  'notifications',
  'search',
  'filter',
  'sort',
  'export',
  'add',
  'chat',
  'general',
];

/// Fallback ("etcetera") icon for categories with no dedicated mapping
/// below and no user-chosen icon.
const String categoryIconFallbackKey = 'general';

/// Default icon key per built-in category (see [defaultIncomeCategories],
/// [defaultExpenseCategories]). Categories not listed here — custom ones,
/// and defaults with no good dedicated icon in the extracted set — fall
/// back to [categoryIconFallbackKey].
const Map<String, String> _defaultCategoryIconKeys = {
  'Salary': 'income',
  'Wage': 'cash',
  'Allowance': 'wallet',
  'Bonus': 'savings_1',
  'Gift': 'rewards',
  'Savings': 'savings_2',
  'Groceries': 'groceries',
  'Dining': 'dining',
  'Subscriptions': 'subscriptions',
  'Transport': 'transport',
  'Housing': 'housing',
  'Utilities': 'bills_up',
};

/// Resolves the icon key for a category: a user-chosen icon (for custom
/// categories, keyed by name in [customIcons]) takes priority, then the
/// built-in default mapping, then [categoryIconFallbackKey].
String categoryIconKeyFor(String category, {Map<String, String> customIcons = const {}}) {
  return customIcons[category] ?? _defaultCategoryIconKeys[category] ?? categoryIconFallbackKey;
}

/// Asset path for a category icon, pre-tinted red (expense) or green
/// (income) — see assets/prep_category_icons.py.
String categoryIconAsset(String key, {required bool isIncome}) {
  final color = isIncome ? 'green' : 'red';
  return 'assets/extracted/tinted/$color/icon_$key.png';
}

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
