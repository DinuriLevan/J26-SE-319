import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../engine/math_picture.dart';
import 'math_drawing.dart';
import 'math_palette.dart';

/// Draws one [MathPicture] as a vector illustration that fills its box.
class MathPictureView extends StatelessWidget {
  const MathPictureView(this.picture, {super.key, this.size});

  final MathPicture picture;

  /// Square size; fills the parent when null.
  final double? size;

  @override
  Widget build(BuildContext context) {
    final paint = CustomPaint(
      painter: _PicturePainter(picture),
      child: const SizedBox.expand(),
    );
    return Semantics(
      label: picture.label,
      image: true,
      child: size == null ? paint : SizedBox.square(dimension: size, child: paint),
    );
  }
}

class _PicturePainter extends UnitPainter {
  const _PicturePainter(this.picture);

  final MathPicture picture;

  @override
  void paintUnits(Canvas canvas) {
    switch (picture) {
      case MathPicture.apple:
        drawApple(canvas, const Offset(50, 58), 36);
      case MathPicture.orange:
        _orange(canvas);
      case MathPicture.star:
        drawStar(canvas, const Offset(50, 53), 44, MathPalette.sun, face: true);
      case MathPicture.fish:
        _fish(canvas);
      case MathPicture.flower:
        _flower(canvas);
      case MathPicture.balloon:
        _balloon(canvas);
      case MathPicture.heart:
        _heart(canvas);
      case MathPicture.sun:
        _sun(canvas);
      case MathPicture.moon:
        _moon(canvas);
      case MathPicture.tree:
        _tree(canvas);
    }
  }

  @override
  bool shouldRepaint(_PicturePainter oldDelegate) => oldDelegate.picture != picture;

  static const _orangeColor = Color(0xFFFF9F1C);
  static const _fishColor = Color(0xFF3B9BFF);
  static const _petalColor = Color(0xFFFF7EB6);
  static const _balloonColor = Color(0xFFE64980);
  static const _moonColor = Color(0xFF74C0FC);

  void _shine(Canvas canvas, Offset center, double w, double h) {
    canvas.drawOval(
      Rect.fromCenter(center: center, width: w, height: h),
      Paint()..color = Colors.white.withValues(alpha: 0.5),
    );
  }

  void _orange(Canvas canvas) {
    const c = Offset(50, 56);
    canvas.drawCircle(c + const Offset(0, 2.5), 38, Paint()..color = darken(_orangeColor));
    canvas.drawCircle(c, 38, Paint()..color = _orangeColor);
    final dots = Paint()..color = darken(_orangeColor).withValues(alpha: 0.35);
    for (final o in const [Offset(14, 10), Offset(-10, 18), Offset(20, -8), Offset(-2, 26)]) {
      canvas.drawCircle(c + o, 2, dots);
    }
    _shine(canvas, c + const Offset(-16, -14), 12, 18);
    final leaf = Path()
      ..moveTo(50, 18)
      ..quadraticBezierTo(62, 4, 76, 10)
      ..quadraticBezierTo(66, 22, 50, 18)
      ..close();
    canvas.drawPath(leaf, Paint()..color = MathPalette.leaf);
  }

  void _fish(Canvas canvas) {
    final body = Paint()..color = _fishColor;
    final tail = Path()
      ..moveTo(72, 50)
      ..lineTo(96, 30)
      ..quadraticBezierTo(88, 50, 96, 70)
      ..close();
    canvas.drawPath(tail, Paint()..color = darken(_fishColor));
    final fin = Path()
      ..moveTo(36, 30)
      ..quadraticBezierTo(48, 14, 62, 30)
      ..close();
    canvas.drawPath(fin, Paint()..color = darken(_fishColor));
    canvas.drawOval(Rect.fromCenter(center: const Offset(44, 50), width: 72, height: 44), body);
    // Stripes
    final stripe = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: const Offset(66, 50), radius: 16), 2.3, 1.7, false, stripe);
    canvas.drawArc(Rect.fromCircle(center: const Offset(56, 50), radius: 18), 2.4, 1.5, false, stripe);
    canvas.drawCircle(const Offset(24, 46), 6.5, Paint()..color = Colors.white);
    canvas.drawCircle(const Offset(23, 46), 3.5, Paint()..color = MathPalette.ink);
    final smile = Path()
      ..moveTo(12, 56)
      ..quadraticBezierTo(18, 61, 24, 58);
    canvas.drawPath(
      smile,
      Paint()
        ..color = MathPalette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
  }

  void _flower(Canvas canvas) {
    final stem = Paint()
      ..color = MathPalette.leaf
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(50, 56), const Offset(50, 96), stem);
    final leaf = Path()
      ..moveTo(50, 82)
      ..quadraticBezierTo(64, 66, 78, 72)
      ..quadraticBezierTo(66, 88, 50, 82)
      ..close();
    canvas.drawPath(leaf, Paint()..color = MathPalette.leaf);

    const c = Offset(50, 40);
    final petal = Paint()..color = _petalColor;
    for (var i = 0; i < 5; i++) {
      final a = -math.pi / 2 + i * 2 * math.pi / 5;
      canvas.drawCircle(c + Offset(math.cos(a) * 20, math.sin(a) * 20), 15, petal);
    }
    canvas.drawCircle(c, 13, Paint()..color = MathPalette.sun);
    drawFace(canvas, c + const Offset(0, 1), 9);
  }

  void _balloon(Canvas canvas) {
    final string = Path()
      ..moveTo(50, 78)
      ..quadraticBezierTo(42, 86, 50, 92)
      ..quadraticBezierTo(58, 98, 50, 100);
    canvas.drawPath(
      string,
      Paint()
        ..color = MathPalette.ink.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    final knot = Path()
      ..moveTo(44, 80)
      ..lineTo(56, 80)
      ..lineTo(50, 72)
      ..close();
    canvas.drawPath(knot, Paint()..color = darken(_balloonColor));
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(50, 40), width: 62, height: 72),
      Paint()..color = _balloonColor,
    );
    _shine(canvas, const Offset(36, 26), 12, 20);
  }

  void _heart(Canvas canvas) {
    final path = Path()
      ..moveTo(50, 88)
      ..cubicTo(14, 64, 4, 42, 16, 26)
      ..cubicTo(28, 10, 46, 16, 50, 30)
      ..cubicTo(54, 16, 72, 10, 84, 26)
      ..cubicTo(96, 42, 86, 64, 50, 88)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 2.5)), Paint()..color = darken(MathPalette.berry));
    canvas.drawPath(path, Paint()..color = MathPalette.berry);
    _shine(canvas, const Offset(28, 32), 12, 16);
  }

  void _sun(Canvas canvas) {
    const c = Offset(50, 50);
    final ray = Paint()
      ..color = MathPalette.tangerine
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final dir = Offset(math.cos(a), math.sin(a));
      canvas.drawLine(c + dir * 34, c + dir * 46, ray);
    }
    canvas.drawCircle(c, 28, Paint()..color = MathPalette.sun);
    drawFace(canvas, c + const Offset(0, 3), 14);
  }

  void _moon(Canvas canvas) {
    final outer = Path()..addOval(Rect.fromCircle(center: const Offset(48, 50), radius: 40));
    final bite = Path()..addOval(Rect.fromCircle(center: const Offset(70, 38), radius: 34));
    final crescent = Path.combine(PathOperation.difference, outer, bite);
    canvas.drawPath(crescent.shift(const Offset(0, 2.5)), Paint()..color = darken(_moonColor));
    canvas.drawPath(crescent, Paint()..color = _moonColor);
    canvas.drawCircle(const Offset(26, 50), 3, Paint()..color = MathPalette.ink);
    final smile = Path()
      ..moveTo(22, 62)
      ..quadraticBezierTo(28, 68, 34, 64);
    canvas.drawPath(
      smile,
      Paint()
        ..color = MathPalette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );
    drawSparkle(canvas, const Offset(80, 74), 7, MathPalette.sun);
  }

  void _tree(Canvas canvas) {
    final trunk = RRect.fromRectAndRadius(
      const Rect.fromLTWH(42, 56, 16, 40),
      const Radius.circular(4),
    );
    canvas.drawRRect(trunk, Paint()..color = MathPalette.stem);
    final crown = Paint()..color = MathPalette.leaf;
    final light = Paint()..color = MathPalette.grass;
    canvas.drawCircle(const Offset(32, 48), 20, crown);
    canvas.drawCircle(const Offset(68, 48), 20, crown);
    canvas.drawCircle(const Offset(50, 32), 26, light);
    canvas.drawCircle(const Offset(40, 30), 3, Paint()..color = MathPalette.berry);
    canvas.drawCircle(const Offset(60, 40), 3, Paint()..color = MathPalette.berry);
    canvas.drawCircle(const Offset(30, 50), 3, Paint()..color = MathPalette.berry);
  }
}
