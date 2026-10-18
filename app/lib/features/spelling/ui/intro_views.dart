import 'package:flutter/material.dart';

import '../game/spelling_game_controller.dart';
import 'game_view.dart';
import 'spelling_style.dart';
import 'widgets/big_icon_button.dart';
import 'widgets/letter_tile.dart';
import 'widgets/mascot.dart';
import 'widgets/start_scene.dart';

/// Start screen: a playful letter-block scene with one huge ▶ in the middle.
/// Tapping ▶ also unlocks audio. A back button (to the language picker)
/// sits top-left and a small adult button top-right.
class StartView extends StatelessWidget {
  const StartView({super.key, required this.act, required this.onTeacher, required this.onBack});

  final ActionHandler act;
  final VoidCallback onTeacher;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StartScene(
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.7),
              boxShadow: const [BoxShadow(color: Color(0x1A2F3A56), blurRadius: 30)],
            ),
            child: Pulse(
              child: BigIconButton(
                icon: Icons.play_arrow_rounded,
                color: SpellingColors.play,
                size: 150,
                semanticLabel: 'Play',
                onTap: () => act(SpellingAction.startPressed),
                onExplain: () => act(SpellingAction.explainButton, {'purpose': ButtonPurpose.play}),
              ),
            ),
          ),
        ),
        Positioned(
          top: 8,
          left: 12,
          child: BigIconButton(
            icon: Icons.arrow_back_rounded,
            color: SpellingColors.neutralButton,
            size: 52,
            semanticLabel: 'Back',
            onTap: onBack,
            onExplain: () => act(SpellingAction.explainButton, {'purpose': ButtonPurpose.back}),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _AdultButton(label: '👩‍🏫 Teacher', onPressed: onTeacher),
        ),
      ],
    );
  }
}

/// Animated demo: a hand drags the "c" tile into the first box while the
/// voice explains. Tap anywhere to skip.
class DemoView extends StatefulWidget {
  const DemoView({super.key, required this.act});

  final ActionHandler act;

  @override
  State<DemoView> createState() => _DemoViewState();
}

class _DemoViewState extends State<DemoView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))..repeat();

  static const double _tile = 64;
  static const double _gap = 14;
  static const double _boardWidth = 3 * _tile + 2 * _gap;
  static const double _slotY = 0;
  static const double _trayY = 130;
  static const _trayLetters = ['a', 'c', 't'];
  static const int _movingIndex = 1; // the "c"

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _x(int i) => i * (_tile + _gap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.act(SpellingAction.skipDemo),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(size: 110),
            const SizedBox(height: 32),
            SizedBox(
              width: _boardWidth + 60,
              height: _trayY + _tile + 60,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final v = _controller.value;
                  final from = Offset(_x(_movingIndex), _trayY);
                  final to = Offset(_x(0), _slotY);
                  final move = Curves.easeInOut.transform(((v - 0.3) / 0.45).clamp(0.0, 1.0));
                  final tilePos = Offset.lerp(from, to, move)!;
                  final handStart = from + const Offset(80, 90);
                  final approach = Curves.easeOut.transform((v / 0.2).clamp(0.0, 1.0));
                  final handPos = v < 0.3
                      ? Offset.lerp(handStart, tilePos + const Offset(28, 30), approach)!
                      : tilePos + const Offset(28, 30);
                  final pressed = v >= 0.2 && v < 0.75;
                  final handOpacity = v > 0.85 ? (1 - (v - 0.85) / 0.15) : 1.0;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // The answer line (no boxes), as in the game.
                      Positioned(
                        left: -10,
                        top: _slotY - 10,
                        child: Container(
                          width: _boardWidth + 20,
                          height: _tile + 20,
                          decoration: const BoxDecoration(
                            color: SpellingColors.slot,
                            borderRadius: BorderRadius.all(Radius.circular(20)),
                            border: Border(
                              left: BorderSide(color: SpellingColors.slotBorder, width: 2),
                              top: BorderSide(color: SpellingColors.slotBorder, width: 2),
                              right: BorderSide(color: SpellingColors.slotBorder, width: 2),
                              bottom: BorderSide(color: SpellingColors.slotBorder, width: 6),
                            ),
                          ),
                        ),
                      ),
                      for (var i = 0; i < 3; i++)
                        if (i != _movingIndex)
                          Positioned(
                            left: _x(i),
                            top: _trayY,
                            child: LetterTileView(letter: _trayLetters[i], size: _tile),
                          ),
                      Positioned(
                        left: tilePos.dx,
                        top: tilePos.dy,
                        child: LetterTileView(letter: 'c', size: _tile, lifted: pressed),
                      ),
                      Positioned(
                        left: handPos.dx,
                        top: handPos.dy,
                        child: Opacity(
                          opacity: handOpacity.clamp(0.0, 1.0),
                          child: Transform.scale(
                            scale: pressed ? 0.9 : 1,
                            child: const Text('👆', style: TextStyle(fontSize: 48)),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small, plain, clearly-for-grown-ups button (has a text label on purpose).
class _AdultButton extends StatelessWidget {
  const _AdultButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: const Color(0xFF3E4A5E),
        backgroundColor: Colors.white.withValues(alpha: 0.75),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: const Size(0, 36),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      child: Text(label),
    );
  }
}
