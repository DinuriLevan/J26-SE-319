import 'package:akurin/features/math_memory/engine/scoring.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  const config = ScoringConfig.standard;

  test('points: 10 first try, 5 after a hint, 0 when missed', () {
    expect(config.pointsFor(firstTry()), 10);
    expect(config.pointsFor(afterHint()), 5);
    expect(config.pointsFor(missed()), 0);
  });

  test('star thresholds are 40 / 70 / 90 percent, inclusive', () {
    expect(config.starsFor(0), 0);
    expect(config.starsFor(39), 0);
    expect(config.starsFor(40), 1);
    expect(config.starsFor(69), 1);
    expect(config.starsFor(70), 2);
    expect(config.starsFor(89), 2);
    expect(config.starsFor(90), 3);
    expect(config.starsFor(100), 3);
  });

  test('percentage is points over maximum points', () {
    // 7 first try (70) + 2 after hint (10) + 1 missed (0) = 80 / 100.
    final score = AttemptScore.compute([
      for (var i = 0; i < 7; i++) firstTry(),
      afterHint(),
      afterHint(),
      missed(),
    ]);
    expect(score.points, 80);
    expect(score.maxPoints, 100);
    expect(score.percentage, 80);
    expect(score.stars, 2);
    expect(score.correct, 9);
    expect(score.total, 10);
  });

  test('percentages are rounded', () {
    // 2 of 3 first try = 20 / 30 = 66.7% → 67.
    final score = AttemptScore.compute([firstTry(), firstTry(), missed()]);
    expect(score.percentage, 67);
    expect(score.stars, 1);
  });

  test('a perfect attempt earns three stars; an empty one none', () {
    expect(AttemptScore.compute([for (var i = 0; i < 6; i++) firstTry()]).stars, 3);
    expect(AttemptScore.compute(const []).percentage, 0);
  });

  test('thresholds are configurable', () {
    const strict = ScoringConfig(oneStarPercent: 50, twoStarPercent: 80, threeStarPercent: 100);
    expect(strict.starsFor(95), 2);
    expect(strict.starsFor(100), 3);
  });
}
