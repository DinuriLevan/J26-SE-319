import 'package:flutter/material.dart';

import 'math_drawing.dart';
import 'math_palette.dart';

/// Vector illustrations for the Math section, drawn with [CustomPainter] so
/// they're bundled in code, work offline and stay crisp at any size.
enum MathArt { header, numberQuest, memoryMatch }

class MathIllustration extends StatelessWidget {
  const MathIllustration(this.art, {super.key});

  final MathArt art;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: CustomPaint(
        painter: switch (art) {
          MathArt.header => const _HeaderPainter(),
          MathArt.numberQuest => const _NumberQuestPainter(),
          MathArt.memoryMatch => const _MemoryMatchPainter(),
        },
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _HeaderPainter extends UnitPainter {
  const _HeaderPainter();

  @override
  void paintUnits(Canvas canvas) {
    canvas.drawCircle(
      const Offset(54, 54),
      42,
      Paint()..color = Colors.white.withValues(alpha: 0.7),
    );
    drawBlock(canvas, const Rect.fromLTWH(8, 58, 26, 26), MathPalette.sky, '1');
    drawBubble(canvas, const Offset(28, 24), 12, MathPalette.grass, '+');
    drawStar(canvas, const Offset(66, 56), 28, MathPalette.sun, face: true);
    drawSparkle(canvas, const Offset(90, 18), 6, MathPalette.tangerine);
    drawSparkle(canvas, const Offset(52, 12), 4, MathPalette.grape);
  }
}

class _NumberQuestPainter extends UnitPainter {
  const _NumberQuestPainter();

  @override
  void paintUnits(Canvas canvas) {
    canvas.drawCircle(
      const Offset(50, 52),
      46,
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );

    // Number blocks climbing like stairs.
    drawBlock(canvas, const Rect.fromLTWH(12, 64, 24, 24), MathPalette.sky, '1');
    drawBlock(canvas, const Rect.fromLTWH(38, 52, 24, 36), MathPalette.grass, '2');
    drawBlock(canvas, const Rect.fromLTWH(64, 40, 24, 48), MathPalette.tangerine, '3');

    // Apples to count.
    drawApple(canvas, const Offset(24, 56), 7);
    drawApple(canvas, const Offset(50, 44), 7);

    drawStar(canvas, const Offset(76, 24), 15, MathPalette.sun, face: true);
    drawBubble(canvas, const Offset(22, 26), 10, MathPalette.grape, '+');
    drawSparkle(canvas, const Offset(48, 16), 4, MathPalette.tangerine);
    drawSparkle(canvas, const Offset(94, 50), 3, MathPalette.grape);
  }
}

class _MemoryMatchPainter extends UnitPainter {
  const _MemoryMatchPainter();

  @override
  void paintUnits(Canvas canvas) {
    canvas.drawCircle(
      const Offset(50, 52),
      46,
      Paint()..color = Colors.white.withValues(alpha: 0.65),
    );

    // A 3x2 board: two matched stars, one apple turned over, the rest hidden.
    const cardSize = Size(26, 32);
    const columns = [8.0, 37.0, 66.0];
    const rows = [16.0, 54.0];
    final faces = <void Function(Canvas, Offset)?>[
      (c, o) => drawStar(c, o, 9, MathPalette.sun),
      null,
      (c, o) => drawApple(c, o + const Offset(0, 2), 7),
      null,
      (c, o) => drawStar(c, o, 9, MathPalette.sun),
      null,
    ];

    for (var i = 0; i < faces.length; i++) {
      final rect = Offset(columns[i % 3], rows[i ~/ 3]) & cardSize;
      drawPictureCard(canvas, rect, faces[i]);
    }

    // Tick badges on the matched pair.
    drawTick(canvas, Offset(columns[0] + cardSize.width - 2, rows[0] + 2));
    drawTick(canvas, Offset(columns[1] + cardSize.width - 2, rows[1] + 2));

    drawSparkle(canvas, const Offset(50, 8), 4, MathPalette.sun);
    drawSparkle(canvas, const Offset(96, 48), 3, MathPalette.tangerine);
  }

  void drawPictureCard(
    Canvas canvas,
    Rect rect,
    void Function(Canvas, Offset)? face,
  ) {
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(5));
    canvas.drawRRect(
      rrect.shift(const Offset(0, 2)),
      Paint()..color = MathPalette.ink.withValues(alpha: 0.12),
    );

    if (face == null) {
      canvas.drawRRect(rrect, Paint()..color = MathPalette.grape);
      canvas.drawRRect(
        rrect.deflate(3),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
      drawLabel(canvas, '?', rect.center, 16, Colors.white);
    } else {
      canvas.drawRRect(rrect, Paint()..color = Colors.white);
      canvas.drawRRect(
        rrect,
        Paint()
          ..color = MathPalette.grape.withValues(alpha: 0.35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      face(canvas, rect.center);
    }
  }
}

