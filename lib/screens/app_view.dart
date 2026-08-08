import 'package:flutter/material.dart';

enum AppView {
  dashboard('Dashboard', Icons.grid_view_rounded),
  transactions('Transactions', Icons.receipt_long_outlined),
  categories('Categories', Icons.category_outlined),
  profile('Profile', Icons.person_outline),
  settings('Settings', Icons.settings_outlined);

  const AppView(this.label, this.icon);
  final String label;
  final IconData icon;
}
