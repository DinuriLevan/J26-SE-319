import 'dart:math' as math;

import 'package:flutter/material.dart';

enum MascotMood { idle, cheer, dance }

/// Friendly owl guide. Idle = slow bob, cheer = happy hops, dance = wiggle.
class Mascot extends StatefulWidget {
  const Mascot({super.key, this.mood = MascotMood.idle, this.size = 96});

  final MascotMood mood;
  final double size;

  @override
  State<Mascot> createState() => _MascotState();
}

class _MascotState extends State<Mascot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value * 2 * math.pi;
        double dy;
        double angle = 0;
        switch (widget.mood) {
          case MascotMood.idle:
            dy = math.sin(t) * size * 0.03;
          case MascotMood.cheer:
            dy = -(math.sin(t * 2).abs()) * size * 0.18;
          case MascotMood.dance:
            dy = -(math.sin(t * 2).abs()) * size * 0.12;
            angle = math.sin(t * 2) * 0.25;
        }
        return Transform.translate(
          offset: Offset(0, dy),
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Color(0xFFFFE9C7), shape: BoxShape.circle),
        child: Text(
          widget.mood == MascotMood.idle ? '🦉' : '🥳',
          style: TextStyle(fontSize: size * 0.6),
        ),
      ),
    );
  }
}
