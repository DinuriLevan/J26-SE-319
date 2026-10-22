import 'package:flutter/material.dart';

import '../engine/scoring.dart';
import 'feedback_panel.dart';
import 'math_palette.dart';
import 'reward_art.dart';

/// Encouragement for a scored result. Every star count gets a kind message.
String encouragementFor(int stars, {required String threeStarMessage}) => switch (stars) {
      3 => threeStarMessage,
      2 => 'Great work! Keep it up!',
      1 => "Good effort! You're getting better!",
      _ => 'Thanks for playing! Practice makes progress.',
    };

/// Returns to the Math game menu (the app shell's first route).
void backToMathGames(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}

/// Shown after a baseline attempt. Deliberately has no score, percentage or
/// stars: the baseline is only for finding where to start.
class BaselineCompleteScreen extends StatelessWidget {
  const BaselineCompleteScreen({
    super.key,
    required this.gameTitle,
    required this.colors,
    required this.onPlayAgain,
  });

  final String gameTitle;
  final MathGameColors colors;
  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ResultScaffold(
      title: gameTitle,
      colors: colors,
      onPlayAgain: onPlayAgain,
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.light, colors.mid],
            ),
          ),
          child: const Center(child: RewardArtView(RewardArt.explore, size: 168)),
        ),
        const SizedBox(height: 24),
        Text(
          'Great exploring!',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: MathPalette.ink,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Let's find the activities that suit you.",
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(color: MathPalette.ink),
        ),
      ],
    );
  }
}

/// Shown after a scored attempt: stars, correct answers, percentage, points.
class ScoredResultsScreen extends StatelessWidget {
  const ScoredResultsScreen({
    super.key,
    required this.gameTitle,
    required this.colors,
    required this.score,
    required this.correctLabel,
    required this.message,
    required this.onPlayAgain,
  });

  final String gameTitle;
  final MathGameColors colors;
  final AttemptScore score;

  /// "Correct answers" or "Correct recalls".
  final String correctLabel;

  /// Encouragement, chosen by the game from the star count.
  final String message;

  final VoidCallback onPlayAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _ResultScaffold(
      title: gameTitle,
      colors: colors,
      onPlayAgain: onPlayAgain,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [colors.light, colors.mid],
            ),
          ),
          child: Column(
            children: [
              StarRatingView(earned: score.stars, size: 76),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MathPalette.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: correctLabel,
                value: '${score.correct} of ${score.total}',
                colors: colors,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(label: 'Score', value: '${score.percentage}%', colors: colors),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatTile(label: 'Points', value: '${score.points}', colors: colors),
            ),
          ],
        ),
      ],
    );
  }
}

class _ResultScaffold extends StatelessWidget {
  const _ResultScaffold({
    required this.title,
    required this.colors,
    required this.onPlayAgain,
    required this.children,
  });

  final String title;
  final MathGameColors colors;
  final VoidCallback onPlayAgain;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(title),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  ...children,
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: onPlayAgain,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Play Again'),
                    style: mathPrimaryButtonStyle(context, colors),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => backToMathGames(context),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Back to Games'),
                    style: mathSecondaryButtonStyle(context, colors),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.colors});

  final String label;
  final String value;
  final MathGameColors colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Column(
        children: [
          FittedBox(
            child: Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colors.accent,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: MathPalette.ink),
          ),
        ],
      ),
    );
  }
}
