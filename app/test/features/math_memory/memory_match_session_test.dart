import 'package:akurin/features/math_memory/engine/activity_phase.dart';
import 'package:akurin/features/math_memory/engine/attempt.dart';
import 'package:akurin/features/math_memory/memory_match/engine/memory_match_adaptive_engine.dart';
import 'package:akurin/features/math_memory/memory_match/engine/memory_match_models.dart';
import 'package:akurin/features/math_memory/memory_match/engine/memory_match_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

int wrongCell(MemoryMatchSession s) =>
    s.round.activeCells.firstWhere((c) => c != s.round.targetCell && !s.wrongCells.contains(c));

MemoryMatchSession playAll(MemoryMatchProgress progress, {bool correct = true, int seed = 1}) {
  final s = MemoryMatchSession(progress: progress, seed: seed);
  while (s.phase != ActivityPhase.finished) {
    s.hidePictures();
    if (correct) {
      s.select(s.round.targetCell);
    } else {
      s.select(wrongCell(s));
      s.select(wrongCell(s));
    }
    s.next();
  }
  return s;
}

void main() {
  test('pictures show first, then hide, then the original position is checked', () {
    final s = MemoryMatchSession(progress: MemoryMatchProgress.initial(), seed: 2);
    expect(s.stage, MemoryStage.memorizing);
    for (final cell in s.round.activeCells) {
      expect(s.isRevealed(cell), isTrue);
    }
    // No answering while the pictures are showing.
    expect(s.select(s.round.targetCell), isFalse);

    expect(s.hidePictures(), isTrue);
    expect(s.stage, MemoryStage.recalling);
    for (final cell in s.round.activeCells) {
      expect(s.isRevealed(cell), isFalse);
    }

    expect(s.select(s.round.targetCell), isTrue);
    expect(s.phase, ActivityPhase.correct);
    expect(s.isRevealed(s.round.targetCell), isTrue);
    expect(s.records.single.selectedNumbers, [s.round.targetNumber]);
  });

  test('a wrong card gives a hint, then the answer is revealed', () {
    final s = MemoryMatchSession(progress: MemoryMatchProgress.initial(), seed: 2)..hidePictures();
    s.select(wrongCell(s));
    expect(s.phase, ActivityPhase.hint);
    s.select(wrongCell(s));
    expect(s.phase, ActivityPhase.revealed);
    expect(s.records.single.outcome.correct, isFalse);
    expect(s.isRevealed(s.round.targetCell), isTrue);
  });

  test('invalid and repeated taps are ignored', () {
    final progress = MemoryMatchProgress.initial().copyWith(completedAttempts: 1);
    final s = MemoryMatchSession(progress: progress, seed: 3)..hidePictures();
    final empty = List.generate(memoryBoardCells, (i) => i).firstWhere((c) => !s.round.board.containsKey(c));
    expect(s.select(empty), isFalse, reason: 'empty cell');

    final w = wrongCell(s);
    expect(s.select(w), isTrue);
    expect(s.select(w), isFalse, reason: 'same wrong card twice');

    expect(s.select(s.round.targetCell), isTrue);
    expect(s.select(s.round.targetCell), isFalse, reason: 'already decided');
    expect(s.records, hasLength(1));
    expect(s.points, 5);
    expect(s.hidePictures(), isFalse);
  });

  test('records configuration, viewing time, tries and response time', () {
    final clock = FakeClock();
    final s = MemoryMatchSession(progress: MemoryMatchProgress.initial(), seed: 2, clock: clock.call);
    clock.advance(const Duration(seconds: 4));
    s.hidePictures();
    clock.advance(const Duration(milliseconds: 1800));
    s.select(s.round.targetCell);

    final json = s.records.single.toJson(0);
    expect(json['positions'], 3);
    expect(json['memorize_seconds'], 6);
    expect(json['viewed_ms'], 4000);
    expect(json['first_response_ms'], 1800);
    expect(json['tries'], 1);
    expect(json['completed'], isTrue);
  });

  test('first attempt is an ungraded baseline that follows the fixed plan', () {
    final s = playAll(MemoryMatchProgress.initial());
    expect(s.attemptType, AttemptType.baseline);
    expect(
      [for (final r in s.records) r.round.config],
      MemoryMatchAdaptiveConfig.defaultBaselinePlan,
    );
    expect(s.result!.score, isNull);
    expect(s.points, 0);
    expect(s.result!.progressAfter.completedAttempts, 1);
    expect(s.result!.progressAfter.adaptive.config, const MemoryConfig(positions: 5, memorizeSeconds: 5));
  });

  test('second attempt is scored and adapts from the baseline configuration', () {
    final baseline = playAll(MemoryMatchProgress.initial(), correct: false);
    final start = baseline.result!.progressAfter.adaptive.config;
    expect(start, const MemoryConfig(positions: 3, memorizeSeconds: 7));

    final second = playAll(baseline.result!.progressAfter, seed: 5);
    expect(second.attemptType, AttemptType.scored);
    expect(second.records.first.round.config, start);
    expect(second.result!.score!.stars, 3);
    // Six correct rounds: gradual, one factor at a time.
    final configs = {for (final r in second.records) r.round.config}.toList();
    expect(configs.length, greaterThan(1));
    expect(second.result!.payload['adaptation']['next_configuration'], isNotNull);
  });
}
