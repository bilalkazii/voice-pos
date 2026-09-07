import 'package:flutter/material.dart';

/// Centralized design tokens for Voice POS.
///
/// Do NOT scatter colors, spacing, radii, or typography values in widgets.
/// Import this file (via `app_theme.dart`) instead.
///
/// Semantics:
/// - Blue = voice interaction
/// - Green = checkout / payment actions
/// - Red = destructive actions only
abstract final class AppTokens {
  // Colors — light, clean POS appearance.
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Colors.white;
  static const Color onSurface = Color(0xFF1A1D21);
  static const Color onSurfaceVariant = Color(0xFF6B7280);

  static const Color voiceBlue = Color(0xFF2563EB);
  static const Color voiceBlueDark = Color(0xFF1D4ED8);
  static const Color voiceBlueSoft = Color(0xFFE3ECFD);

  static const Color checkoutGreen = Color(0xFF16A34A);
  static const Color checkoutGreenDark = Color(0xFF15803D);
  static const Color checkoutGreenSoft = Color(0xFFDCFCE7);

  static const Color destructiveRed = Color(0xFFDC2626);
  static const Color destructiveRedSoft = Color(0xFFFEE2E2);

  static const Color border = Color(0xFFE5E7EB);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFF59E0B);

  // Spacing (dp).
  static const double space4 = 4;
  static const double space8 = 8;
  static const double space12 = 12;
  static const double space16 = 16;
  static const double space20 = 20;
  static const double space24 = 24;
  static const double space32 = 32;

  static const double screenPadding = 16;

  // Corner radii.
  static const double radiusCard = 16;
  static const double radiusButton = 14;
  static const double radiusSheet = 20;
  static const double radiusChip = 999;

  // Touch targets — comfortable one-handed Android use, min ~48dp.
  static const double buttonHeightLarge = 56;
  static const double buttonHeightMedium = 48;
  static const double minTouchTarget = 48;

  // Icon sizes.
  static const double iconSmall = 18;
  static const double iconMedium = 24;
  static const double iconLarge = 32;
  static const double iconVoice = 36;

  // Typography scale (logical px, Material 3 aligned).
  static const double fontDisplay = 28;
  static const double fontHeadline = 22;
  static const double fontTitle = 17;
  static const double fontBody = 15;
  static const double fontLabel = 13;
  static const double fontTotal = 24;

  // Elevation.
  static const double elevationCard = 0;
}
