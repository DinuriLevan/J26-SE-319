import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../widgets/math_palette.dart';
import '../../widgets/math_pictures.dart';
import '../engine/memory_match_models.dart';

/// The 3×3 Memory Match board. Cells with a picture show it face-up or as a
/// numbered face-down card; empty cells are faint placeholders.
class MemoryBoard extends StatelessWidget {
  const MemoryBoard({
    super.key,
    required this.round,
    required this.isRevealed,
    this.wrongCells = const {},
    this.correctCell,
    this.onTapCell,
  });

  final MemoryRound round;
  final bool Function(int cell) isRevealed;

  /// Face-down cards already tried (shown dimmed with a cross, not tappable).
  final Set<int> wrongCells;

  /// Face-up card to highlight as the answer.
  final int? correctCell;

  /// Null disables every card (e.g. while memorizing).
  final ValueChanged<int>? onTapCell;

  static const _gap = 10.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 380.0);
        final cell = (width - _gap * (memoryBoardColumns - 1)) / memoryBoardColumns;
        return Center(
          child: SizedBox(
            width: width,
            child: Wrap(
              spacing: _gap,
              runSpacing: _gap,
              children: [
                for (var i = 0; i < memoryBoardCells; i++)
                  SizedBox(
                    width: cell,
                    height: cell,
                    child: _buildCell(i),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCell(int cell) {
    final picture = round.board[cell];
    if (picture == null) return const _EmptySlot();

    final number = round.numberFor(cell)!;
    final revealed = isRevealed(cell);
    final wrong = wrongCells.contains(cell);
    final tappable = onTapCell != null && !revealed && !wrong;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation) => ScaleTransition(
        scale: Tween(begin: 0.85, end: 1.0).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      child: revealed
          ? _PictureCard(
              key: ValueKey('up-$cell'),
              cell: cell,
              highlighted: cell == correctCell,
              child: MathPictureView(picture),
            )
          : _NumberCard(
              key: ValueKey('down-$cell'),
              cell: cell,
              number: number,
              tried: wrong,
              onTap: tappable ? () => onTapCell!(cell) : null,
            ),
    );
  }
}

class _PictureCard extends StatelessWidget {
  const _PictureCard({
    super.key,
    required this.cell,
    required this.child,
    required this.highlighted,
  });

  final int cell;
  final Widget child;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: highlighted ? MathPalette.leaf : MathPalette.grape.withValues(alpha: 0.35),
                width: highlighted ? 4 : 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: MathPalette.ink.withValues(alpha: 0.1),
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: child,
          ),
        ),
        if (highlighted)
          const Positioned(
            top: -6,
            right: -6,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: Colors.white,
              child: Icon(Icons.check_circle_rounded, color: MathPalette.leaf, size: 26),
            ),
          ),
      ],
    );
  }
}

class _NumberCard extends StatelessWidget {
  const _NumberCard({
    super.key,
    required this.cell,
    required this.number,
    required this.tried,
    required this.onTap,
  });

  final int cell;
  final int number;
  final bool tried;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final base = tried ? const Color(0xFFD9D2EC) : MathPalette.grape;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: tried ? 'Card $number, already tried' : 'Card $number',
      excludeSemantics: true,
      child: Material(
        color: base,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
        elevation: tried ? 0 : 2,
        child: InkWell(
          key: ValueKey('memory-card-$number'),
          onTap: onTap,
          child: Container(
            margin: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.45), width: 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Text(
                    '$number',
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: tried ? MathPalette.ink.withValues(alpha: 0.4) : Colors.white,
                        ),
                  ),
                ),
                if (tried)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Icon(Icons.close_rounded, size: 20, color: MathPalette.ink.withValues(alpha: 0.5)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MathPalette.grape.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MathPalette.grape.withValues(alpha: 0.12), width: 2),
      ),
    );
  }
}
