import 'dart:math';

import '../../engine/math_picture.dart';
import 'memory_match_models.dart';

/// Builds Memory Match boards. Deterministic for a given [Random] seed.
class MemoryRoundGenerator {
  MemoryRoundGenerator(this._random);

  final Random _random;

  /// A board with [MemoryConfig.positions] distinct pictures in random cells.
  /// Avoids reusing [previousTarget] as the target when possible.
  MemoryRound generate(MemoryConfig config, {MathPicture? previousTarget}) {
    final positions = config.positions.clamp(1, min(memoryBoardCells, MathPicture.values.length));

    final cells = List.generate(memoryBoardCells, (i) => i)..shuffle(_random);
    final pictures = List.of(MathPicture.values)..shuffle(_random);
    final board = {
      for (var i = 0; i < positions; i++) cells[i]: pictures[i],
    };

    final candidates = board.keys.where((c) => board[c] != previousTarget).toList()..sort();
    final pool = candidates.isEmpty ? (board.keys.toList()..sort()) : candidates;
    final targetCell = pool[_random.nextInt(pool.length)];

    return MemoryRound(config: config, board: board, targetCell: targetCell);
  }
}
