import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../data/letter_sounds.dart';
import '../data/spelling_storage.dart';
import '../data/word_bank.dart';
import '../engine/error_analyzer.dart';
import '../engine/event_logger.dart';
import '../engine/spelling_config.dart';
import '../engine/spelling_engine.dart';
import '../services/sound_effects.dart';
import '../services/voice_service.dart';

enum GamePhase { loading, start, demo, playing, roundEnd, goodbye }

/// What happened on the current word after the child pressed ✓.
enum WordFeedback { none, tryAgain, correct, revealed }

/// How a finished word ended — drives the star colour in the progress bar.
enum WordOutcome { solved, revealed }

/// Every user action in the game. All of them go through
/// [SpellingGameController.handleAction].
enum SpellingAction {
  startPressed,
  skipDemo,
  replayWord,
  tapTile,
  dragStarted,
  dropOnLine,
  dropOnTray,
  checkPressed,
  homePressed,
  nextRoundPressed,
  toggleMute,
  explainButton,

  /// The game is out of view (`reason`: "app" = app in the background,
  /// otherwise the screen/tab was left). Stops the voice and pauses timers.
  screenHidden,

  /// The game is visible again (same `reason`). Timers resume once nothing
  /// is hiding it any more.
  screenShown,
}

class LetterTile {
  const LetterTile({required this.id, required this.letter});

  final int id;
  final String letter;
}

/// Plain game-state object. The UI only reads it; only the controller writes.
class SpellingGameState {
  GamePhase phase = GamePhase.loading;

  /// Avatar of the phone's child (set when play starts).
  String? childAvatar;

  List<WordEntry> roundWords = [];
  int wordIndex = 0;

  /// Tiles in their fixed tray order (a tile's tray spot never moves).
  List<LetterTile> tiles = [];

  /// The answer line: tile ids in order. It has no fixed length — the child
  /// can leave letters out or add extra ones.
  List<int> line = [];

  int triesThisWord = 0;
  WordFeedback feedback = WordFeedback.none;
  List<WordOutcome?> outcomes = [];

  /// Blocks dragging/tapping while feedback animations and voice are playing.
  bool inputLocked = false;

  /// The written word is only revealed after the child has answered.
  bool showWord = false;

  /// Letter being read aloud during "c … a … t", for highlighting.
  int? spokenLetterIndex;

  /// Incremented to trigger one-shot animations in the UI.
  int wobbleSignal = 0;
  int confettiSignal = 0;

  bool soundEffectsMuted = false;

  WordEntry get word => roundWords[wordIndex];

  /// ✓ is available as soon as one letter is on the line.
  bool get canCheck => line.isNotEmpty;

  int get starsEarned => outcomes.where((o) => o == WordOutcome.solved).length;

  LetterTile tileById(int id) => tiles.firstWhere((t) => t.id == id);

  /// Position of a tile on the answer line, or null if it is in the tray.
  int? lineIndexOf(int id) {
    final i = line.indexOf(id);
    return i < 0 ? null : i;
  }

  String get answer => line.map((id) => tileById(id).letter).join();
}

class SpellingGameController extends ChangeNotifier {
  SpellingGameController({
    VoiceService? voice,
    SoundEffects? sounds,
    math.Random? random,
    Future<SpellingEngine> Function()? loadEngine,
  })  : voice = voice ?? VoiceService(),
        sounds = sounds ?? SoundEffects(),
        _random = random ?? math.Random(),
        _loadEngine = loadEngine ?? _defaultEngine;

  final VoiceService voice;
  final SoundEffects sounds;
  final math.Random _random;
  final Future<SpellingEngine> Function() _loadEngine;
  final SpellingGameState state = SpellingGameState();
  final EventLogger logger = EventLogger();

  /// Available once [init] has finished.
  SpellingEngine? engine;

  static const _praise = ['Great job!', 'You did it!', 'Super speller!', 'Wonderful!'];

  /// Bumped whenever the flow is reset, so in-flight voice/feedback
  /// sequences from the previous flow stop instead of acting on new state.
  int _flow = 0;
  bool _disposed = false;

  /// When each placed tile landed on the line (for msSincePlaced).
  final Map<int, double> _placedAt = {};

  /// Why the game is currently out of view ("app", "screen"); timers run
  /// only while this is empty.
  final Set<String> _hiddenBy = {};

  /// Saving rows happens in the background, one word after another.
  Future<void> _pendingSaves = Future.value();

  static Future<SpellingEngine> _defaultEngine() async {
    final engine = SpellingEngine(bank: await WordBank.load(), storage: FileSpellingStorage());
    await engine.init();
    return engine;
  }

  Future<void> init() async {
    engine = await _loadEngine();
    state.phase = GamePhase.start;
    _notify();
  }

  /// The single entry point for every user action. Interaction events for
  /// the research log are recorded here.
  void handleAction(SpellingAction type, [Map<String, Object?> data = const {}]) {
    switch (type) {
      case SpellingAction.startPressed:
        sounds.warmUp();
        if (engine == null || state.phase != GamePhase.start) return;
        _play();
      case SpellingAction.skipDemo:
        if (state.phase == GamePhase.demo) _startRound();
      case SpellingAction.replayWord:
        if (state.phase != GamePhase.playing || state.inputLocked) return;
        logger.log(SpellingEventType.replay);
        _speakWord(_flow, intro: false);
      case SpellingAction.tapTile:
        if (state.inputLocked) return;
        final tile = state.tileById(data['tileId']! as int);
        voice.say([letterSounds[tile.letter] ?? tile.letter]);
      case SpellingAction.dragStarted:
        if (!state.inputLocked) sounds.play(SoundEffect.pickUp);
      case SpellingAction.dropOnLine:
        _dropOnLine(data['tileId']! as int, data['index']! as int);
      case SpellingAction.dropOnTray:
        _dropOnTray(data['tileId']! as int);
      case SpellingAction.checkPressed:
        _check();
      case SpellingAction.homePressed:
        _goHome();
      case SpellingAction.nextRoundPressed:
        if (state.phase == GamePhase.roundEnd) _startRound();
      case SpellingAction.toggleMute:
        state.soundEffectsMuted = !state.soundEffectsMuted;
        sounds.muted = state.soundEffectsMuted;
        _notify();
      case SpellingAction.explainButton:
        voice.say([data['purpose']! as String]);
      case SpellingAction.screenHidden:
        voice.stop();
        _hiddenBy.add(data['reason'] as String? ?? 'screen');
        logger.pause();
      case SpellingAction.screenShown:
        _hiddenBy.remove(data['reason'] as String? ?? 'screen');
        if (_hiddenBy.isEmpty) logger.resume();
    }
  }

  /// An adult screen changed something (name, reset) — refresh. After a
  /// reset there is no child any more, so go back to the start screen.
  void refresh() {
    if (engine?.child == null && state.phase != GamePhase.start && state.phase != GamePhase.loading) {
      _goHome();
      return;
    }
    _notify();
  }

  // --------------------------------------------------------------- child

  /// One phone = one child: play as the phone's child (made on first play).
  Future<void> _play() async {
    final e = engine!;
    final child = await e.deviceChild();
    if (_disposed || state.phase != GamePhase.start) return;
    e.selectChild(child);
    state.childAvatar = child.avatar;
    if (child.rounds.isEmpty) {
      _startDemo(); // brand new: show how to play, then placement
    } else {
      _startRound();
    }
  }

  // ---------------------------------------------------------------- flow

  Future<void> _startDemo() async {
    final flow = ++_flow;
    state.phase = GamePhase.demo;
    _notify();
    await Future.wait([
      voice.say(['Listen to the word,', 'then drag the letters onto the line.']),
      Future<void>.delayed(const Duration(milliseconds: 3200)),
    ]);
    if (flow == _flow && state.phase == GamePhase.demo) _startRound();
  }

  void _startRound() {
    final plan = engine!.startRound();
    state
      ..roundWords = plan.words
      ..outcomes = List<WordOutcome?>.filled(plan.words.length, null);
    _beginWord(0);
  }

  void _beginWord(int index) {
    final flow = ++_flow;
    state
      ..phase = GamePhase.playing
      ..wordIndex = index
      ..triesThisWord = 0
      ..feedback = WordFeedback.none
      ..inputLocked = false
      ..showWord = false
      ..spokenLetterIndex = null;

    final all = trayLettersFor(state.word, _random)..shuffle(_random);
    state.tiles = [for (var i = 0; i < all.length; i++) LetterTile(id: i, letter: all[i])];
    state.line = [];
    _placedAt.clear();
    logger.takeWord(); // drop anything left over from a previous word
    _notify();

    _speakWord(flow, intro: true);
  }

  /// "word … sentence … word", or the word twice. Logged as
  /// AUDIO_START / AUDIO_END (END is logged even if a tap interrupts it).
  Future<void> _speakWord(int flow, {required bool intro}) async {
    if (flow != _flow || state.phase != GamePhase.playing) return;
    final w = state.word;
    final lines = [
      if (intro) 'Listen!',
      w.word,
      if (w.audioSentence.isNotEmpty) w.audioSentence,
      w.word,
    ];
    final wordIndex = state.wordIndex;
    logger.log(SpellingEventType.audioStart);
    try {
      await _sayIf(flow, lines);
    } finally {
      if (flow == _flow && state.wordIndex == wordIndex) logger.log(SpellingEventType.audioEnd);
    }
  }

  /// Every tray letter: the word's letters, 2–3 distractors (3 for words of
  /// up to 4 letters, to keep long-word trays small) and one extra copy of a
  /// letter already in the word, so doubling mistakes ("froog") are possible.
  static List<String> trayLettersFor(WordEntry word, math.Random random) => [
        ...word.letters,
        ...distractorsFor(word, random, count: word.letters.length <= 4 ? 3 : 2),
        extraCopyFor(word, random),
      ];

  /// A letter of the word to put in the tray twice: a vowel if there is one
  /// (children often double vowels), else any letter of the word.
  static String extraCopyFor(WordEntry word, math.Random random) {
    final vowels = word.letters.where('aeiou'.contains).toList();
    final pool = vowels.isNotEmpty ? vowels : word.letters;
    return pool[random.nextInt(pool.length)];
  }

  /// Letters for the tray that are not in the word: one mirror twin when the
  /// word has a confusable letter (b↔d, p↔q), the rest random non-look-alikes.
  static List<String> distractorsFor(WordEntry word, math.Random random, {int count = 2}) {
    final letters = word.letters.toSet();
    final out = <String>[];
    for (final c in word.confusableLetters.toLowerCase().split('')) {
      final mirror = mirrorLetters[c];
      if (mirror != null) {
        out.add(mirror);
        break;
      }
    }
    final pool = 'abcdefghijklmnopqrstuvwxyz'
        .split('')
        .where((l) => !letters.contains(l) && !out.contains(l) && !mirrorLetters.containsKey(l) && !'qxz'.contains(l))
        .toList()
      ..shuffle(random);
    while (out.length < count && pool.isNotEmpty) {
      out.add(pool.removeLast());
    }
    return out;
  }

  /// Puts [tileId] on the answer line at [index] (0 = before the first
  /// letter). [index] counts the line *without* the dragged tile, which is
  /// how the line looks while that tile is being dragged.
  void _dropOnLine(int tileId, int index) {
    if (state.inputLocked || state.phase != GamePhase.playing) return;
    final line = state.line;
    final from = state.lineIndexOf(tileId);
    final now = logger.now;
    final letter = state.tileById(tileId).letter;

    if (from == null) {
      // From the tray: insert (between letters, or at either end).
      final at = index.clamp(0, line.length);
      logger.log(SpellingEventType.tilePlace, {'letter': letter, 'index': at, 'lineLength': line.length + 1});
      line.insert(at, tileId);
      _placedAt[tileId] = now;
      _afterDrop(at);
    } else {
      // Along the line: reorder.
      line.removeAt(from);
      final at = index.clamp(0, line.length);
      line.insert(at, tileId);
      if (at == from) return;
      logger.log(SpellingEventType.tileMove, {
        'letter': letter,
        'fromIndex': from,
        'toIndex': at,
        'msSincePlaced': now - (_placedAt[tileId] ?? now),
      });
      _placedAt[tileId] = now;
      _afterDrop(at);
    }
  }

  void _afterDrop(int index) {
    state.feedback = WordFeedback.none;
    // Each position plays the next note up, so building a word plays a tune.
    sounds.play(SoundEffect.drop, variant: index);
    _notify();
  }

  void _dropOnTray(int tileId) {
    if (state.inputLocked) return;
    final from = state.lineIndexOf(tileId);
    if (from == null) return;
    final now = logger.now;
    logger.log(SpellingEventType.tileRemove, {
      'letter': state.tileById(tileId).letter,
      'index': from,
      'msSincePlaced': now - (_placedAt.remove(tileId) ?? now),
    });
    state.line.removeAt(from);
    state.feedback = WordFeedback.none;
    sounds.play(SoundEffect.backToTray);
    _notify();
  }

  void _check() {
    if (state.inputLocked || !state.canCheck) return;
    state.triesThisWord++;
    final answer = state.answer;
    final correct = answer == state.word.spelling;
    logger.log(SpellingEventType.check, {
      'answer': answer,
      'correct': correct,
      'attemptNo': state.triesThisWord,
    });
    if (correct) {
      _onCorrect();
    } else if (state.triesThisWord >= SpellingConfig.maxAttempts) {
      _reveal();
    } else {
      _onWrong();
    }
  }

  Future<void> _onCorrect() async {
    final flow = _flow;
    state
      ..inputLocked = true
      ..feedback = WordFeedback.correct
      ..showWord = true
      ..confettiSignal = state.confettiSignal + 1;
    state.outcomes[state.wordIndex] = WordOutcome.solved;
    _finishWord(finalCorrect: true);
    sounds.play(SoundEffect.happy);
    _notify();

    if (!await _sayIf(flow, [_praise[_random.nextInt(_praise.length)]])) return;
    if (!await _readLetterByLetter(flow)) return;
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    if (flow == _flow) _next();
  }

  Future<void> _onWrong() async {
    final flow = _flow;
    state
      ..inputLocked = true
      ..feedback = WordFeedback.tryAgain
      ..wobbleSignal = state.wobbleSignal + 1;
    sounds.play(SoundEffect.softTryAgain);
    _notify();

    final speech = voice.say(['Almost!', "Let's try again."]);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (flow != _flow) return;
    // Letters that fit the word in order stay; the rest go back to the tray.
    final keep = keptOnLine(state.line.map((id) => state.tileById(id).letter).toList(), state.word.letters);
    final returned = <String>[];
    for (var i = state.line.length - 1; i >= 0; i--) {
      if (keep.contains(i)) continue;
      final id = state.line.removeAt(i);
      returned.insert(0, state.tileById(id).letter);
      _placedAt.remove(id);
    }
    logger.log(SpellingEventType.autoReturn, {'letters': returned.join()});
    sounds.play(SoundEffect.backToTray);
    state.inputLocked = false;
    _notify();
    await speech;
  }

  Future<void> _reveal() async {
    final flow = _flow;
    state
      ..inputLocked = true
      ..feedback = WordFeedback.revealed
      ..showWord = true;
    state.outcomes[state.wordIndex] = WordOutcome.revealed;
    _finishWord(finalCorrect: false);

    // Lay out the right word, reusing tiles already on the line first.
    final onLine = [...state.line];
    final used = <int>{};
    int pick(String letter) {
      final tile = [
        ...onLine.map(state.tileById),
        ...state.tiles,
      ].firstWhere((t) => t.letter == letter && !used.contains(t.id));
      used.add(tile.id);
      return tile.id;
    }

    state.line = [for (final letter in state.word.letters) pick(letter)];
    _notify();

    if (!await _sayIf(flow, ["Good try! Let's spell it together."])) return;
    if (!await _readLetterByLetter(flow)) return;
    if (!await _sayIf(flow, ["You're doing great!"])) return;
    await Future<void>.delayed(const Duration(milliseconds: 1000));
    if (flow == _flow) _next();
  }

  /// Logs WORD_END and hands the word's events to the engine (in the
  /// background, so the celebration isn't delayed).
  void _finishWord({required bool finalCorrect}) {
    logger.log(SpellingEventType.wordEnd, {
      'finalCorrect': finalCorrect,
      'attempts': state.triesThisWord,
    });
    final events = logger.takeWord();
    final word = state.word;
    final index = state.wordIndex;
    final e = engine!;
    _pendingSaves = _pendingSaves.then((_) async {
      try {
        await e.recordWord(word: word, wordIndex: index, events: events);
      } catch (err) {
        debugPrint('Spelling: could not record word ($err)');
      }
    });
  }

  /// Positions in [answer] that belong to the longest run of letters that
  /// appear in [target] in the same order (longest common subsequence).
  /// After a wrong try these stay on the line: "fis" for "fish" keeps all
  /// three letters, "froog" for "frog" sends one "o" back.
  static Set<int> keptOnLine(List<String> answer, List<String> target) {
    final n = answer.length, m = target.length;
    final d = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
    for (var i = n - 1; i >= 0; i--) {
      for (var j = m - 1; j >= 0; j--) {
        d[i][j] = answer[i] == target[j] ? d[i + 1][j + 1] + 1 : math.max(d[i + 1][j], d[i][j + 1]);
      }
    }
    final keep = <int>{};
    var i = 0, j = 0;
    while (i < n && j < m) {
      if (answer[i] == target[j]) {
        keep.add(i);
        i++;
        j++;
      } else if (d[i + 1][j] >= d[i][j + 1]) {
        i++;
      } else {
        j++;
      }
    }
    return keep;
  }

  Future<bool> _readLetterByLetter(int flow) async {
    final letters = state.word.letters;
    for (var i = 0; i < letters.length; i++) {
      if (flow != _flow) return false;
      state.spokenLetterIndex = i;
      _notify();
      if (!await _sayIf(flow, [letters[i]])) return false;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (flow != _flow) return false;
    state.spokenLetterIndex = null;
    _notify();
    return _sayIf(flow, [state.word.word]);
  }

  void _next() {
    if (state.wordIndex < state.roundWords.length - 1) {
      _beginWord(state.wordIndex + 1);
    } else {
      _endRound();
    }
  }

  Future<void> _endRound() async {
    final flow = ++_flow;
    state.inputLocked = true;
    await _pendingSaves;
    await engine!.finishRound();
    if (flow != _flow) return;
    final over = engine!.sessionOver;
    state
      ..phase = over ? GamePhase.goodbye : GamePhase.roundEnd
      ..inputLocked = false
      ..confettiSignal = state.confettiSignal + 1;
    sounds.play(SoundEffect.celebrate);
    _notify();
    _sayIf(flow, over ? ['You worked so hard today!', 'See you next time!'] : ['Great job!', 'You finished!']);
  }

  void _goHome() {
    _flow++;
    voice.stop();
    state
      ..phase = GamePhase.start
      ..roundWords = []
      ..tiles = []
      ..line = []
      ..outcomes = []
      ..feedback = WordFeedback.none
      ..inputLocked = false
      ..showWord = false
      ..spokenLetterIndex = null;
    logger.takeWord();
    _notify();
  }

  // ---------------------------------------------------------------- helpers

  Future<bool> _sayIf(int flow, List<String> lines) async {
    if (flow != _flow || _disposed) return false;
    final finished = await voice.say(lines);
    return finished && flow == _flow && !_disposed;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _flow++;
    voice.stop();
    sounds.dispose();
    super.dispose();
  }
}
