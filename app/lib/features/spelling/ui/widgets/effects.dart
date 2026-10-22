import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Gentle side-to-side wobble, replayed each time [signal] changes.
/// Used instead of a red X when the answer isn't right yet.
class Wobble extends StatelessWidget {
  const Wobble({super.key, required this.signal, required this.child});

  final int signal;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (signal == 0) return child;
    return TweenAnimationBuilder<double>(
      key: ValueKey(signal),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, t, child) => Transform.translate(
        offset: Offset(math.sin(t * math.pi * 6) * 10 * (1 - t), 0),
        child: child,
      ),
      child: child,
    );
  }
}

/// Soft falling confetti (pastel dots and stars), played when [signal]
/// changes. It never blocks touches.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, required this.signal});

  final int signal;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200));
  final _random = math.Random();
  List<_Piece> _pieces = const [];

  static const _colors = [
    Color(0xFFFFC93C),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF9F45),
    Color(0xFFC490E4),
    Color(0xFFFF8FAB),
  ];

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.signal != oldWidget.signal && widget.signal > 0) {
      _pieces = List.generate(
        45,
        (_) => _Piece(
          x: _random.nextDouble(),
          delay: _random.nextDouble() * 0.3,
          speed: 0.7 + _random.nextDouble() * 0.5,
          sway: _random.nextDouble() * 2 * math.pi,
          size: 7 + _random.nextDouble() * 9,
          color: _colors[_random.nextInt(_colors.length)],
          isStar: _random.nextBool(),
        ),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => _controller.isAnimating
            ? CustomPaint(
                size: Size.infinite,
                painter: _ConfettiPainter(_pieces, _controller.value),
              )
            : const SizedBox.expand(),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.sway,
    required this.size,
    required this.color,
    required this.isStar,
  });

  final double x, delay, speed, sway, size;
  final Color color;
  final bool isStar;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;
      final y = -20 + local * p.speed * (size.height + 40);
      final x = p.x * size.width + math.sin(p.sway + local * 6) * 18;
      final paint = Paint()..color = p.color.withValues(alpha: 1 - local * 0.6);
      if (p.isStar) {
        canvas.drawPath(_star(Offset(x, y), p.size), paint);
      } else {
        canvas.drawCircle(Offset(x, y), p.size / 2, paint);
      }
    }
  }

  Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final radius = i.isEven ? r : r * 0.45;
      final a = -math.pi / 2 + i * math.pi / 5;
      final point = c + Offset(math.cos(a) * radius, math.sin(a) * radius);
      i == 0 ? path.moveTo(point.dx, point.dy) : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
