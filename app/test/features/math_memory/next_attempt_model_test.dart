import 'dart:convert';
import 'dart:io';

import 'package:akurin/features/math_memory/engine/activity_phase.dart';
import 'package:akurin/features/math_memory/memory_match/engine/memory_match_models.dart';
import 'package:akurin/features/math_memory/memory_match/engine/memory_match_session.dart';
import 'package:akurin/features/math_memory/ml/next_attempt_features.dart';
import 'package:akurin/features/math_memory/ml/next_attempt_planner.dart';
import 'package:akurin/features/math_memory/ml/tree_ensemble_model.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_quest_models.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_quest_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

TreeEnsembleModel loadArtifact(String id) => TreeEnsembleModel.fromJson(
      jsonDecode(File('assets/models/math_memory/$id.json').readAsStringSync()) as Map<String, dynamic>,
    );

Future<TreeEnsembleModel> fileLoader(String id) async => loadArtifact(id);

/// Plays a Number Quest attempt. [skill] decides whether each answer is right
/// first time; wrong answers miss both tries. [seconds] per answer.
NumberQuestAttemptResult playNumberQuest(
  NumberQuestProgress progress, {
  required bool Function(MathSkill skill) correct,
  int seconds = 4,
  int seed = 1,
}) {
  final clock = FakeClock();
  final s = NumberQuestSession(progress: progress, seed: seed, clock: clock.call);
  while (s.phase != ActivityPhase.finished) {
    clock.advance(Duration(seconds: seconds));
    if (correct(s.current.skill)) {
      s.select(s.current.answer);
    } else {
      final wrong = s.current.choices.where((c) => c != s.current.answer).toList();
      s.select(wrong[0]);
      s.select(wrong[1]);
    }
    s.next();
  }
  return s.result!;
}

MemoryMatchAttemptResult playMemoryMatch(
  MemoryMatchProgress progress, {
  required bool Function(int round) correct,
  int seed = 1,
}) {
  final clock = FakeClock();
  final s = MemoryMatchSession(progress: progress, seed: seed, clock: clock.call);
  var round = 0;
  while (s.phase != ActivityPhase.finished) {
    clock.advance(const Duration(seconds: 5));
    s.hidePictures();
    clock.advance(const Duration(seconds: 3));
    if (correct(round)) {
      s.select(s.round.targetCell);
    } else {
      final wrong = s.round.activeCells.where((c) => c != s.round.targetCell).toList();
      s.select(wrong[0]);
      s.select(wrong[1]);
    }
    s.next();
    round++;
  }
  return s.result!;
}

void main() {
  final planner = NextAttemptPlanner(fileLoader);

  group('bundled model artifacts', () {
    for (final id in [NextAttemptPlanner.numberQuestModelId, NextAttemptPlanner.memoryMatchModelId]) {
      test('$id loads and matches the Python reference exactly', () {
        final model = loadArtifact(id);
        expect(model.modelVersion, isNotEmpty);
        final fixture = jsonDecode(
          File('test/features/math_memory/fixtures/${id}_parity.json').readAsStringSync(),
        ) as Map<String, dynamic>;
        final cases = fixture['cases'] as List;
        expect(cases, isNotEmpty);
        for (final c in cases.cast<Map<String, dynamic>>()) {
          final features = [for (final f in c['features'] as List) (f as num).toDouble()];
          final (cls, probs) = model.classify(features);
          expect(cls, c['expected_class']);
          final expected = [for (final p in c['probabilities'] as List) (p as num).toDouble()];
          for (var k = 0; k < probs.length; k++) {
            expect(probs[k], closeTo(expected[k], 1e-9));
          }
        }
      });
    }

    test('feature names match what the app computes', () {
      expect(loadArtifact(NextAttemptPlanner.numberQuestModelId).featureNames,
          NextAttemptFeatures.numberQuestNames);
      expect(loadArtifact(NextAttemptPlanner.memoryMatchModelId).featureNames,
          NextAttemptFeatures.memoryMatchNames);
    });

    testWidgets('loads from the app bundle with no network', (tester) async {
      final models = BundledMathModels(rootBundle);
      final loaded = await tester.runAsync(() => Future.wait([
            models.load(NextAttemptPlanner.numberQuestModelId),
            models.load(NextAttemptPlanner.memoryMatchModelId),
          ]));
      expect(loaded!.map((m) => m.modelId), [
        NextAttemptPlanner.numberQuestModelId,
        NextAttemptPlanner.memoryMatchModelId,
      ]);
    });

    test('rejects malformed artifacts', () {
      expect(() => TreeEnsembleModel.fromJson({'model_id': 'x', 'model_version': '1', 'feature_names': [], 'classes': [0], 'trees': []}),
          throwsFormatException);
    });
  });

  group('Number Quest next attempt', () {
    test('baseline performance drives each skill\'s predicted start level, within bounds', () async {
      final strong = await planner.planNumberQuest(
        playNumberQuest(NumberQuestProgress.initial(), correct: (_) => true),
      );
      final weak = await planner.planNumberQuest(
        playNumberQuest(NumberQuestProgress.initial(), correct: (_) => false, seconds: 25),
      );
      expect(strong.source, PredictionSource.model);
      expect(strong.trace['model_version'], '1.0.0');
      for (final skill in MathSkill.values) {
        final s = strong.progressAfter.skills[skill]!.level;
        final w = weak.progressAfter.skills[skill]!.level;
        // Baseline asks levels 1-2, so the next level is 1..3.
        expect(s, inInclusiveRange(1, 3));
        expect(w, inInclusiveRange(1, 3));
        expect(s, greaterThan(w), reason: '$skill: strong performance should start higher');
      }
    });

    test('mixed skills get different predictions (tracked per skill)', () async {
      final plan = await planner.planNumberQuest(playNumberQuest(
        NumberQuestProgress.initial(),
        correct: (skill) => skill == MathSkill.counting || skill == MathSkill.addition,
      ));
      final levels = plan.progressAfter.skills;
      expect(levels[MathSkill.counting]!.level, greaterThan(levels[MathSkill.division]!.level));
      expect(levels[MathSkill.addition]!.level, greaterThan(levels[MathSkill.subtraction]!.level));
    });

    test('scored predictions move at most one level and stay within 1..5', () async {
      for (final start in [1, 3, 5]) {
        final progress = NumberQuestProgress.initial().copyWith(
          completedAttempts: 1,
          skills: {for (final s in MathSkill.values) s: SkillState(level: start)},
        );
        for (final good in [true, false]) {
          final plan = await planner.planNumberQuest(playNumberQuest(progress, correct: (_) => good));
          for (final state in plan.progressAfter.skills.values) {
            expect(state.level, inInclusiveRange(1, 5));
            expect((state.level - start).abs(), lessThanOrEqualTo(1));
          }
        }
      }
    });

    test('the next attempt starts each skill at the predicted level', () async {
      final baseline = playNumberQuest(NumberQuestProgress.initial(), correct: (_) => true);
      final plan = await planner.planNumberQuest(baseline);
      final next = NumberQuestSession(progress: plan.progressAfter, seed: 9);
      final seen = <MathSkill>{};
      while (next.phase != ActivityPhase.finished && seen.length < MathSkill.values.length) {
        final q = next.current;
        if (seen.add(q.skill)) {
          expect(q.level, plan.progressAfter.skills[q.skill]!.level);
        }
        next.select(q.answer);
        next.next();
      }
      expect(next.attemptType.name, 'scored');
    });

    test('falls back to the rules engine when the model cannot load', () async {
      final failing = NextAttemptPlanner((_) async => throw const FormatException('corrupt'));
      final result = playNumberQuest(NumberQuestProgress.initial(), correct: (_) => true);
      final plan = await failing.planNumberQuest(result);
      expect(plan.source, PredictionSource.fallback);
      expect(plan.trace['source'], 'fallback');
      expect(plan.trace['fallback_engine'], 'rules_v1');
      expect(plan.trace['fallback_reason'], contains('corrupt'));
      expect(plan.progressAfter.toJson(), result.progressAfter.toJson());
    });

    test('falls back when the model expects different features', () async {
      final wrongFeatures = NextAttemptPlanner((id) async {
        final json = jsonDecode(File('assets/models/math_memory/$id.json').readAsStringSync()) as Map<String, dynamic>;
        return TreeEnsembleModel.fromJson({...json, 'feature_names': [...(json['feature_names'] as List).reversed]});
      });
      final plan = await wrongFeatures.planNumberQuest(
        playNumberQuest(NumberQuestProgress.initial(), correct: (_) => true),
      );
      expect(plan.source, PredictionSource.fallback);
      expect(plan.trace['fallback_reason'], contains('feature mismatch'));
    });
  });

  group('Memory Match next attempt', () {
    test('baseline performance drives the predicted configuration', () async {
      final strong = await planner.planMemoryMatch(
        playMemoryMatch(MemoryMatchProgress.initial(), correct: (_) => true),
      );
      final weak = await planner.planMemoryMatch(
        playMemoryMatch(MemoryMatchProgress.initial(), correct: (_) => false),
      );
      expect(strong.source, PredictionSource.model);
      final s = strong.progressAfter.adaptive.config;
      final w = weak.progressAfter.adaptive.config;
      expect(NextAttemptFeatures.memoryLadder, contains(s));
      expect(NextAttemptFeatures.memoryLadder, contains(w));
      expect(NextAttemptFeatures.nearestRung(s), greaterThan(NextAttemptFeatures.nearestRung(w)));
      // Struggling children get a small board with longer looking time.
      expect(w.positions, 3);
      expect(w.memorizeSeconds, greaterThanOrEqualTo(6));
    });

    test('predictions stay on the ladder and within ±2 rungs after scored attempts', () async {
      for (final rung in [0, 5, 10]) {
        final config = NextAttemptFeatures.memoryLadder[rung];
        final progress = MemoryMatchProgress.initial().copyWith(
          completedAttempts: 1,
          adaptive: MemoryAdaptiveState(config: config),
        );
        for (final good in [true, false]) {
          final plan = await planner.planMemoryMatch(playMemoryMatch(progress, correct: (_) => good));
          final next = plan.progressAfter.adaptive.config;
          expect(NextAttemptFeatures.memoryLadder, contains(next));
          expect((NextAttemptFeatures.nearestRung(next) - rung).abs(), lessThanOrEqualTo(2));
          expect(next.positions, inInclusiveRange(3, 9));
          expect(next.memorizeSeconds, inInclusiveRange(3, 10));
        }
      }
    });

    test('the next attempt uses the predicted configuration', () async {
      final plan = await planner.planMemoryMatch(
        playMemoryMatch(MemoryMatchProgress.initial(), correct: (_) => true),
      );
      final next = MemoryMatchSession(progress: plan.progressAfter, seed: 4);
      expect(next.attemptType.name, 'scored');
      expect(next.round.config, plan.progressAfter.adaptive.config);
      expect(next.round.board.length, plan.progressAfter.adaptive.config.positions);
    });

    test('falls back to the rules configuration when inference fails', () async {
      final failing = NextAttemptPlanner((_) async => throw StateError('no model'));
      final result = playMemoryMatch(MemoryMatchProgress.initial(), correct: (_) => true);
      final plan = await failing.planMemoryMatch(result);
      expect(plan.source, PredictionSource.fallback);
      expect(plan.progressAfter.adaptive.config, result.progressAfter.adaptive.config);
      expect(plan.trace['next_configuration'], result.progressAfter.adaptive.config.toJson());
    });
  });

  group('features', () {
    test('Number Quest features follow the documented definitions', () {
      final result = playNumberQuest(
        NumberQuestProgress.initial(),
        correct: (skill) => skill == MathSkill.counting,
        seconds: 7,
      );
      final f = NextAttemptFeatures.numberQuest(result);
      final counting = f[MathSkill.counting]!;
      expect(counting['is_baseline'], 1);
      expect(counting['ref_level'], 2);
      expect(counting['mean_level'], 1.5);
      expect(counting['n_questions'], 2);
      expect(counting['first_try_acc'], 1);
      expect(counting['mean_rt_s'], 7);
      final division = f[MathSkill.division]!;
      expect(division['first_try_acc'], 0);
      expect(division['eventual_acc'], 0);
      expect(division['hint_rate'], 1);
      expect(division['max_miss_streak'], 2);
    });

    test('Memory Match features follow the documented definitions', () {
      final result = playMemoryMatch(MemoryMatchProgress.initial(), correct: (round) => round < 4);
      final f = NextAttemptFeatures.memoryMatch(result);
      expect(f['is_baseline'], 1);
      expect(f['ref_rung'], NextAttemptFeatures.memoryBaselineRefRung);
      expect(f['mean_positions'], 4);
      expect(f['mean_seconds'], 6);
      expect(f['first_try_acc'], closeTo(4 / 6, 1e-9));
      expect(f['wrong_per_round'], closeTo(4 / 6, 1e-9)); // two wrong taps in each of 2 rounds
      expect(f['max_miss_streak'], 2);
      expect(f['largest_board_first_try_acc'], 0); // both 5-picture rounds missed
      expect(f['mean_rt_s'], 3);
    });

    test('nearest rung prefers the same board size', () {
      expect(NextAttemptFeatures.nearestRung(const MemoryConfig(positions: 4, memorizeSeconds: 6)), 3);
      expect(NextAttemptFeatures.nearestRung(const MemoryConfig(positions: 4, memorizeSeconds: 7)), 3);
    // (4, 9) is equally far from (3, 8) and (4, 6): ties go to the easier rung.
    expect(NextAttemptFeatures.nearestRung(const MemoryConfig(positions: 4, memorizeSeconds: 9)), 0);
      expect(NextAttemptFeatures.nearestRung(const MemoryConfig(positions: 9, memorizeSeconds: 10)), 10);
    });
  });
}
