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
import '../widgets/reward_art.dart';

/// Intro screen for Number Quest. Picture-first for children; written
/// instructions with Parent support on. Start Game opens the tutorial on a
/// first visit, otherwise the game.
class NumberQuestScreen extends ConsumerWidget {
  const NumberQuestScreen({super.key});

  static const _colors = MathGameColors.numberQuest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MathGameIntroScaffold(
      title: 'Number Quest',
      headline: 'Ready for a maths adventure?',
      intro: 'Count the objects and solve fun maths questions.',
      steps: const [
        (Icons.apple, 'Count the objects'),
        (Icons.calculate_rounded, 'Solve the question'),
        (Icons.star_rounded, 'Collect stars'),
      ],
      kidSteps: const [
        KidStep(
          label: 'Look at the pictures and count. Add, take away, times or share.',
          visual: _CountPicture(),
        ),
        KidStep(label: 'Tap the right answer', visual: _AnswerPicture()),
        KidStep(label: 'Right answers give you points and stars', visual: _StarsPicture()),
      ],
      art: MathArt.numberQuest,
      colors: _colors,
      onStart: () => startMathGame(context, ref, MathGameId.numberQuest),
      onHowToPlay: () => openMathGameTutorial(context, MathGameId.numberQuest),
    );
  }
}

const _signColors = [MathPalette.sky, MathPalette.grass, MathPalette.tangerine, MathPalette.grape];

TextStyle _bigSign(Color color) =>
    TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color, height: 1);

/// Step 1: a picture sum (🍎🍎 + 🍎 = ?) above the four maths signs.
class _CountPicture extends StatelessWidget {
  const _CountPicture();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MathPictureView(MathPicture.apple, size: 30),
            const MathPictureView(MathPicture.apple, size: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('+', style: _bigSign(MathPalette.ink)),
            ),
            const MathPictureView(MathPicture.apple, size: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text('=', style: _bigSign(MathPalette.ink)),
            ),
            CircleAvatar(
              radius: 15,
              backgroundColor: Colors.white,
              child: Text('?',
                  style: _bigSign(MathGameColors.numberQuest.accent).copyWith(fontSize: 20)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, sign) in const ['+', '-', '×', '÷'].indexed)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: MathSignBadge(sign, color: _signColors[i], size: 24),
              ),
          ],
        ),
      ],
    );
  }
}

/// Step 2: "=" then answer bubbles 2 3 4, with a finger tapping the right one.
class _AnswerPicture extends StatelessWidget {
  const _AnswerPicture();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text('=', style: _bigSign(MathPalette.ink).copyWith(fontSize: 30)),
        ),
        for (final n in const [2, 3, 4])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: n == 3 ? MathPalette.leaf : Colors.white,
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: n == 3 ? Colors.white : MathPalette.ink,
                    ),
                  ),
                ),
                if (n == 3) ...[
                  const Positioned(
                    top: -6,
                    right: -6,
                    child: CircleAvatar(
                      radius: 10,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.check_circle_rounded, color: MathPalette.leaf, size: 20),
                    ),
                  ),
                  const Positioned(
                    right: -10,
                    bottom: -12,
                    child: Icon(Icons.touch_app_rounded, size: 28, color: MathPalette.ink),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Step 3: right answer → +10 points → stars.
class _StarsPicture extends StatelessWidget {
  const _StarsPicture();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const RewardArtView(RewardArt.correct, size: 36),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward_rounded, size: 22, color: MathPalette.ink),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
          child: const Text(
            '+10',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: MathPalette.leaf),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Icon(Icons.arrow_forward_rounded, size: 22, color: MathPalette.ink),
        ),
        const StarRatingView(earned: 3, size: 26),
      ],
    );
  }
}
