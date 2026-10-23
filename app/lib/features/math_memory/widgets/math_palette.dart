import 'package:flutter/material.dart';

/// Colours shared by the Math section's game menu, intro screens and
/// illustrations. Accent colours are dark enough to carry white button text
/// at WCAG AA contrast.
class MathPalette {
  const MathPalette._();

  static const Color ink = Color(0xFF2B2D42);
  static const Color sky = Color(0xFF4D96FF);
  static const Color grass = Color(0xFF6BCB77);
  static const Color sun = Color(0xFFFFC93C);
  static const Color tangerine = Color(0xFFFF8C42);
  static const Color berry = Color(0xFFFF5C5C);
  static const Color grape = Color(0xFF8B5CF6);
  static const Color leaf = Color(0xFF3FA34D);
  static const Color stem = Color(0xFF8D5A3B);

  static const Color headerLight = Color(0xFFE6F1FF);
  static const Color headerMid = Color(0xFFD3E6FF);
}

/// Colour set for one game, so each card and its intro screen match.
class MathGameColors {
  const MathGameColors({
    required this.light,
    required this.mid,
    required this.accent,
  });

  /// Top-left of the card gradient.
  final Color light;

  /// Bottom-right of the card gradient and illustration backdrop.
  final Color mid;

  /// Buttons, chips and borders.
  final Color accent;

  static const numberQuest = MathGameColors(
    light: Color(0xFFFFF4E0),
    mid: Color(0xFFFFE1AD),
    accent: Color(0xFFC2410C),
  );

  static const memoryMatch = MathGameColors(
    light: Color(0xFFF3EEFF),
    mid: Color(0xFFDFD3FF),
    accent: Color(0xFF6D28D9),
  );
}
