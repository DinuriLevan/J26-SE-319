import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../engine/activity_phase.dart';
import '../../engine/attempt.dart';
import '../../engine/scoring.dart';
import 'memory_match_adaptive_engine.dart';
import 'memory_match_models.dart';
import 'memory_round_generator.dart';

/// Whether the current round's pictures are showing or hidden.
enum MemoryStage { memorizing, recalling }

/// One completed recall round.
class MemoryRoundRecord {
  const MemoryRoundRecord({
    required this.round,
    required this.viewedMs,
    required this.outcome,
    required this.selectedNumbers,
    required this.change,
  });

  final MemoryRound round;

  /// How long the pictures were actually face-up (the child may tap
  /// "I'm ready!" before the configured time runs out).
  final int viewedMs;

  final AnswerOutcome outcome;

  /// Card numbers tapped, in order.
  final List<int> selectedNumbers;

  /// The configuration change this round caused (always none in a baseline).
  final MemoryChange change;

  Map<String, dynamic> toJson(int index) => {
        'index': index,
        ...round.toJson(),
        'viewed_ms': viewedMs,
        ...outcome.toJson(),
        'selected_numbers': selectedNumbers,
        'config_change': change.name,
        'completed': true,
      };
}

class MemoryMatchAttemptResult {
  const MemoryMatchAttemptResult({
    required this.attemptType,
    required this.attemptNumber,
    required this.records,
    required this.score,
    required this.progressAfter,
    required this.payload,
  });

  final AttemptType attemptType;
  final int attemptNumber;
  final List<MemoryRoundRecord> records;

  /// Null for a baseline: baselines are never graded.
  final AttemptScore? score;

  final MemoryMatchProgress progressAfter;
  final Map<String, dynamic> payload;
}

/// Runs one real Memory Match attempt: look → pictures hide → find the
/// target's numbered card. UI-free so it can be unit tested.
class MemoryMatchSession extends ChangeNotifier {
  MemoryMatchSession({
    required MemoryMatchProgress progress,
    required int seed,
    DateTime Function()? clock,
    this.engine = const MemoryMatchAdaptiveEngine(),
    this.scoring = ScoringConfig.standard,
    String? attemptId,
  })  : _progressBefore = progress,
        _adaptive = progress.adaptive,
        _generator = MemoryRoundGenerator(Random(seed)),
        _clock = clock ?? DateTime.now,
        attemptId = attemptId ?? const Uuid().v4(),
        attemptType = progress.nextAttemptType {
    _startedAt = _clock();
    _startRound();
  }

  final MemoryMatchAdaptiveEngine engine;
  final ScoringConfig scoring;
  final String attemptId;
  final AttemptType attemptType;

  final MemoryMatchProgress _progressBefore;
  MemoryAdaptiveState _adaptive;
  final MemoryRoundGenerator _generator;
  final DateTime Function() _clock;
  final _records = <MemoryRoundRecord>[];

  late DateTime _startedAt;
  late MemoryRound _round;
  late DateTime _stageStartedAt;
  MemoryStage _stage = MemoryStage.memorizing;
  ActivityPhase _phase = ActivityPhase.answering;
  int _viewedMs = 0;
  final _selectedCells = <int>[];
  int? _firstResponseMs;
  int _points = 0;
  MemoryMatchAttemptResult? _result;

  bool get isBaseline => attemptType == AttemptType.baseline;
  int get attemptNumber => _progressBefore.nextAttemptNumber;
  int get totalRounds => isBaseline
      ? engine.config.baselinePlan.length
      : engine.config.roundsPerScoredAttempt;

  /// 0-based index of the current round.
  int get index => _records.length - (_phase.awaitingNext || _phase == ActivityPhase.finished ? 1 : 0);

  MemoryRound get round => _round;
  MemoryStage get stage => _stage;
  ActivityPhase get phase => _phase;
  int get points => _points;
  MemoryConfig get currentConfig => _adaptive.config;
  List<MemoryRoundRecord> get records => List.unmodifiable(_records);
  MemoryMatchAttemptResult? get result => _result;
  bool get hasProgress => _records.isNotEmpty || _selectedCells.isNotEmpty;

  /// Cells already tapped wrongly in this round (can't be chosen again).
  Set<int> get wrongCells => {for (final c in _selectedCells) if (c != _round.targetCell) c};

  /// Whether a cell's picture should be face-up right now.
  bool isRevealed(int cell) {
    if (!_round.board.containsKey(cell)) return false;
    if (_stage == MemoryStage.memorizing) return true;
    return cell == _round.targetCell && _phase.awaitingNext;
  }

  /// Turns the pictures face-down. Called when the memorize time runs out or
  /// the child taps "I'm ready!". Ignored if they're already hidden.
  bool hidePictures() {
    if (_stage != MemoryStage.memorizing || _phase == ActivityPhase.finished) return false;
    _viewedMs = _clock().difference(_stageStartedAt).inMilliseconds;
    _stage = MemoryStage.recalling;
    _stageStartedAt = _clock();
    notifyListeners();
    return true;
  }

  /// Chooses the card at [cell]. Returns false (and changes nothing) for
  /// taps while memorizing, on empty or already-tried cells, or after the
  /// round is decided — so a round can never be scored twice.
  bool select(int cell) {
    if (_stage != MemoryStage.recalling || !_phase.acceptsAnswer) return false;
    if (!_round.board.containsKey(cell) || _selectedCells.contains(cell)) return false;

    _firstResponseMs ??= _clock().difference(_stageStartedAt).inMilliseconds;
    _selectedCells.add(cell);

    final correct = cell == _round.targetCell;
    if (!correct && _selectedCells.length < maxTriesPerActivity) {
      _phase = ActivityPhase.hint;
      notifyListeners();
      return true;
    }

    final outcome = AnswerOutcome(
      correct: correct,
      tries: _selectedCells.length,
      firstResponseMs: _firstResponseMs!,
    );

    var change = MemoryChange.none;
    if (!isBaseline) {
      _points += scoring.pointsFor(outcome);
      final update = engine.recordRound(_adaptive, outcome);
      _adaptive = update.state;
      change = update.change;
    }

    _records.add(MemoryRoundRecord(
      round: _round,
      viewedMs: _viewedMs,
      outcome: outcome,
      selectedNumbers: [for (final c in _selectedCells) _round.numberFor(c)!],
      change: change,
    ));
    _phase = correct ? ActivityPhase.correct : ActivityPhase.revealed;
    notifyListeners();
    return true;
  }

  void next() {
    if (!_phase.awaitingNext) return;
    if (_records.length >= totalRounds) {
      _finish();
    } else {
      _startRound();
    }
    notifyListeners();
  }

  void _startRound() {
    final config = isBaseline ? engine.config.baselinePlan[_records.length] : _adaptive.config;
    final previous = _records.isEmpty ? null : _records.last.round.target;
    _round = _generator.generate(config, previousTarget: previous);
    _stage = MemoryStage.memorizing;
    _phase = ActivityPhase.answering;
    _selectedCells.clear();
    _firstResponseMs = null;
    _viewedMs = 0;
    _stageStartedAt = _clock();
  }

  void _finish() {
    final outcomes = [for (final r in _records) r.outcome];
    final score = isBaseline ? null : AttemptScore.compute(outcomes, config: scoring);
    final adaptiveAfter = isBaseline
        ? engine.estimateFromBaseline([for (final r in _records) (r.round.config, r.outcome)])
        : _adaptive;
    final progressAfter = _progressBefore.copyWith(
      completedAttempts: _progressBefore.completedAttempts + 1,
      adaptive: adaptiveAfter,
    );

    _phase = ActivityPhase.finished;
    _result = MemoryMatchAttemptResult(
      attemptType: attemptType,
      attemptNumber: attemptNumber,
      records: List.unmodifiable(_records),
      score: score,
      progressAfter: progressAfter,
      payload: _payload(
        status: CompletionStatus.completed,
        score: score,
        adaptiveAfter: adaptiveAfter,
      ),
    );
  }

  /// Payload for an attempt the child left early; progress is unchanged.
  Map<String, dynamic> abandonedPayload() => _payload(
        status: CompletionStatus.abandoned,
        score: null,
        adaptiveAfter: _progressBefore.adaptive,
      );

  Map<String, dynamic> _payload({
    required CompletionStatus status,
    required AttemptScore? score,
    required MemoryAdaptiveState adaptiveAfter,
  }) {
    final times = _records.map((r) => r.outcome.firstResponseMs.toDouble());
    return {
      'schema_version': mathMemorySchemaVersion,
      'game_id': MathGameId.memoryMatch.key,
      'attempt_id': attemptId,
      'attempt_number': attemptNumber,
      'attempt_type': attemptType.name,
      'completion_status': status.name,
      'started_at': _startedAt.toUtc().toIso8601String(),
      'ended_at': _clock().toUtc().toIso8601String(),
      'activities_planned': totalRounds,
      'activities': [for (final (i, r) in _records.indexed) r.toJson(i)],
      'recall_summary': {
        'rounds': _records.length,
        'correct': _records.where((r) => r.outcome.correct).length,
        'correct_first_try': _records.where((r) => r.outcome.correctFirstTry).length,
        'mean_response_ms': meanOf(times)?.round(),
      },
      'score': score?.toJson(),
      'scoring': isBaseline ? null : scoring.toJson(),
      'adaptation': {
        'engine': 'rules_v1',
        'applied': status == CompletionStatus.completed,
        'config': engine.config.toJson(),
        'state_before': _progressBefore.adaptive.toJson(),
        'state_after': adaptiveAfter.toJson(),
        'next_configuration': adaptiveAfter.config.toJson(),
      },
    };
  }
}
