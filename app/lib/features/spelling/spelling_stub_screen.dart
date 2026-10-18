import 'package:flutter/material.dart';

import '../../core/theme/app_fonts.dart';
import '../../shared/widgets/app_drawer.dart';
import 'english_spelling_screen.dart';
import 'services/voice_service.dart';
import 'sinhala_spelling_screen.dart';
import 'ui/spelling_style.dart';
import 'ui/widgets/mascot.dart';

/// Spelling & Phonics tab: pick English or Sinhala, then open that
/// language's game.
///
/// Made for children who find reading hard: the game's calm cream/sky look,
/// big picture-like cards (letter blocks + the language's own name), no
/// instructions to read. Long-press a card to hear its name.
///
/// File/class name kept from the original stub (see docs/CONTRIBUTING.md) so
/// the home shell doesn't need to change.
class SpellingStubScreen extends StatefulWidget {
  const SpellingStubScreen({super.key});

  @override
  State<SpellingStubScreen> createState() => _SpellingStubScreenState();
}

class _SpellingStubScreenState extends State<SpellingStubScreen> {
  final VoiceService _voice = VoiceService();

  @override
  void dispose() {
    _voice.stop();
    super.dispose();
  }

  void _open(Widget screen) {
    _voice.stop();
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpellingColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFCDE9FF), Color(0xFFEAF5FF), SpellingColors.background],
            stops: [0, 0.35, 0.7],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 64, 24, 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        const Mascot(size: 120),
                        const SizedBox(height: 32),
                        _LanguageCard(
                          name: 'English',
                          spoken: 'English',
                          fontFamily: AppFonts.latin,
                          letters: const ['a', 'b', 'c'],
                          color: SpellingColors.replay,
                          background: const Color(0xFFE3F0FF),
                          onTap: () => _open(const EnglishSpellingScreen()),
                          onExplain: () => _voice.say(['English']),
                        ),
                        const SizedBox(height: 24),
                        _LanguageCard(
                          name: 'සිංහල',
                          spoken: 'Sinhala',
                          fontFamily: AppFonts.sinhala,
                          letters: const ['අ', 'ආ', 'ඉ'],
                          color: SpellingColors.play,
                          background: const Color(0xFFFFF0D6),
                          comingSoon: true,
                          onTap: () => _open(const SinhalaSpellingScreen()),
                          onExplain: () => _voice.say(['Sinhala']),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Positioned(top: 4, left: 4, child: DrawerMenuButton()),
            ],
          ),
        ),
      ),
    );
  }
}

/// One big, picture-like card: three coloured letter blocks, the language's
/// name in its own script, and a round ▶ (or ⏳ while it is not ready yet).
/// Shrinks a little under the finger so the child sees it was pressed.
class _LanguageCard extends StatefulWidget {
  const _LanguageCard({
    required this.name,
    required this.spoken,
    required this.fontFamily,
    required this.letters,
    required this.color,
    required this.background,
    required this.onTap,
    required this.onExplain,
    this.comingSoon = false,
  });

  final String name;
  final String spoken;
  final String fontFamily;
  final List<String> letters;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  final VoidCallback onExplain;
  final bool comingSoon;

  @override
  State<_LanguageCard> createState() => _LanguageCardState();
}

class _LanguageCardState extends State<_LanguageCard> {
  bool _pressed = false;

  static const _blockColors = [Color(0xFFFF8FAB), Color(0xFF6BCB77), Color(0xFFC490E4)];
  static const _tilt = [-0.12, 0.06, -0.05];

  void _press(bool down) => setState(() => _pressed = down);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.spoken,
      child: GestureDetector(
        onTapDown: (_) => _press(true),
        onTapCancel: () => _press(false),
        onTapUp: (_) => _press(false),
        onTap: widget.onTap,
        onLongPress: widget.onExplain,
        child: AnimatedScale(
          scale: _pressed ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 20, 24),
            decoration: BoxDecoration(
              color: widget.background,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: widget.color.withValues(alpha: 0.45), width: 3),
              boxShadow: const [BoxShadow(color: SpellingColors.tileShadow, blurRadius: 14, offset: Offset(0, 6))],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < widget.letters.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Transform.rotate(
                                angle: _tilt[i % _tilt.length],
                                child: _Block(
                                  letter: widget.letters[i],
                                  color: _blockColors[i % _blockColors.length],
                                  fontFamily: widget.fontFamily,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.name,
                        style: TextStyle(
                          fontFamily: widget.fontFamily,
                          fontSize: 34,
                          fontWeight: FontWeight.w600,
                          color: SpellingColors.ink,
                          letterSpacing: widget.fontFamily == AppFonts.latin ? 1.5 : 0,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _GoBadge(color: widget.comingSoon ? SpellingColors.neutralButton : widget.color, wait: widget.comingSoon),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A coloured 3-D letter block, as in the game's start scene.
class _Block extends StatelessWidget {
  const _Block({required this.letter, required this.color, required this.fontFamily});

  final String letter;
  final Color color;
  final String fontFamily;

  static const double size = 60;

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
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Text(
        letter,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: size * 0.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Round "go" button on the card: ▶ when the game is ready, ⏳ when not yet.
class _GoBadge extends StatelessWidget {
  const _GoBadge({required this.color, required this.wait});

  final Color color;
  final bool wait;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Icon(
        wait ? Icons.hourglass_top_rounded : Icons.play_arrow_rounded,
        color: Colors.white,
        size: wait ? 32 : 44,
      ),
    );
  }
}
