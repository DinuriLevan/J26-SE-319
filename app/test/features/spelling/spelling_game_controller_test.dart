import 'dart:math' as math;

import 'package:akurin/features/spelling/data/spelling_storage.dart';
import 'package:akurin/features/spelling/engine/event_logger.dart';
import 'package:akurin/features/spelling/engine/spelling_engine.dart';
import 'package:akurin/features/spelling/game/spelling_game_controller.dart';
import 'package:akurin/features/spelling/services/sound_effects.dart';
import 'package:akurin/features/spelling/services/voice_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spelling_test_helpers.dart';

class _SilentVoice extends VoiceService {
  final spoken = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<bool> say(List<String> lines, {Duration gap = Duration.zero}) async {
    spoken.addAll(lines);
    return true;
  }

  @override
  Future<void> stop() async {}
}

class _SilentSounds extends SoundEffects {
  @override
  Future<void> warmUp() async {}

  @override
  Future<void> play(SoundEffect effect, {int variant = 0}) async {}

  @override
  void dispose() {}
}

final _bank = loadTestBank();

Future<(SpellingGameController, InMemorySpellingStorage, _SilentVoice)> _newGame(WidgetTester tester) async {
  final storage = InMemorySpellingStorage();
  final voice = _SilentVoice();
  final game = SpellingGameController(
    voice: voice,
    sounds: _SilentSounds(),
    random: math.Random(1),
    loadEngine: () async {
      final e = SpellingEngine(bank: _bank, storage: storage, random: math.Random(2));
      await e.init(loadClassifier: false); // asset loading never finishes under the fake test clock
      return e;
    },
  );
  await game.init();
  return (game, storage, voice);
}

/// Start (the phone's child is made on first play) → skip the demo →
/// first (placement) word.
Future<void> _startNewChild(SpellingGameController game, WidgetTester tester) async {
  game.handleAction(SpellingAction.startPressed);
  await tester.pump();
  expect(game.state.phase, GamePhase.demo);
  game.handleAction(SpellingAction.skipDemo);
  await tester.pump();
}

/// Drags tray tiles onto the end of the answer line to spell [letters].
void _spell(SpellingGameController game, List<String> letters) {
  for (final letter in letters) {
    final s = game.state;
    final tile = s.tiles.firstWhere((t) => t.letter == letter && s.lineIndexOf(t.id) == null);
    game.handleAction(SpellingAction.dropOnLine, {'tileId': tile.id, 'index': s.line.length});
  }
}

/// Answers the current word correctly and waits for the next one.
Future<void> _solve(SpellingGameController game, WidgetTester tester) async {
  _spell(game, game.state.word.letters);
  game.handleAction(SpellingAction.checkPressed);
  expect(game.state.feedback, WordFeedback.correct);
  await tester.pump(const Duration(seconds: 6));
}

Future<void> _playRoundCorrectly(SpellingGameController game, WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    expect(game.state.wordIndex, i);
    await _solve(game, tester);
  }
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('new child plays placement, then model-chosen rounds, then goodbye after 3', (tester) async {
    final (game, storage, voice) = await _newGame(tester);
    await _startNewChild(game, tester);

    expect(game.state.phase, GamePhase.playing);
    expect(game.state.roundWords.map((w) => w.word).first, 'cat'); // placement starts with stage 1
    await _playRoundCorrectly(game, tester);
    expect(game.state.phase, GamePhase.roundEnd);
    expect(storage.rows.length, 10);
    expect(storage.events.length, 10);

    for (var round = 2; round <= 3; round++) {
      game.handleAction(SpellingAction.nextRoundPressed);
      await tester.pump();
      expect(game.state.phase, GamePhase.playing);
      await _playRoundCorrectly(game, tester);
    }
    expect(game.state.phase, GamePhase.goodbye);
    expect(storage.rows.length, 30);
    expect(voice.spoken, contains('See you next time!'));

    final child = (await storage.loadChildren()).single;
    expect(child.placementDone, isTrue);
    expect(child.roundsCompleted, 3);
    expect(child.rounds[1].mode, 'adaptive');
    game.dispose();
  });

  testWidgets('every action is logged; after a wrong try the letters in order stay', (tester) async {
    final (game, storage, _) = await _newGame(tester);
    await _startNewChild(game, tester);

    // "cat": a wrong letter goes on, moves, comes off, goes back on; then "?at".
    final s = game.state;
    final wrong = s.tiles.firstWhere((t) => !s.word.letters.contains(t.letter));
    game.handleAction(SpellingAction.replayWord);
    game.handleAction(SpellingAction.dropOnLine, {'tileId': wrong.id, 'index': 0});
    _spell(game, ['a']);
    game.handleAction(SpellingAction.dropOnLine, {'tileId': wrong.id, 'index': 1}); // move to the end
    expect(s.answer, 'a${wrong.letter}');
    game.handleAction(SpellingAction.dropOnTray, {'tileId': wrong.id});
    game.handleAction(SpellingAction.dropOnLine, {'tileId': wrong.id, 'index': 0});
    _spell(game, ['t']);
    expect(s.answer, '${wrong.letter}at');
    game.handleAction(SpellingAction.checkPressed);
    expect(s.feedback, WordFeedback.tryAgain);
    await tester.pump(const Duration(seconds: 1));
    expect(s.answer, 'at'); // only the wrong letter went back

    final types = game.logger.events.map((e) => e.type).toList();
    expect(types, containsAll([
      SpellingEventType.audioStart,
      SpellingEventType.replay,
      SpellingEventType.tilePlace,
      SpellingEventType.tileMove,
      SpellingEventType.tileRemove,
      SpellingEventType.check,
      SpellingEventType.autoReturn,
    ]));

    // Insert the missing "c" at the start and finish.
    final c = s.tiles.firstWhere((t) => t.letter == 'c' && s.lineIndexOf(t.id) == null);
    game.handleAction(SpellingAction.dropOnLine, {'tileId': c.id, 'index': 0});
    game.handleAction(SpellingAction.checkPressed);
    expect(s.feedback, WordFeedback.correct);
    await tester.pump(const Duration(seconds: 6));
    final row = storage.rows.single;
    expect(row.values['attempts'], 2);
    expect(row.values['final_correct'], isTrue);
    expect(row.values['replays'], 1);
    expect(row.values['mode'], 'placement');
    // Test time is fast, so taking the wrong letter off was a motor slip.
    expect(row.values['motor_slips'], 1);
    expect(row.values['n_reorders'], 1);
    expect(row.values['n_insertions'], 4); // wrong, a, t, c (the slip re-place is not counted)
    expect(row.values['distractor_picks'], 1);
    game.dispose();
  });

  testWidgets('check works with fewer letters, and letters can be inserted between others', (tester) async {
    final (game, _, _) = await _newGame(tester);
    await _startNewChild(game, tester);
    final s = game.state; // "cat"
    _spell(game, ['c']);
    expect(s.canCheck, isTrue);
    _spell(game, ['t']);
    final a = s.tiles.firstWhere((t) => t.letter == 'a');
    game.handleAction(SpellingAction.dropOnLine, {'tileId': a.id, 'index': 1});
    expect(s.answer, 'cat');
    game.handleAction(SpellingAction.checkPressed);
    expect(s.feedback, WordFeedback.correct);
    await tester.pump(const Duration(seconds: 6));
    game.dispose();
  });

  testWidgets('play-level: "fis" for fish is an omission + target-sound error; "froog" for frog an insertion',
      (tester) async {
    final (game, storage, _) = await _newGame(tester);
    await _startNewChild(game, tester);
    final s = game.state;
    for (final expected in ['cat', 'bed', 'sun']) {
      expect(s.word.word, expected);
      await _solve(game, tester);
    }

    expect(s.word.word, 'fish');
    _spell(game, ['f', 'i', 's']);
    game.handleAction(SpellingAction.checkPressed);
    expect(s.feedback, WordFeedback.tryAgain);
    await tester.pump(const Duration(seconds: 1));
    expect(s.answer, 'fis'); // nothing is wrong, something is missing
    _spell(game, ['h']);
    game.handleAction(SpellingAction.checkPressed);
    expect(s.feedback, WordFeedback.correct);
    await tester.pump(const Duration(seconds: 6));

    expect(s.word.word, 'duck');
    await _solve(game, tester);

    expect(s.word.word, 'frog');
    expect(s.tiles.where((t) => t.letter == 'o').length, 2); // the extra copy
    _spell(game, ['f', 'r', 'o', 'o', 'g']);
    game.handleAction(SpellingAction.checkPressed);
    expect(s.feedback, WordFeedback.tryAgain);
    await tester.pump(const Duration(seconds: 1));
    expect(s.answer, 'frog'); // the extra "o" went back
    game.handleAction(SpellingAction.checkPressed);
    await tester.pump(const Duration(seconds: 6));

    final fish = storage.rows.firstWhere((r) => r.word == 'fish');
    expect(fish.firstWrongAnswer, 'fis');
    expect(fish.errorCount('omission'), 1);
    expect(fish.targetGraphemeError, isTrue);
    expect(fish.values['answer_length_diff'], -1);

    final frog = storage.rows.firstWhere((r) => r.word == 'frog');
    expect(frog.firstWrongAnswer, 'froog');
    expect(frog.errorCount('insertion'), 1);
    expect(frog.values['answer_length_diff'], 1);
    game.dispose();
  });

  testWidgets('leaving the screen pauses the clock and logs PAUSE / RESUME', (tester) async {
    final (game, _, _) = await _newGame(tester);
    await _startNewChild(game, tester);
    game.handleAction(SpellingAction.screenHidden, {'reason': 'app'});
    game.handleAction(SpellingAction.screenHidden); // tab left too
    expect(game.logger.paused, isTrue);
    final before = game.logger.now;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    expect(game.logger.now, before); // no time passes while paused
    game.handleAction(SpellingAction.screenShown, {'reason': 'app'});
    expect(game.logger.paused, isTrue); // still hidden by the tab
    game.handleAction(SpellingAction.screenShown);
    expect(game.logger.paused, isFalse);
    final types = game.logger.events.map((e) => e.type);
    expect(types, containsAllInOrder([SpellingEventType.pause, SpellingEventType.resume]));
    expect(game.logger.events.last.data['pausedMs'], greaterThanOrEqualTo(100));
    await tester.pump(const Duration(seconds: 6));
    game.dispose();
  });

  testWidgets('tray: word letters, 2-3 distractors with the mirror rule, one extra copy', (tester) async {
    final bed = _bank.byId['EN0025']!; // confusable "bd"
    for (var seed = 0; seed < 10; seed++) {
      final d = SpellingGameController.distractorsFor(bed, math.Random(seed));
      expect(d.length, 2);
      expect(d.first, 'd'); // mirror of b
    }
    final cat = _bank.byId['EN0001']!;
    expect(SpellingGameController.distractorsFor(cat, math.Random(1)).any((l) => 'bdpqmwnu'.contains(l)), isFalse);

    final tray = SpellingGameController.trayLettersFor(cat, math.Random(3));
    expect(tray.length, 3 + 3 + 1); // short word: 3 distractors
    expect(tray.where((l) => l == 'a').length, 2); // extra copy of the vowel
    final long = _bank.entries.firstWhere((w) => w.letters.length >= 6);
    expect(SpellingGameController.trayLettersFor(long, math.Random(3)).length, long.letters.length + 2 + 1);
  });

  test('wrong-try bounce-back keeps the letters that are in order', () {
    List<String> l(String s) => s.split('');
    expect(SpellingGameController.keptOnLine(l('fis'), l('fish')), {0, 1, 2});
    expect(SpellingGameController.keptOnLine(l('froog'), l('frog')).length, 4);
    expect(SpellingGameController.keptOnLine(l('deb'), l('bed')).length, 1);
  });
}
