import 'package:flutter/material.dart';

import '../game/spelling_game_controller.dart';
import 'game_view.dart';
import 'spelling_style.dart';
import 'widgets/big_icon_button.dart';
import 'widgets/mascot.dart';

/// After every 10 words: dancing mascot, the round's stars, ▶ for the next
/// 10 words, and below it a calm "See progress" button for the adult.
class RoundEndView extends StatelessWidget {
  const RoundEndView({
    super.key,
    required this.state,
    required this.act,
    required this.onTeacher,
    this.sessionOver = false,
  });

  final SpellingGameState state;
  final ActionHandler act;
  final VoidCallback onTeacher;

  /// Third round done: friendly goodbye instead of another round.
  final bool sessionOver;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Mascot(size: 150, mood: sessionOver ? MascotMood.cheer : MascotMood.dance),
                if (sessionOver) const Text('👋', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final outcome in state.outcomes)
                      Icon(
                        Icons.star_rounded,
                        size: 44,
                        color: outcome == WordOutcome.solved ? SpellingColors.star : SpellingColors.starSoft,
                      ),
                  ],
                ),
                const SizedBox(height: 40),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    BigIconButton(
                      icon: Icons.home_rounded,
                      color: SpellingColors.neutralButton,
                      size: sessionOver ? 110 : 72,
                      semanticLabel: 'Home',
                      onTap: () => act(SpellingAction.homePressed),
                      onExplain: () => act(SpellingAction.explainButton, {'purpose': ButtonPurpose.home}),
                    ),
                    if (!sessionOver) ...[
                      const SizedBox(width: 32),
                      Pulse(
                        child: BigIconButton(
                          icon: Icons.play_arrow_rounded,
                          color: SpellingColors.play,
                          size: 120,
                          semanticLabel: 'Next words',
                          onTap: () => act(SpellingAction.nextRoundPressed),
                          onExplain: () =>
                              act(SpellingAction.explainButton, {'purpose': ButtonPurpose.playAgain}),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 36),
                SeeProgressButton(onPressed: onTeacher),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Adult-facing, calm but easy to find: opens the Teacher View.
class SeeProgressButton extends StatelessWidget {
  const SeeProgressButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(260, 56),
        foregroundColor: const Color(0xFF3E4A5E),
        backgroundColor: Colors.white.withValues(alpha: 0.85),
        side: const BorderSide(color: Color(0xFFC9D0DC), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
      child: const Text('👩‍🏫  See progress'),
    );
  }
}
