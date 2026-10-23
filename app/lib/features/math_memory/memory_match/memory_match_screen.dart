import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../engine/attempt.dart';
import '../engine/math_picture.dart';
import '../math_game_launcher.dart';
import '../widgets/kid_intro_view.dart';
import '../widgets/math_game_intro_scaffold.dart';
import '../widgets/math_illustrations.dart';
import '../widgets/math_palette.dart';
import '../widgets/math_pictures.dart';

/// Intro screen for Memory Match. Picture-first for children; written
/// instructions with Parent support on. Start Game opens the tutorial on a
/// first visit, otherwise the game.
class MemoryMatchScreen extends ConsumerWidget {
  const MemoryMatchScreen({super.key});

  static const _colors = MathGameColors.memoryMatch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MathGameIntroScaffold(
      title: 'Memory Match',
      headline: 'Can you remember them all?',
      intro: 'Look at the pictures and remember where they are.',
      steps: const [
        (Icons.visibility_rounded, 'Look at the pictures'),
        (Icons.psychology_rounded, 'Remember where they are'),
        (Icons.touch_app_rounded, 'Find the right card'),
      ],
      kidSteps: const [
        KidStep(label: 'Look at the pictures', visual: _LookPicture()),
        KidStep(label: 'They hide behind numbers. Remember where they are', visual: _HiddenPicture()),
        KidStep(label: 'Find the right card', visual: _FindPicture()),
      ],
      art: MathArt.memoryMatch,
      colors: _colors,
      onStart: () => startMathGame(context, ref, MathGameId.memoryMatch),
      onHowToPlay: () => openMathGameTutorial(context, MathGameId.memoryMatch),
    );
  }
}

const _demoPictures = [MathPicture.star, MathPicture.apple, MathPicture.fish];

class _NumberCard extends StatelessWidget {
  const _NumberCard(this.number, {this.highlighted = false});

  final int number;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return MiniCard(
      color: MathPalette.grape,
      border: highlighted ? MathPalette.leaf : Colors.white.withValues(alpha: 0.5),
      child: Text(
        '$number',
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}

/// An eye and three face-up picture cards.
class _LookPicture extends StatelessWidget {
  const _LookPicture();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility_rounded, size: 34, color: MathGameColors.memoryMatch.accent),
        const SizedBox(width: 8),
        for (final p in _demoPictures)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: MiniCard(child: MathPictureView(p)),
          ),
      ],
    );
  }
}

/// A "hidden" eye and the same three cards, face-down with numbers.
class _HiddenPicture extends StatelessWidget {
  const _HiddenPicture();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.visibility_off_rounded, size: 34, color: MathGameColors.memoryMatch.accent),
        const SizedBox(width: 8),
        for (var n = 1; n <= 3; n++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _NumberCard(n),
          ),
      ],
    );
  }
}

/// "Apple → card 2", with a finger and a tick.
class _FindPicture extends StatelessWidget {
  const _FindPicture();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MiniCard(border: MathPalette.grape, child: MathPictureView(MathPicture.apple)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.arrow_forward_rounded, size: 30, color: MathPalette.ink),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: const [
            _NumberCard(2, highlighted: true),
            Positioned(
              top: -8,
              right: -8,
              child: CircleAvatar(
                radius: 11,
                backgroundColor: Colors.white,
                child: Icon(Icons.check_circle_rounded, color: MathPalette.leaf, size: 22),
              ),
            ),
            Positioned(
              right: -14,
              bottom: -12,
              child: Icon(Icons.touch_app_rounded, size: 30, color: MathPalette.ink),
            ),
          ],
        ),
      ],
    );
  }
}
