import 'package:flutter/material.dart';

import 'math_palette.dart';

/// "Question 3 of 10" with a rounded progress bar and, for scored attempts,
/// the running points.
class GameProgressHeader extends StatelessWidget {
  const GameProgressHeader({
    super.key,
    required this.label,
    required this.index,
    required this.total,
    required this.colors,
    this.points,
  });

  /// "Question" or "Round".
  final String label;

  /// 0-based.
  final int index;
  final int total;
  final MathGameColors colors;

  /// Null hides the points pill (baseline attempts).
  final int? points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$label ${index + 1} of $total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: MathPalette.ink,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (index + 1) / total,
                  minHeight: 10,
                  color: colors.accent,
                  backgroundColor: colors.mid,
                ),
              ),
            ],
          ),
        ),
        if (points != null) ...[
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: colors.light,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: colors.accent.withValues(alpha: 0.3), width: 1.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: Color(0xFFF59F00), size: 22),
                const SizedBox(width: 4),
                Text(
                  '$points',
                  semanticsLabel: '$points points',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: MathPalette.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
