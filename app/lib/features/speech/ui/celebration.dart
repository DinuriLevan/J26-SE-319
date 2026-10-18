import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'speech_theme.dart';

/// A one-off burst of pastel confetti and stars (about 1.6 s). Plays once and then stays empty.
/// Draws nothing when the system asks for reduced motion.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.pieces = 70, this.seed = 7});

  final int pieces;
  final int seed;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1600));
  late final List<_Piece> _pieces = _make();
  bool _started = false;

  List<_Piece> _make() {
    final r = math.Random(widget.seed);
    const colors = [
      SpeechColors.coral,
      SpeechColors.sun,
      SpeechColors.success,
      SpeechColors.blue,
      Color(0xFFB9A3F0),
      SpeechColors.peach,
    ];
    return [
      for (var i = 0; i < widget.pieces; i++)
        _Piece(
          x: r.nextDouble(),
          vx: (r.nextDouble() - 0.5) * 0.5,
          vy: 0.35 + r.nextDouble() * 0.6,
          spin: (r.nextDouble() - 0.5) * 12,
          color: colors[i % colors.length],
          star: i % 5 == 0,
          size: 8 + r.nextDouble() * 8,
        ),
    ];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started && SpeechTheme.motion(context)) {
      _started = true;
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!SpeechTheme.motion(context)) return const SizedBox.shrink();
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(_pieces, _c.value),
          ),
        ),
      ),
    );
  }
}

class _Piece {
  _Piece({
    required this.x,
    required this.vx,
    required this.vy,
    required this.spin,
    required this.color,
    required this.star,
    required this.size,
  });

  final double x, vx, vy, spin, size;
  final Color color;
  final bool star;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final fade = t < 0.75 ? 1.0 : (1 - t) / 0.25;
    for (final p in pieces) {
      final x = (p.x + p.vx * t) * size.width;
      final y = (-0.1 + p.vy * t + 0.6 * t * t) * size.height;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      final paint = Paint()..color = p.color.withValues(alpha: fade);
      if (p.star) {
        final path = Path();
        for (var i = 0; i < 10; i++) {
          final a = -math.pi / 2 + i * math.pi / 5;
          final r = i.isEven ? p.size : p.size * 0.45;
          final pt = Offset(math.cos(a) * r, math.sin(a) * r);
          i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
        }
        canvas.drawPath(path..close(), paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(
                Rect.fromCenter(
                    center: Offset.zero, width: p.size, height: p.size * 0.6),
                const Radius.circular(2)),
            paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Three stars that pop in one after another.
class StarRow extends StatefulWidget {
  const StarRow({super.key, this.size = 48});

  final double size;

  @override
  State<StarRow> createState() => _StarRowState();
}

class _StarRowState extends State<StarRow> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SpeechTheme.motion(context)) {
      if (_c.value == 0) _c.forward();
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Transform.scale(
                scale: Curves.elasticOut
                    .transform(((_c.value - i * 0.2) / 0.6).clamp(0.0, 1.0)),
                child: Icon(Icons.star_rounded,
                    size: i == 1 ? widget.size * 1.3 : widget.size,
                    color: SpeechColors.sun),
              ),
          ],
        ),
      ),
    );
  }
}

/// A reward card that flips over to show its front.
class CardReveal extends StatefulWidget {
  const CardReveal({super.key, required this.label});

  final String label;

  @override
  State<CardReveal> createState() => _CardRevealState();
}

class _CardRevealState extends State<CardReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (SpeechTheme.motion(context)) {
      if (_c.value == 0) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _c.forward();
        });
      }
    } else {
      _c.value = 1;
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final angle = math.pi * (1 - Curves.easeInOut.transform(_c.value));
        final front = angle < math.pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle),
          child: Container(
            width: 260,
            // Fixed height: the label may wrap to two lines, and a fixed size keeps the parent's
            // intrinsic-height layout (FillOrScroll) correct.
            height: 96,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: front
                    ? const [SpeechColors.butter, SpeechColors.peach]
                    : const [SpeechColors.lilac, SpeechColors.sky],
              ),
              boxShadow: speechShadow,
            ),
            child: front
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.style_rounded,
                          size: 36, color: SpeechColors.coralDeep),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(widget.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium!
                                .copyWith(fontWeight: FontWeight.w700)),
                      ),
                    ],
                  )
                : const SizedBox.expand(
                    child: Center(
                      child: Icon(Icons.help_rounded,
                          size: 36, color: SpeechColors.navySoft),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
