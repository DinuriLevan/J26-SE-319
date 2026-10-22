import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/math_progress_repository.dart';
import '../engine/activity_phase.dart';
import '../engine/attempt.dart';
import '../engine/math_picture.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/math_tutorial_scaffold.dart';
import '../widgets/parent_support.dart';
import 'engine/memory_match_models.dart';
import 'memory_match_game_screen.dart';
import 'widgets/memory_board.dart';

/// First-visit (and "How to play") tutorial for Memory Match. Its practice
/// round is local to this screen and never saved or scored.
class MemoryMatchTutorialScreen extends ConsumerWidget {
  const MemoryMatchTutorialScreen({super.key});

  static const _colors = MemoryMatchGameScreen.colors;

  static final demoRound = MemoryRound(
    config: const MemoryConfig(positions: 3, memorizeSeconds: 6),
    board: const {3: MathPicture.star, 4: MathPicture.apple, 5: MathPicture.fish},
    targetCell: 4,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MathTutorialScaffold(
      title: MemoryMatchGameScreen.title,
      colors: _colors,
      onFinish: () async {
        final navigator = Navigator.of(context);
        await ref.read(mathProgressRepositoryProvider).markTutorialSeen(MathGameId.memoryMatch);
        navigator.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const MemoryMatchGameScreen()),
        );
      },
      steps: [
        TutorialStep(
          instruction: 'Look at the pictures. Remember where they are.',
          icon: Icons.visibility_rounded,
          visual: MemoryBoard(round: demoRound, isRevealed: (_) => true),
        ),
        TutorialStep(
          instruction: 'Then the pictures hide behind numbers.',
          icon: Icons.visibility_off_rounded,
          visual: MemoryBoard(round: demoRound, isRevealed: (_) => false),
        ),
        const TutorialStep(
          instruction: 'Now you try!',
          icon: Icons.waving_hand_rounded,
          visual: MemoryMatchPractice(),
        ),
      ],
    );
  }
}

/// The tutorial's practice round: the child hides the pictures when ready
/// (no timer), then finds the apple. Nothing is recorded.
class MemoryMatchPractice extends ConsumerStatefulWidget {
  const MemoryMatchPractice({super.key});

  @override
  ConsumerState<MemoryMatchPractice> createState() => _MemoryMatchPracticeState();
}

class _MemoryMatchPracticeState extends ConsumerState<MemoryMatchPractice> {
  bool _hidden = false;
  bool _solved = false;
  final _tried = <int>{};

  static const _colors = MemoryMatchGameScreen.colors;

  @override
  Widget build(BuildContext context) {
    final round = MemoryMatchTutorialScreen.demoRound;
    final phase = _solved
        ? ActivityPhase.correct
        : (_tried.isEmpty ? ActivityPhase.answering : ActivityPhase.hint);

    final parentSupport = ref.watch(parentSupportProvider);

    // Fixed slots above and below the board keep the picture the same size
    // as the practice moves on.
    return Column(
      children: [
        SizedBox(
          height: parentSupport ? 112 : 100,
          child: _hidden
              ? TargetPrompt(picture: round.target, showText: parentSupport)
              : Center(
                  child: Icon(Icons.visibility_rounded, size: 48, color: _colors.accent),
                ),
        ),
        const SizedBox(height: 12),
        MemoryBoard(
          round: round,
          isRevealed: (cell) => !_hidden || (_solved && cell == round.targetCell),
          wrongCells: _tried,
          correctCell: _solved ? round.targetCell : null,
          onTapCell: !_hidden || _solved
              ? null
              : (cell) => setState(() {
                    if (cell == round.targetCell) {
                      _solved = true;
                    } else {
                      _tried.add(cell);
                    }
                  }),
        ),
        const SizedBox(height: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: !_hidden
              ? FilledButton.icon(
                  key: const ValueKey('practice-hide'),
                  onPressed: () => setState(() => _hidden = true),
                  icon: const Icon(Icons.visibility_off_rounded),
                  label: Text(parentSupport ? 'Hide the pictures' : 'Hide'),
                  style: mathPrimaryButtonStyle(context, _colors, height: 56),
                )
              : phase == ActivityPhase.answering
                  ? const SizedBox(width: double.infinity)
                  : FeedbackPanel(
                      phase: phase,
                      title: _solved ? 'Great job!' : FeedbackWords.tryAgain,
                      message: !parentSupport
                          ? ''
                          : (_solved
                              ? "The apple was on card 2. You're ready!"
                              : 'Think about where the apple was.'),
                      colors: _colors,
                      showNextButton: false,
                      onNext: () {},
                    ),
        ),
      ],
    );
  }
}
