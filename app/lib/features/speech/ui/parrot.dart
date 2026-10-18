import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'speech_theme.dart';

/// What the parrot buddy is doing.
enum ParrotMood {
  /// Gentle bob and blink.
  idle,

  /// Head tilt with sound waves: the child is speaking.
  listening,

  /// Bouncing dots: checking the attempt.
  thinking,

  /// Smiling eyes, wings up, little hop: success.
  happy,

  /// Soft nod with a heart: "let's try again", never punitive.
  encourage,
}

/// The Speech screens' friendly guide: a parrot (parrots repeat words!) drawn in code, so there are
/// no image assets. Purely decorative for screen readers. Motion follows the system
/// "reduce motion" setting; with it on, the parrot is drawn in its pose without animating.
class ParrotBuddy extends StatefulWidget {
  const ParrotBuddy(
      {super.key,
      this.mood = ParrotMood.idle,
      this.size = 120,
      this.talking = false});

  final ParrotMood mood;
  final double size;

  /// The parrot's beak moves while its spoken instruction is playing.
  final bool talking;

  @override
  State<ParrotBuddy> createState() => _ParrotBuddyState();
}

class _ParrotBuddyState extends State<ParrotBuddy>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    if (SpeechTheme.motion(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c
        ..stop()
        ..value = 0;
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
      child: SizedBox.square(
        dimension: widget.size,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) => CustomPaint(
            painter: _ParrotPainter(widget.mood, _c.value, widget.talking),
          ),
        ),
      ),
    );
  }
}

class _ParrotPainter extends CustomPainter {
  _ParrotPainter(this.mood, this.t, this.talking);

  final ParrotMood mood;
  final double t; // 0..1, loops
  final bool talking;

  static const green = Color(0xFF5BC27A);
  static const greenDark = Color(0xFF3FA25F);
  static const belly = Color(0xFFC8F2D2);
  static const beak = Color(0xFFFF9F43);
  static const crest = Color(0xFFFFC94D);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final wave = math.sin(t * 2 * math.pi);
    canvas.save();
    // Whole-body motion per mood.
    final dy = switch (mood) {
      ParrotMood.happy => -wave.abs() * s * 0.07,
      ParrotMood.encourage => wave * s * 0.012,
      _ => wave * s * 0.02,
    };
    canvas.translate(0, dy);
    final tilt = switch (mood) {
      ParrotMood.listening => 0.14 + wave * 0.03,
      ParrotMood.encourage => wave * 0.06,
      _ => 0.0,
    };
    canvas.translate(s * 0.5, s * 0.55);
    canvas.rotate(tilt);
    canvas.translate(-s * 0.5, -s * 0.55);

    Paint p(Color c) => Paint()..color = c;

    // Tail feathers.
    final tail = Path()
      ..moveTo(s * 0.42, s * 0.78)
      ..quadraticBezierTo(s * 0.30, s * 0.98, s * 0.38, s * 1.0)
      ..quadraticBezierTo(s * 0.50, s * 0.92, s * 0.52, s * 0.80)
      ..close();
    canvas.drawPath(tail, p(greenDark));
    // Feet.
    final foot = Paint()
      ..color = beak
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        Offset(s * 0.44, s * 0.86), Offset(s * 0.42, s * 0.93), foot);
    canvas.drawLine(
        Offset(s * 0.56, s * 0.86), Offset(s * 0.58, s * 0.93), foot);
    // Body and belly.
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(s * 0.5, s * 0.64), width: s * 0.5, height: s * 0.5),
        p(green));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(s * 0.53, s * 0.69),
            width: s * 0.3,
            height: s * 0.34),
        p(belly));
    // Wing (raised when happy).
    canvas.save();
    canvas.translate(s * 0.36, s * 0.6);
    canvas.rotate(mood == ParrotMood.happy ? -0.9 + wave * 0.15 : 0.35);
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(0, s * 0.06), width: s * 0.16, height: s * 0.3),
        p(greenDark));
    canvas.restore();
    // Head.
    final head = Offset(s * 0.55, s * 0.36);
    // Crest.
    for (final (dx, ang) in [(-0.06, -0.5), (0.0, -0.15), (0.06, 0.2)]) {
      canvas.save();
      canvas.translate(head.dx + s * dx, head.dy - s * 0.17);
      canvas.rotate(ang);
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset.zero, width: s * 0.06, height: s * 0.14),
          p(crest));
      canvas.restore();
    }
    canvas.drawCircle(head, s * 0.2, p(green));
    // Cheek blush.
    canvas.drawCircle(
        head + Offset(s * 0.1, s * 0.07), s * 0.045, p(SpeechColors.peach));
    // Eye: blinks briefly near the end of each loop; smiling arc when happy.
    final eye = head + Offset(s * 0.04, -s * 0.03);
    final blinking = mood != ParrotMood.happy && t > 0.93;
    if (mood == ParrotMood.happy || blinking) {
      final arc = Paint()
        ..color = SpeechColors.navy
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.025
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: eye, radius: s * 0.045),
          mood == ParrotMood.happy ? math.pi : 0, math.pi, false, arc);
    } else {
      canvas.drawCircle(eye, s * 0.055, p(SpeechColors.paper));
      canvas.drawCircle(
          eye + Offset(s * 0.01, 0), s * 0.03, p(SpeechColors.navy));
      canvas.drawCircle(
          eye + Offset(s * 0.02, -s * 0.012), s * 0.01, p(SpeechColors.paper));
    }
    // Hooked beak (opens a little while listening).
    final open = talking
        ? (math.sin(t * 2 * math.pi * 8).abs() * s * 0.04)
        : mood == ParrotMood.listening
            ? (wave.abs() * s * 0.03)
            : 0.0;
    final upper = Path()
      ..moveTo(head.dx + s * 0.15, head.dy - s * 0.02)
      ..quadraticBezierTo(head.dx + s * 0.32, head.dy - s * 0.01,
          head.dx + s * 0.25, head.dy + s * 0.1)
      ..quadraticBezierTo(head.dx + s * 0.22, head.dy + s * 0.04,
          head.dx + s * 0.15, head.dy + s * 0.05)
      ..close();
    canvas.drawPath(upper, p(beak));
    canvas.drawOval(
        Rect.fromCenter(
            center: Offset(head.dx + s * 0.18, head.dy + s * 0.08 + open),
            width: s * 0.1,
            height: s * 0.05),
        p(const Color(0xFFE88A2E)));
    canvas.restore();

    // Extras drawn upright, beside the parrot.
    switch (mood) {
      case ParrotMood.listening:
        final arc = Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = s * 0.025;
        for (var i = 0; i < 3; i++) {
          final phase = (t * 3 + i / 3) % 1.0;
          arc.color = SpeechColors.coral.withValues(alpha: 1 - phase);
          canvas.drawArc(
              Rect.fromCircle(
                  center: Offset(s * 0.86, s * 0.32),
                  radius: s * (0.05 + 0.08 * i)),
              -0.7,
              1.4,
              false,
              arc);
        }
      case ParrotMood.thinking:
        for (var i = 0; i < 3; i++) {
          final bounce = math.sin((t * 2 + i * 0.2) * 2 * math.pi).abs();
          canvas.drawCircle(
              Offset(s * (0.68 + i * 0.1), s * 0.1 - bounce * s * 0.04),
              s * 0.035,
              p(SpeechColors.blue.withValues(alpha: 0.8)));
        }
      case ParrotMood.encourage:
        _heart(canvas, Offset(s * 0.86, s * 0.2 + wave * s * 0.02), s * 0.09);
      case ParrotMood.happy:
        _sparkle(canvas, Offset(s * 0.12, s * 0.22),
            s * 0.06 * (0.7 + wave.abs() * 0.5));
        _sparkle(canvas, Offset(s * 0.9, s * 0.14),
            s * 0.05 * (1.2 - wave.abs() * 0.5));
      case ParrotMood.idle:
        break;
    }
  }

  void _heart(Canvas canvas, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy + r * 0.9)
      ..cubicTo(c.dx - r * 1.4, c.dy - r * 0.2, c.dx - r * 0.5, c.dy - r * 1.1,
          c.dx, c.dy - r * 0.35)
      ..cubicTo(c.dx + r * 0.5, c.dy - r * 1.1, c.dx + r * 1.4, c.dy - r * 0.2,
          c.dx, c.dy + r * 0.9)
      ..close();
    canvas.drawPath(path, Paint()..color = SpeechColors.coral);
  }

  void _sparkle(Canvas canvas, Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.4;
      final pt = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = SpeechColors.sun);
  }

  @override
  bool shouldRepaint(_ParrotPainter old) =>
      old.t != t || old.mood != mood || old.talking != talking;
}
