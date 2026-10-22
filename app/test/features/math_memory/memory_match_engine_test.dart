import 'dart:math';

import 'package:akurin/features/math_memory/memory_match/engine/memory_match_adaptive_engine.dart';
import 'package:akurin/features/math_memory/memory_match/engine/memory_match_models.dart';
import 'package:akurin/features/math_memory/memory_match/engine/memory_round_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  const engine = MemoryMatchAdaptiveEngine();

  group('round generator', () {
    test('every picture is unique, so each target has one right card', () {
      final gen = MemoryRoundGenerator(Random(5));
      for (var positions = 3; positions <= 9; positions++) {
        final round = gen.generate(MemoryConfig(positions: positions, memorizeSeconds: 5));
        expect(round.board.length, positions);
        expect(round.board.values.toSet().length, positions);
        expect(round.board.keys.every((c) => c >= 0 && c < memoryBoardCells), isTrue);
        expect(round.board.values.where((p) => p == round.target).length, 1);
        expect(round.numberFor(round.targetCell), round.targetNumber);
        expect(round.activeCells.map(round.numberFor), [for (var i = 1; i <= positions; i++) i]);
      }
    });

    test('avoids repeating the previous target when it can', () {
      final gen = MemoryRoundGenerator(Random(2));
      var previous = gen.generate(const MemoryConfig(positions: 4, memorizeSeconds: 6));
      for (var i = 0; i < 20; i++) {
        final next = gen.generate(
          const MemoryConfig(positions: 4, memorizeSeconds: 6),
          previousTarget: previous.target,
        );
        expect(next.target, isNot(previous.target));
        previous = next;
      }
    });
  });

  group('baseline estimate', () {
    test('starts at the largest board size recalled well, stopping at the first miss', () {
      final state = engine.estimateFromBaseline([
        (const MemoryConfig(positions: 3, memorizeSeconds: 6), firstTry()),
        (const MemoryConfig(positions: 3, memorizeSeconds: 6), firstTry()),
        (const MemoryConfig(positions: 4, memorizeSeconds: 6), firstTry()),
        (const MemoryConfig(positions: 4, memorizeSeconds: 6), afterHint()),
        (const MemoryConfig(positions: 5, memorizeSeconds: 6), missed()),
        (const MemoryConfig(positions: 5, memorizeSeconds: 6), firstTry()),
      ]);
      expect(state.config.positions, 4);
      // overall mastery = (1+1+1+0.5+0+1)/6 = 0.75 → 6 s.
      expect(state.config.memorizeSeconds, 6);
    });

    test('a struggling child starts small with extra looking time', () {
      final state = engine.estimateFromBaseline([
        for (final c in MemoryMatchAdaptiveConfig.defaultBaselinePlan) (c, missed()),
      ]);
      expect(state.config, const MemoryConfig(positions: 3, memorizeSeconds: 7));
    });

    test('a confident child starts bigger with less time', () {
      final state = engine.estimateFromBaseline([
        for (final c in MemoryMatchAdaptiveConfig.defaultBaselinePlan) (c, firstTry()),
      ]);
      expect(state.config, const MemoryConfig(positions: 5, memorizeSeconds: 5));
    });
  });

  group('per-round adaptation', () {
    test('success changes only one factor at a time, alternating', () {
      var state = const MemoryAdaptiveState(config: MemoryConfig(positions: 4, memorizeSeconds: 6));
      final configs = <MemoryConfig>[state.config];
      for (var i = 0; i < 12; i++) {
        state = engine.recordRound(state, firstTry()).state;
        if (state.config != configs.last) configs.add(state.config);
      }
      for (var i = 1; i < configs.length; i++) {
        final positionsChanged = configs[i].positions != configs[i - 1].positions;
        final timeChanged = configs[i].memorizeSeconds != configs[i - 1].memorizeSeconds;
        expect(positionsChanged != timeChanged, isTrue, reason: 'exactly one factor changes');
      }
      expect(configs[1], const MemoryConfig(positions: 5, memorizeSeconds: 6));
      expect(configs[2], const MemoryConfig(positions: 5, memorizeSeconds: 5));
    });

    test('struggling first adds looking time, then removes a picture', () {
      var state = const MemoryAdaptiveState(config: MemoryConfig(positions: 5, memorizeSeconds: 5));
      final changes = <MemoryChange>[];
      for (var i = 0; i < 8; i++) {
        final u = engine.recordRound(state, missed());
        state = u.state;
        if (u.change != MemoryChange.none) changes.add(u.change);
      }
      expect(changes.take(2), [MemoryChange.moreTime, MemoryChange.fewerPositions]);
    });

    test('stays within the configured limits', () {
      var hard = const MemoryAdaptiveState(config: MemoryConfig(positions: 9, memorizeSeconds: 3));
      for (var i = 0; i < 10; i++) {
        hard = engine.recordRound(hard, firstTry()).state;
      }
      expect(hard.config, const MemoryConfig(positions: 9, memorizeSeconds: 3));

      var easy = const MemoryAdaptiveState(config: MemoryConfig(positions: 3, memorizeSeconds: 10));
      for (var i = 0; i < 10; i++) {
        easy = engine.recordRound(easy, missed()).state;
      }
      expect(easy.config, const MemoryConfig(positions: 3, memorizeSeconds: 10));
    });

    test('mixed results do not cause oscillation', () {
      var state = const MemoryAdaptiveState(config: MemoryConfig(positions: 4, memorizeSeconds: 6));
      var changes = 0;
      for (var i = 0; i < 12; i++) {
        final u = engine.recordRound(state, i.isEven ? firstTry() : missed());
        state = u.state;
        if (u.change != MemoryChange.none) changes++;
      }
      expect(changes, 0);
    });
  });
}
