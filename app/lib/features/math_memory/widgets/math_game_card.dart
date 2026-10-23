import 'package:flutter/material.dart';

import 'math_illustrations.dart';
import 'math_palette.dart';

/// Large, fully tappable game card on the Math game-selection screen.
class MathGameCard extends StatelessWidget {
  const MathGameCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.category,
    required this.categoryIcon,
    required this.art,
    required this.colors,
    required this.onPlay,
  });

  final String title;
  final String subtitle;
  final String category;
  final IconData categoryIcon;
  final MathArt art;
  final MathGameColors colors;
  final VoidCallback onPlay;

  static const _radius = BorderRadius.all(Radius.circular(28));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // One button node for screen readers instead of card + nested button.
    return Semantics(
      button: true,
      label: 'Play $title. $subtitle',
      onTap: onPlay,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: _radius,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [colors.light, colors.mid],
          ),
          border: Border.all(color: colors.accent.withValues(alpha: 0.25), width: 2),
          boxShadow: [
            BoxShadow(
              color: colors.accent.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: _radius,
            onTap: onPlay,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final artSize = (constraints.maxWidth * 0.36).clamp(96.0, 150.0);

                  return Row(
                    children: [
                      SizedBox.square(dimension: artSize, child: MathIllustration(art)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _CategoryChip(
                              label: category,
                              icon: categoryIcon,
                              color: colors.accent,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              title,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: MathPalette.ink,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: MathPalette.ink.withValues(alpha: 0.85),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: onPlay,
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text('Play Now'),
                              style: FilledButton.styleFrom(
                                backgroundColor: colors.accent,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(48),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                shape: const StadiumBorder(),
                                textStyle: theme.textTheme.labelLarge?.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
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
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({required this.label, required this.icon, required this.color});

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
