import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../spelling_style.dart';

/// Animated backdrop for the start screen: soft sky, a slowly turning sun,
/// drifting clouds, rolling hills and colourful letter blocks floating about.
class StartScene extends StatefulWidget {
  const StartScene({super.key, required this.child});

  /// Shown in the middle of the scene (the ▶ button).
  final Widget child;

  @override
  State<StartScene> createState() => _StartSceneState();
}

class _StartSceneState extends State<StartScene> with SingleTickerProviderStateMixin {
  late final AnimationController _clock =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))..repeat();

  // (letter, colour, x, y, size, phase) — x/y are fractions of the screen.
  static const _blocks = [
    ('a', Color(0xFFFF8FAB), 0.12, 0.20, 64.0, 0.0),
    ('b', Color(0xFF4D96FF), 0.80, 0.17, 58.0, 1.3),
    ('c', Color(0xFF6BCB77), 0.22, 0.36, 52.0, 2.1),
    ('s', Color(0xFFC490E4), 0.72, 0.34, 66.0, 3.4),
    ('d', Color(0xFFFF9F45), 0.08, 0.56, 50.0, 4.2),
    ('m', Color(0xFFFFC93C), 0.88, 0.55, 54.0, 5.0),
  ];

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) => AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final t = _clock.value;
          return Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _SkyPainter(t))),
              for (final (letter, color, x, y, size, phase) in _blocks)
                Positioned(
                  left: x * box.maxWidth - size / 2,
                  top: y * box.maxHeight - size / 2 + math.sin(t * 2 * math.pi * 6 + phase) * 10,
                  child: Transform.rotate(
                    angle: math.sin(t * 2 * math.pi * 4 + phase) * 0.12,
                    child: _FloatingBlock(letter: letter, color: color, size: size),
                  ),
                ),
              Center(child: widget.child),
            ],
          );
        },
      ),
    );
  }
}

class _FloatingBlock extends StatelessWidget {
  const _FloatingBlock({required this.letter, required this.color, required this.size});

  final String letter;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.26),
        border: Border(bottom: BorderSide(color: Color.lerp(color, Colors.black, 0.18)!, width: 5)),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Text(letter, style: letterStyle(size * 0.52).copyWith(color: Colors.white)),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter(this.t);

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Sky fading into the cream page colour.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFCDE9FF), Color(0xFFEAF5FF), SpellingColors.background],
          stops: [0, 0.45, 0.8],
        ).createShader(Offset.zero & size),
    );

    // Sun with slowly turning rays.
    final sun = Offset(w * 0.84, h * 0.06);
    final rays = Paint()
      ..color = const Color(0x66FFC93C)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 10; i++) {
      final a = t * 2 * math.pi + i * math.pi / 5;
      canvas.drawLine(
        sun + Offset(math.cos(a), math.sin(a)) * 48,
        sun + Offset(math.cos(a), math.sin(a)) * 64,
        rays,
      );
    }
    canvas.drawCircle(sun, 38, Paint()..color = const Color(0xFFFFD45C));

    // Clouds drifting across, wrapping around.
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (final (speed, y, scale) in [(1.0, 0.11, 1.0), (0.6, 0.27, 0.75), (0.8, 0.44, 0.6)]) {
      final x = ((t * speed + y * 3) % 1.0) * (w + 240) - 120;
      _cloud(canvas, Offset(x, h * y), scale, cloud);
    }

    // Two rolling hills along the bottom.
    _hill(canvas, size, h * 0.84, 0.25, const Color(0xFFBFE6B6));
    _hill(canvas, size, h * 0.9, 0.7, const Color(0xFF9ED897));
  }

  void _cloud(Canvas canvas, Offset c, double s, Paint paint) {
    canvas.drawCircle(c, 26 * s, paint);
    canvas.drawCircle(c + Offset(28 * s, -10 * s), 32 * s, paint);
    canvas.drawCircle(c + Offset(60 * s, 0), 24 * s, paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(c.dx - 10 * s, c.dy, 82 * s, 24 * s),
        Radius.circular(12 * s),
      ),
      paint,
    );
  }

  void _hill(Canvas canvas, Size size, double top, double peakAt, Color color) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, top + 30)
      ..quadraticBezierTo(size.width * peakAt, top - 60, size.width, top + 20)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SkyPainter old) => old.t != t;
}
