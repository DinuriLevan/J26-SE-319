import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../engine/event_logger.dart';
import '../../engine/feature_extractor.dart' show FeatureRow;
import '../../engine/spelling_config.dart';
import '../../game/spelling_game_controller.dart' show GamePhase, SpellingGameController, WordFeedback, WordOutcome;
import '../../model/difficulty_classifier.dart';
import '../../services/sound_effects.dart';
import '../data/akshara.dart';
import '../data/sinhala_progress.dart';
import '../data/sinhala_word_bank.dart';
import '../engine/sinhala_errors.dart';
import '../engine/sinhala_features.dart';
import '../engine/sinhala_learner.dart';
import '../engine/sinhala_selector.dart';
import '../model/difficulty_model_si_m2cgen.dart';
import '../services/sinhala_voice.dart';

/// Every user action in the Sinhala game. All of them go through
/// [SinhalaGameController.handleAction].
enum SinhalaAction {
  startPressed,
  skipDemo,
  replayWord,
  tapTile,
  dragStarted,

  /// A letter tile dropped on the answer line (`tileId`, `index`).
  dropOnLine,

  /// A pilla tile dropped on an akshara of the line (`tileId`, `lineIndex`).
  dropOnAkshara,

  /// A letter (with its pillas) or a pilla taken back to the tray (`tileId`).
  dropOnTray,
  checkPressed,
  homePressed,
  nextRoundPressed,
  toggleMute,

  /// Long-press on a button: say what it does (`prompt` = a prompt key).
  explainButton,
  screenHidden,
  screenShown,
}

/// A tray tile: a base letter (ප) or a pilla mark (ූ, ්, ්‍ය).
class SinhalaTile {
  const SinhalaTile({required this.id, required this.text});

  final int id;
  final String text;

  bool get isMark => Akshara.isMark(text);

  /// What the tile shows: the letter, or the pilla on a dotted circle (◌ූ).
  String get label => isMark ? Akshara.markLabel(text) : text;
}

/// One akshara on the answer line: a letter tile and the pilla tiles on it.
class LineAkshara {
  LineAkshara(this.letterId, [List<int>? markIds]) : markIds = markIds ?? [];

  final int letterId;
  final List<int> markIds;
}

/// Plain game-state object. The UI only reads it; only the controller writes.
class SinhalaGameState {
  GamePhase phase = GamePhase.loading;

  List<SinhalaWord> roundWords = [];
  int wordIndex = 0;

  /// Tray tiles in their fixed order: letters first, then pillas.
  List<SinhalaTile> tiles = [];

  /// The answer line: aksharas in order, each a letter plus its pillas. No
  /// fixed length, so aksharas can be left out or added.
  List<LineAkshara> line = [];

  int triesThisWord = 0;
  WordFeedback feedback = WordFeedback.none;
  List<WordOutcome?> outcomes = [];

  /// Blocks dragging/tapping while feedback and voice are playing.
  bool inputLocked = false;

  /// The written word is only shown after the child has answered.
  bool showWord = false;

  /// Akshara being read aloud, for highlighting.
  int? spokenIndex;

  int wobbleSignal = 0;
  int confettiSignal = 0;
  bool soundEffectsMuted = false;

  SinhalaWord get word => roundWords[wordIndex];

  bool get canCheck => line.isNotEmpty;

  SinhalaTile tileById(int id) => tiles.firstWhere((t) => t.id == id);

  /// Line position of the akshara whose letter is [id], or null.
  int? lineIndexOfLetter(int id) {
    final i = line.indexWhere((a) => a.letterId == id);
    return i < 0 ? null : i;
  }

  /// Line position of the akshara that holds pilla [id], or null.
  int? lineIndexOfMark(int id) {
    final i = line.indexWhere((a) => a.markIds.contains(id));
    return i < 0 ? null : i;
  }

  /// True when the tile is on the line (as a letter or on a letter).
  bool isPlaced(int id) => lineIndexOfLetter(id) != null || lineIndexOfMark(id) != null;

  String aksharaText(LineAkshara a) =>
      Akshara.compose(tileById(a.letterId).text, a.markIds.map((id) => tileById(id).text));

  List<String> get lineTexts => [for (final a in line) aksharaText(a)];

  String get answer => lineTexts.join();

  /// The line as aksharas (for the mistake checker).
  List<Akshara> get lineAksharas => [
        for (final a in line) Akshara(tileById(a.letterId).text, [for (final id in a.markIds) tileById(id).text]),
      ];
}

/// Runs the Sinhala listen-and-spell game: hear the word, drag the letters
/// onto the line, then drag each pilla onto its letter (ප + ූ → පූ).
///
/// The adaptive Sinhala game, built like the English one:
/// - every tap and drag is logged (EventLogger) and each word becomes a
///   feature row (sinhala_features.dart);
/// - the learner model (BKT, sinhala_learner.dart) keeps a "knows it"
///   estimate per stage; the first game (warm-up) finds the weak stages;
/// - the trained difficulty classifier predicts easy / medium / hard after
///   every word;
/// - the selector (sinhala_selector.dart) plans the next round from both.
/// One phone = one child.
class SinhalaGameController extends ChangeNotifier {
  SinhalaGameController({
    SinhalaVoice? voice,
    SoundEffects? sounds,
    math.Random? random,
    Future<SinhalaWordBank> Function()? loadBank,
    SinhalaProgressStore? store,
    this.loadClassifier = true,
  })  : voice = voice ?? SinhalaVoice(),
        sounds = sounds ?? SoundEffects(),
        store = store ?? FileSinhalaProgressStore(),
        _random = random ?? math.Random(),
        _loadBank = loadBank ?? SinhalaWordBank.load;

  final SinhalaVoice voice;
  final SoundEffects sounds;
  final SinhalaProgressStore store;
  final math.Random _random;
  final Future<SinhalaWordBank> Function() _loadBank;
  final SinhalaGameState state = SinhalaGameState();

  SinhalaWordBank? bank;

  /// The phone's child: results, learner model and the planned next round.
  SinhalaProgress progress = SinhalaProgress();

  /// The trained difficulty model (assets/spelling/model_si), or the BKT
  /// rule if it is missing.
  DifficultyClassifier classifier = const FallbackDifficultyClassifier();
  final bool loadClassifier;
  static const modelDir = 'assets/spelling/model_si';

  final EventLogger logger = EventLogger();

  /// When each tile landed (for msSincePlaced: quick take-backs are slips).
  final Map<int, double> _placedAt = {};

  /// The round being played is the warm-up (placement).
  bool _warmUpRound = false;

  /// A word whose answer was shown comes back this many rounds later.
  static const retryAfterRounds = 2;

  int _roundsThisSession = 0;
  String _sessionId = '';
  final List<SinhalaWordResult> _roundResults = [];

  /// First wrong answer of the current word, and its mistakes.
  String? _firstWrong;
  Map<String, int> _firstErrors = {};

  int _flow = 0;
  bool _disposed = false;
  Future<void> _saving = Future.value();

  Future<void> init() async {
    bank = await _loadBank();
    progress = await store.load();
    if (loadClassifier) {
      classifier = await MlDifficultyClassifier.load(dir: modelDir, score: difficultyModelScoreSi);
    }
    state.phase = GamePhase.start;
    _notify();
  }

  /// Teacher View -> Reset all data: forget everything and go to the start.
  Future<void> resetAll() async {
    await _saving;
    await store.clear();
    progress = SinhalaProgress();
    _goHome();
  }

  /// An adult screen changed something (e.g. the name).
  Future<void> saveProgress() => _save();

  void handleAction(SinhalaAction type, [Map<String, Object?> data = const {}]) {
    switch (type) {
      case SinhalaAction.startPressed:
        sounds.warmUp();
        if (bank == null || state.phase != GamePhase.start) return;
        _roundsThisSession = 0;
        _sessionId = '${DateTime.now().millisecondsSinceEpoch}';
        progress.warmUpDone ? _startRound() : _startDemo();
      case SinhalaAction.skipDemo:
        if (state.phase == GamePhase.demo) _startRound();
      case SinhalaAction.replayWord:
        if (state.phase != GamePhase.playing || state.inputLocked) return;
        logger.log(SpellingEventType.replay);
        _speakWord(_flow, intro: false);
      case SinhalaAction.tapTile:
        if (state.inputLocked) return;
        final id = data['tileId']! as int;
        final onLine = state.lineIndexOfLetter(id);
        // A letter on the line says its whole akshara (පූ), a tray letter its
        // own sound. Pillas have no sound of their own.
        if (onLine == null && state.tileById(id).isMark) return;
        voice.say([SinhalaClip.tile(onLine != null ? state.lineTexts[onLine] : state.tileById(id).text)]);
      case SinhalaAction.dragStarted:
        if (!state.inputLocked) sounds.play(SoundEffect.pickUp);
      case SinhalaAction.dropOnLine:
        _dropOnLine(data['tileId']! as int, data['index']! as int);
      case SinhalaAction.dropOnAkshara:
        _dropOnAkshara(data['tileId']! as int, data['lineIndex']! as int);
      case SinhalaAction.dropOnTray:
        _dropOnTray(data['tileId']! as int);
      case SinhalaAction.checkPressed:
        _check();
      case SinhalaAction.homePressed:
        _goHome();
      case SinhalaAction.nextRoundPressed:
        if (state.phase == GamePhase.roundEnd) _startRound();
      case SinhalaAction.toggleMute:
        state.soundEffectsMuted = !state.soundEffectsMuted;
        sounds.muted = state.soundEffectsMuted;
        _notify();
      case SinhalaAction.explainButton:
        voice.say([SinhalaClip.prompt(data['prompt']! as String)]);
      case SinhalaAction.screenHidden:
        voice.stop();
        logger.pause();
      case SinhalaAction.screenShown:
        logger.resume();
    }
  }

  // ---------------------------------------------------------------- flow

  Future<void> _startDemo() async {
    final flow = ++_flow;
    state.phase = GamePhase.demo;
    _notify();
    await Future.wait([
      voice.say([SinhalaClip.prompt('demo_1'), SinhalaClip.prompt('demo_2'), SinhalaClip.prompt('demo_3')]),
      Future<void>.delayed(const Duration(milliseconds: 4200)),
    ]);
    if (flow == _flow && state.phase == GamePhase.demo) _startRound();
  }

  /// The planned round (made when the last round ended), or a new plan.
  List<SinhalaWord> _nextWords() {
    final b = bank!;
    final planned = [for (final id in progress.pendingPlan ?? const <String>[]) b.byId(id)].whereType<SinhalaWord>();
    final plan = planned.isEmpty ? SinhalaSelector.plan(b, progress) : null;
    final words = plan?.words ?? planned.toList();
    _warmUpRound = !progress.warmUpDone && (plan?.kind == 'warmup' || words.every((w) => w.role == 'placement'));
    for (final w in words) {
      progress.retryDue.remove(w.id);
    }
    progress
      ..pendingPlan = null
      ..pendingReason = null
      ..pendingFocus = null;
    return words;
  }

  void _startRound() {
    _roundResults.clear();
    final words = _nextWords();
    state
      ..roundWords = words
      ..outcomes = List<WordOutcome?>.filled(words.length, null);
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
      ..spokenIndex = null;
    _firstWrong = null;
    _firstErrors = {};
    logger.takeWord(); // drop anything left over from the previous word
    _placedAt.clear();

    final tray = trayFor(state.word, _random);
    state.tiles = [for (var i = 0; i < tray.length; i++) SinhalaTile(id: i, text: tray[i])];
    state.line = [];
    _notify();
    _speakWord(flow, intro: true);
  }

  Future<void> _speakWord(int flow, {required bool intro}) async {
    if (flow != _flow || state.phase != GamePhase.playing) return;
    final w = SinhalaClip.word(state.word);
    final index = state.wordIndex;
    logger.log(SpellingEventType.audioStart);
    try {
      await _sayIf(flow, [if (intro) SinhalaClip.prompt('listen'), w, w]);
    } finally {
      if (flow == _flow && state.wordIndex == index) logger.log(SpellingEventType.audioEnd);
    }
  }

  /// The tray: the word's letters (shuffled), then its pillas (shuffled),
  /// plus up to 2 look-alike letters and 1 look-alike pilla from the word
  /// bank, so the child has to choose.
  static List<String> trayFor(SinhalaWord word, math.Random random) {
    final letters = [...word.letters];
    final marks = [...word.marks];
    final extraLetters = [
      for (final d in word.distractors)
        if (!Akshara.isMark(d) && !letters.contains(d)) d,
    ]..shuffle(random);
    final extraMarks = [
      for (final d in word.distractors)
        if (Akshara.isMark(d) && !marks.contains(d)) d,
    ]..shuffle(random);
    letters.addAll(extraLetters.toSet().take(2));
    marks.addAll(extraMarks.toSet().take(1));
    return [...letters..shuffle(random), ...marks..shuffle(random)];
  }

  /// A letter from the tray goes onto the line at [index]; a letter already
  /// on the line moves there (its pillas go with it).
  void _dropOnLine(int tileId, int index) {
    if (state.inputLocked || state.phase != GamePhase.playing) return;
    if (state.tileById(tileId).isMark) return;
    final line = state.line;
    final from = state.lineIndexOfLetter(tileId);
    final text = state.tileById(tileId).text;
    final now = logger.now;
    if (from == null) {
      final at = index.clamp(0, line.length);
      line.insert(at, LineAkshara(tileId));
      logger.log(SpellingEventType.tilePlace, {'tile': text, 'mark': false, 'index': at});
      _placedAt[tileId] = now;
      _afterDrop(at);
    } else {
      final moved = line.removeAt(from);
      final at = index.clamp(0, line.length);
      line.insert(at, moved);
      if (at != from) {
        logger.log(SpellingEventType.tileMove, {
          'tile': text,
          'fromIndex': from,
          'toIndex': at,
          'msSincePlaced': now - (_placedAt[tileId] ?? now),
        });
        _placedAt[tileId] = now;
        _afterDrop(at);
      }
    }
  }

  /// A pilla lands on the akshara at [lineIndex]. An akshara holds one vowel
  /// sign or hal; a new one sends the old one back to the tray. The same goes
  /// for the bindu and for each joined form (්‍ය, ්‍ර).
  void _dropOnAkshara(int tileId, int lineIndex) {
    if (state.inputLocked || state.phase != GamePhase.playing) return;
    if (lineIndex < 0 || lineIndex >= state.line.length) return;
    final mark = state.tileById(tileId);
    if (!mark.isMark) return;
    final from = state.lineIndexOfMark(tileId);
    if (from != null) state.line[from].markIds.remove(tileId);
    final target = state.line[lineIndex];
    final before = target.markIds.length;
    target.markIds.removeWhere((id) => clashes(state.tileById(id).text, mark.text));
    final replaced = before - target.markIds.length;
    target.markIds.add(tileId);
    final now = logger.now;
    if (from == null) {
      logger.log(SpellingEventType.tilePlace, {'tile': mark.text, 'mark': true, 'onAkshara': lineIndex, 'replaced': replaced});
    } else {
      logger.log(SpellingEventType.tileMove, {
        'tile': mark.text,
        'fromIndex': from,
        'toIndex': lineIndex,
        'replaced': replaced,
        'msSincePlaced': now - (_placedAt[tileId] ?? now),
      });
    }
    _placedAt[tileId] = now;
    _afterDrop(lineIndex);
  }

  /// True when [a] and [b] cannot both sit on one akshara.
  static bool clashes(String a, String b) {
    final oa = Akshara.markOrder(a), ob = Akshara.markOrder(b);
    if (oa != ob) return false;
    return oa == 1 || a == b; // one vowel sign/hal; no doubled joined form or bindu
  }

  void _afterDrop(int index) {
    state.feedback = WordFeedback.none;
    sounds.play(SoundEffect.drop, variant: index);
    _notify();
  }

  void _dropOnTray(int tileId) {
    if (state.inputLocked) return;
    if (!state.isPlaced(tileId)) return;
    final now = logger.now;
    logger.log(SpellingEventType.tileRemove, {
      'tile': state.tileById(tileId).text,
      'msSincePlaced': now - (_placedAt.remove(tileId) ?? now),
    });
    final letterAt = state.lineIndexOfLetter(tileId);
    if (letterAt != null) {
      state.line.removeAt(letterAt); // its pillas go back with it
    } else {
      final markAt = state.lineIndexOfMark(tileId);
      if (markAt == null) return;
      state.line[markAt].markIds.remove(tileId);
    }
    state.feedback = WordFeedback.none;
    sounds.play(SoundEffect.backToTray);
    _notify();
  }

  void _check() {
    if (state.inputLocked || !state.canCheck || state.phase != GamePhase.playing) return;
    state.triesThisWord++;
    final correct = state.answer == state.word.word;
    if (!correct && _firstWrong == null) {
      _firstWrong = state.answer;
      _firstErrors = analyzeSinhala(state.word.aksharas, state.lineAksharas, lookalikes: state.word.distractors)
          .counts
        ..removeWhere((_, n) => n == 0);
    }
    logger.log(SpellingEventType.check, {
      'answer': state.answer,
      'correct': correct,
      'attemptNo': state.triesThisWord,
      'aksharas': state.line.length,
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

    final praise = SinhalaPrompts.praise[_random.nextInt(SinhalaPrompts.praise.length)];
    if (!await _sayIf(flow, [SinhalaClip.prompt(praise)])) return;
    if (!await _readAksharas(flow)) return;
    await Future<void>.delayed(const Duration(milliseconds: 1200));
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

    final speech = voice.say([SinhalaClip.prompt('almost'), SinhalaClip.prompt('try_again')]);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (flow != _flow) return;
    // Aksharas that are right and in order stay; the rest go back to the tray.
    final keep = SpellingGameController.keptOnLine(state.lineTexts, state.word.aksharaTexts);
    final returned = <String>[];
    for (var i = state.line.length - 1; i >= 0; i--) {
      if (!keep.contains(i)) returned.insert(0, state.lineTexts[i]);
      if (!keep.contains(i)) state.line.removeAt(i);
    }
    logger.log(SpellingEventType.autoReturn, {'aksharas': returned.join()});
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

    // Build the right word from the tray tiles.
    final used = <int>{};
    int pick(String text) {
      final tile = state.tiles.firstWhere((t) => t.text == text && !used.contains(t.id));
      used.add(tile.id);
      return tile.id;
    }

    state.line = [
      for (final a in state.word.aksharas) LineAkshara(pick(a.base), [for (final m in a.marks) pick(m)]),
    ];
    _notify();

    if (!await _sayIf(flow, [SinhalaClip.prompt('together')])) return;
    if (!await _readAksharas(flow)) return;
    if (!await _sayIf(flow, [SinhalaClip.prompt('doing_great')])) return;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (flow == _flow) _next();
  }

  /// Turns the word's events into a feature row, updates the learner model,
  /// asks the classifier how hard the stage is now, and saves it all.
  void _finishWord({required bool finalCorrect}) {
    final w = state.word;
    logger.log(SpellingEventType.wordEnd, {'finalCorrect': finalCorrect, 'attempts': state.triesThisWord});
    final features = featurizeSinhala(
      events: logger.takeWord(),
      word: w,
      progress: progress,
      sessionId: _sessionId,
      roundNo: progress.nextRoundNo,
      wordIndex: state.wordIndex,
      mode: _warmUpRound ? 'placement' : 'adaptive',
      errors: _firstErrors,
      firstWrongAnswer: _firstWrong,
    );
    SinhalaLearner.recordTiming(
      progress,
      (features['first_input_ms']! as num).toDouble(),
      (features['max_gap_ms']! as num).toDouble(),
    );
    final (before, after) =
        SinhalaLearner.applyWord(progress, features, roundNo: progress.nextRoundNo, warmUp: _warmUpRound);
    features
      ..['evidence_weight'] = SinhalaLearner.evidenceWeight(features)
      ..['p_before'] = before
      ..['p_after'] = after;
    _predict(features);

    final result = SinhalaWordResult(
      wordId: w.id,
      word: w.word,
      skill: w.skill,
      stage: w.stage,
      roundNo: progress.nextRoundNo,
      tries: state.triesThisWord,
      correctFirstTry: finalCorrect && state.triesThisWord == 1,
      finalCorrect: finalCorrect,
      at: DateTime.now(),
      firstWrongAnswer: _firstWrong,
      errors: _firstErrors,
      features: features,
    );
    progress.results.add(result);
    _roundResults.add(result);
    if (!finalCorrect) progress.retryDue[w.id] = progress.nextRoundNo + retryAfterRounds;
    _save();
  }

  /// The classifier's prediction for the word's stage: kept (last 3) and
  /// written into the row. "Mastered" is held back while BKT and the
  /// classifier strongly disagree (classifier said hard twice in a row).
  void _predict(Map<String, Object?> features) {
    final skill = features['phonics_skill']! as String;
    final prediction = classifier.predict(FeatureRow(features));
    final list = progress.predictions.putIfAbsent(skill, () => [])..add(prediction);
    if (list.length > 3) list.removeAt(0);
    features
      ..['clf_label'] = prediction.label
      ..['clf_p_hard'] = prediction.probs['hard']
      ..['clf_source'] = prediction.source;
    final hardTwice = list.length >= 2 && list.reversed.take(2).every((p) => p.label == 'hard');
    progress.skill(skill).masteryHeld = SinhalaLearner.bktMastered(progress, skill) && hardTwice;
  }

  Future<void> _save() => _saving = _saving.then((_) async {
        try {
          await store.save(progress);
        } catch (e) {
          debugPrint('Sinhala spelling: could not save progress ($e)');
        }
      });

  /// Reads the word one akshara at a time (පූ … සා), then the whole word.
  Future<bool> _readAksharas(int flow) async {
    final aksharas = state.word.aksharaTexts;
    for (var i = 0; i < aksharas.length; i++) {
      if (flow != _flow) return false;
      state.spokenIndex = i;
      _notify();
      if (!await _sayIf(flow, [SinhalaClip.tile(aksharas[i])])) return false;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    if (flow != _flow) return false;
    state.spokenIndex = null;
    _notify();
    return _sayIf(flow, [SinhalaClip.word(state.word)]);
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
    _roundsThisSession++;
    progress.rounds.add(SinhalaRound(
      roundNo: progress.nextRoundNo,
      sessionId: _sessionId,
      wordIds: [for (final w in state.roundWords) w.id],
      firstTry: _roundResults.where((r) => r.correctFirstTry).length,
      afterRetry: _roundResults.where((r) => r.finalCorrect && !r.correctFirstTry).length,
      shown: _roundResults.where((r) => !r.finalCorrect).length,
      finishedAt: DateTime.now(),
    ));
    if (_warmUpRound) {
      // The first game: set every stage's starting estimate (weak areas).
      SinhalaLearner.applyPlacement(progress, [for (final r in _roundResults) r.features], bank!);
      progress.warmUpDone = true;
      _warmUpRound = false;
    }
    _roundResults.clear();
    // Plan the next round now, so the Teacher View shows exactly what comes.
    final plan = SinhalaSelector.plan(bank!, progress);
    progress
      ..pendingPlan = [for (final w in plan.words) w.id]
      ..pendingReason = plan.reason
      ..pendingFocus = plan.focusSkill;
    _save();
    final over = _roundsThisSession >= SpellingConfig.roundsPerSession;
    state
      ..phase = over ? GamePhase.goodbye : GamePhase.roundEnd
      ..inputLocked = false
      ..confettiSignal = state.confettiSignal + 1;
    sounds.play(SoundEffect.celebrate);
    _notify();
    _sayIf(
      flow,
      over
          ? [SinhalaClip.prompt('goodbye_1'), SinhalaClip.prompt('goodbye_2')]
          : [SinhalaClip.prompt('praise_3'), SinhalaClip.prompt('round_done')],
    );
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
      ..spokenIndex = null;
    _notify();
  }

  Future<bool> _sayIf(int flow, List<SinhalaClip> clips) async {
    if (flow != _flow || _disposed) return false;
    final finished = await voice.say(clips);
    return finished && flow == _flow && !_disposed;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _flow++;
    voice.dispose();
    sounds.dispose();
    super.dispose();
  }
}
