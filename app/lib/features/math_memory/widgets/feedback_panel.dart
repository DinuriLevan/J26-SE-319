import 'package:flutter/material.dart';

import '../engine/activity_phase.dart';
import 'math_palette.dart';
import 'reward_art.dart';

/// Friendly words for each outcome. Rotates by activity index so feedback
/// doesn't feel repetitive, but stays deterministic.
class FeedbackWords {
  const FeedbackWords._();

  static const _praise = ['Great job!', 'Well done!', 'You got it!', 'Super!', 'Brilliant!'];

  static String praise(int index) => _praise[index % _praise.length];

  static const tryAgain = 'Good try! Try again.';
  static const keepGoing = "Let's keep going!";
}

/// Feedback under an activity: art, a short title, one line of help, and a
/// Next button once the activity is decided. Never uses harsh wording.
class FeedbackPanel extends StatelessWidget {
  const FeedbackPanel({
    super.key,
    required this.phase,
    required this.title,
    required this.message,
    required this.colors,
    required this.onNext,
    this.pointsEarned,
    this.nextLabel = 'Next',
    this.showNextButton = true,
  });

  /// Only [ActivityPhase.hint], [ActivityPhase.correct] and
  /// [ActivityPhase.revealed] show anything.
  final ActivityPhase phase;
  final String title;
  final String message;
  final MathGameColors colors;
  final VoidCallback onNext;

  /// Shown as "+10 points" in scored attempts.
  final int? pointsEarned;

  final String nextLabel;

  /// Hidden in tutorial practice, where the tutorial's own Next is used.
  final bool showNextButton;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final art = switch (phase) {
      ActivityPhase.correct => RewardArt.correct,
      ActivityPhase.revealed => RewardArt.reveal,
      _ => RewardArt.hint,
    };
    final background = switch (phase) {
      ActivityPhase.correct => const Color(0xFFE6F7E9),
      _ => const Color(0xFFFFF6DB),
    };
    final border = switch (phase) {
      ActivityPhase.correct => MathPalette.leaf,
      _ => const Color(0xFFF2B33D),
    };

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: ValueKey('feedback-${phase.name}'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: border.withValues(alpha: 0.5), width: 2),
        ),
        child: Column(
          children: [
            Row(
              children: [
                RewardArtView(art, size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: MathPalette.ink,
                        ),
                      ),
                      if (message.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          message,
                          style: theme.textTheme.bodyLarge?.copyWith(color: MathPalette.ink),
                        ),
                      ],
                    ],
                  ),
                ),
                if (pointsEarned != null && pointsEarned! > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(
                      '+$pointsEarned',
                      semanticsLabel: 'plus $pointsEarned points',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MathPalette.leaf,
                      ),
                    ),
                  ),
              ],
            ),
            if (phase.awaitingNext && showNextButton) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onNext,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: Text(nextLabel),
                style: mathPrimaryButtonStyle(context, colors),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Keeps a game's Next button on screen on small phones:
/// scrolls to the top for a new activity, or to the feedback once the
/// activity is decided. Hints don't scroll, so the choices stay in view.
class GameScrollFollower {
  final controller = ScrollController();
  final feedbackKey = GlobalKey();
  int _lastIndex = 0; // Every attempt starts at its first activity.

  void onActivityChanged({required int index, required bool showingFeedback}) {
    final newActivity = index != _lastIndex;
    _lastIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (newActivity) {
        if (controller.hasClients) controller.jumpTo(0);
      } else if (showingFeedback) {
        final context = feedbackKey.currentContext;
        if (context != null) {
          Scrollable.ensureVisible(
            context,
            duration: const Duration(milliseconds: 250),
            alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          );
        }
      }
    });
  }

  void dispose() => controller.dispose();
}

/// Large rounded button in a game's accent colour, matching the menu's
/// Play Now / Start Game buttons.
ButtonStyle mathPrimaryButtonStyle(BuildContext context, MathGameColors colors, {double height = 56}) {
  return FilledButton.styleFrom(
    backgroundColor: colors.accent,
    foregroundColor: Colors.white,
    minimumSize: Size.fromHeight(height),
    shape: const StadiumBorder(),
    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
  );
}

/// Outlined companion to [mathPrimaryButtonStyle].
ButtonStyle mathSecondaryButtonStyle(BuildContext context, MathGameColors colors, {double height = 56}) {
  return OutlinedButton.styleFrom(
    foregroundColor: colors.accent,
    minimumSize: Size.fromHeight(height),
    shape: const StadiumBorder(),
    side: BorderSide(color: colors.accent, width: 2),
    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
  );
}
