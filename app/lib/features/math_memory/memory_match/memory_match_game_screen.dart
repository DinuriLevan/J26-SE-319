import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/math_progress_repository.dart';
import '../engine/activity_phase.dart';
import '../engine/attempt.dart';
import '../ml/next_attempt_planner.dart';
import '../engine/math_picture.dart';
import '../widgets/feedback_panel.dart';
import '../widgets/game_progress_header.dart';
import '../widgets/leave_game_dialog.dart';
import '../widgets/math_palette.dart';
import '../widgets/math_pictures.dart';
import '../widgets/math_result_screens.dart';
import 'engine/memory_match_models.dart';
import 'engine/memory_match_session.dart';
import 'widgets/memory_board.dart';

/// One real Memory Match attempt — the baseline the first time, then scored.
class MemoryMatchGameScreen extends ConsumerStatefulWidget {
  const MemoryMatchGameScreen({super.key});

  static const title = 'Memory Match';
  static const colors = MathGameColors.memoryMatch;
  static const memorizeInstruction = 'Look carefully and remember where each picture is!';

  @override
  ConsumerState<MemoryMatchGameScreen> createState() => _MemoryMatchGameScreenState();
}

class _MemoryMatchGameScreenState extends ConsumerState<MemoryMatchGameScreen>
    with SingleTickerProviderStateMixin {
  MemoryMatchSession? _session;
  late final AnimationController _memorizeTimer;
  MemoryRound? _timedRound;
  bool _saving = false;
  final _scroll = GameScrollFollower();

  @override
  void initState() {
    super.initState();
    _memorizeTimer = AnimationController(vsync: this)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _session?.hidePictures();
      });
    _load();
  }

  Future<void> _load() async {
    final progress = await ref.read(mathProgressRepositoryProvider).loadMemoryMatch();
    if (!mounted) return;
    setState(() {
      _session = MemoryMatchSession(
        progress: progress,
        seed: ref.read(mathGameSeedProvider)(),
        clock: ref.read(mathGameClockProvider),
      )..addListener(_onSessionChanged);
    });
    _startMemorizeTimerIfNeeded();
  }

  @override
  void dispose() {
    _memorizeTimer.dispose();
    _session?.removeListener(_onSessionChanged);
    _session?.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    final session = _session!;
    setState(() {});
    _scroll.onActivityChanged(
      index: session.index,
      showingFeedback: session.phase.awaitingNext,
    );
    if (session.phase == ActivityPhase.finished) {
      _memorizeTimer.stop();
      _finish(session);
    } else if (session.stage == MemoryStage.recalling) {
      _memorizeTimer.stop();
    } else {
      _startMemorizeTimerIfNeeded();
    }
  }

  /// Starts the gentle "look" timer once per round.
  void _startMemorizeTimerIfNeeded() {
    final session = _session;
    if (session == null || session.stage != MemoryStage.memorizing) return;
    if (identical(_timedRound, session.round)) return;
    _timedRound = session.round;
    _memorizeTimer.duration = Duration(seconds: session.round.config.memorizeSeconds);
    _memorizeTimer.forward(from: 0);
  }

  Future<void> _finish(MemoryMatchSession session) async {
    if (_saving) return;
    _saving = true;
    final result = session.result!;
    try {
      // The trained model picks where the next attempt starts (rules fallback).
      final plan = await ref.read(nextAttemptPlannerProvider).planMemoryMatch(result);
      await ref.read(mathProgressRepositoryProvider).completeAttempt(
            game: MathGameId.memoryMatch,
            progressAfter: plan.progressAfter.toJson(),
            payload: {...result.payload, 'next_attempt': plan.trace},
          );
    } catch (e) {
      debugPrint('Memory Match: could not save attempt: $e');
    }
    if (!mounted) return;

    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (context) {
        void playAgain() => Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(builder: (_) => const MemoryMatchGameScreen()),
            );
        final score = result.score;
        if (score == null) {
          return BaselineCompleteScreen(
            gameTitle: MemoryMatchGameScreen.title,
            colors: MemoryMatchGameScreen.colors,
            onPlayAgain: playAgain,
          );
        }
        return ScoredResultsScreen(
          gameTitle: MemoryMatchGameScreen.title,
          colors: MemoryMatchGameScreen.colors,
          score: score,
          correctLabel: 'Correct recalls',
          message: encouragementFor(score.stars, threeStarMessage: 'Amazing memory!'),
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
    if (!await confirmLeaveGame(context, MemoryMatchGameScreen.colors)) return;
    ref
        .read(mathProgressRepositoryProvider)
        .recordAbandonedAttempt(game: MathGameId.memoryMatch, payload: session.abandonedPayload())
        .catchError((Object e) => debugPrint('Memory Match: could not queue abandoned attempt: $e'));
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
          title: const Text(MemoryMatchGameScreen.title),
        ),
        body: SafeArea(
          child: session == null || session.phase == ActivityPhase.finished
              ? const Center(child: CircularProgressIndicator())
              : _RoundView(session: session, memorizeTimer: _memorizeTimer, scroll: _scroll),
        ),
      ),
    );
  }
}

class _RoundView extends StatelessWidget {
  const _RoundView({required this.session, required this.memorizeTimer, required this.scroll});

  final MemoryMatchSession session;
  final GameScrollFollower scroll;
  final AnimationController memorizeTimer;

  static const _colors = MemoryMatchGameScreen.colors;

  @override
  Widget build(BuildContext context) {
    final memorizing = session.stage == MemoryStage.memorizing;
    final round = session.round;

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
                label: 'Round',
                index: session.index,
                total: session.totalRounds,
                colors: _colors,
                points: session.isBaseline ? null : session.points,
              ),
              const SizedBox(height: 10),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: memorizing
                    ? _MemorizeBanner(key: const ValueKey('memorize'), timer: memorizeTimer)
                    : TargetPrompt(key: ValueKey('recall-${session.index}'), picture: round.target),
              ),
              const SizedBox(height: 10),
              MemoryBoard(
                round: round,
                isRevealed: session.isRevealed,
                wrongCells: session.wrongCells,
                correctCell: session.phase.awaitingNext ? round.targetCell : null,
                onTapCell: memorizing || !session.phase.acceptsAnswer ? null : session.select,
              ),
              const SizedBox(height: 12),
              if (memorizing)
                FilledButton.icon(
                  onPressed: session.hidePictures,
                  icon: const Icon(Icons.thumb_up_alt_rounded),
                  label: const Text("I'm ready!"),
                  style: mathPrimaryButtonStyle(context, _colors),
                )
              else
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

  Widget _feedback() {
    final round = session.round;
    final phase = session.phase;
    final name = round.target.label;
    final isLast = session.index == session.totalRounds - 1;
    final points = session.isBaseline || session.records.isEmpty
        ? null
        : session.scoring.pointsFor(session.records.last.outcome);

    return switch (phase) {
      ActivityPhase.hint => FeedbackPanel(
          phase: phase,
          title: FeedbackWords.tryAgain,
          message: 'Think about where the $name was.',
          colors: _colors,
          onNext: () {},
        ),
      ActivityPhase.correct => FeedbackPanel(
          phase: phase,
          title: FeedbackWords.praise(session.index),
          message: 'The $name was on card ${round.targetNumber}.',
          colors: _colors,
          pointsEarned: points,
          nextLabel: isLast ? 'Finish' : 'Next',
          onNext: session.next,
        ),
      ActivityPhase.revealed => FeedbackPanel(
          phase: phase,
          title: 'It was card ${round.targetNumber}.',
          message: 'Here it is! ${FeedbackWords.keepGoing}',
          colors: _colors,
          pointsEarned: points,
          nextLabel: isLast ? 'Finish' : 'Next',
          onNext: session.next,
        ),
      _ => const SizedBox.shrink(),
    };
  }
}

/// "Look carefully…" with a soft bar that empties while the pictures show.
/// No numbers counting down, to keep it calm.
class _MemorizeBanner extends StatelessWidget {
  const _MemorizeBanner({super.key, required this.timer});

  final AnimationController timer;

  static const _colors = MemoryMatchGameScreen.colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [_colors.light, _colors.mid]),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                child: Icon(Icons.visibility_rounded, color: _colors.accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  MemoryMatchGameScreen.memorizeInstruction,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: MathPalette.ink,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedBuilder(
            animation: timer,
            builder: (context, _) => ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: 1 - timer.value,
                minHeight: 8,
                color: _colors.accent.withValues(alpha: 0.7),
                backgroundColor: Colors.white,
                semanticsLabel: 'Looking time',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Where was the fish?" with the target picture. With [showText] off (child
/// mode) it's just the picture and a big "?"; screen readers still hear the
/// question.
class TargetPrompt extends StatelessWidget {
  const TargetPrompt({super.key, required this.picture, this.showText = true});

  final MathPicture picture;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    final colors = MemoryMatchGameScreen.colors;
    final pictureBox = Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent, width: 3),
      ),
      child: MathPictureView(picture),
    );

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(colors: [colors.light, colors.mid]),
      ),
      child: showText
          ? Row(
              children: [
                pictureBox,
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Where was the ${picture.label}?',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: MathPalette.ink,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tap its card number.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: MathPalette.ink),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Semantics(
              label: 'Where was the ${picture.label}? Tap its card number.',
              excludeSemantics: true,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  pictureBox,
                  const SizedBox(width: 14),
                  Icon(Icons.question_mark_rounded, size: 48, color: colors.accent),
                ],
              ),
            ),
    );
  }
}
