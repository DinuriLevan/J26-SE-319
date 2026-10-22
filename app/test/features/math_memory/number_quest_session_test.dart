import 'package:akurin/features/math_memory/engine/activity_phase.dart';
import 'package:akurin/features/math_memory/engine/attempt.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_quest_adaptive_engine.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_quest_models.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_quest_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Answers the current question right (or with the first wrong choice).
void answer(NumberQuestSession s, {required bool correct, FakeClock? clock}) {
  clock?.advance(const Duration(seconds: 4));
  final q = s.current;
  s.select(correct ? q.answer : q.choices.firstWhere((c) => c != q.answer));
}

int wrong(NumberQuestSession s) => s.current.choices.firstWhere((c) => c != s.current.answer);

/// Plays a full attempt, answering every question correctly.
NumberQuestSession playAll(NumberQuestProgress progress, {bool correct = true, int seed = 1}) {
  final s = NumberQuestSession(progress: progress, seed: seed);
  while (s.phase != ActivityPhase.finished) {
    if (correct) {
      s.select(s.current.answer);
    } else {
      s.select(wrong(s));
      if (s.phase.acceptsAnswer) {
        s.select(s.current.choices.firstWhere((c) => c != s.current.answer && !s.wrongChoices.contains(c)));
      }
    }
    s.next();
  }
  return s;
}

void main() {
  test('the first real attempt is an ungraded baseline', () {
    final s = NumberQuestSession(progress: NumberQuestProgress.initial(), seed: 1);
    expect(s.attemptType, AttemptType.baseline);
    expect(s.attemptNumber, 1);
    expect(s.totalQuestions, NumberQuestAdaptiveConfig.defaultBaselinePlan.length);

    // The baseline follows the fixed plan regardless of answers.
    final plan = NumberQuestAdaptiveConfig.defaultBaselinePlan;
    for (final (skill, level) in plan) {
      expect((s.current.skill, s.current.level), (skill, level));
      s.select(wrong(s));
      s.select(s.current.answer);
      s.next();
    }

    final result = s.result!;
    expect(result.score, isNull);
    expect(result.payload['score'], isNull);
    expect(result.payload['attempt_type'], 'baseline');
    expect(s.points, 0);
    expect(result.progressAfter.completedAttempts, 1);
  });

  test('baseline completion initializes skill levels from its own results', () {
    final s = NumberQuestSession(progress: NumberQuestProgress.initial(), seed: 3);
    while (s.phase != ActivityPhase.finished) {
      // Ace counting, miss everything else.
      if (s.current.skill == MathSkill.counting) {
        s.select(s.current.answer);
      } else {
        s.select(wrong(s));
        s.select(s.current.choices.firstWhere((c) => c != s.current.answer && !s.wrongChoices.contains(c)));
      }
      s.next();
    }
    final skills = s.result!.progressAfter.skills;
    expect(skills[MathSkill.counting]!.level, 3);
    expect(skills[MathSkill.addition]!.level, 1);
    expect(skills[MathSkill.division]!.level, 1);
  });

  test('the second real attempt is scored', () {
    final baseline = playAll(NumberQuestProgress.initial());
    final second = playAll(baseline.result!.progressAfter, seed: 2);
    expect(second.attemptType, AttemptType.scored);
    expect(second.attemptNumber, 2);
    final score = second.result!.score!;
    expect(score.total, 10);
    expect(score.percentage, 100);
    expect(score.stars, 3);
    expect(second.result!.payload['score'], isNotNull);
    expect(second.result!.payload['attempt_type'], 'scored');
  });

  test('a later attempt never changes the baseline record', () {
    final baseline = playAll(NumberQuestProgress.initial());
    final baselinePayload = Map.of(baseline.result!.payload);
    playAll(baseline.result!.progressAfter, seed: 2);
    expect(baseline.result!.payload, baselinePayload);
    expect(baseline.result!.score, isNull);
  });

  test('repeated taps cannot score a question twice', () {
    final progress = NumberQuestProgress.initial().copyWith(completedAttempts: 1);
    final s = NumberQuestSession(progress: progress, seed: 4);
    final answer = s.current.answer;
    expect(s.select(answer), isTrue);
    expect(s.select(answer), isFalse);
    expect(s.select(answer), isFalse);
    expect(s.records, hasLength(1));
    expect(s.points, 10);

    // Same wrong choice twice counts once.
    s.next();
    final w = wrong(s);
    expect(s.select(w), isTrue);
    expect(s.select(w), isFalse);
    expect(s.phase, ActivityPhase.hint);
    expect(s.select(999), isFalse, reason: 'not one of the choices');
  });

  test('records skill, level, tries, hint and response time', () {
    final clock = FakeClock();
    final progress = NumberQuestProgress.initial().copyWith(completedAttempts: 1);
    final s = NumberQuestSession(progress: progress, seed: 4, clock: clock.call);
    clock.advance(const Duration(milliseconds: 2500));
    s.select(wrong(s));
    clock.advance(const Duration(seconds: 3));
    s.select(s.current.answer);

    final activity = (s.records.single.toJson(0));
    expect(activity['skill'], isNotNull);
    expect(activity['level'], isNotNull);
    expect(activity['tries'], 2);
    expect(activity['hint_shown'], isTrue);
    expect(activity['correct'], isTrue);
    expect(activity['correct_first_try'], isFalse);
    expect(activity['first_response_ms'], 2500);
    expect(activity['completed'], isTrue);
    expect(s.points, 5);
  });

  test('repeated errors in one skill bring extra practice in that skill only', () {
    final progress = NumberQuestProgress.initial().copyWith(
      completedAttempts: 1,
      skills: {for (final s in MathSkill.values) s: const SkillState(level: 3)},
    );
    final s = NumberQuestSession(progress: progress, seed: 8);
    final firstSkill = s.current.skill;

    // Miss the first skill twice in a row (it comes back while it's weak).
    var misses = 0;
    while (misses < 2) {
      if (s.current.skill == firstSkill) {
        s.select(wrong(s));
        s.select(s.current.choices.firstWhere((c) => c != s.current.answer && !s.wrongChoices.contains(c)));
        misses++;
      } else {
        s.select(s.current.answer);
      }
      s.next();
    }

    // The next two questions reinforce that skill, with pictures.
    for (var i = 0; i < 2; i++) {
      expect(s.current.skill, firstSkill);
      expect(s.currentIsReinforcement, isTrue);
      expect(s.current.showObjects, isTrue);
      s.select(s.current.answer);
      s.next();
    }
    expect(s.skills[firstSkill]!.level, 2);
    // Other skills keep their own levels.
    for (final skill in MathSkill.values.where((k) => k != firstSkill)) {
      expect(s.skills[skill]!.level, 3);
    }
  });

  test('consistent correct answers raise each skill gradually', () {
    final progress = NumberQuestProgress.initial().copyWith(completedAttempts: 1);
    var p = progress;
    for (var attempt = 0; attempt < 3; attempt++) {
      p = playAll(p, seed: attempt).result!.progressAfter;
    }
    for (final state in p.skills.values) {
      // 30 correct answers spread over 5 skills can lift a skill by at most
      // two levels (3 answers per level + cooldown).
      expect(state.level, inInclusiveRange(2, 3));
    }
  });

  test('abandoned attempts are marked and leave progress untouched', () {
    final s = NumberQuestSession(progress: NumberQuestProgress.initial(), seed: 1);
    s.select(s.current.answer);
    final payload = s.abandonedPayload();
    expect(payload['completion_status'], 'abandoned');
    expect(payload['attempt_type'], 'baseline');
    expect((payload['adaptation'] as Map)['applied'], isFalse);
    expect(s.result, isNull);
  });
}
