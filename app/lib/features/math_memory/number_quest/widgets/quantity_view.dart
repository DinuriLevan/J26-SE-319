import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../engine/math_picture.dart';
import '../../widgets/math_palette.dart';
import '../../widgets/math_pictures.dart';
import '../engine/number_quest_models.dart';

/// Draws a question's quantities: counting objects, two groups to add,
/// objects being taken away, equal groups, or objects to share. Falls back
/// to big number blocks when [NumberQuestion.showObjects] is false.
///
/// Pictures are sized to the space available: as big as will fit, up to a
/// cap that shrinks as the count grows, so children can see and count each
/// one.
class QuantityView extends StatelessWidget {
  const QuantityView({super.key, required this.question, this.maxHeight});

  final NumberQuestion question;

  /// Tallest the pictures may be. Defaults to ~30% of the screen height
  /// (150–300 dp), which keeps the answers in view on small phones.
  final double? maxHeight;

  static const _gap = 4.0; // between pictures
  static const _groupChrome = 19.0; // group padding + border, both sides
  static const _groupSpacing = 8.0; // between groups
  static const _operatorWidth = 40.0;
  static const _operatorHeight = 40.0;
  static const _platesHeight = 34.0;
  static const _minSize = 22.0;

  /// Largest size per picture: big for a few, smaller for many.
  static double _cap(int total) {
    if (total <= 5) return 72;
    if (total <= 10) return 60;
    if (total <= 15) return 52;
    return 46;
  }

  @override
  Widget build(BuildContext context) {
    final q = question;
    if (!q.showObjects) return _NumberBlocks(question: q);

    final screenHeight = MediaQuery.sizeOf(context).height;
    final maxH = maxHeight ?? (screenHeight * 0.3).clamp(150.0, 300.0);

    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // A little slack for the half-pixel each group adds against rounding.
          final maxW = (constraints.maxWidth.isFinite ? constraints.maxWidth : 320.0) - 3;
          return switch (q.skill) {
            MathSkill.counting => _single(q.a, maxW, maxH, q.picture),
            MathSkill.subtraction => _single(q.a, maxW, maxH, q.picture, crossedOut: q.b),
            MathSkill.addition => _addition(q, maxW, maxH),
            MathSkill.multiplication => _multiplication(q, maxW, maxH),
            MathSkill.division => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _single(q.a, maxW, maxH - _platesHeight, q.picture),
                  const SizedBox(height: 10),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 10,
                    runSpacing: 8,
                    children: [for (var i = 0; i < q.b; i++) const _Plate()],
                  ),
                ],
              ),
          };
        },
      ),
    );
  }

  static int _perRow(int count) => math.max(1, math.min(count, 5));

  static int _rows(int count) => (count / _perRow(count)).ceil();

  static double _clampSize(double size, int total) =>
      size.clamp(_minSize, _cap(total)).toDouble();

  /// Largest picture size for one group of [count] within [w] × [h].
  static double _fitGroup(int count, double w, double h) {
    final perRow = _perRow(count);
    final rows = _rows(count);
    final byWidth = (w - _groupChrome - (perRow - 1) * _gap) / perRow;
    final byHeight = (h - _groupChrome - (rows - 1) * _gap) / rows;
    return math.min(byWidth, byHeight);
  }

  Widget _single(int count, double w, double h, MathPicture picture, {int crossedOut = 0}) {
    final size = _clampSize(_fitGroup(count, w, h), count);
    return _ObjectGroup(count: count, picture: picture, size: size, crossedOut: crossedOut);
  }

  /// Two groups side by side if that gives bigger pictures, otherwise stacked.
  Widget _addition(NumberQuestion q, double w, double h) {
    final across = _perRow(q.a) + _perRow(q.b);
    final tallest = math.max(_rows(q.a), _rows(q.b));
    final sideBySide = math.min(
      (w - 2 * _groupChrome - _operatorWidth - (across - 2) * _gap) / across,
      (h - _groupChrome - (tallest - 1) * _gap) / tallest,
    );

    final widest = math.max(_perRow(q.a), _perRow(q.b));
    final down = _rows(q.a) + _rows(q.b);
    final stacked = math.min(
      (w - _groupChrome - (widest - 1) * _gap) / widest,
      (h - 2 * _groupChrome - _operatorHeight - (down - 2) * _gap) / down,
    );

    final size = _clampSize(math.max(sideBySide, stacked), q.a + q.b);
    final children = [
      _ObjectGroup(count: q.a, picture: q.picture, size: size),
      const _Operator('+'),
      _ObjectGroup(count: q.b, picture: q.picture, size: size),
    ];
    return sideBySide >= stacked
        ? Row(mainAxisSize: MainAxisSize.min, children: children)
        : Column(mainAxisSize: MainAxisSize.min, children: children);
  }

  /// `a` groups of `b`, in whichever grid of groups gives the biggest
  /// pictures.
  Widget _multiplication(NumberQuestion q, double w, double h) {
    final perRow = _perRow(q.b);
    final groupRows = _rows(q.b);
    var best = 0.0;
    var bestGroupsPerRow = 1;
    for (var g = 1; g <= q.a; g++) {
      final rowsOfGroups = (q.a / g).ceil();
      final groupW = (w - (g - 1) * _groupSpacing) / g;
      final groupH = (h - (rowsOfGroups - 1) * _groupSpacing) / rowsOfGroups;
      final size = math.min(
        (groupW - _groupChrome - (perRow - 1) * _gap) / perRow,
        (groupH - _groupChrome - (groupRows - 1) * _gap) / groupRows,
      );
      if (size > best) {
        best = size;
        bestGroupsPerRow = g;
      }
    }
    final size = _clampSize(best, q.a * q.b);
    final groupWidth = perRow * size + (perRow - 1) * _gap + _groupChrome + 0.5;
    return SizedBox(
      width: bestGroupsPerRow * groupWidth + (bestGroupsPerRow - 1) * _groupSpacing + 1,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: _groupSpacing,
        runSpacing: _groupSpacing,
        children: [
          for (var i = 0; i < q.a; i++) _ObjectGroup(count: q.b, picture: q.picture, size: size),
        ],
      ),
    );
  }
}

/// A rounded box of pictures in rows of five (easy to count in fives).
/// The last [crossedOut] pictures are faded and struck through.
class _ObjectGroup extends StatelessWidget {
  const _ObjectGroup({
    required this.count,
    required this.picture,
    required this.size,
    this.crossedOut = 0,
  });

  final int count;
  final MathPicture picture;
  final double size;
  final int crossedOut;

  @override
  Widget build(BuildContext context) {
    const gap = QuantityView._gap;
    final perRow = QuantityView._perRow(count);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: MathPalette.ink.withValues(alpha: 0.08), width: 1.5),
      ),
      child: SizedBox(
        // +0.5 so rounding never pushes the last picture onto a new row.
        width: perRow * size + (perRow - 1) * gap + 0.5,
        child: Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < count; i++)
              i >= count - crossedOut
                  ? _CrossedOut(size: size, child: MathPictureView(picture, size: size))
                  : MathPictureView(picture, size: size),
          ],
        ),
      ),
    );
  }
}

class _CrossedOut extends StatelessWidget {
  const _CrossedOut({required this.size, required this.child});

  final double size;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        children: [
          Opacity(opacity: 0.3, child: child),
          CustomPaint(size: Size.square(size), painter: _CrossPainter()),
        ],
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = MathPalette.ink.withValues(alpha: 0.7)
      ..strokeWidth = size.width * 0.1
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(size.width * 0.15, size.height * 0.85),
      Offset(size.width * 0.85, size.height * 0.15),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Operator extends StatelessWidget {
  const _Operator(this.symbol);

  final String symbol;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Text(
        symbol,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: MathPalette.ink,
            ),
      ),
    );
  }
}

/// An empty plate to share objects onto (division).
class _Plate extends StatelessWidget {
  const _Plate();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 24,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.elliptical(26, 12)),
        border: Border.all(color: MathPalette.sky, width: 3),
      ),
    );
  }
}

/// Numerals in chunky coloured blocks, for questions too big to draw.
class _NumberBlocks extends StatelessWidget {
  const _NumberBlocks({required this.question});

  final NumberQuestion question;

  @override
  Widget build(BuildContext context) {
    final op = switch (question.skill) {
      MathSkill.addition => '+',
      MathSkill.subtraction => '-',
      MathSkill.multiplication => '×',
      MathSkill.division => '÷',
      MathSkill.counting => '',
    };
    return ExcludeSemantics(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _Block(value: question.a, color: MathPalette.sky),
          _Operator(op),
          _Block(value: question.b, color: MathPalette.grass),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({required this.value, required this.color});

  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 76),
      height: 76,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Color.lerp(color, Colors.black, 0.25)!, offset: const Offset(0, 5)),
        ],
      ),
      child: Text(
        '$value',
        style: Theme.of(context).textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
      ),
    );
  }
}
