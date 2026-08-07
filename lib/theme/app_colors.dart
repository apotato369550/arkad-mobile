import 'package:flutter/material.dart';

/// Arkad brand tokens — "the ledger in the garden".
/// See STYLE_GUIDE.md § Color system for usage rules.
class AppColors {
  AppColors._();

  static const cream = Color(0xFFF4F0E6);
  static const paper = Color(0xFFFCFBF7);
  static const ink = Color(0xFF24362D);
  static const darkGreen = Color(0xFF244F3A);
  static const sage = Color(0xFFB4C6AC);
  static const sageTint = Color(0xFFE3EBDF);
  static const pastelYellow = Color(0xFFF5D66B);
  static const clay = Color(0xFFC87865);

  static Color ink60 = ink.withValues(alpha: 0.6);
  static Color ink50 = ink.withValues(alpha: 0.5);
  static Color ink40 = ink.withValues(alpha: 0.4);
  static Color ink10 = ink.withValues(alpha: 0.1);
}
