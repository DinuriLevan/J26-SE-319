import 'dart:math' as math;

import 'package:akurin/features/spelling/data/spelling_storage.dart';
import 'package:akurin/features/spelling/engine/event_logger.dart';
import 'package:akurin/features/spelling/engine/feature_extractor.dart';
import 'package:akurin/features/spelling/engine/learner_model.dart';
import 'package:akurin/features/spelling/engine/spelling_config.dart';
import 'package:akurin/features/spelling/engine/spelling_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spelling_test_helpers.dart';

void main() {
  final bank = loadTestBank();
  const params = ModelParams();

  test('word bank loads every row with skills in stage order', () {
    expect(bank.entries.length, 648);
    expect(bank.placementWords.map((w) => w.word),
        ['cat', 'bed', 'sun', 'fish', 'duck', 'frog', 'hand', 'cake', 'tree', 'star']);
    expect(bank.skillOrder.first, 'sight_words');
    expect(bank.skillOrder[1], 'short_a');
    expect(bank.byId['EN0040']!.audioSentence, 'Yes, I can.'); // quoted CSV field
  });

  test('words without an emoji have no picture (no placeholder)', () {
    expect(bank.entries.where((w) => w.emoji.isEmpty).every((w) => w.picture == null), isTrue);
    expect(bank.byId['EN0001']!.picture, '🐱');
  });

  group('BKT maths', () {
    test('Bayes update matches the formulas', () {
      // correct: 0.5·0.9 / (0.5·0.9 + 0.5·0.2) = 0.45 / 0.55
      expect(LearnerModel.bayes(0.5, true, guess: 0.2, slip: 0.1), closeTo(0.45 / 0.55, 1e-9));
      // incorrect: 0.5·0.1 / (0.5·0.1 + 0.5·0.8) = 0.05 / 0.45
      expect(LearnerModel.bayes(0.5, false, guess: 0.2, slip: 0.1), closeTo(0.05 / 0.45, 1e-9));
    });

    test('guess chance depends on word length (drag-and-drop is easier to guess)', () {
      expect(SpellingConfig.pGuessForLength(3), 0.35);
      expect(SpellingConfig.pGuessForLength(4), 0.25);
      expect(SpellingConfig.pGuessForLength(7), 0.15);
      expect(const ModelParams(pGuessScale: 1).pGuess(3), 0.35);
      expect(params.pGuess(3), closeTo(0.35 * SpellingConfig.pGuessScale, 1e-9));
    });

    test('weighted posterior then learning transition', () {
      const p = 0.4, w = 0.6;
      final g = params.pGuess(3), s = params.pSlip;
      final posterior = w * LearnerModel.bayes(p, true, guess: g, slip: s) +
          (1 - w) * LearnerModel.bayes(p, false, guess: g, slip: s);
      expect(LearnerModel.update(p, w, letters: 3), closeTo(posterior + (1 - posterior) * params.pLearn, 1e-9));
    });

    test('evidence weights follow the behaviour rules', () {
      final w = bank.byId['EN0001']!;
      double weight(FeatureRow row, {bool behaviour = true}) =>
          LearnerModel.evidenceWeight(row, useBehaviour: behaviour);
      expect(weight(fakeRow(w)), SpellingConfig.wFluent);
      expect(weight(fakeRow(w, hesitationRatio: 2)), SpellingConfig.wHesitant); // slow start
      expect(weight(fakeRow(w, corrections: 2)), SpellingConfig.wHesitant); // many corrections
      expect(weight(fakeRow(w, correctFirstTry: false, attempts: 2)), SpellingConfig.wSecondTry);
      expect(weight(fakeRow(w, correctFirstTry: false, attempts: 3)), SpellingConfig.wThirdTry);
      expect(weight(fakeRow(w, correctFirstTry: false, finalCorrect: false, attempts: 3)), 0.0);
      // Mistake outside the target sound (e.g. b/d flip in a short-e word).
      expect(weight(fakeRow(w, correctFirstTry: false, attempts: 2, targetGraphemeError: false)),
          SpellingConfig.wOffTargetSolved);
      // Plain BKT ignores behaviour.
      expect(weight(fakeRow(w, hesitationRatio: 2), behaviour: false), 1.0);
      expect(weight(fakeRow(w, correctFirstTry: false, attempts: 2), behaviour: false), 0.0);
    });
  });

  test('behaviour changes the model: fast & clean ends clearly above slow & corrected; off = equal', () {
    final words = bank.wordsOfSkill('short_a').take(6).toList();
    ChildModel play({required bool fast, required bool behaviour}) {
      final c = ChildModel.create(childId: fast ? 'A' : 'B', avatar: '🐶', bank: bank)
        ..skills['short_a']!.pL = 0.3;
      for (final w in words) {
        LearnerModel.applyWord(
          c,
          fakeRow(w, hesitationRatio: fast ? 0.8 : 2.0, corrections: fast ? 0 : 3),
          bank,
          useBehaviour: behaviour,
        );
      }
      return c;
    }

    final a = play(fast: true, behaviour: true).skills['short_a']!.pL;
    final b = play(fast: false, behaviour: true).skills['short_a']!.pL;
    expect(a - b, greaterThan(0.1), reason: 'A=$a B=$b');

    final aOff = play(fast: true, behaviour: false).skills['short_a']!.pL;
    final bOff = play(fast: false, behaviour: false).skills['short_a']!.pL;
    expect(aOff, bOff);
  });

  test('no over-fast mastery: 2 right answers are not enough, mastery needs 5 words over 2 rounds', () {
    final c = ChildModel.create(childId: 'm', avatar: '🐶', bank: bank);
    final words = bank.wordsOfSkill('short_a');
    c.skills['short_a']!
      ..pL = 0.1
      ..unlocked = true;
    LearnerModel.applyWord(c, fakeRow(words[0], roundNo: 2), bank, useBehaviour: true);
    LearnerModel.applyWord(c, fakeRow(words[1], roundNo: 2), bank, useBehaviour: true);
    expect(c.skills['short_a']!.pL, lessThan(0.85));
    expect(c.isMastered('short_a'), isFalse);

    for (var i = 2; i < 5; i++) {
      LearnerModel.applyWord(c, fakeRow(words[i], roundNo: 2), bank, useBehaviour: true);
    }
    expect(c.skills['short_a']!.pL, greaterThanOrEqualTo(0.85));
    expect(c.isMastered('short_a'), isFalse, reason: 'all 5 words came from one round');
    LearnerModel.applyWord(c, fakeRow(words[5], roundNo: 3), bank, useBehaviour: true);
    expect(c.isMastered('short_a'), isTrue);
  });

  group('counts and prior source through the real engine', () {
    Future<(SpellingEngine, ChildModel)> afterPlacement() async {
      final engine = SpellingEngine(bank: bank, storage: InMemorySpellingStorage(), random: math.Random(1));
      final child = await engine.createChild('🐱');
      engine.selectChild(child);
      final plan = engine.startRound();
      for (var i = 0; i < plan.words.length; i++) {
        await engine.recordWord(word: plan.words[i], wordIndex: i, events: quickCorrectEvents(plan.words[i]));
      }
      await engine.finishRound();
      return (engine, child);
    }

    test('placement words count: cat, bed, sun … give seen = 1', () async {
      final (_, child) = await afterPlacement();
      for (final w in bank.placementWords) {
        expect(child.skills[w.phonicsSkill]!.seen, 1, reason: w.phonicsSkill);
        expect(child.skills[w.phonicsSkill]!.correct, 1);
        expect(child.skills[w.phonicsSkill]!.priorSource, PriorSource.evidence);
      }
      expect(child.skills['short_i']!.seen, 0);
      expect(child.skills['short_i']!.priorSource, PriorSource.assumed);
    });

    test('every word played updates exactly one skill', () async {
      final (engine, child) = await afterPlacement();
      final before = {for (final e in child.skills.entries) e.key: e.value.seen};
      final plan = engine.startRound();
      for (var i = 0; i < plan.words.length; i++) {
        final w = plan.words[i];
        final seenBefore = {for (final e in child.skills.entries) e.key: e.value.seen};
        await engine.recordWord(word: w, wordIndex: i, events: quickCorrectEvents(w));
        final changed = [for (final e in child.skills.entries) if (e.value.seen != seenBefore[e.key]) e.key];
        expect(changed, [w.phonicsSkill]);
      }
      final total = child.skills.entries.fold<int>(0, (s, e) => s + e.value.seen - before[e.key]!);
      expect(total, plan.words.length);
      expect(child.skills.values.fold<int>(0, (s, k) => s + k.seen), 20);
      expect(child.skills.values.fold<int>(0, (s, k) => s + k.correct), 20);
      // Skills of practised words are now evidence-based.
      for (final w in plan.words) {
        expect(child.skills[w.phonicsSkill]!.priorSource, PriorSource.evidence);
      }
    });
  });

  test('placement: earlier stages assumed known, error stage learning, later locked', () {
    final child = ChildModel.create(childId: 'c', avatar: '🐼', bank: bank);
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

    expect(child.skills['short_i']!.pL, 0.6); // stage 1, assumed
    expect(child.skills['short_i']!.priorSource, PriorSource.assumed);
    expect(child.skills['digraph_sh']!.pL, 0.15); // failed placement word
    expect(child.skills['digraph_sh']!.priorSource, PriorSource.evidence);
    expect(child.skills['digraph_ch']!.pL, 0.3); // same stage, untested
    expect(child.skills['blend_initial']!.unlocked, isFalse); // later stage
    expect(child.skills['sight_words']!.pL, 0.3);
    expect(child.placementDone, isTrue);
    // Starting guesses never show up as results.
    expect(child.isMastered('short_i'), isFalse);
    expect(child.isWeak('short_i'), isFalse);
  });

  test('error-pattern rates decay towards recent behaviour', () {
    final child = ChildModel.create(childId: 'd', avatar: '🦁', bank: bank);
    final w = bank.byId['EN0025']!;
    LearnerModel.applyWord(child, fakeRow(w, correctFirstTry: false, errors: {'reversal': 1}), bank,
        useBehaviour: true);
    expect(child.errorRates['reversal'], closeTo(0.1, 1e-9));
    LearnerModel.applyWord(child, fakeRow(w), bank, useBehaviour: true);
    expect(child.errorRates['reversal'], closeTo(0.09, 1e-9));
  });

  test('featurize measures timing, slips vs corrections and the first wrong answer', () {
    final w = bank.byId['EN0025']!; // bed
    final child = ChildModel.create(childId: 'e', avatar: '🐰', bank: bank);
    final events = [
      const SpellingEvent(SpellingEventType.audioStart, 0),
      const SpellingEvent(SpellingEventType.audioEnd, 1500),
      const SpellingEvent(SpellingEventType.tilePlace, 3000, {'letter': 'd', 'slot': 0}),
      const SpellingEvent(SpellingEventType.tileRemove, 3300, {'letter': 'd', 'slot': 0, 'msSincePlaced': 300}),
      const SpellingEvent(SpellingEventType.tilePlace, 4000, {'letter': 'd', 'slot': 0}),
      const SpellingEvent(SpellingEventType.tilePlace, 5000, {'letter': 'e', 'slot': 1}),
      const SpellingEvent(SpellingEventType.tilePlace, 8000, {'letter': 'b', 'slot': 2}),
      const SpellingEvent(SpellingEventType.check, 9000, {'answer': 'deb', 'correct': false, 'attemptNo': 1}),
      const SpellingEvent(SpellingEventType.tileMove, 11000, {'letter': 'b', 'fromSlot': 2, 'toSlot': 0, 'msSincePlaced': 3000}),
      const SpellingEvent(SpellingEventType.check, 12000, {'answer': 'bed', 'correct': true, 'attemptNo': 2}),
    ];
    final row = featurize(events, w, child,
        const WordContext(childId: 'e', sessionId: 's', roundNo: 1, wordIndex: 0, mode: 'adaptive'));
    final v = row.values;
    expect(v['first_input_ms'], 1500);
    expect(v['total_ms'], 12000);
    expect(v['max_gap_ms'], 3000);
    expect(v['motor_slips'], 1);
    expect(v['corrections'], 1);
    expect(v['attempts'], 2);
    expect(v['correct_first_try'], isFalse);
    expect(v['final_correct'], isTrue);
    expect(v['reversal'], 2);
    expect(v['target_grapheme_error'], isFalse); // the "e" was right
    expect(v['hesitation_ratio'], closeTo(1500 / 3000, 1e-9)); // default median
  });

  test('motor slips (undo < SLIP_MS) are never corrections', () {
    final w = bank.byId['EN0001']!; // cat
    final child = ChildModel.create(childId: 's', avatar: '🐰', bank: bank);
    final events = [
      const SpellingEvent(SpellingEventType.audioEnd, 0),
      const SpellingEvent(SpellingEventType.tilePlace, 1000, {'letter': 'c', 'slot': 0}),
      const SpellingEvent(SpellingEventType.tileRemove, 1200, {'letter': 'c', 'msSincePlaced': 200}),
      const SpellingEvent(SpellingEventType.tilePlace, 1500, {'letter': 'c', 'slot': 0}),
      const SpellingEvent(SpellingEventType.tileMove, 1900, {'letter': 'c', 'msSincePlaced': 400}),
      const SpellingEvent(SpellingEventType.tileRemove, 2500, {'letter': 'c', 'msSincePlaced': 999}),
      const SpellingEvent(SpellingEventType.tilePlace, 2600, {'letter': 'c', 'slot': 0}),
      const SpellingEvent(SpellingEventType.tilePlace, 3000, {'letter': 'a', 'slot': 1}),
      const SpellingEvent(SpellingEventType.tilePlace, 3400, {'letter': 't', 'slot': 2}),
      const SpellingEvent(SpellingEventType.check, 3600, {'answer': 'cat', 'correct': true, 'attemptNo': 1}),
    ];
    final row = featurize(events, w, child,
        const WordContext(childId: 's', sessionId: 's', roundNo: 2, wordIndex: 0, mode: 'adaptive'));
    expect(row.motorSlips, 2);
    expect(row.corrections, 0);
    expect(LearnerModel.evidenceWeight(row, useBehaviour: true), SpellingConfig.wFluent);
  });

  group('running medians for hesitation', () {
    final w = bank.byId['EN0001']!;
    List<SpellingEvent> startAfter(double ms) => [
          const SpellingEvent(SpellingEventType.audioEnd, 0),
          SpellingEvent(SpellingEventType.tilePlace, ms, const {'letter': 'c', 'slot': 0}),
          SpellingEvent(SpellingEventType.check, ms + 100, const {'answer': 'cat', 'correct': true, 'attemptNo': 1}),
        ];
    const ctx = WordContext(childId: 'x', sessionId: 's', roundNo: 2, wordIndex: 0, mode: 'adaptive');

    test('3000 ms default until 5 words, then the child\'s own median', () {
      final c = ChildModel.create(childId: 'x', avatar: '🐶', bank: bank);
      for (var i = 0; i < 4; i++) {
        c.recordTiming(1000, 500);
        expect(c.medianFirstInput, SpellingConfig.defaultMedianMs);
      }
      c.recordTiming(1000, 500);
      expect(c.medianFirstInput, 1000);
    });

    test('medians are per child', () {
      final a = ChildModel.create(childId: 'a', avatar: '🐶', bank: bank);
      final b = ChildModel.create(childId: 'b', avatar: '🐱', bank: bank);
      for (var i = 0; i < 5; i++) {
        a.recordTiming(1000, 500);
        b.recordTiming(4000, 500);
      }
      expect(featurize(startAfter(2000), w, a, ctx).hesitationRatio, 2.0);
      expect(featurize(startAfter(2000), w, b, ctx).hesitationRatio, 0.5);
    });

    test('hesitation_ratio uses the median *before* the current word', () async {
      final engine = SpellingEngine(bank: bank, storage: InMemorySpellingStorage(), random: math.Random(2));
      final c = await engine.createChild('🐸');
      for (var i = 0; i < 5; i++) {
        c.recordTiming(1000, 500);
      }
      engine.selectChild(c);
      engine.startRound();
      // A very slow start would move the median if it were added first.
      final row = await engine.recordWord(word: w, wordIndex: 0, events: startAfter(9000));
      expect(row.hesitationRatio, 9.0);
      expect(c.firstInputHistory.last, 9000);
    });
  });
}
