import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'data/math_progress_repository.dart';
import 'engine/attempt.dart';
import 'memory_match/memory_match_game_screen.dart';
import 'memory_match/memory_match_tutorial_screen.dart';
import 'number_quest/number_quest_game_screen.dart';
import 'number_quest/number_quest_tutorial_screen.dart';

/// Start Game: the tutorial on a child's first visit to [game], otherwise
/// straight into a real attempt. Each game tracks this separately.
Future<void> startMathGame(BuildContext context, WidgetRef ref, MathGameId game) async {
  final repo = ref.read(mathProgressRepositoryProvider);
  final tutorialSeen = switch (game) {
    MathGameId.numberQuest => (await repo.loadNumberQuest()).tutorialSeen,
    MathGameId.memoryMatch => (await repo.loadMemoryMatch()).tutorialSeen,
  };
  if (!context.mounted) return;
  Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (_) => tutorialSeen ? _gameScreen(game) : _tutorialScreen(game),
  ));
}

/// How to play: the tutorial again, any time.
void openMathGameTutorial(BuildContext context, MathGameId game) {
  Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _tutorialScreen(game)));
}

Widget _gameScreen(MathGameId game) => switch (game) {
      MathGameId.numberQuest => const NumberQuestGameScreen(),
      MathGameId.memoryMatch => const MemoryMatchGameScreen(),
    };

Widget _tutorialScreen(MathGameId game) => switch (game) {
      MathGameId.numberQuest => const NumberQuestTutorialScreen(),
      MathGameId.memoryMatch => const MemoryMatchTutorialScreen(),
    };
