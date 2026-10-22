import 'dart:math' as math;

import 'package:akurin/features/spelling/data/skill_labels.dart';
import 'package:akurin/features/spelling/data/spelling_storage.dart';
import 'package:akurin/features/spelling/engine/event_logger.dart';
import 'package:akurin/features/spelling/engine/learner_model.dart';
import 'package:akurin/features/spelling/engine/selector.dart';
import 'package:akurin/features/spelling/engine/simulator.dart';
import 'package:akurin/features/spelling/engine/spelling_config.dart';
import 'package:akurin/features/spelling/engine/spelling_engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spelling_test_helpers.dart';

void main() {
  final bank = loadTestBank();

  ChildModel placedChild({String failed = 'fish'}) {
    final child = ChildModel.create(childId: 'c', avatar: '🐶', bank: bank);
    final rows = [
      for (final w in bank.placementWords)
        w.word == failed
            ? fakeRow(w, correctFirstTry: false, finalCorrect: false, attempts: 3, roundNo: 1)
            : fakeRow(w, roundNo: 1),
    ];
    for (final r in rows) {
      LearnerModel.applyPlacementWord(child, r, bank);
    }
    LearnerModel.applyPlacement(child, rows, bank);
    return child;
  }

  test('a new child gets the placement round', () {
    final child = ChildModel.create(childId: 'n', avatar: '🐶', bank: bank);
    final plan = Selector(bank).next(child);
    expect(plan.isPlacement, isTrue);
    expect(plan.words.map((w) => w.stage).toList(), [1, 1, 1, 2, 2, 3, 3, 4, 5, 6]);
  });

  test('adaptive round: 10 unique words, 6 from the focus skill, easiest first and last', () {
    for (var seed = 0; seed < 20; seed++) {
      final plan = Selector(bank, random: math.Random(seed)).adaptive(placedChild());
      expect(plan.words.length, 10);
      expect(plan.words.map((w) => w.id).toSet().length, 10);
      expect(plan.words.where((w) => w.phonicsSkill == plan.focusSkill).length, greaterThanOrEqualTo(6));
      final minD = plan.words.map((w) => w.difficulty).reduce(math.min);
      expect(plan.words.first.difficulty, minD);
      expect(plan.reason, contains('Main practice: ${skillLabel(plan.focusSkill!).full}'));
    }
  });

  test('locked and too-hard untested skills are never the focus', () {
    for (var seed = 0; seed < 30; seed++) {
      final child = placedChild();
      final plan = Selector(bank, random: math.Random(seed)).adaptive(child);
      final s = child.skills[plan.focusSkill]!;
      expect(s.unlocked, isTrue);
      expect(s.pL, lessThan(SpellingConfig.mastered));
    }
  });

  test('a high reversal rate brings in b/d words', () {
    final child = placedChild()..errorRates['reversal'] = 0.42;
    final plan = Selector(bank, random: math.Random(3)).adaptive(child);
    expect(plan.errorFocus, 'reversal');
    expect(plan.reason, contains('b/d words'));
    expect(plan.teacherSentence, contains('a few b/d words'));
    expect(plan.words.where((w) => w.confusableLetters.isNotEmpty).length, greaterThanOrEqualTo(2));
  });

  test('no repeats from the last 3 rounds, but a failed word returns once 2 rounds later', () async {
    final engine = SpellingEngine(bank: bank, storage: InMemorySpellingStorage(), random: math.Random(5));
    final child = await engine.createChild('🐱');
    engine.selectChild(child);

    // Placement, with "fish" failed.
    final placement = engine.startRound();
    for (var i = 0; i < placement.words.length; i++) {
      final w = placement.words[i];
      final events = quickCorrectEvents(w);
      if (w.word == 'fish') {
        final check = events.removeLast();
        for (var a = 1; a <= 3; a++) {
          events.add(SpellingEvent(SpellingEventType.check, check.t + a * 1000,
              {'answer': 'fisk', 'correct': false, 'attemptNo': a}));
        }
      }
      await engine.recordWord(word: w, wordIndex: i, events: events);
    }
    await engine.finishRound(); // round 1
    expect(child.failedDue['EN0123'], 3);

    final seen = <int, Set<String>>{};
    for (var round = 2; round <= 4; round++) {
      final plan = engine.startRound();
      seen[round] = plan.words.map((w) => w.id).toSet();
      for (var i = 0; i < plan.words.length; i++) {
        await engine.recordWord(word: plan.words[i], wordIndex: i, events: quickCorrectEvents(plan.words[i]));
      }
      await engine.finishRound();
    }
    expect(seen[3], contains('EN0123')); // fish comes back in round 3
    expect(seen[4]!.intersection(seen[3]!), isEmpty);
    expect(seen[3]!.intersection(seen[2]!), isEmpty);
  });

  test('fixed group gives every child the same sequence', () {
    final a = placedChild(), b = placedChild(failed: 'cat');
    final s = Selector(bank);
    expect(s.fixed(a).words.map((w) => w.id), s.fixed(b).words.map((w) => w.id));
    expect(s.fixed(a).words.first.stage, 1);
    final fixedChild = ChildModel.create(childId: 'f', avatar: '🐶', bank: bank, group: SpellingMode.fixed)
      ..placementDone = true;
    expect(s.next(fixedChild).kind, 'fixed');
  });

  test('review words come only from truly mastered skills', () {
    final child = placedChild();
    // High estimate but only 2 words: NOT mastered, so no review from it.
    child.skills['short_a']!
      ..pL = 0.95
      ..seen = 2;
    var plan = Selector(bank, random: math.Random(1)).adaptive(child);
    expect(plan.reason, contains('nothing is mastered yet'));

    child.skills['short_o']!
      ..pL = 0.95
      ..seen = 6
      ..roundsSeen.addAll({1, 2});
    expect(child.isMastered('short_o'), isTrue);
    plan = Selector(bank, random: math.Random(1)).adaptive(child);
    expect(plan.reason, contains('review words from sounds already mastered'));
    expect(plan.words.where((w) => w.phonicsSkill == 'short_o').length, greaterThanOrEqualTo(2));
    expect(plan.words.where((w) => w.phonicsSkill == 'short_a'), isEmpty);
  });

  test('remediation first: a struggling tested skill is the focus, but at most 2 rounds in a row', () {
    final child = placedChild(); // "fish" failed → digraph_sh at 0.15, tested
    for (var seed = 0; seed < 10; seed++) {
      expect(Selector(bank, random: math.Random(seed)).adaptive(child).focusSkill, 'digraph_sh');
    }
    RoundRecord round(int n) => RoundRecord(
          roundNo: n, mode: 'adaptive', focusSkill: 'digraph_sh', reason: '', wordIds: const [],
          failedWordIds: const [], pSnapshot: const {}, finishedAt: DateTime.now());
    child.rounds.addAll([round(2), round(3)]);
    expect(Selector(bank, random: math.Random(0)).adaptive(child).focusSkill, isNot('digraph_sh'));
  });

  test('the next round is planned when a round ends and is exactly what gets played', () async {
    final engine = SpellingEngine(bank: bank, storage: InMemorySpellingStorage(), random: math.Random(8));
    final child = await engine.createChild('🐵');
    engine.selectChild(child);
    final placement = engine.startRound();
    for (var i = 0; i < placement.words.length; i++) {
      await engine.recordWord(word: placement.words[i], wordIndex: i, events: quickCorrectEvents(placement.words[i]));
    }
    await engine.finishRound();
    final preview = engine.previewNext(child);
    expect(engine.startRound().words.map((w) => w.id), preview.words.map((w) => w.id));
  });

  test('experiment group is assigned once at creation (take turns alternates)', () async {
    final engine = SpellingEngine(bank: bank, storage: InMemorySpellingStorage());
    expect((await engine.createChild('🐶')).group, SpellingMode.adaptive);
    engine.settings.newChildGroup = NewChildGroup.alternate;
    expect((await engine.createChild('🐱')).group, SpellingMode.fixed);
    expect((await engine.createChild('🐼')).group, SpellingMode.adaptive);
    final reset = await engine.resetChild(engine.children.first, group: SpellingMode.fixed);
    expect(reset.group, SpellingMode.fixed);
  });

  test('simulated child: the model finds the "sh" weakness and the b/d habit', () async {
    final result = await ChildSimulator(bank, seed: 11).run(SimulatedChildProfile.presets.first, rounds: 6);
    final m = result.finalModel;
    expect(m.skills['digraph_sh']!.pL, lessThan(m.skills['short_a']!.pL));
    expect(m.topErrorType, 'reversal');
    final focused = result.rounds.where((r) => r.focusSkill == 'digraph_sh' || r.reason.contains('b/d')).length;
    expect(focused, greaterThanOrEqualTo(2));
  });
}
