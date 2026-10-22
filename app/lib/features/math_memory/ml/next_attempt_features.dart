import '../engine/attempt.dart';
import '../memory_match/engine/memory_match_models.dart';
import '../memory_match/engine/memory_match_session.dart';
import '../number_quest/engine/number_quest_models.dart';
import '../number_quest/engine/number_quest_session.dart';

/// Model inputs computed from a completed attempt.
///
/// KEEP IN SYNC WITH ml/math_memory/features.py — the exported model lists its
/// `feature_names`, and the planner falls back to the rules engine if they
/// don't match these.
class NextAttemptFeatures {
  const NextAttemptFeatures._();

  static const responseTimeCapSeconds = 60.0;

  static const numberQuestNames = [
    'is_baseline',
    'ref_level',
    'mean_level',
    'n_questions',
    'first_try_acc',
    'eventual_acc',
    'hint_rate',
    'mean_rt_s',
    'max_miss_streak',
  ];

  static const memoryMatchNames = [
    'is_baseline',
    'ref_rung',
    'mean_positions',
    'mean_seconds',
    'first_try_acc',
    'eventual_acc',
    'wrong_per_round',
    'mean_rt_s',
    'max_miss_streak',
    'largest_board_first_try_acc',
  ];

  /// Difficulty ladder for Memory Match predictions: neighbouring rungs
  /// differ in exactly one factor (pictures or seconds).
  static const memoryLadder = [
    MemoryConfig(positions: 3, memorizeSeconds: 8),
    MemoryConfig(positions: 3, memorizeSeconds: 7),
    MemoryConfig(positions: 3, memorizeSeconds: 6),
    MemoryConfig(positions: 4, memorizeSeconds: 6),
    MemoryConfig(positions: 4, memorizeSeconds: 5),
    MemoryConfig(positions: 5, memorizeSeconds: 5),
    MemoryConfig(positions: 5, memorizeSeconds: 4),
    MemoryConfig(positions: 6, memorizeSeconds: 4),
    MemoryConfig(positions: 7, memorizeSeconds: 4),
    MemoryConfig(positions: 8, memorizeSeconds: 4),
    MemoryConfig(positions: 9, memorizeSeconds: 4),
  ];

  /// (4 pictures, 6 s): the middle of the Memory Match baseline.
  static const memoryBaselineRefRung = 3;

  /// Largest rung change per prediction.
  static int memoryMaxStep({required bool baseline}) => baseline ? 3 : 2;

  /// Closest ladder rung; a picture counts double a second. Ties → easier.
  static int nearestRung(MemoryConfig config) {
    var best = 0;
    var bestCost = 1 << 30;
    for (var i = 0; i < memoryLadder.length; i++) {
      final rung = memoryLadder[i];
      final cost = 2 * (rung.positions - config.positions).abs() +
          (rung.memorizeSeconds - config.memorizeSeconds).abs();
      if (cost < bestCost) {
        best = i;
        bestCost = cost;
      }
    }
    return best;
  }

  /// One feature map per skill asked in the attempt (skills not asked are
  /// absent). Keys are [numberQuestNames].
  static Map<MathSkill, Map<String, double>> numberQuest(NumberQuestAttemptResult result) {
    final baseline = result.attemptType == AttemptType.baseline;
    return {
      for (final skill in MathSkill.values)
        if (result.records.any((r) => r.question.skill == skill))
          skill: () {
            final records = result.records.where((r) => r.question.skill == skill).toList();
            final levels = [for (final r in records) r.question.level];
            final outcomes = [for (final r in records) r.outcome];
            // A skill's first question is always asked at its starting level.
            final ref = baseline ? levels.reduce((a, b) => a > b ? a : b) : levels.first;
            return {
              'is_baseline': baseline ? 1.0 : 0.0,
              'ref_level': ref.toDouble(),
              'mean_level': _mean(levels.map((l) => l.toDouble())),
              'n_questions': records.length.toDouble(),
              ..._outcomeFeatures(outcomes),
            };
          }(),
    };
  }

  /// One feature map for the attempt. Keys are [memoryMatchNames].
  static Map<String, double> memoryMatch(MemoryMatchAttemptResult result) {
    final baseline = result.attemptType == AttemptType.baseline;
    final configs = [for (final r in result.records) r.round.config];
    final outcomes = [for (final r in result.records) r.outcome];
    final largest = configs.map((c) => c.positions).reduce((a, b) => a > b ? a : b);
    final onLargest = [
      for (var i = 0; i < configs.length; i++)
        if (configs[i].positions == largest) outcomes[i].correctFirstTry ? 1.0 : 0.0,
    ];
    return {
      'is_baseline': baseline ? 1.0 : 0.0,
      'ref_rung': (baseline ? memoryBaselineRefRung : nearestRung(configs.first)).toDouble(),
      'mean_positions': _mean(configs.map((c) => c.positions.toDouble())),
      'mean_seconds': _mean(configs.map((c) => c.memorizeSeconds.toDouble())),
      'first_try_acc': _mean(outcomes.map((o) => o.correctFirstTry ? 1.0 : 0.0)),
      'eventual_acc': _mean(outcomes.map((o) => o.correct ? 1.0 : 0.0)),
      'wrong_per_round': _mean(outcomes.map((o) => (o.tries - (o.correct ? 1 : 0)).toDouble())),
      'mean_rt_s': _meanResponseSeconds(outcomes),
      'max_miss_streak': _maxMissStreak(outcomes).toDouble(),
      'largest_board_first_try_acc': _mean(onLargest),
    };
  }

  static Map<String, double> _outcomeFeatures(List<AnswerOutcome> outcomes) => {
        'first_try_acc': _mean(outcomes.map((o) => o.correctFirstTry ? 1.0 : 0.0)),
        'eventual_acc': _mean(outcomes.map((o) => o.correct ? 1.0 : 0.0)),
        'hint_rate': _mean(outcomes.map((o) => o.neededHint ? 1.0 : 0.0)),
        'mean_rt_s': _meanResponseSeconds(outcomes),
        'max_miss_streak': _maxMissStreak(outcomes).toDouble(),
      };

  static double _meanResponseSeconds(List<AnswerOutcome> outcomes) => _mean(outcomes.map(
        (o) => (o.firstResponseMs / 1000).clamp(0, responseTimeCapSeconds).toDouble(),
      ));

  static int _maxMissStreak(List<AnswerOutcome> outcomes) {
    var best = 0;
    var run = 0;
    for (final o in outcomes) {
      run = o.correctFirstTry ? 0 : run + 1;
      if (run > best) best = run;
    }
    return best;
  }

  static double _mean(Iterable<double> values) => meanOf(values) ?? 0.0;

  /// Orders [features] as [names] for the model.
  static List<double> vector(Map<String, double> features, List<String> names) =>
      [for (final n in names) features[n]!];
}
