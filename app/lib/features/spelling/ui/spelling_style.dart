import 'package:flutter/material.dart';

import '../../../core/theme/app_fonts.dart';

/// Calm pastel palette for the spelling game: cream background (not pure
/// white), soft but clear contrast, no harsh reds.
class SpellingColors {
  const SpellingColors._();

  static const background = Color(0xFFFFF6E5);
  static const ink = Color(0xFF2F3A56);
  static const tile = Color(0xFFFFFFFF);
  static const tileShadow = Color(0x332F3A56);
  static const slot = Color(0xFFEDE7F6);
  static const slotBorder = Color(0xFFB9A8DE);
  static const slotHover = Color(0xFFD9CCF2);
  static const correct = Color(0xFF6BCB77);
  static const replay = Color(0xFF4D96FF);
  static const play = Color(0xFFFF9F45);
  static const neutralButton = Color(0xFFB8C4D6);
  static const star = Color(0xFFFFC93C);
  static const starSoft = Color(0xFFFFE3A3);
  static const starEmpty = Color(0xFFD9D4C7);
  static const highlight = Color(0xFFFFE7A0);
  static const card = Color(0xFFFFFFFF);
}

TextStyle letterStyle(double size) => TextStyle(
      fontFamily: AppFonts.latin,
      fontSize: size,
      fontWeight: FontWeight.w600,
      color: SpellingColors.ink,
      letterSpacing: size * 0.08,
      height: 1.0,
    );

/// What each icon button says when it is long-pressed (no reading needed).
class ButtonPurpose {
  const ButtonPurpose._();

  static const play = "Let's play!";
  static const playAgain = 'Play again!';
  static const replay = 'Hear the word again.';
  static const check = 'Check my spelling.';
  static const home = 'Go back to the start.';
  static const back = 'Go back.';
  static const mute = 'Turn the sounds on or off.';
}
