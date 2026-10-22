import 'package:flutter/material.dart';

import '../../game/spelling_game_controller.dart';
import '../spelling_style.dart';

/// Row of stars at the top that fills as words are completed (no numbers).
/// Solved words get a gold star; words where the answer was shown get a
/// softer star, so every finished word still counts as progress.
class ProgressStars extends StatelessWidget {
  const ProgressStars({super.key, required this.outcomes, required this.currentIndex});

  final List<WordOutcome?> outcomes;
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth / outcomes.length).clamp(14.0, 34.0);
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < outcomes.length; i++)
              AnimatedScale(
                duration: const Duration(milliseconds: 300),
                scale: i == currentIndex && outcomes[i] == null ? 1.15 : 1,
                child: Icon(
                  outcomes[i] == null ? Icons.star_outline_rounded : Icons.star_rounded,
                  size: size,
                  color: switch (outcomes[i]) {
                    WordOutcome.solved => SpellingColors.star,
                    WordOutcome.revealed => SpellingColors.starSoft,
                    null => i == currentIndex ? SpellingColors.star : SpellingColors.starEmpty,
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
