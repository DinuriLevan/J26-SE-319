import 'package:flutter/material.dart';

import '../../shared/widgets/app_drawer.dart';
import 'memory_match/memory_match_screen.dart';
import 'number_quest/number_quest_screen.dart';
import 'widgets/math_game_card.dart';
import 'widgets/math_illustrations.dart';
import 'widgets/math_palette.dart';

/// Entry screen for the Math tab: choose Number Quest or Memory Match.
class MathGameSelectionScreen extends StatelessWidget {
  const MathGameSelectionScreen({super.key});

  /// Below this width the cards stack vertically; above it they sit side by side.
  static const _wideLayoutWidth = 720.0;

  @override
  Widget build(BuildContext context) {
    final numberQuestCard = MathGameCard(
      title: 'Number Quest',
      subtitle: 'Count, solve and collect stars!',
      category: 'Maths Adventure',
      categoryIcon: Icons.explore_rounded,
      art: MathArt.numberQuest,
      colors: MathGameColors.numberQuest,
      onPlay: () => _open(context, const NumberQuestScreen()),
    );
    final memoryMatchCard = MathGameCard(
      title: 'Memory Match',
      subtitle: 'Look carefully, remember and match!',
      category: 'Brain & Memory',
      categoryIcon: Icons.psychology_rounded,
      art: MathArt.memoryMatch,
      colors: MathGameColors.memoryMatch,
      onPlay: () => _open(context, const MemoryMatchScreen()),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Math & Memory'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= _wideLayoutWidth;

                  return Column(
                    children: [
                      const _Header(),
                      const SizedBox(height: 20),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: numberQuestCard),
                            const SizedBox(width: 16),
                            Expanded(child: memoryMatchCard),
                          ],
                        )
                      else ...[
                        numberQuestCard,
                        const SizedBox(height: 16),
                        memoryMatchCard,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MathPalette.headerLight, MathPalette.headerMid],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Let's Play & Learn!",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MathPalette.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose a game and have fun learning!',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: MathPalette.ink.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const SizedBox(width: 96, height: 96, child: MathIllustration(MathArt.header)),
        ],
      ),
    );
  }
}
