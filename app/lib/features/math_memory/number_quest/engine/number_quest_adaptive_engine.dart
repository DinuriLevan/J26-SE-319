import '../../engine/attempt.dart';
import 'number_quest_models.dart';
import 'number_question_generator.dart';

/// Tunable thresholds for Number Quest. Documented in
/// docs/math-memory-adaptive-engine.md.
class NumberQuestAdaptiveConfig {
  const NumberQuestAdaptiveConfig({
    this.questionsPerScoredAttempt = 10,
    this.levelUpStreak = 3,
    this.levelDownErrors = 2,
    this.reinforcementQuestions = 2,
    this.cooldownAnswers = 2,
    this.recentWindow = 6,
    this.weakAccuracy = 0.6,
    this.slowResponseMs = 20000,
    this.baselinePlan = defaultBaselinePlan,
  });

  final int questionsPerScoredAttempt;

  /// Quick first-try correct answers in a row needed to go up a level.
  final int levelUpStreak;

  /// Non-first-try answers in a row that trigger reinforcement (and a level
  /// down, unless already at level 1 or in cooldown).
  final int levelDownErrors;

  /// Extra same-skill, visual questions queued after repeated errors.
  final int reinforcementQuestions;

  /// Answers at a new level before it may change again.
  final int cooldownAnswers;

  /// How many recent outcomes per skill are remembered.
  final int recentWindow;

  /// Recent accuracy below this marks a skill for extra practice.
  final double weakAccuracy;

  /// First-try correct answers slower than this don't count towards a level up.
  final int slowResponseMs;

  /// Fixed, non-adaptive baseline: (skill, level) per question.
  final List<(MathSkill, int)> baselinePlan;

  static const defaultBaselinePlan = [
    (MathSkill.counting, 1),
    (MathSkill.counting, 2),
    (MathSkill.addition, 1),
    (MathSkill.addition, 2),
    (MathSkill.subtraction, 1),
    (MathSkill.subtraction, 2),
    (MathSkill.multiplication, 1),
    (MathSkill.multiplication, 2),
    (MathSkill.division, 1),
    (MathSkill.division, 2),
  ];

  Map<String, dynamic> toJson() => {
        'questions_per_scored_attempt': questionsPerScoredAttempt,
        'level_up_streak': levelUpStreak,
        'level_down_errors': levelDownErrors,
        'reinforcement_questions': reinforcementQuestions,
        'cooldown_answers': cooldownAnswers,
        'recent_window': recentWindow,
        'weak_accuracy': weakAccuracy,
        'slow_response_ms': slowResponseMs,
      };
}

enum LevelChange { none, up, down }

/// Result of feeding one answer to the engine.
class SkillUpdate {
  const SkillUpdate(this.state, this.change, {required this.reinforce});

  final SkillState state;
  final LevelChange change;

  /// Whether to queue extra visual practice for this skill.
  final bool reinforce;
}

/// Rules-based, per-skill difficulty adaptation for Number Quest. Pure and
/// deterministic: the same inputs always give the same decisions.
class NumberQuestAdaptiveEngine {
  const NumberQuestAdaptiveEngine([this.config = const NumberQuestAdaptiveConfig()]);

  final NumberQuestAdaptiveConfig config;

  static const minLevel = NumberQuestionGenerator.minLevel;
  static const maxLevel = NumberQuestionGenerator.maxLevel;

  /// Starting level per skill from the baseline. Mean mastery 1.0 (all first
  /// try) → level 3, ≥0.5 → level 2, otherwise level 1. Conservative on
  /// purpose: one step above what the child showed, never more.
  Map<MathSkill, SkillState> estimateFromBaseline(
    List<(MathSkill, AnswerOutcome)> results,
  ) {
    return {
      for (final skill in MathSkill.values)
        skill: () {
          final masteries = [
            for (final (s, outcome) in results)
              if (s == skill) outcome.mastery,
          ];
          final mean = meanOf(masteries);
          final level = mean == null
              ? minLevel
              : mean >= 1.0
                  ? 3
                  : mean >= 0.5
                      ? 2
                      : 1;
          final recent = masteries.length <= config.recentWindow
              ? masteries
              : masteries.sublist(masteries.length - config.recentWindow);
          return SkillState(level: level.clamp(minLevel, maxLevel), recent: recent);
        }(),
    };
  }

  /// Updates one skill after an answer in a scored attempt.
  SkillUpdate recordAnswer(SkillState state, AnswerOutcome outcome) {
    final recent = pushRecent(state.recent, outcome.mastery, config.recentWindow);
    final cooldown = state.cooldown > 0 ? state.cooldown - 1 : 0;

    var streak = state.firstTryStreak;
    var errors = state.errorStreak;
    if (outcome.correctFirstTry) {
      errors = 0;
      // Slow-but-correct keeps the streak without adding to it.
      if (outcome.firstResponseMs <= config.slowResponseMs) streak++;
    } else {
      streak = 0;
      errors++;
    }

    var level = state.level;
    var change = LevelChange.none;
    var reinforce = false;

    if (errors >= config.levelDownErrors) {
      reinforce = true;
      if (cooldown == 0 && level > minLevel) {
        level--;
        change = LevelChange.down;
      }
      errors = 0;
    } else if (streak >= config.levelUpStreak && cooldown == 0 && level < maxLevel) {
      level++;
      change = LevelChange.up;
      streak = 0;
    }

    return SkillUpdate(
      SkillState(
        level: level,
        firstTryStreak: change == LevelChange.none ? streak : 0,
        errorStreak: errors,
        cooldown: change == LevelChange.none ? cooldown : config.cooldownAnswers,
        recent: recent,
      ),
      change,
      reinforce: reinforce,
    );
  }

  /// Picks the skill for the next scored question. Reinforcement comes first;
  /// otherwise the skill not asked for longest wins, with a bonus for weak
  /// skills. Never more than two of the same skill in a row (outside
  /// reinforcement). Ties go to the earlier skill in [MathSkill.values].
  MathSkill chooseNextSkill({
    required Map<MathSkill, SkillState> skills,
    required List<MathSkill> askedThisAttempt,
    required List<MathSkill> reinforcementQueue,
  }) {
    if (reinforcementQueue.isNotEmpty) return reinforcementQueue.first;

    final n = askedThisAttempt.length;
    final blocked = n >= 2 && askedThisAttempt[n - 1] == askedThisAttempt[n - 2]
        ? askedThisAttempt[n - 1]
        : null;

    MathSkill? best;
    var bestScore = double.negativeInfinity;
    for (final skill in MathSkill.values) {
      if (skill == blocked) continue;
      final last = askedThisAttempt.lastIndexOf(skill);
      final staleness = last == -1 ? 100.0 : (n - last).toDouble();
      final accuracy = skills[skill]?.recentAccuracy;
      final weak = (skills[skill]?.recent.length ?? 0) >= 2 &&
          accuracy != null &&
          accuracy < config.weakAccuracy;
      final score = staleness + (weak ? 2.0 : 0.0);
      if (score > bestScore) {
        best = skill;
        bestScore = score;
      }
    }
    return best!;
  }
}
