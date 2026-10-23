import 'dart:convert';
import 'dart:io';

import 'package:akurin/features/speech/logic/retry_loop.dart';
import 'package:flutter_test/flutter_test.dart';

/// Runs the SAME scenarios as ml/speech/tests/test_retry.py, so the Dart port cannot drift from
/// src/retry.py. `flutter test` runs with app/ as the working directory.
void main() {
  final file = File('../ml/speech/tests/retry_cases.json');
  final cases = (jsonDecode(file.readAsStringSync()) as Map)['cases'] as List;

  for (final c in cases.cast<Map<String, dynamic>>()) {
    test('shared scenario: ${c['name']}', () {
      final listen = c['listen_units'] as List?;
      final loop = RetryLoop(
        c['n_units'] as int,
        listenUnits: listen?.cast<int>().toSet(),
      );
      final steps = <Map<String, Object?>>[];
      for (final a in (c['actions'] as List).cast<Map<String, dynamic>>()) {
        final s = switch (a['input']) {
          'full_word' => loop.onFullWord(
              accepted: a['accepted'] as bool,
              flagged: (a['flagged'] as List).cast<int>()),
          'listened' => loop.onListened(),
          'unit' => loop.onUnit(passed: a['passed'] as bool),
          'blend' => loop.onBlend(passed: a['passed'] as bool),
          'practised' => loop.onPractised(),
          _ => throw ArgumentError(a),
        };
        steps.add(s.toJson());
      }
      expect(jsonEncode(steps), jsonEncode(c['steps']));
      expect(loop.events.map((e) => e.toString()).toList(),
          (c['events'] as List).cast<String>());
      expect(loop.scheduledUnits, (c['scheduled'] as List).cast<int>());
      expect(stepKindName(loop.step.kind), c['final']);
      expect(loop.done, isTrue);
    });
  }

  test('covers the scenarios the spec requires', () {
    final names = cases.map((c) => (c as Map)['name']).toSet();
    expect(
        names,
        containsAll(
            ['happy_path', 'one_retry', 'exhaustion', 'two_flagged_units']));
  });

  test('the whole word is always scored, never just practised', () {
    expect(() => RetryLoop(3).onPractised(), throwsA(isA<RetryStateError>()));
  });

  test('rejects input for the wrong step', () {
    final loop = RetryLoop(3);
    expect(() => loop.onUnit(passed: true), throwsA(isA<RetryStateError>()));
    loop.onFullWord(accepted: true, flagged: []);
    expect(() => loop.onFullWord(accepted: true, flagged: []),
        throwsA(isA<RetryStateError>()));
  });
}
