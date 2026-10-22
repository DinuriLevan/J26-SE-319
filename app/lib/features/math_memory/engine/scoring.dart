import 'attempt.dart';

/// Points and star thresholds for scored attempts. Baseline attempts are
/// never scored. Documented in docs/math-memory-adaptive-engine.md.
class ScoringConfig {
  const ScoringConfig({
    this.pointsFirstTry = 10,
    this.pointsAfterHint = 5,
    this.oneStarPercent = 40,
    this.twoStarPercent = 70,
    this.threeStarPercent = 90,
  }) : assert(oneStarPercent <= twoStarPercent && twoStarPercent <= threeStarPercent);

  final int pointsFirstTry;
  final int pointsAfterHint;
  final int oneStarPercent;
  final int twoStarPercent;
  final int threeStarPercent;

  static const standard = ScoringConfig();

  int pointsFor(AnswerOutcome outcome) {
    if (outcome.correctFirstTry) return pointsFirstTry;
    if (outcome.correct) return pointsAfterHint;
    return 0;
  }

  int starsFor(int percentage) {
    if (percentage >= threeStarPercent) return 3;
    if (percentage >= twoStarPercent) return 2;
    if (percentage >= oneStarPercent) return 1;
    return 0;
  }

  Map<String, dynamic> toJson() => {
        'points_first_try': pointsFirstTry,
        'points_after_hint': pointsAfterHint,
        'star_thresholds_percent': [oneStarPercent, twoStarPercent, threeStarPercent],
      };
}

/// End-of-attempt summary for a scored attempt.
class AttemptScore {
  const AttemptScore({
    required this.correct,
    required this.total,
    required this.points,
    required this.maxPoints,
    required this.percentage,
    required this.stars,
  });

  factory AttemptScore.compute(
    List<AnswerOutcome> outcomes, {
    ScoringConfig config = ScoringConfig.standard,
  }) {
    final points = outcomes.fold<int>(0, (sum, o) => sum + config.pointsFor(o));
    final maxPoints = outcomes.length * config.pointsFirstTry;
    final percentage = maxPoints == 0 ? 0 : (points * 100 / maxPoints).round();
    return AttemptScore(
      correct: outcomes.where((o) => o.correct).length,
      total: outcomes.length,
      points: points,
      maxPoints: maxPoints,
      percentage: percentage,
      stars: config.starsFor(percentage),
    );
  }

  /// Activities eventually answered correctly (first try or after a hint).
  final int correct;
  final int total;
  final int points;
  final int maxPoints;

  /// points / maxPoints, rounded to a whole percent.
  final int percentage;

  /// 0-3.
  final int stars;

  Map<String, dynamic> toJson() => {
        'correct': correct,
        'total': total,
        'points': points,
        'max_points': maxPoints,
        'percentage': percentage,
        'stars': stars,
      };
}
