import 'package:flutter/material.dart';

import 'game/spelling_game_controller.dart';
import 'teacher/teacher_view_screen.dart';
import 'ui/game_view.dart';
import 'ui/intro_views.dart';
import 'ui/round_views.dart';
import 'ui/spelling_style.dart';
import 'ui/widgets/effects.dart';

/// The adaptive English listen-and-spell game, opened from the language
/// picker (spelling_stub_screen.dart).
class EnglishSpellingScreen extends StatefulWidget {
  const EnglishSpellingScreen({super.key});

  @override
  State<EnglishSpellingScreen> createState() => _EnglishSpellingScreenState();
}

class _EnglishSpellingScreenState extends State<EnglishSpellingScreen> {
  final SpellingGameController _controller = SpellingGameController();

  /// Pauses the game timers while the app is in the background.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: () => _act(SpellingAction.screenHidden, {'reason': 'app'}),
    onShow: () => _act(SpellingAction.screenShown, {'reason': 'app'}),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle;
    _controller.init();
  }

  void _act(SpellingAction type, [Map<String, Object?> data = const {}]) =>
      _controller.handleAction(type, data);

  /// Teacher View for the child who just played (or the most recent one).
  /// Closing it returns to the screen it was opened from.
  void _openTeacherView() {
    final engine = _controller.engine;
    if (engine == null) return;
    _act(SpellingAction.screenHidden);
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => TeacherViewScreen(engine: engine)))
        .then((_) {
      _act(SpellingAction.screenShown);
      _controller.refresh();
    });
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
                        GamePhase.start => StartView(
                            act: _act,
                            onTeacher: _openTeacherView,
                            onBack: () => Navigator.of(context).maybePop(),
                          ),
                        GamePhase.demo => DemoView(act: _act),
                        GamePhase.playing => GameView(state: state, act: _act),
                        GamePhase.roundEnd =>
                          RoundEndView(state: state, act: _act, onTeacher: _openTeacherView),
                        GamePhase.goodbye => RoundEndView(
                            state: state,
                            act: _act,
                            onTeacher: _openTeacherView,
                            sessionOver: true,
                          ),
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
