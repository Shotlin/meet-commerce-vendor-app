import 'package:flutter/material.dart';

/// FreshCuts Vendor App brand tokens.
///
/// Source of truth: the existing customer app's real tokens
/// (meet-commerce-mobile-main/lib/core/theme/app_colors.dart) — the
/// blueprint design system (02_VENDOR_UI_UX_DESIGN_SYSTEM.md §2) mandates
/// reusing existing brand tokens over the fallback palette.
class AppColors {
  AppColors._();

  // Brand
  static const Color brandRed = Color(0xFFD02428);
  static const Color brandRedDark = Color(0xFFA81C1F);
  static const Color brandRedSurface = Color(0xFFFBEAEA);

  // Semantic
  static const Color success = Color(0xFF22A95C);
  static const Color successSurface = Color(0xFFEAF8EF);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFFF7E6);
  static const Color error = Color(0xFFD92D20);
  static const Color errorSurface = Color(0xFFFEF0F0);
  static const Color info = Color(0xFF2563EB);
  static const Color infoSurface = Color(0xFFEFF6FF);

  // Neutrals
  static const Color ink = Color(0xFF101114);
  static const Color inkSecondary = Color(0xFF344054);
  static const Color muted = Color(0xFF667085);
  static const Color subtle = Color(0xFF98A2B3);
  static const Color canvas = Color(0xFFF7F7F8);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFEAECF0);
  static const Color divider = Color(0xFFEEF0F2);
}
