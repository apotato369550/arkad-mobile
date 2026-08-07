import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Three typefaces, strict roles. See STYLE_GUIDE.md § Typography.
/// Fraunces = display/editorial. Manrope = UI/body. DM Mono = ledger data only.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle fraunces({
    double fontSize = 24,
    FontWeight fontWeight = FontWeight.w600,
    Color color = AppColors.ink,
    double? height,
  }) =>
      GoogleFonts.fraunces(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  static TextStyle manrope({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.ink,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.manrope(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle dmMono({
    double fontSize = 15,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.ink,
    double? height,
  }) =>
      GoogleFonts.dmMono(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      );

  // Pre-composed roles used across the app.
  static TextStyle pageHeading({Color color = AppColors.ink}) =>
      fraunces(fontSize: 32, fontWeight: FontWeight.w700, color: color, height: 1.02);

  static TextStyle cardHeading({Color color = AppColors.ink}) =>
      fraunces(fontSize: 22, fontWeight: FontWeight.w600, color: color);

  static TextStyle balance({Color color = Colors.white}) =>
      dmMono(fontSize: 44, fontWeight: FontWeight.w700, color: color, height: 1.0);

  static TextStyle amount({Color color = AppColors.ink, double fontSize = 16}) =>
      dmMono(fontSize: fontSize, fontWeight: FontWeight.w600, color: color);

  static TextStyle body({Color color = AppColors.ink}) =>
      manrope(fontSize: 15, fontWeight: FontWeight.w400, color: color, height: 1.5);

  static TextStyle buttonLabel({Color color = AppColors.paper}) =>
      manrope(fontSize: 14, fontWeight: FontWeight.w700, color: color);

  static TextStyle eyebrow({Color color = AppColors.ink}) => manrope(
        fontSize: 10,
        fontWeight: FontWeight.w800,
        color: color,
        letterSpacing: 2.0,
      );

  static TextStyle metadata({Color? color}) =>
      manrope(fontSize: 12, fontWeight: FontWeight.w500, color: color ?? AppColors.ink60);
}
