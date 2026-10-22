import 'package:flutter/material.dart';

import '../spelling_style.dart';

/// A large, rounded lowercase letter tile.
class LetterTileView extends StatelessWidget {
  const LetterTileView({
    super.key,
    required this.letter,
    required this.size,
    this.lifted = false,
    this.highlighted = false,
  });

  final String letter;
  final double size;
  final bool lifted;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: highlighted ? SpellingColors.highlight : SpellingColors.tile,
        borderRadius: BorderRadius.circular(size * 0.24),
        boxShadow: [
          BoxShadow(
            color: SpellingColors.tileShadow,
            blurRadius: lifted ? 18 : 6,
            offset: Offset(0, lifted ? 10 : 4),
          ),
        ],
      ),
      child: Text(letter.toLowerCase(), style: letterStyle(size * 0.56)),
    );
  }
}

/// Empty spot (in the tray or a slot) shown where a tile could go.
class EmptySpot extends StatelessWidget {
  const EmptySpot({
    super.key,
    required this.size,
    this.color = Colors.transparent,
    this.borderColor,
  });

  final double size;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: borderColor == null ? null : Border.all(color: borderColor!, width: 3),
      ),
    );
  }
}
