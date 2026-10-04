import 'package:flutter/material.dart';

import 'app_fonts.dart';

/// Shared placeholder theme: large touch targets, bumped type sizing, and a
/// simple color system. Not final visual design — each component should feel
/// free to layer its own styling on top within its own feature folder.
class AppTheme {
  const AppTheme._();

  // Minimum tappable target recommended for young children (above Material's
  // 48dp baseline would be even safer, but 48 is a reasonable floor).
  static const double minTouchTarget = 48.0;

  static const Color primary = Color(0xFF4D96FF);
  static const Color secondary = Color(0xFF6BCB77);
  static const Color background = Color(0xFFFFFBF2);
  static const Color error = Color(0xFFFF6B6B);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        error: error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,
      fontFamily: AppFonts.latin,
      // Falling back to the Sinhala font lets a single Text widget render
      // mixed Sinhala/Latin content correctly without per-widget logic.
      fontFamilyFallback: const [AppFonts.sinhala],
    );

    return base.copyWith(
      textTheme: _scaled(base.textTheme, 1.15),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          textStyle: const TextStyle(fontSize: 18),
        ),
      ),
      // The home shell uses Material 3's NavigationBar, not the older
      // BottomNavigationBar, so it's this theme type that applies.
      navigationBarTheme: const NavigationBarThemeData(
        labelTextStyle: WidgetStatePropertyAll(TextStyle(fontSize: 14)),
      ),
    );
  }

  /// Scales only the text styles that already declare a fontSize — Material
  /// 3's default TextTheme includes some styles with a null fontSize, and
  /// TextTheme.apply(fontSizeFactor:) asserts on those, so we scale manually.
  static TextTheme _scaled(TextTheme theme, double factor) {
    TextStyle? scale(TextStyle? style) {
      if (style?.fontSize == null) return style;
      return style!.copyWith(fontSize: style.fontSize! * factor);
    }

    return TextTheme(
      displayLarge: scale(theme.displayLarge),
      displayMedium: scale(theme.displayMedium),
      displaySmall: scale(theme.displaySmall),
      headlineLarge: scale(theme.headlineLarge),
      headlineMedium: scale(theme.headlineMedium),
      headlineSmall: scale(theme.headlineSmall),
      titleLarge: scale(theme.titleLarge),
      titleMedium: scale(theme.titleMedium),
      titleSmall: scale(theme.titleSmall),
      bodyLarge: scale(theme.bodyLarge),
      bodyMedium: scale(theme.bodyMedium),
      bodySmall: scale(theme.bodySmall),
      labelLarge: scale(theme.labelLarge),
      labelMedium: scale(theme.labelMedium),
      labelSmall: scale(theme.labelSmall),
    );
  }
}
