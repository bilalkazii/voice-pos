import 'package:flutter/material.dart';

import 'tokens.dart';

/// Clean Material 3 light theme for Voice POS.
///
/// All color / shape / size decisions flow from [AppTokens].
/// Widgets must use `Theme.of(context)` — never hardcode values.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppTokens.voiceBlue,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppTokens.voiceBlue,
      onPrimary: Colors.white,
      secondary: AppTokens.checkoutGreen,
      onSecondary: Colors.white,
      error: AppTokens.destructiveRed,
      onError: Colors.white,
      surface: AppTokens.surface,
      onSurface: AppTokens.onSurface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppTokens.background,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppTokens.surface,
        foregroundColor: AppTokens.onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: AppTokens.onSurface,
          fontSize: AppTokens.fontTitle,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppTokens.surface,
        elevation: AppTokens.elevationCard,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusCard),
          side: const BorderSide(color: AppTokens.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppTokens.voiceBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(
            double.infinity,
            AppTokens.buttonHeightLarge,
          ),
          textStyle: const TextStyle(
            fontSize: AppTokens.fontTitle,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(
            double.infinity,
            AppTokens.buttonHeightLarge,
          ),
          textStyle: const TextStyle(
            fontSize: AppTokens.fontTitle,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(
            double.infinity,
            AppTokens.buttonHeightMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTokens.radiusButton),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(
            AppTokens.minTouchTarget,
            AppTokens.minTouchTarget,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppTokens.voiceBlue,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppTokens.surface,
        indicatorColor: AppTokens.voiceBlueSoft,
        labelTextStyle: WidgetStateProperty.all(
          const TextStyle(
            fontSize: AppTokens.fontLabel,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: AppTokens.fontDisplay,
          fontWeight: FontWeight.w800,
          color: AppTokens.onSurface,
        ),
        headlineSmall: TextStyle(
          fontSize: AppTokens.fontHeadline,
          fontWeight: FontWeight.w700,
          color: AppTokens.onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: AppTokens.fontTitle,
          fontWeight: FontWeight.w700,
          color: AppTokens.onSurface,
        ),
        bodyLarge: TextStyle(
          fontSize: AppTokens.fontBody,
          color: AppTokens.onSurface,
        ),
        bodyMedium: TextStyle(
          fontSize: AppTokens.fontBody,
          color: AppTokens.onSurfaceVariant,
        ),
        labelLarge: TextStyle(
          fontSize: AppTokens.fontLabel,
          fontWeight: FontWeight.w600,
          color: AppTokens.onSurfaceVariant,
        ),
      ),
      dividerTheme: const DividerThemeData(color: AppTokens.border),
    );
  }
}
