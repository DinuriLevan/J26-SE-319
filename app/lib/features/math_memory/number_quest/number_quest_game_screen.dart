import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/math_progress_repository.dart';
import '../engine/activity_phase.dart';
import '../engine/attempt.dart';
import '../ml/next_attempt_planner.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/game_progress_header.dart';
import '../widgets/leave_game_dialog.dart';
import '../widgets/math_palette.dart';
import '../widgets/math_result_screens.dart';
import 'engine/number_quest_models.dart';
import 'engine/number_quest_session.dart';
import 'widgets/answer_choice_button.dart';
import 'widgets/quantity_view.dart';

/// One real Number Quest attempt — the baseline the first time, then scored.
class NumberQuestGameScreen extends ConsumerStatefulWidget {
  const NumberQuestGameScreen({super.key});

  static const title = 'Number Quest';
  static const colors = MathGameColors.numberQuest;

  @override
  ConsumerState<NumberQuestGameScreen> createState() => _NumberQuestGameScreenState();
}

class _NumberQuestGameScreenState extends ConsumerState<NumberQuestGameScreen> {
  NumberQuestSession? _session;
  bool _saving = false;
  final _scroll = GameScrollFollower();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final progress = await ref.read(mathProgressRepositoryProvider).loadNumberQuest();
    if (!mounted) return;
    setState(() {
      _session = NumberQuestSession(
        progress: progress,
        seed: ref.read(mathGameSeedProvider)(),
        clock: ref.read(mathGameClockProvider),
      )..addListener(_onSessionChanged);
    });
  }

  @override
  void dispose() {
    _session?.removeListener(_onSessionChanged);
    _session?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    final session = _session!;
    setState(() {});
    _scroll.onActivityChanged(index: session.index, showingFeedback: session.phase.awaitingNext);
    if (session.phase == ActivityPhase.finished) _finish(session);
  }

  Future<void> _finish(NumberQuestSession session) async {
    if (_saving) return;
    _saving = true;
    final result = session.result!;
    try {
      // The trained model picks where the next attempt starts (rules fallback).
      final plan = await ref.read(nextAttemptPlannerProvider).planNumberQuest(result);
      await ref.read(mathProgressRepositoryProvider).completeAttempt(
            game: MathGameId.numberQuest,
            progressAfter: plan.progressAfter.toJson(),
            payload: {...result.payload, 'next_attempt': plan.trace},
          );
    } catch (e) {
      debugPrint('Number Quest: could not save attempt: $e');
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (context) {
        void playAgain() => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const NumberQuestGameScreen()),
            );
        final score = result.score;
        if (score == null) {
          return BaselineCompleteScreen(
            gameTitle: NumberQuestGameScreen.title,
            colors: NumberQuestGameScreen.colors,
            onPlayAgain: playAgain,
          );
        }
        return ScoredResultsScreen(
          gameTitle: NumberQuestGameScreen.title,
          colors: NumberQuestGameScreen.colors,
          score: score,
          correctLabel: 'Correct answers',
          message: encouragementFor(score.stars, threeStarMessage: "Amazing! You're a number star!"),
          onPlayAgain: playAgain,
        );
      },
    ));
  }

  Future<void> _leave() async {
    final session = _session;
    final navigator = Navigator.of(context);
    if (session == null || !session.hasProgress || _saving) {
      navigator.pop();
      return;
    }
    if (!await confirmLeaveGame(context, NumberQuestGameScreen.colors)) return;
    ref
        .read(mathProgressRepositoryProvider)
        .recordAbandonedAttempt(game: MathGameId.numberQuest, payload: session.abandonedPayload())
        .catchError((Object e) => debugPrint('Number Quest: could not queue abandoned attempt: $e'));
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            tooltip: 'Stop playing',
            onPressed: _leave,
          ),
          title: const Text(NumberQuestGameScreen.title),
        ),
        body: SafeArea(
          child: session == null || session.phase == ActivityPhase.finished
              ? const Center(child: CircularProgressIndicator())
              : _QuestionView(session: session, scroll: _scroll),
        ),
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({required this.session, required this.scroll});

  final NumberQuestSession session;
  final GameScrollFollower scroll;

  static const _colors = NumberQuestGameScreen.colors;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = session.current;
    final phase = session.phase;

    return SingleChildScrollView(
      controller: scroll.controller,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GameProgressHeader(
                label: 'Question',
                index: session.index,
                total: session.totalQuestions,
                colors: _colors,
                points: session.isBaseline ? null : session.points,
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_colors.light, _colors.mid],
                  ),
                  border: Border.all(color: _colors.accent.withValues(alpha: 0.2), width: 2),
                ),
                child: Column(
                  children: [
                    if (session.currentIsReinforcement) ...[
                      const _PracticeChip(),
                      const SizedBox(height: 8),
                    ],
                    Text(
                      q.prompt,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MathPalette.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    QuantityView(question: q),
                    if (q.equation != null && q.showObjects) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          q.equation!,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: MathPalette.ink,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  for (final (i, choice) in q.choices.indexed) ...[
                    if (i > 0) const SizedBox(width: 10),
                    Expanded(
                      child: AnswerChoiceButton(
                        key: ValueKey('choice-$choice'),
                        value: choice,
                        state: _stateFor(choice),
                        colors: _colors,
                        onTap: phase.acceptsAnswer && !session.wrongChoices.contains(choice)
                            ? () => session.select(choice)
                            : null,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: KeyedSubtree(key: scroll.feedbackKey, child: _feedback()),
              ),
            ],
          ),
        ),
      ),
    );
  }

  ChoiceState _stateFor(int choice) {
    final q = session.current;
    final tried = session.wrongChoices.contains(choice);
    return switch (session.phase) {
      ActivityPhase.correct when choice == q.answer => ChoiceState.correct,
      ActivityPhase.revealed when choice == q.answer => ChoiceState.revealed,
      _ when tried => ChoiceState.tried,
      ActivityPhase.correct || ActivityPhase.revealed => ChoiceState.inactive,
      _ => ChoiceState.idle,
    };
  }

  Widget _feedback() {
    final q = session.current;
    final phase = session.phase;
    final solved = _solvedSentence(q);
    final isLast = session.index == session.totalQuestions - 1;

    return switch (phase) {
      ActivityPhase.hint => FeedbackPanel(
          phase: phase,
          title: FeedbackWords.tryAgain,
          message: hintFor(q),
          colors: _colors,
          onNext: () {},
        ),
      ActivityPhase.correct => FeedbackPanel(
          phase: phase,
          title: FeedbackWords.praise(session.index),
          message: solved,
          colors: _colors,
          pointsEarned: session.isBaseline ? null : _lastPoints(),
          nextLabel: isLast ? 'Finish' : 'Next',
          onNext: session.next,
        ),
      ActivityPhase.revealed => FeedbackPanel(
          phase: phase,
          title: 'The answer is ${q.answer}.',
          message: '$solved ${FeedbackWords.keepGoing}',
          colors: _colors,
          pointsEarned: session.isBaseline ? null : _lastPoints(),
          nextLabel: isLast ? 'Finish' : 'Next',
          onNext: session.next,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  int _lastPoints() => session.scoring.pointsFor(session.records.last.outcome);

  static String _solvedSentence(NumberQuestion q) => q.skill == MathSkill.counting
      ? 'There are ${q.answer} ${q.answer == 1 ? q.picture.label : q.picture.plural}.'
      : q.equation!.replaceFirst('?', '${q.answer}');
}

/// One short, skill-specific tip after a wrong answer.
String hintFor(NumberQuestion q) {
  if (q.showObjects) {
    return switch (q.skill) {
      MathSkill.counting => 'Touch each one as you count.',
      MathSkill.addition => 'Count all the pictures together.',
      MathSkill.subtraction => 'Count the ones that are not crossed out.',
      MathSkill.multiplication => 'Count every group, one by one.',
      MathSkill.division => 'Share them onto the plates, one at a time.',
    };
  }
  return switch (q.skill) {
    MathSkill.counting => 'Touch each one as you count.',
    MathSkill.addition => 'Start at ${q.a} and count on ${q.b}.',
    MathSkill.subtraction => 'Start at ${q.a} and count back ${q.b}.',
    MathSkill.multiplication => 'Add ${q.b}, ${q.a} times.',
    MathSkill.division => 'How many ${q.b}s make ${q.a}?',
  };
}

class _PracticeChip extends StatelessWidget {
  const _PracticeChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.replay_rounded, size: 18, color: NumberQuestGameScreen.colors.accent),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              "Let's practise this one",
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: NumberQuestGameScreen.colors.accent,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
