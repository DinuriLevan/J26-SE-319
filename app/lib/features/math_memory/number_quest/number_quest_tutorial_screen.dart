import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/math_progress_repository.dart';
import '../engine/activity_phase.dart';
import '../engine/attempt.dart';
import '../engine/math_picture.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/math_tutorial_scaffold.dart';
import '../widgets/parent_support.dart';
import 'engine/number_quest_models.dart';
import 'number_quest_game_screen.dart';
import 'widgets/answer_choice_button.dart';
import 'widgets/quantity_view.dart';

/// First-visit (and "How to play") tutorial for Number Quest. Its practice
/// question is local to this screen and never saved or scored.
class NumberQuestTutorialScreen extends ConsumerWidget {
  const NumberQuestTutorialScreen({super.key});

  static const _colors = NumberQuestGameScreen.colors;

  static const _demo = NumberQuestion(
    skill: MathSkill.addition,
    level: 1,
    a: 2,
    b: 2,
    answer: 4,
    choices: [3, 4, 5],
    picture: MathPicture.apple,
    showObjects: true,
  );

  static const practice = NumberQuestion(
    skill: MathSkill.addition,
    level: 1,
    a: 2,
    b: 1,
    answer: 3,
    choices: [2, 3, 4],
    picture: MathPicture.star,
    showObjects: true,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MathTutorialScaffold(
      title: NumberQuestGameScreen.title,
      colors: _colors,
      onFinish: () async {
        final navigator = Navigator.of(context);
        await ref.read(mathProgressRepositoryProvider).markTutorialSeen(MathGameId.numberQuest);
        navigator.pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const NumberQuestGameScreen()),
        );
      },
      steps: [
        TutorialStep(
          instruction: 'Look at the pictures and count.',
          icon: Icons.visibility_rounded,
          visual: Column(
            children: [
              const QuantityView(question: _demo),
              const SizedBox(height: 10),
              _EquationPill(_demo.equation!),
            ],
          ),
        ),
        TutorialStep(
          instruction: 'Tap the right number.',
          icon: Icons.touch_app_rounded,
          visual: Column(
            children: [
              _EquationPill(_demo.equation!.replaceFirst('?', '${_demo.answer}')),
              const SizedBox(height: 14),
              Row(
                children: [
                  for (final (i, n) in _demo.choices.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: AnswerChoiceButton(
                        value: n,
                        state: n == _demo.answer ? ChoiceState.correct : ChoiceState.inactive,
                        colors: _colors,
                        onTap: null,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
        const TutorialStep(
          instruction: 'Now you try!',
          icon: Icons.waving_hand_rounded,
          visual: NumberQuestPractice(),
        ),
      ],
    );
  }
}

/// The tutorial's practice question. Retry as often as you like; nothing is
/// recorded.
class NumberQuestPractice extends ConsumerStatefulWidget {
  const NumberQuestPractice({super.key});

  @override
  ConsumerState<NumberQuestPractice> createState() => _NumberQuestPracticeState();
}

class _NumberQuestPracticeState extends ConsumerState<NumberQuestPractice> {
  final _tried = <int>{};
  bool _solved = false;

  static const _q = NumberQuestTutorialScreen.practice;
  static const _colors = NumberQuestGameScreen.colors;

  @override
  Widget build(BuildContext context) {
    final phase = _solved
        ? ActivityPhase.correct
        : (_tried.isEmpty ? ActivityPhase.answering : ActivityPhase.hint);
    final parentSupport = ref.watch(parentSupportProvider);

    return Column(
      children: [
        if (parentSupport) ...[
          Text(
            _q.prompt,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
        ],
        const QuantityView(question: _q),
        const SizedBox(height: 10),
        _EquationPill(_q.equation!),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final (i, n) in _q.choices.indexed) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(
                child: AnswerChoiceButton(
                  key: ValueKey('practice-$n'),
                  value: n,
                  state: _solved
                      ? (n == _q.answer ? ChoiceState.correct : ChoiceState.inactive)
                      : (_tried.contains(n) ? ChoiceState.tried : ChoiceState.idle),
                  colors: _colors,
                  onTap: _solved || _tried.contains(n)
                      ? null
                      : () => setState(() {
                            if (n == _q.answer) {
                              _solved = true;
                            } else {
                              _tried.add(n);
                            }
                          }),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 14),
        // Space is kept for feedback so the picture doesn't resize when it
        // appears.
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84),
          child: phase == ActivityPhase.answering
              ? const SizedBox(width: double.infinity)
              : FeedbackPanel(
                  phase: phase,
                  title: _solved ? 'Great job!' : FeedbackWords.tryAgain,
                  message: !parentSupport
                      ? ''
                      : (_solved ? "2 + 1 = 3. You're ready to play!" : 'Count all the stars together.'),
                  colors: _colors,
                  showNextButton: false,
                  onNext: () {},
                ),
        ),
      ],
    );
  }
}

class _EquationPill extends StatelessWidget {
  const _EquationPill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(999)),
      child: Text(
        text,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}
