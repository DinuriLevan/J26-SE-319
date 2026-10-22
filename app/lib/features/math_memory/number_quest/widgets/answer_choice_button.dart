import 'package:flutter/material.dart';

import '../../widgets/math_palette.dart';

enum ChoiceState {
  /// Can be tapped.
  idle,

  /// Tapped and right.
  correct,

  /// Tapped and wrong — stays visible but can't be tapped again.
  tried,

  /// Not tapped, but shown as the answer after the last try.
  revealed,

  /// Activity decided; this option is no longer relevant.
  inactive,
}

/// A big, easy-to-tap number answer. State is shown with colour *and* an
/// icon, never colour alone.
class AnswerChoiceButton extends StatelessWidget {
  const AnswerChoiceButton({
    super.key,
    required this.value,
    required this.state,
    required this.colors,
    required this.onTap,
  });

  final int value;
  final ChoiceState state;
  final MathGameColors colors;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (background, foreground, border, icon) = switch (state) {
      ChoiceState.idle => (Colors.white, MathPalette.ink, colors.accent.withValues(alpha: 0.45), null),
      ChoiceState.correct => (MathPalette.leaf, Colors.white, MathPalette.leaf, Icons.check_circle_rounded),
      ChoiceState.revealed => (const Color(0xFFE6F7E9), MathPalette.ink, MathPalette.leaf, Icons.check_circle_rounded),
      ChoiceState.tried => (const Color(0xFFF1F0EC), MathPalette.ink.withValues(alpha: 0.45), const Color(0xFFDAD6CC), Icons.close_rounded),
      ChoiceState.inactive => (Colors.white, MathPalette.ink.withValues(alpha: 0.45), const Color(0xFFDAD6CC), null),
    };
    final hint = switch (state) {
      ChoiceState.correct => ', correct',
      ChoiceState.revealed => ', the answer',
      ChoiceState.tried => ', already tried',
      _ => '',
    };

    return Semantics(
      button: true,
      enabled: onTap != null,
      label: '$value$hint',
      excludeSemantics: true,
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: border, width: 3),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 84,
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$value',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: foreground,
                        ),
                  ),
                ),
                if (icon != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Icon(
                      icon,
                      size: 22,
                      color: state == ChoiceState.correct ? Colors.white : foreground,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
