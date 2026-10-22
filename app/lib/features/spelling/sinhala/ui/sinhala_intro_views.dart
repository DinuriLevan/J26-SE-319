import 'package:flutter/material.dart';

import '../../../../core/theme/app_fonts.dart';
import '../../game/spelling_game_controller.dart' show WordOutcome;
import '../../ui/round_views.dart' show SeeProgressButton;
import '../../ui/spelling_style.dart';
import '../../ui/widgets/big_icon_button.dart';
import '../../ui/widgets/mascot.dart';
import '../../ui/widgets/start_scene.dart';
import '../data/akshara.dart';
import '../game/sinhala_game_controller.dart';
import 'sinhala_game_view.dart';

/// Start screen: the same sky scene as English, with Sinhala letter blocks
/// and one huge ▶. Back (to the language picker) top-left; a small adult
/// "Teacher" button top-right.
class SinhalaStartView extends StatelessWidget {
  const SinhalaStartView({super.key, required this.act, required this.onBack, required this.onTeacher});

  final SinhalaActionHandler act;
  final VoidCallback onBack;
  final VoidCallback onTeacher;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        StartScene(
          letters: const ['අ', 'ක', 'ම', 'ප', 'ස', 'ල'],
          fontFamily: AppFonts.sinhala,
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
                onTap: () => act(SinhalaAction.startPressed),
                onExplain: () => act(SinhalaAction.explainButton, {'prompt': 'explain_play'}),
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
            onExplain: () => act(SinhalaAction.explainButton, {'prompt': 'explain_back'}),
          ),
        ),
        Positioned(
          top: 8,
          right: 8,
          child: TextButton(
            onPressed: onTeacher,
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF3E4A5E),
              backgroundColor: Colors.white.withValues(alpha: 0.75),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            child: const Text('👩‍🏫 Teacher'),
          ),
        ),
      ],
    );
  }
}

/// Animated demo: a hand drags the letter ප onto the line, then drags the
/// pilla ූ onto it, which turns it into පූ. Tap anywhere to skip.
class SinhalaDemoView extends StatefulWidget {
  const SinhalaDemoView({super.key, required this.act});

  final SinhalaActionHandler act;

  @override
  State<SinhalaDemoView> createState() => _SinhalaDemoViewState();
}

class _SinhalaDemoViewState extends State<SinhalaDemoView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))..repeat();

  static const double _tile = 64;
  static const double _gap = 14;
  static const double _lineY = 0;
  static const double _trayY = 130;
  static const String _letter = 'ප';
  static const String _mark = 'ූ'; // ූ

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
      onTap: () => widget.act(SinhalaAction.skipDemo),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Mascot(size: 110),
            const SizedBox(height: 32),
            SizedBox(
              width: 3 * _tile + 2 * _gap + 60,
              height: _trayY + _tile + 60,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final v = _controller.value;
                  // 0.10–0.40: the letter moves to the line.
                  final letterMove = Curves.easeInOut.transform(((v - 0.10) / 0.30).clamp(0.0, 1.0));
                  final letterPos = Offset.lerp(Offset(_x(0), _trayY), Offset(_x(1), _lineY), letterMove)!;
                  // 0.50–0.80: the pilla moves onto the letter.
                  final markMove = Curves.easeInOut.transform(((v - 0.50) / 0.30).clamp(0.0, 1.0));
                  final markPos = Offset.lerp(Offset(_x(2), _trayY), Offset(_x(1), _lineY), markMove)!;
                  final joined = v >= 0.80;
                  final dragging = v < 0.45 ? letterPos : markPos;
                  final pressed = (v >= 0.06 && v < 0.42) || (v >= 0.46 && v < 0.82);
                  final handOpacity = v > 0.9 ? (1 - (v - 0.9) / 0.1) : 1.0;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -10,
                        top: _lineY - 10,
                        child: Container(
                          width: 3 * _tile + 2 * _gap + 20,
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
                      Positioned(
                        left: _x(1),
                        top: _trayY,
                        child: const SinhalaTileView(label: 'ස', size: _tile),
                      ),
                      Positioned(
                        left: letterPos.dx,
                        top: letterPos.dy,
                        child: SinhalaTileView(
                          label: joined ? '$_letter$_mark' : _letter,
                          size: _tile,
                          lifted: v < 0.45 && pressed,
                          highlighted: joined,
                        ),
                      ),
                      if (!joined)
                        Positioned(
                          left: markPos.dx,
                          top: markPos.dy,
                          child: SinhalaTileView(
                            label: Akshara.markLabel(_mark),
                            size: _tile,
                            mark: true,
                            lifted: v >= 0.45 && pressed,
                          ),
                        ),
                      Positioned(
                        left: dragging.dx + 28,
                        top: dragging.dy + 30,
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

/// After every 10 words: dancing mascot, the round's stars, ▶ for the next
/// 10 words (or a goodbye after the last round of the session).
class SinhalaRoundEndView extends StatelessWidget {
  const SinhalaRoundEndView({
    super.key,
    required this.state,
    required this.act,
    required this.onTeacher,
    this.sessionOver = false,
  });

  final SinhalaGameState state;
  final SinhalaActionHandler act;
  final VoidCallback onTeacher;
  final bool sessionOver;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Mascot(size: 150, mood: sessionOver ? MascotMood.cheer : MascotMood.dance),
            if (sessionOver) const Text('👋', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 24),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final outcome in state.outcomes)
                  Icon(
                    Icons.star_rounded,
                    size: 44,
                    color: outcome == WordOutcome.solved ? SpellingColors.star : SpellingColors.starSoft,
                  ),
              ],
            ),
            const SizedBox(height: 40),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                BigIconButton(
                  icon: Icons.home_rounded,
                  color: SpellingColors.neutralButton,
                  size: sessionOver ? 110 : 72,
                  semanticLabel: 'Home',
                  onTap: () => act(SinhalaAction.homePressed),
                  onExplain: () => act(SinhalaAction.explainButton, {'prompt': 'explain_home'}),
                ),
                if (!sessionOver) ...[
                  const SizedBox(width: 32),
                  Pulse(
                    child: BigIconButton(
                      icon: Icons.play_arrow_rounded,
                      color: SpellingColors.play,
                      size: 120,
                      semanticLabel: 'Next words',
                      onTap: () => act(SinhalaAction.nextRoundPressed),
                      onExplain: () => act(SinhalaAction.explainButton, {'prompt': 'explain_play_again'}),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 36),
            SeeProgressButton(onPressed: onTeacher),
          ],
        ),
      ),
    );
  }
}
