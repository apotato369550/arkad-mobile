import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radii.dart';
import 'app_text_styles.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.darkGreen,
        onPrimary: AppColors.paper,
        secondary: AppColors.pastelYellow,
        onSecondary: AppColors.ink,
        surface: AppColors.paper,
        onSurface: AppColors.ink,
        error: AppColors.clay,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.ink,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: AppTextStyles.cardHeading(),
        iconTheme: const IconThemeData(color: AppColors.ink),
      ),
      drawerTheme: const DrawerThemeData(backgroundColor: AppColors.paper),
      textTheme: base.textTheme.copyWith(
        bodyMedium: AppTextStyles.body(),
        bodyLarge: AppTextStyles.body(),
        titleLarge: AppTextStyles.cardHeading(),
        headlineMedium: AppTextStyles.pageHeading(),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.darkGreen,
          foregroundColor: AppColors.paper,
          textStyle: AppTextStyles.buttonLabel(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          side: BorderSide(color: AppColors.ink10),
          textStyle: AppTextStyles.buttonLabel(color: AppColors.ink),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.pill)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          textStyle: AppTextStyles.buttonLabel(color: AppColors.ink),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cream,
        hintStyle: AppTextStyles.body(color: AppColors.ink40),
        labelStyle: AppTextStyles.metadata(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: AppColors.ink10),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: BorderSide(color: AppColors.ink10),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.input),
          borderSide: const BorderSide(color: AppColors.darkGreen, width: 1.5),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.paper,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
          side: BorderSide(color: AppColors.ink10),
        ),
      ),
      dividerTheme: DividerThemeData(color: AppColors.ink10, thickness: 1, space: 1),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
