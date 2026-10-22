import 'dart:math';

import 'package:akurin/features/math_memory/number_quest/engine/number_quest_adaptive_engine.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_quest_models.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_question_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  const engine = NumberQuestAdaptiveEngine();

  group('question generator', () {
    test('questions are valid, unique-choice and within level bounds', () {
      final gen = NumberQuestionGenerator(Random(1));
      for (final skill in MathSkill.values) {
        for (var level = 1; level <= 5; level++) {
          for (var i = 0; i < 40; i++) {
            final q = gen.generate(skill, level);
            expect(q.choices, contains(q.answer));
            expect(q.choices.toSet().length, q.choices.length);
            expect(q.choices.every((c) => c >= 0), isTrue);
            switch (skill) {
              case MathSkill.counting:
                expect(q.answer, inInclusiveRange(1, 20));
                expect(q.showObjects, isTrue);
              case MathSkill.addition:
                expect(q.a + q.b, q.answer);
                expect(q.answer, lessThanOrEqualTo(const [5, 10, 15, 20, 50][level - 1]));
              case MathSkill.subtraction:
                expect(q.a - q.b, q.answer);
                expect(q.answer, greaterThanOrEqualTo(0));
              case MathSkill.multiplication:
                expect(q.a * q.b, q.answer);
              case MathSkill.division:
                expect(q.b * q.answer, q.a);
            }
            if (q.showObjects && skill != MathSkill.counting) {
              expect(level, lessThanOrEqualTo(3));
            }
          }
        }
      }
    });

    test('is deterministic for a seed', () {
      final a = NumberQuestionGenerator(Random(9)).generate(MathSkill.addition, 2);
      final b = NumberQuestionGenerator(Random(9)).generate(MathSkill.addition, 2);
      expect(a.toJson(), b.toJson());
    });

    test('reinforcement can force visuals above level 3 when they fit', () {
      final gen = NumberQuestionGenerator(Random(3));
      final q = gen.generate(MathSkill.addition, 4, forceVisual: true);
      expect(q.answer, lessThanOrEqualTo(20));
      expect(q.showObjects, isTrue);
    });
  });

  group('baseline estimate', () {
    test('maps each skill separately from its own baseline answers', () {
      final skills = engine.estimateFromBaseline([
        (MathSkill.counting, firstTry()),
        (MathSkill.counting, firstTry()),
        (MathSkill.addition, firstTry()),
        (MathSkill.addition, missed()),
        (MathSkill.subtraction, missed()),
        (MathSkill.subtraction, missed()),
        (MathSkill.multiplication, afterHint()),
        (MathSkill.multiplication, missed()),
      ]);
      expect(skills[MathSkill.counting]!.level, 3); // all first try
      expect(skills[MathSkill.addition]!.level, 2); // mean 0.5
      expect(skills[MathSkill.subtraction]!.level, 1);
      expect(skills[MathSkill.multiplication]!.level, 1); // mean 0.25
      expect(skills[MathSkill.division]!.level, 1); // not assessed
      expect(skills[MathSkill.counting]!.recent, [1.0, 1.0]);
    });
  });

  group('per-answer adaptation', () {
    test('levels up gradually: one level after three quick first-try answers', () {
      var state = const SkillState(level: 2);
      final changes = <LevelChange>[];
      for (var i = 0; i < 3; i++) {
        final u = engine.recordAnswer(state, firstTry());
        state = u.state;
        changes.add(u.change);
      }
      expect(changes, [LevelChange.none, LevelChange.none, LevelChange.up]);
      expect(state.level, 3);
    });

    test('cooldown prevents another change right after a level up', () {
      var state = const SkillState(level: 2);
      for (var i = 0; i < 3; i++) {
        state = engine.recordAnswer(state, firstTry()).state;
      }
      expect(state.level, 3);
      // Two errors straight after levelling up: the first is in cooldown.
      final first = engine.recordAnswer(state, missed());
      expect(first.change, LevelChange.none);
      final second = engine.recordAnswer(first.state, missed());
      expect(second.change, LevelChange.down);
      expect(second.state.level, 2);
    });

    test('slow first-try answers do not push the level up', () {
      var state = const SkillState(level: 1);
      for (var i = 0; i < 5; i++) {
        state = engine.recordAnswer(state, firstTry(ms: 30000)).state;
      }
      expect(state.level, 1);
    });

    test('repeated errors ask for reinforcement and ease the level', () {
      final u1 = engine.recordAnswer(const SkillState(level: 3), missed());
      expect(u1.reinforce, isFalse);
      final u2 = engine.recordAnswer(u1.state, afterHint());
      expect(u2.reinforce, isTrue);
      expect(u2.change, LevelChange.down);
      expect(u2.state.level, 2);
    });

    test('never goes below level 1 or above level 5', () {
      var low = const SkillState(level: 1);
      for (var i = 0; i < 10; i++) {
        low = engine.recordAnswer(low, missed()).state;
      }
      expect(low.level, 1);

      var high = const SkillState(level: 5);
      for (var i = 0; i < 10; i++) {
        high = engine.recordAnswer(high, firstTry()).state;
      }
      expect(high.level, 5);
    });
  });

  group('skill selection', () {
    final skills = {for (final s in MathSkill.values) s: const SkillState(level: 2)};

    test('reinforcement queue comes first', () {
      expect(
        engine.chooseNextSkill(
          skills: skills,
          askedThisAttempt: const [MathSkill.addition, MathSkill.addition],
          reinforcementQueue: const [MathSkill.addition],
        ),
        MathSkill.addition,
      );
    });

    test('rotates through skills, weak skills first', () {
      final weak = {
        ...skills,
        MathSkill.subtraction: const SkillState(level: 1, recent: [0, 0.5]),
      };
      final asked = <MathSkill>[];
      for (var i = 0; i < 5; i++) {
        asked.add(engine.chooseNextSkill(
          skills: weak,
          askedThisAttempt: asked,
          reinforcementQueue: const [],
        ));
      }
      expect(asked.first, MathSkill.subtraction);
      expect(asked.toSet(), MathSkill.values.toSet());
    });

    test('is deterministic', () {
      List<MathSkill> run() {
        final asked = <MathSkill>[];
        for (var i = 0; i < 10; i++) {
          asked.add(engine.chooseNextSkill(skills: skills, askedThisAttempt: asked, reinforcementQueue: const []));
        }
        return asked;
      }

      expect(run(), run());
    });
  });
}
