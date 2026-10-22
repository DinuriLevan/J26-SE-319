import 'package:akurin/features/spelling/engine/event_logger.dart';
import 'package:akurin/features/spelling/engine/feature_extractor.dart';
import 'package:akurin/features/spelling/engine/learner_model.dart';
import 'package:akurin/features/spelling/engine/simulator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spelling_test_helpers.dart';

void main() {
  final bank = loadTestBank();
  final cat = bank.byId['EN0001']!;
  const ctx = WordContext(childId: 'x', sessionId: 's', roundNo: 2, wordIndex: 0, mode: 'adaptive');

  SpellingEvent place(double t, String letter, int index) =>
      SpellingEvent(SpellingEventType.tilePlace, t, {'letter': letter, 'index': index});
  SpellingEvent remove(double t, String letter, int index, double since) =>
      SpellingEvent(SpellingEventType.tileRemove, t, {'letter': letter, 'index': index, 'msSincePlaced': since});

  test('edits are classified as insertion, deletion, replacement and reorder', () {
    final edits = classifyEdits([
      place(0, 'c', 0),
      place(1000, 'o', 1), // distractor
      remove(3000, 'o', 1, 2000),
      place(3500, 'a', 1), // same place, different letter → replacement
      place(4500, 'k', 2), // distractor
      remove(7000, 'k', 2, 2500), // deletion
      const SpellingEvent(SpellingEventType.tileMove, 7500, {'letter': 'a', 'fromIndex': 1, 'toIndex': 0, 'msSincePlaced': 4000}),
      remove(7700, 'a', 0, 200), // motor slip …
      place(7900, 'a', 0), // … and its re-placement: neither counted
    ], cat.letters.toSet());
    expect(edits.insertions, 3); // c, o, k
    expect(edits.replacements, 1);
    expect(edits.deletions, 1);
    expect(edits.reorders, 1);
    expect(edits.distractorPicks, 2); // o, k
  });

  test('with the open answer line, simulated omissions and insertions are no longer zero', () async {
    var omissions = 0, insertions = 0, rows = 0;
    for (var seed = 0; seed < 5; seed++) {
      final r = await ChildSimulator(bank, seed: seed).run(SimulatedChildProfile.presets.first, rounds: 4);
      rows += r.rows.length;
      omissions += r.rows.where((x) => x.errorCount('omission') > 0).length;
      insertions += r.rows.where((x) => x.errorCount('insertion') > 0).length;
    }
    expect(rows, 200);
    expect(omissions, greaterThan(0));
    expect(insertions, greaterThan(0));
  });

  test('paused time is left out of every timing feature', () {
    final child = ChildModel.create(childId: 'x', avatar: '🐶', bank: bank);
    final events = [
      const SpellingEvent(SpellingEventType.audioStart, 0),
      const SpellingEvent(SpellingEventType.audioEnd, 1000),
      const SpellingEvent(SpellingEventType.pause, 1500),
      const SpellingEvent(SpellingEventType.resume, 61500, {'pausedMs': 60000}), // a minute away
      place(62000, 'c', 0),
      place(62500, 'a', 1),
      place(63000, 't', 2),
      const SpellingEvent(SpellingEventType.check, 63500, {'answer': 'cat', 'correct': true, 'attemptNo': 1}),
    ];
    final row = featurize(events, cat, child, ctx);
    expect(row.firstInputMs, 1000); // not 61 000
    expect(row.values['total_ms'], 3500);
    expect(row.values['paused_ms'], 60000);
    expect(row.values['answer_length_diff'], 0);
  });
}
