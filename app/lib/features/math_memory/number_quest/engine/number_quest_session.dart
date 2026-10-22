import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../../engine/activity_phase.dart';
import '../../engine/attempt.dart';
import '../../engine/scoring.dart';
import 'number_quest_adaptive_engine.dart';
import 'number_quest_models.dart';
import 'number_question_generator.dart';

/// One answered Number Quest question.
class NumberQuestActivityRecord {
  const NumberQuestActivityRecord({
    required this.question,
    required this.outcome,
    required this.selections,
    required this.reinforcement,
    required this.levelChange,
  });

  final NumberQuestion question;
  final AnswerOutcome outcome;

  /// Every choice tapped, in order.
  final List<int> selections;

  /// Whether this was extra practice queued after repeated errors.
  final bool reinforcement;

  /// The level change this answer caused (always none in a baseline).
  final LevelChange levelChange;

  Map<String, dynamic> toJson(int index) => {
        'index': index,
        ...question.toJson(),
        ...outcome.toJson(),
        'selections': selections,
        'reinforcement': reinforcement,
        'level_change': levelChange.name,
        'completed': true,
      };
}

/// What a finished attempt produced.
class NumberQuestAttemptResult {
  const NumberQuestAttemptResult({
    required this.attemptType,
    required this.attemptNumber,
    required this.records,
    required this.score,
    required this.progressAfter,
    required this.payload,
  });

  final AttemptType attemptType;
  final int attemptNumber;
  final List<NumberQuestActivityRecord> records;

  /// Null for a baseline: baselines are never graded.
  final AttemptScore? score;

  final NumberQuestProgress progressAfter;

  /// The `result_payload` queued for sync.
  final Map<String, dynamic> payload;
}

/// Runs one real Number Quest attempt: a fixed baseline the first time, then
/// adaptive, scored attempts. UI-free so it can be unit tested.
class NumberQuestSession extends ChangeNotifier {
  NumberQuestSession({
    required NumberQuestProgress progress,
    required int seed,
    DateTime Function()? clock,
    this.engine = const NumberQuestAdaptiveEngine(),
    this.scoring = ScoringConfig.standard,
    String? attemptId,
  })  : _progressBefore = progress,
        _skills = Map.of(progress.skills),
        _generator = NumberQuestionGenerator(Random(seed)),
        _clock = clock ?? DateTime.now,
        attemptId = attemptId ?? const Uuid().v4(),
        attemptType = progress.nextAttemptType {
    _startedAt = _clock();
    if (attemptType == AttemptType.baseline) {
      final avoid = <String>{};
      for (final (skill, level) in engine.config.baselinePlan) {
        final q = _generator.generate(skill, level, avoid: avoid);
        avoid.add(q.key);
        _baselineQuestions.add(q);
      }
    }
    _showQuestion(_nextQuestion());
  }

  final NumberQuestAdaptiveEngine engine;
  final ScoringConfig scoring;
  final String attemptId;
  final AttemptType attemptType;

  final NumberQuestProgress _progressBefore;
  final Map<MathSkill, SkillState> _skills;
  final NumberQuestionGenerator _generator;
  final DateTime Function() _clock;
  final _baselineQuestions = <NumberQuestion>[];
  final _records = <NumberQuestActivityRecord>[];
  final _reinforcementQueue = <MathSkill>[];
  final _askedKeys = <String>{};

  late DateTime _startedAt;
  late NumberQuestion _current;
  late DateTime _shownAt;
  bool _currentIsReinforcement = false;
  ActivityPhase _phase = ActivityPhase.answering;
  final _selections = <int>[];
  int? _firstResponseMs;
  int _points = 0;
  NumberQuestAttemptResult? _result;

  bool get isBaseline => attemptType == AttemptType.baseline;
  int get attemptNumber => _progressBefore.nextAttemptNumber;
  int get totalQuestions =>
      isBaseline ? _baselineQuestions.length : engine.config.questionsPerScoredAttempt;

  /// 0-based index of the current question.
  int get index => _records.length - (_phase.awaitingNext || _phase == ActivityPhase.finished ? 1 : 0);

  NumberQuestion get current => _current;
  ActivityPhase get phase => _phase;
  bool get currentIsReinforcement => _currentIsReinforcement;

  /// Wrong choices tapped for the current question (shown as used).
  Set<int> get wrongChoices => {for (final c in _selections) if (c != _current.answer) c};

  /// Running points; always 0 in a baseline.
  int get points => _points;

  List<NumberQuestActivityRecord> get records => List.unmodifiable(_records);
  Map<MathSkill, SkillState> get skills => Map.unmodifiable(_skills);
  NumberQuestAttemptResult? get result => _result;

  /// Whether the child has done anything worth recording if they leave.
  bool get hasProgress => _records.isNotEmpty || _selections.isNotEmpty;

  /// Answers the current question. Returns false (and changes nothing) for
  /// repeated, invalid or late taps, so a question can never be scored twice.
  bool select(int choice) {
    if (!_phase.acceptsAnswer) return false;
    if (!_current.choices.contains(choice) || _selections.contains(choice)) return false;

    _firstResponseMs ??= _clock().difference(_shownAt).inMilliseconds;
    _selections.add(choice);

    final correct = choice == _current.answer;
    if (!correct && _selections.length < maxTriesPerActivity) {
      _phase = ActivityPhase.hint;
      notifyListeners();
      return true;
    }

    final outcome = AnswerOutcome(
      correct: correct,
      tries: _selections.length,
      firstResponseMs: _firstResponseMs!,
    );

    var change = LevelChange.none;
    if (!isBaseline) {
      _points += scoring.pointsFor(outcome);
      final update = engine.recordAnswer(_skills[_current.skill]!, outcome);
      _skills[_current.skill] = update.state;
      change = update.change;
      if (update.reinforce) {
        for (var i = 0; i < engine.config.reinforcementQuestions; i++) {
          _reinforcementQueue.add(_current.skill);
        }
      }
    }

    _records.add(NumberQuestActivityRecord(
      question: _current,
      outcome: outcome,
      selections: List.of(_selections),
      reinforcement: _currentIsReinforcement,
      levelChange: change,
    ));
    _phase = correct ? ActivityPhase.correct : ActivityPhase.revealed;
    notifyListeners();
    return true;
  }

  /// Moves on after feedback. Ignored unless feedback is showing.
  void next() {
    if (!_phase.awaitingNext) return;
    if (_records.length >= totalQuestions) {
      _finish();
    } else {
      _showQuestion(_nextQuestion());
    }
    notifyListeners();
  }

  NumberQuestion _nextQuestion() {
    if (isBaseline) {
      _currentIsReinforcement = false;
      return _baselineQuestions[_records.length];
    }

    final skill = engine.chooseNextSkill(
      skills: _skills,
      askedThisAttempt: [for (final r in _records) r.question.skill],
      reinforcementQueue: _reinforcementQueue,
    );
    _currentIsReinforcement = _reinforcementQueue.isNotEmpty;
    if (_currentIsReinforcement) _reinforcementQueue.removeAt(0);

    return _generator.generate(
      skill,
      _skills[skill]!.level,
      avoid: _askedKeys,
      forceVisual: _currentIsReinforcement,
    );
  }

  void _showQuestion(NumberQuestion question) {
    _current = question;
    _askedKeys.add(question.key);
    _selections.clear();
    _firstResponseMs = null;
    _shownAt = _clock();
    _phase = ActivityPhase.answering;
  }

  void _finish() {
    final outcomes = [for (final r in _records) r.outcome];
    final score = isBaseline ? null : AttemptScore.compute(outcomes, config: scoring);
    final skillsAfter = isBaseline
        ? engine.estimateFromBaseline([for (final r in _records) (r.question.skill, r.outcome)])
        : Map.of(_skills);
    final progressAfter = _progressBefore.copyWith(
      completedAttempts: _progressBefore.completedAttempts + 1,
      skills: skillsAfter,
    );

    _phase = ActivityPhase.finished;
    _result = NumberQuestAttemptResult(
      attemptType: attemptType,
      attemptNumber: attemptNumber,
      records: List.unmodifiable(_records),
      score: score,
      progressAfter: progressAfter,
      payload: _payload(
        status: CompletionStatus.completed,
        score: score,
        skillsAfter: skillsAfter,
      ),
    );
  }

  /// Payload for an attempt the child left early. Progress is not changed by
  /// an abandoned attempt; this is only queued for research data.
  Map<String, dynamic> abandonedPayload() => _payload(
        status: CompletionStatus.abandoned,
        score: null,
        skillsAfter: _progressBefore.skills,
      );

  Map<String, dynamic> _payload({
    required CompletionStatus status,
    required AttemptScore? score,
    required Map<MathSkill, SkillState> skillsAfter,
  }) {
    return {
      'schema_version': mathMemorySchemaVersion,
      'game_id': MathGameId.numberQuest.key,
      'attempt_id': attemptId,
      'attempt_number': attemptNumber,
      'attempt_type': attemptType.name,
      'completion_status': status.name,
      'started_at': _startedAt.toUtc().toIso8601String(),
      'ended_at': _clock().toUtc().toIso8601String(),
      'activities_planned': totalQuestions,
      'activities': [for (final (i, r) in _records.indexed) r.toJson(i)],
      'skill_summary': _skillSummary(skillsAfter),
      'score': score?.toJson(),
      'scoring': isBaseline ? null : scoring.toJson(),
      'adaptation': {
        'engine': 'rules_v1',
        'applied': status == CompletionStatus.completed,
        'config': engine.config.toJson(),
        'skills_before': {
          for (final e in _progressBefore.skills.entries) e.key.name: e.value.toJson(),
        },
        'skills_after': {for (final e in skillsAfter.entries) e.key.name: e.value.toJson()},
      },
    };
  }

  Map<String, dynamic> _skillSummary(Map<MathSkill, SkillState> skillsAfter) {
    return {
      for (final skill in MathSkill.values)
        if (_records.any((r) => r.question.skill == skill))
          skill.name: () {
            final rs = _records.where((r) => r.question.skill == skill).toList();
            final times = rs.map((r) => r.outcome.firstResponseMs.toDouble());
            return {
              'asked': rs.length,
              'correct': rs.where((r) => r.outcome.correct).length,
              'correct_first_try': rs.where((r) => r.outcome.correctFirstTry).length,
              'hints': rs.where((r) => r.outcome.neededHint).length,
              'mean_response_ms': meanOf(times)?.round(),
              'level_before': _progressBefore.skills[skill]!.level,
              'level_after': skillsAfter[skill]!.level,
            };
          }(),
    };
  }
}
