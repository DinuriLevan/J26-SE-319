import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_fonts.dart';
import 'math_palette.dart';

/// Vector drawing helpers shared by the Math & Memory illustrations and
/// picture cards. All sizes are in the caller's canvas units.
Color darken(Color color) => Color.lerp(color, Colors.black, 0.22)!;

void drawLabel(
  Canvas canvas,
  String text,
  Offset center,
  double fontSize,
  Color color,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        fontFamily: AppFonts.latin,
        fontSize: fontSize,
        fontWeight: FontWeight.w700,
        color: color,
        height: 1,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
}

/// A chunky number block with a darker base so it looks three-dimensional.
void drawBlock(Canvas canvas, Rect rect, Color color, String label) {
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(rect.width * 0.2));
  canvas.drawRRect(rrect.shift(const Offset(0, 2.5)), Paint()..color = darken(color));
  canvas.drawRRect(rrect, Paint()..color = color);
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(rect.left + 3, rect.top + 3, rect.width - 6, rect.width * 0.18),
      Radius.circular(rect.width * 0.1),
    ),
    Paint()..color = Colors.white.withValues(alpha: 0.3),
  );
  drawLabel(canvas, label, rect.center + const Offset(0, 1), rect.width * 0.6, Colors.white);
}

void drawBubble(Canvas canvas, Offset center, double radius, Color color, String label) {
  canvas.drawCircle(center + const Offset(0, 2), radius, Paint()..color = darken(color));
  canvas.drawCircle(center, radius, Paint()..color = color);
  drawLabel(canvas, label, center, radius * 1.5, Colors.white);
}

void drawStar(Canvas canvas, Offset center, double radius, Color color, {bool face = false}) {
  final path = Path();
  for (var i = 0; i < 10; i++) {
    final r = i.isEven ? radius : radius * 0.5;
    final angle = -math.pi / 2 + i * math.pi / 5;
    final point = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
    if (i == 0) {
      path.moveTo(point.dx, point.dy);
    } else {
      path.lineTo(point.dx, point.dy);
    }
  }
  path.close();

  // A same-coloured round-joined stroke softens the points.
  canvas.drawPath(
    path,
    Paint()
      ..color = darken(color)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.2
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(
    path,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.1
      ..strokeJoin = StrokeJoin.round,
  );
  canvas.drawPath(path, Paint()..color = color);

  if (face) drawFace(canvas, center + Offset(0, radius * 0.1), radius * 0.45);
}

void drawFace(Canvas canvas, Offset center, double size) {
  final ink = Paint()..color = MathPalette.ink;
  canvas.drawCircle(center + Offset(-size * 0.38, -size * 0.18), size * 0.12, ink);
  canvas.drawCircle(center + Offset(size * 0.38, -size * 0.18), size * 0.12, ink);

  final cheek = Paint()..color = MathPalette.berry.withValues(alpha: 0.35);
  canvas.drawCircle(center + Offset(-size * 0.62, size * 0.15), size * 0.13, cheek);
  canvas.drawCircle(center + Offset(size * 0.62, size * 0.15), size * 0.13, cheek);

  final smile = Path()
    ..moveTo(center.dx - size * 0.28, center.dy + size * 0.1)
    ..quadraticBezierTo(center.dx, center.dy + size * 0.45, center.dx + size * 0.28, center.dy + size * 0.1);
  canvas.drawPath(
    smile,
    Paint()
      ..color = MathPalette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = size * 0.1
      ..strokeCap = StrokeCap.round,
  );
}

void drawApple(Canvas canvas, Offset center, double r) {
  canvas.drawLine(
    center + Offset(0, -r * 0.6),
    center + Offset(r * 0.15, -r * 1.15),
    Paint()
      ..color = MathPalette.stem
      ..strokeWidth = r * 0.18
      ..strokeCap = StrokeCap.round,
  );

  final leaf = Path()
    ..moveTo(center.dx + r * 0.12, center.dy - r * 0.95)
    ..quadraticBezierTo(center.dx + r * 0.6, center.dy - r * 1.4, center.dx + r * 0.95, center.dy - r * 1.0)
    ..quadraticBezierTo(center.dx + r * 0.5, center.dy - r * 0.7, center.dx + r * 0.12, center.dy - r * 0.95)
    ..close();
  canvas.drawPath(leaf, Paint()..color = MathPalette.leaf);

  final body = Paint()..color = MathPalette.berry;
  canvas.drawOval(Rect.fromCenter(center: center + Offset(-r * 0.3, 0), width: r * 1.4, height: r * 1.7), body);
  canvas.drawOval(Rect.fromCenter(center: center + Offset(r * 0.3, 0), width: r * 1.4, height: r * 1.7), body);

  canvas.drawOval(
    Rect.fromCenter(center: center + Offset(-r * 0.45, -r * 0.3), width: r * 0.3, height: r * 0.5),
    Paint()..color = Colors.white.withValues(alpha: 0.55),
  );
}

/// Four-pointed twinkle.
void drawSparkle(Canvas canvas, Offset c, double r, Color color) {
  final path = Path()
    ..moveTo(c.dx, c.dy - r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
    ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
    ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
    ..close();
  canvas.drawPath(path, Paint()..color = color);
}

void drawTick(Canvas canvas, Offset center) {
  canvas.drawCircle(center, 6, Paint()..color = Colors.white);
  canvas.drawCircle(center, 5, Paint()..color = MathPalette.leaf);
  final tick = Path()
    ..moveTo(center.dx - 2.4, center.dy)
    ..lineTo(center.dx - 0.6, center.dy + 1.9)
    ..lineTo(center.dx + 2.6, center.dy - 1.8);
  canvas.drawPath(
    tick,
    Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round,
  );
}

/// Draws in a 100x100 design space, scaled and centred to fit the widget.
abstract class UnitPainter extends CustomPainter {
  const UnitPainter();

  void paintUnits(Canvas canvas);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / 100;
    canvas
      ..save()
      ..translate((size.width - 100 * scale) / 2, (size.height - 100 * scale) / 2)
      ..scale(scale);
    paintUnits(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
