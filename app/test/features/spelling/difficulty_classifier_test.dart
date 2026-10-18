import 'dart:math' as math;

import 'package:akurin/features/spelling/data/spelling_storage.dart';
import 'package:akurin/features/spelling/engine/feature_extractor.dart';
import 'package:akurin/features/spelling/engine/learner_model.dart';
import 'package:akurin/features/spelling/engine/selector.dart';
import 'package:akurin/features/spelling/engine/spelling_engine.dart';
import 'package:akurin/features/spelling/model/difficulty_classifier.dart';
import 'package:akurin/features/spelling/model/difficulty_prediction.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spelling_test_helpers.dart';

/// Always predicts [label] (stands in for the trained model in tests).
class _Always implements DifficultyClassifier {
  _Always(this.label);
  final String label;

  @override
  DifficultyPrediction predict(FeatureRow row) => _pred(label);
}

DifficultyPrediction _pred(String label, [double p = 0.8]) => DifficultyPrediction(
      label: label,
      probs: {for (final c in DifficultyPrediction.classes) c: c == label ? p : (1 - p) / 2},
      source: 'ml',
      at: DateTime(2026),
    );

class _BrokenBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => throw Exception('missing $key');
}

void main() {
  final bank = loadTestBank();

  ChildModel placedChild() {
    final child = ChildModel.create(childId: 'c', avatar: '🐶', bank: bank);
    final rows = [
      for (final w in bank.placementWords)
        w.word == 'fish'
            ? fakeRow(w, correctFirstTry: false, finalCorrect: false, attempts: 3, roundNo: 1)
            : fakeRow(w, roundNo: 1),
    ];
    for (final r in rows) {
      LearnerModel.applyPlacementWord(child, r, bank);
    }
    LearnerModel.applyPlacement(child, rows, bank);
    return child;
  }

  group('preprocessing', () {
    final spec = ModelSpec(
      recipes: [
        {'name': 'ok', 'kind': 'bool', 'source': 'final_correct'},
        {'name': 'skill=short_a', 'kind': 'onehot', 'source': 'phonics_skill', 'value': 'short_a'},
        {'name': 'len', 'kind': 'length', 'source': 'word'},
        {'name': 'bd', 'kind': 'has_bdpq', 'source': 'word'},
        {'name': 'log_t', 'kind': 'log1p', 'source': 'total_ms'},
        {'name': 'hes', 'kind': 'num', 'source': 'hesitation_ratio', 'clip': [0, 10]},
        {'name': 'bkt', 'kind': 'num', 'source': 'p_before', 'default': 0.1},
      ],
      classes: DifficultyPrediction.classes,
      output: 'logits',
    );

    test('recipes build the same vector as spell_features.py', () {
      final v = spec.vector({
        'final_correct': true, 'phonics_skill': 'short_a', 'word': 'Bed', 'total_ms': 999.0,
        'hesitation_ratio': 42.0, 'p_before': null,
      });
      expect(v.sublist(0, 4), [1, 1, 3, 1]);
      expect(v[4], closeTo(math.log(1000), 1e-12));
      expect(v[5], 10); // clipped
      expect(v[6], 0.1); // missing → default
    });

    test('logits are turned into probabilities with softmax', () {
      final p = spec.probabilities([0, 0, math.log(2)]);
      expect(p['hard'], closeTo(0.5, 1e-12));
      expect(p.values.reduce((a, b) => a + b), closeTo(1, 1e-12));
    });
  });

  group('fallback', () {
    test('BKT rule: below 45% hard, below 70% medium, else easy', () {
      const f = FallbackDifficultyClassifier();
      expect(f.predict(FeatureRow({'p_after': 0.3})).label, 'hard');
      expect(f.predict(FeatureRow({'p_after': 0.6})).label, 'medium');
      expect(f.predict(FeatureRow({'p_after': 0.9})).label, 'easy');
      expect(f.predict(FeatureRow({'p_after': 0.9})).source, 'fallback');
    });

    test('a model that throws falls back instead of crashing', () {
      final ml = MlDifficultyClassifier(
        ModelSpec(recipes: const [], classes: DifficultyPrediction.classes, output: 'probabilities'),
        score: (_) => throw StateError('boom'),
      );
      final p = ml.predict(FeatureRow({'p_after': 0.3}));
      expect(p.source, 'fallback');
      expect(p.label, 'hard');
    });

    test('missing model files load as the fallback classifier', () async {
      expect(await MlDifficultyClassifier.load(bundle: _BrokenBundle()), isA<FallbackDifficultyClassifier>());
    });
  });

  group('selector uses BKT for WHICH skill and the classifier for HOW HARD', () {
    double meanDifficulty(RoundPlan plan) {
      final focus = plan.words.where((w) => w.phonicsSkill == plan.focusSkill).toList();
      return focus.map((w) => w.difficulty).reduce((a, b) => a + b) / focus.length;
    }

    test('hard → difficulty 1 words, easy → difficulty 3 words', () {
      final hard = placedChild();
      for (var i = 0; i < 3; i++) {
        hard.addPrediction('digraph_sh', _pred('hard'));
      }
      final easy = placedChild();
      for (var i = 0; i < 3; i++) {
        easy.addPrediction('digraph_sh', _pred('easy'));
      }
      final h = Selector(bank, random: math.Random(1)).adaptive(hard);
      final e = Selector(bank, random: math.Random(1)).adaptive(easy);
      expect(h.focusSkill, 'digraph_sh'); // BKT still picks the skill
      expect(e.focusSkill, 'digraph_sh');
      expect(meanDifficulty(h), lessThan(meanDifficulty(e)));
      expect(h.reason, contains('classifier: hard (0.80) → difficulty 1'));
      expect(e.reason, contains('→ difficulty 3'));
    });

    test('predictions are averaged over the last 3, and the toggle turns them off', () {
      final c = placedChild()
        ..addPrediction('digraph_sh', _pred('easy', 0.5))
        ..addPrediction('digraph_sh', _pred('hard', 0.9))
        ..addPrediction('digraph_sh', _pred('hard', 0.9));
      expect(c.averagePrediction('digraph_sh')!.label, 'hard');
      final off = Selector(bank, random: math.Random(1)).adaptive(c, useClassifier: false);
      expect(off.reason, contains('Classifier switched off'));
    });
  });

  test('BKT says mastered but the classifier says hard twice → not mastered yet, 2 review words', () async {
    final engine = SpellingEngine(bank: bank, storage: InMemorySpellingStorage(), random: math.Random(3))
      ..classifier = _Always('hard');
    final child = await engine.createChild('🐼');
    engine.selectChild(child);
    // Warm-up, then make short_o look mastered to BKT.
    final placement = engine.startRound();
    for (var i = 0; i < placement.words.length; i++) {
      await engine.recordWord(word: placement.words[i], wordIndex: i, events: quickCorrectEvents(placement.words[i]));
    }
    await engine.finishRound();
    child.skills['short_o']!
      ..pL = 0.97
      ..seen = 6
      ..roundsSeen.addAll({1, 2});
    expect(child.isMastered('short_o'), isTrue);

    child.pendingPlan = null;
    engine.startRound();
    final dog = bank.wordsOfSkill('short_o');
    await engine.recordWord(word: dog[0], wordIndex: 0, events: quickCorrectEvents(dog[0]));
    expect(child.skills['short_o']!.masteryHeld, isFalse); // only one "hard" so far
    await engine.recordWord(word: dog[1], wordIndex: 1, events: quickCorrectEvents(dog[1]));
    expect(child.bktMastered('short_o'), isTrue);
    expect(child.skills['short_o']!.masteryHeld, isTrue);
    expect(child.isMastered('short_o'), isFalse);

    final next = engine.selector.adaptive(child);
    expect(next.reason, contains('not called mastered yet'));
    expect(next.words.where((w) => w.phonicsSkill == 'short_o').length, greaterThanOrEqualTo(2));

    // With the classifier switched off, BKT alone decides.
    engine.settings.useClassifier = false;
    await engine.recordWord(word: dog[2], wordIndex: 2, events: quickCorrectEvents(dog[2]));
    expect(child.isMastered('short_o'), isTrue);
  });

  test('every recorded word gets a prediction (kept: last 3 per skill)', () async {
    final storage = InMemorySpellingStorage();
    final engine = SpellingEngine(bank: bank, storage: storage, random: math.Random(4));
    final child = await engine.createChild('🦊');
    engine.selectChild(child);
    final plan = engine.startRound();
    for (var i = 0; i < plan.words.length; i++) {
      await engine.recordWord(word: plan.words[i], wordIndex: i, events: quickCorrectEvents(plan.words[i]));
    }
    expect(storage.rows.every((r) => r.values['clf_label'] != null && r.values['clf_source'] == 'fallback'), isTrue);
    expect(child.predictions.values.every((l) => l.length <= 3), isTrue);
    final restored = ChildModel.fromJson(child.toJson());
    expect(restored.predictions.keys, child.predictions.keys);
  });
}
