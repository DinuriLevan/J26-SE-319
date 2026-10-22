import 'dart:math';

import '../../engine/math_picture.dart';
import 'number_quest_models.dart';

/// Builds questions for a skill and level. Deterministic for a given [Random]
/// seed, so tests can reproduce exact questions.
///
/// Level ranges (ages 7-9), documented in docs/math-memory-adaptive-engine.md:
///
/// | Level | Counting | Addition (sum) | Subtraction (start) | Multiplication | Division |
/// |---|---|---|---|---|---|
/// | 1 | 1-5   | ≤5  | ≤5  | 2 × 1-3   | ÷2, answer 1-3 |
/// | 2 | 4-10  | ≤10 | ≤10 | 2-3 × 1-5 | ÷2-3, answer 1-5 |
/// | 3 | 8-15  | ≤15 | ≤15 | 2-5 × 2-5 | ÷2-5, answer 2-5 |
/// | 4 | 12-20 | ≤20 | ≤20 | 2-5 × 2-10 | ÷2-5, answer 2-10 |
/// | 5 | 15-20 | ≤50 | ≤50 | 2-10 × 2-10 | ÷2-10, answer 2-10 |
class NumberQuestionGenerator {
  NumberQuestionGenerator(this._random);

  final Random _random;

  static const minLevel = 1;
  static const maxLevel = 5;

  /// Most pictures drawn at once; above this, numerals only.
  static const maxVisibleObjects = 20;

  /// Visuals are used up to this level (counting is always visual).
  static const maxVisualLevel = 3;

  static const choiceCount = 3;

  /// Generates a question, avoiding any key in [avoid] where possible.
  /// [forceVisual] draws the quantities even above [maxVisualLevel] (used for
  /// reinforcement after repeated errors), as long as they fit on screen.
  NumberQuestion generate(
    MathSkill skill,
    int level, {
    Set<String> avoid = const {},
    bool forceVisual = false,
  }) {
    final lvl = level.clamp(minLevel, maxLevel);
    NumberQuestion question = _build(skill, lvl, forceVisual);
    for (var i = 0; i < 12 && avoid.contains(question.key); i++) {
      question = _build(skill, lvl, forceVisual);
    }
    return question;
  }

  NumberQuestion _build(MathSkill skill, int level, bool forceVisual) {
    final (a, b, answer, objects) = switch (skill) {
      MathSkill.counting => _counting(level),
      MathSkill.addition => _addition(level),
      MathSkill.subtraction => _subtraction(level),
      MathSkill.multiplication => _multiplication(level),
      MathSkill.division => _division(level),
    };

    final fits = objects <= maxVisibleObjects;
    final showObjects = skill == MathSkill.counting ||
        (fits && (level <= maxVisualLevel || forceVisual));

    return NumberQuestion(
      skill: skill,
      level: level,
      a: a,
      b: b,
      answer: answer,
      choices: _choices(answer, skill == MathSkill.multiplication ? b : 1),
      picture: MathPicture.countable[_random.nextInt(MathPicture.countable.length)],
      showObjects: showObjects,
    );
  }

  int _between(int min, int max) => min + _random.nextInt(max - min + 1);

  (int, int, int, int) _counting(int level) {
    final (min, max) = switch (level) {
      1 => (1, 5),
      2 => (4, 10),
      3 => (8, 15),
      4 => (12, 20),
      _ => (15, 20),
    };
    final n = _between(min, max);
    return (n, 0, n, n);
  }

  (int, int, int, int) _addition(int level) {
    final maxSum = const [5, 10, 15, 20, 50][level - 1];
    final minSum = const [2, 4, 8, 12, 21][level - 1];
    final sum = _between(minSum, maxSum);
    // Level 5: two-digit + one-digit.
    final a = level == 5 ? _between(sum - 9, sum - 1) : _between(1, sum - 1);
    return (a, sum - a, sum, sum);
  }

  (int, int, int, int) _subtraction(int level) {
    final maxStart = const [5, 10, 15, 20, 50][level - 1];
    final minStart = const [2, 4, 8, 12, 21][level - 1];
    final start = _between(minStart, maxStart);
    final take = level == 5 ? _between(1, 9) : _between(1, start - 1);
    return (start, take, start - take, start);
  }

  (int, int, int, int) _multiplication(int level) {
    final (groups, size) = switch (level) {
      1 => (2, _between(1, 3)),
      2 => (_between(2, 3), _between(1, 5)),
      3 => (_between(2, 5), _between(2, 5)),
      4 => (_between(2, 5), _between(2, 10)),
      _ => (_between(2, 10), _between(2, 10)),
    };
    return (groups, size, groups * size, groups * size);
  }

  (int, int, int, int) _division(int level) {
    final (divisor, quotient) = switch (level) {
      1 => (2, _between(1, 3)),
      2 => (_between(2, 3), _between(1, 5)),
      3 => (_between(2, 5), _between(2, 5)),
      4 => (_between(2, 5), _between(2, 10)),
      _ => (_between(2, 10), _between(2, 10)),
    };
    final total = divisor * quotient;
    return (total, divisor, quotient, total);
  }

  /// The answer plus two nearby, non-negative distractors, shuffled.
  List<int> _choices(int answer, int step) {
    final candidates = <int>{
      answer + 1,
      answer - 1,
      answer + 2,
      answer - 2,
      if (step > 1) answer + step,
      if (step > 1) answer - step,
    }.where((n) => n >= 0 && n != answer).toList()
      ..sort();
    candidates.shuffle(_random);
    final choices = [answer, ...candidates.take(choiceCount - 1)]..shuffle(_random);
    return choices;
  }
}
