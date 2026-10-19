import 'package:flutter/material.dart';

import 'game/spelling_game_controller.dart' show GamePhase;
import 'sinhala/game/sinhala_game_controller.dart';
import 'sinhala/teacher/sinhala_teacher_screen.dart';
import 'sinhala/ui/sinhala_game_view.dart';
import 'sinhala/ui/sinhala_intro_views.dart';
import 'ui/spelling_style.dart';
import 'ui/widgets/effects.dart';

/// The Sinhala listen-and-spell game, opened from the language picker
/// (spelling_stub_screen.dart). Same look and flow as the English game.
class SinhalaSpellingScreen extends StatefulWidget {
  const SinhalaSpellingScreen({super.key});

  @override
  State<SinhalaSpellingScreen> createState() => _SinhalaSpellingScreenState();
}

class _SinhalaSpellingScreenState extends State<SinhalaSpellingScreen> {
  final SinhalaGameController _controller = SinhalaGameController();

  /// Stops the voice while the app is in the background.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: () => _act(SinhalaAction.screenHidden),
    onShow: () => _act(SinhalaAction.screenShown),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _controller.init();
  }

  void _act(SinhalaAction type, [Map<String, Object?> data = const {}]) => _controller.handleAction(type, data);

  /// Teacher View for the phone's child. The voice stops while it is open.
  void _openTeacher() {
    if (_controller.bank == null) return;
    _act(SinhalaAction.screenHidden);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => SinhalaTeacherScreen(controller: _controller)))
        .then((_) => _act(SinhalaAction.screenShown));
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SpellingColors.background,
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            final state = _controller.state;
            return Stack(
              children: [
                Positioned.fill(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: KeyedSubtree(
                      key: ValueKey(state.phase),
                      child: switch (state.phase) {
                        GamePhase.loading => const Center(child: CircularProgressIndicator()),
                        GamePhase.start =>
                          SinhalaStartView(
                            act: _act,
                            onBack: () => Navigator.of(context).maybePop(),
                            onTeacher: _openTeacher,
                          ),
                        GamePhase.demo => SinhalaDemoView(act: _act),
                        GamePhase.playing => SinhalaGameView(state: state, act: _act),
                        GamePhase.roundEnd => SinhalaRoundEndView(state: state, act: _act, onTeacher: _openTeacher),
                        GamePhase.goodbye =>
                          SinhalaRoundEndView(state: state, act: _act, onTeacher: _openTeacher, sessionOver: true),
                      },
                    ),
                  ),
                ),
                Positioned.fill(child: ConfettiOverlay(signal: state.confettiSignal)),
              ],
            );
          },
        ),
      ),
    );
  }
}
