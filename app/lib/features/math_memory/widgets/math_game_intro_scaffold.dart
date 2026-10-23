import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'kid_intro_view.dart';
import 'math_illustrations.dart';
import 'math_palette.dart';
import 'parent_support.dart';

/// Shared layout for a game's intro screen. Children see a picture-first
/// page ([KidIntroView]); with Parent support on, the written version below.
class MathGameIntroScaffold extends ConsumerWidget {
  const MathGameIntroScaffold({
    super.key,
    required this.title,
    required this.headline,
    required this.intro,
    required this.steps,
    required this.kidSteps,
    required this.art,
    required this.colors,
    required this.onStart,
    required this.onHowToPlay,
  });

  /// Present in both modes, so callers and tests needn't know which is on.
  static const startGameKey = ValueKey('start-game');
  static const howToPlayKey = ValueKey('how-to-play');

  final String title;
  final String headline;
  final String intro;

  /// Written steps (parent support).
  final List<(IconData, String)> steps;

  /// Picture steps (child mode); their labels are read by screen readers.
  final List<KidStep> kidSteps;

  final MathArt art;
  final MathGameColors colors;
  final VoidCallback onStart;

  /// Reopens the tutorial.
  final VoidCallback onHowToPlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parentSupport = ref.watch(parentSupportProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [ParentSupportToggle(colors: colors)],
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: parentSupport
              ? KeyedSubtree(key: const ValueKey('parent'), child: _writtenIntro(context))
              : KidIntroView(
                  key: const ValueKey('kid'),
                  title: title,
                  description: '$headline $intro',
                  art: art,
                  colors: colors,
                  steps: kidSteps,
                  onStart: onStart,
                  onHowToPlay: onHowToPlay,
                  startKey: startGameKey,
                  howToPlayKey: howToPlayKey,
                ),
        ),
      ),
    );
  }

  Widget _writtenIntro(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            children: [
              Container(
                height: 200,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [colors.light, colors.mid],
                  ),
                ),
                child: MathIllustration(art),
              ),
              const SizedBox(height: 24),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MathPalette.ink,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                intro,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: MathPalette.ink.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 20),
              for (final (i, (icon, text)) in steps.indexed)
                _StepTile(number: i + 1, icon: icon, text: text, colors: colors),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: startGameKey,
                onPressed: onStart,
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text('Start Game'),
                style: FilledButton.styleFrom(
                  backgroundColor: colors.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(56),
                  shape: const StadiumBorder(),
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                key: howToPlayKey,
                onPressed: onHowToPlay,
                icon: const Icon(Icons.help_outline_rounded),
                label: const Text('How to play'),
                style: TextButton.styleFrom(
                  foregroundColor: colors.accent,
                  minimumSize: const Size(48, 48),
                  textStyle: theme.textTheme.labelLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.number,
    required this.icon,
    required this.text,
    required this.colors,
  });

  final int number;
  final IconData icon;
  final String text;
  final MathGameColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colors.light,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colors.accent.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colors.accent,
              child: Text(
                '$number',
                style:
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                text,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(color: MathPalette.ink),
              ),
            ),
            Icon(icon, color: colors.accent, size: 28),
          ],
        ),
      ),
    );
  }
}
