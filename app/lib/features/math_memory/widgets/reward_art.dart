import 'package:flutter/material.dart';

import 'math_drawing.dart';
import 'math_palette.dart';

/// Row of three stars: [earned] filled with smiling faces, the rest outlined.
class StarRatingView extends StatelessWidget {
  const StarRatingView({super.key, required this.earned, this.size = 72});

  final int earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$earned of 3 stars',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              // The middle star sits a little higher, like a podium.
              padding: EdgeInsets.only(
                left: i == 0 ? 0 : 6,
                bottom: i == 1 ? size * 0.25 : 0,
              ),
              child: SizedBox.square(
                dimension: i == 1 ? size * 1.2 : size,
                child: CustomPaint(painter: _RatingStarPainter(filled: i < earned)),
              ),
            ),
        ],
      ),
    );
  }
}

class _RatingStarPainter extends UnitPainter {
  const _RatingStarPainter({required this.filled});

  final bool filled;

  @override
  void paintUnits(Canvas canvas) {
    if (filled) {
      drawStar(canvas, const Offset(50, 52), 46, MathPalette.sun, face: true);
    } else {
      drawStar(canvas, const Offset(50, 52), 46, const Color(0xFFE9E4D8));
    }
  }

  @override
  bool shouldRepaint(_RatingStarPainter oldDelegate) => oldDelegate.filled != filled;
}

/// Kinds of small art used around feedback and results.
enum RewardArt {
  /// Green tick with sparkles — a correct answer.
  correct,

  /// Warm lightbulb — a gentle hint after a wrong answer.
  hint,

  /// Open hand with a star — "here's the answer, let's keep going".
  reveal,

  /// Smiling star surrounded by confetti — baseline finished / results.
  celebrate,

  /// Telescope-style magnifier — exploring (baseline completion).
  explore,
}

class RewardArtView extends StatelessWidget {
  const RewardArtView(this.art, {super.key, this.size = 56});

  final RewardArt art;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _RewardPainter(art)),
      ),
    );
  }
}

class _RewardPainter extends UnitPainter {
  const _RewardPainter(this.art);

  final RewardArt art;

  @override
  bool shouldRepaint(_RewardPainter oldDelegate) => oldDelegate.art != art;

  @override
  void paintUnits(Canvas canvas) {
    switch (art) {
      case RewardArt.correct:
        canvas.drawCircle(const Offset(50, 52), 38, Paint()..color = darken(MathPalette.leaf));
        canvas.drawCircle(const Offset(50, 50), 38, Paint()..color = MathPalette.leaf);
        final tick = Path()
          ..moveTo(32, 50)
          ..lineTo(45, 63)
          ..lineTo(69, 37);
        canvas.drawPath(
          tick,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 9
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        drawSparkle(canvas, const Offset(88, 16), 9, MathPalette.sun);
        drawSparkle(canvas, const Offset(12, 84), 6, MathPalette.sun);
      case RewardArt.hint:
        // Lightbulb
        canvas.drawCircle(const Offset(50, 42), 30, Paint()..color = MathPalette.sun);
        canvas.drawRRect(
          RRect.fromRectAndRadius(const Rect.fromLTWH(38, 66, 24, 18), const Radius.circular(5)),
          Paint()..color = const Color(0xFFADB5BD),
        );
        canvas.drawLine(
          const Offset(40, 74),
          const Offset(60, 74),
          Paint()
            ..color = Colors.white
            ..strokeWidth = 2.5,
        );
        drawFace(canvas, const Offset(50, 44), 14);
        final glow = Paint()
          ..color = MathPalette.tangerine
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(const Offset(10, 30), const Offset(18, 34), glow);
        canvas.drawLine(const Offset(90, 30), const Offset(82, 34), glow);
        canvas.drawLine(const Offset(50, 2), const Offset(50, 8), glow);
      case RewardArt.reveal:
        canvas.drawCircle(const Offset(50, 52), 40, Paint()..color = MathPalette.headerMid);
        drawStar(canvas, const Offset(50, 50), 28, MathPalette.sun, face: true);
        drawSparkle(canvas, const Offset(86, 20), 7, MathPalette.grape);
      case RewardArt.celebrate:
        const confetti = [
          (Offset(12, 20), MathPalette.berry),
          (Offset(86, 14), MathPalette.sky),
          (Offset(92, 62), MathPalette.grass),
          (Offset(8, 70), MathPalette.grape),
          (Offset(30, 6), MathPalette.tangerine),
          (Offset(70, 92), MathPalette.berry),
        ];
        for (final (o, c) in confetti) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: o, width: 8, height: 5), const Radius.circular(2)),
            Paint()..color = c,
          );
        }
        drawStar(canvas, const Offset(50, 52), 36, MathPalette.sun, face: true);
        drawSparkle(canvas, const Offset(80, 36), 6, MathPalette.sun);
        drawSparkle(canvas, const Offset(20, 44), 5, MathPalette.sun);
      case RewardArt.explore:
        // Magnifying glass over a star map.
        canvas.drawCircle(const Offset(50, 52), 44, Paint()..color = Colors.white.withValues(alpha: 0.7));
        drawStar(canvas, const Offset(28, 30), 9, MathPalette.sun);
        drawStar(canvas, const Offset(76, 74), 8, MathPalette.tangerine);
        drawSparkle(canvas, const Offset(80, 22), 6, MathPalette.grape);
        canvas.drawLine(
          const Offset(64, 64),
          const Offset(86, 86),
          Paint()
            ..color = MathPalette.stem
            ..strokeWidth = 11
            ..strokeCap = StrokeCap.round,
        );
        canvas.drawCircle(const Offset(46, 46), 24, Paint()..color = MathPalette.sky.withValues(alpha: 0.25));
        canvas.drawCircle(
          const Offset(46, 46),
          24,
          Paint()
            ..color = MathPalette.sky
            ..style = PaintingStyle.stroke
            ..strokeWidth = 7,
        );
        drawStar(canvas, const Offset(46, 47), 12, MathPalette.sun, face: true);
    }
  }
}
