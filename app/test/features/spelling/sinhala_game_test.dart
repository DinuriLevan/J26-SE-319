import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:akurin/features/spelling/engine/event_logger.dart';
import 'package:akurin/features/spelling/game/spelling_game_controller.dart' show GamePhase, WordFeedback, WordOutcome;
import 'package:akurin/features/spelling/model/difficulty_prediction.dart';
import 'package:akurin/features/spelling/services/sound_effects.dart';
import 'package:akurin/features/spelling/sinhala/data/akshara.dart';
import 'package:akurin/features/spelling/sinhala/data/sinhala_progress.dart';
import 'package:akurin/features/spelling/sinhala/data/sinhala_word_bank.dart';
import 'package:akurin/features/spelling/sinhala/engine/sinhala_errors.dart';
import 'package:akurin/features/spelling/sinhala/engine/sinhala_features.dart';
import 'package:akurin/features/spelling/sinhala/engine/sinhala_learner.dart';
import 'package:akurin/features/spelling/sinhala/engine/sinhala_selector.dart';
import 'package:akurin/features/spelling/sinhala/game/sinhala_game_controller.dart';
import 'package:akurin/features/spelling/sinhala/services/sinhala_voice.dart';
import 'package:akurin/features/spelling/sinhala/teacher/sinhala_insights.dart';
import 'package:akurin/features/spelling/sinhala/teacher/sinhala_teacher_screen.dart';
import 'package:akurin/features/spelling/sinhala/ui/sinhala_game_view.dart';
import 'package:akurin/features/spelling/teacher/teacher_insights.dart' show SkillStatus;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _SilentVoice extends SinhalaVoice {
  final played = <String>[];

  @override
  Future<bool> say(List<SinhalaClip> clips, {Duration gap = Duration.zero}) async {
    played.addAll(clips.map((c) => c.asset));
    return true;
  }

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}

class _SilentSounds extends SoundEffects {
  @override
  Future<void> warmUp() async {}

  @override
  Future<void> play(SoundEffect effect, {int variant = 0}) async {}

  @override
  void dispose() {}
}

final _json = File(SinhalaWordBank.assetPath).readAsStringSync();
final _bank = SinhalaWordBank.fromJson(_json);

/// A bank with just these words, all as warm-up words, in this order.
SinhalaWordBank _bankOf(List<String> ids) {
  final rows = {
    for (final r in jsonDecode(_json) as List) (r as Map)['word_id'] as String: r.cast<String, Object?>(),
  };
  return SinhalaWordBank([
    for (final id in ids) SinhalaWord.fromJson({...rows[id]!, 'role': 'placement'}),
  ]);
}

Future<SinhalaGameController> _newGame(WidgetTester tester, List<String> ids, {SinhalaProgressStore? store}) async {
  final game = SinhalaGameController(
    voice: _SilentVoice(),
    sounds: _SilentSounds(),
    random: math.Random(3),
    loadBank: () async => _bankOf(ids),
    store: store ?? InMemorySinhalaProgressStore(),
    loadClassifier: false, // asset loading never finishes under the fake test clock
  );
  await game.init();
  game
    ..handleAction(SinhalaAction.startPressed)
    ..handleAction(SinhalaAction.skipDemo);
  await tester.pump();
  return game;
}

/// Puts each akshara's letter on the line, then its pillas on it.
void _build(SinhalaGameController game, List<Akshara> aksharas) {
  final s = game.state;
  int free(String text) => s.tiles.firstWhere((t) => t.text == text && !s.isPlaced(t.id)).id;
  for (final a in aksharas) {
    game.handleAction(SinhalaAction.dropOnLine, {'tileId': free(a.base), 'index': s.line.length});
  }
  for (var i = 0; i < aksharas.length; i++) {
    for (final m in aksharas[i].marks) {
      game.handleAction(SinhalaAction.dropOnAkshara, {'tileId': free(m), 'lineIndex': i});
    }
  }
}

Future<void> _finish(SinhalaGameController game, WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 6));
  game.dispose();
}

void main() {
  group('word bank', () {
    test('every word splits into aksharas that join back to the word, and has its picture', () {
      expect(_bank.words.length, 300);
      for (final w in _bank.words) {
        expect(w.aksharaTexts.join(), w.word, reason: w.id);
        expect(File(w.imageAsset!).existsSync(), isTrue, reason: '${w.id} ${w.imageAsset}');
      }
      expect(_bank.placement.length, 10);
      expect(_bank.practiceInOrder.first.stage, 1);
    });

    test('joined pillas are one mark and the written order does not depend on drop order', () {
      final a = Akshara.parse('ව්‍යා');
      expect(a.base, 'ව');
      expect(a.marks, [Akshara.yansaya, 'ා']);
      expect(Akshara.compose('ව', ['ා', Akshara.yansaya]), 'ව්‍යා');
      expect(Akshara.compose('ස', ['ං', 'ි']), 'සිං');
      expect(Akshara.isMark('ූ'), isTrue);
      expect(Akshara.isMark('ප'), isFalse);
    });

    test('the tray has the word\'s letters and pillas plus at most 3 look-alikes', () {
      final w = _bank.words.firstWhere((w) => w.id == 'SI0001'); // පූසා
      final tray = SinhalaGameController.trayFor(w, math.Random(1));
      for (final t in [...w.letters, ...w.marks]) {
        expect(tray, contains(t));
      }
      expect(tray.length - w.letters.length - w.marks.length, inInclusiveRange(1, 3));
      // Letters come first, then pillas.
      final firstMark = tray.indexWhere(Akshara.isMark);
      expect(tray.skip(firstMark).every(Akshara.isMark), isTrue);
    });
  });

  testWidgets('building පූසා letter by letter, pilla by pilla, is right first time', (tester) async {
    final game = await _newGame(tester, ['SI0001']);
    expect(game.state.phase, GamePhase.playing);
    expect(game.state.word.word, 'පූසා');

    _build(game, game.state.word.aksharas);
    expect(game.state.lineTexts, ['පූ', 'සා']);
    game.handleAction(SinhalaAction.checkPressed);
    expect(game.state.feedback, WordFeedback.correct);
    expect(game.state.outcomes.first, WordOutcome.solved);
    await _finish(game, tester);
  });

  testWidgets('a new vowel sign replaces the old one; a pilla can go back to the tray', (tester) async {
    final game = await _newGame(tester, ['SI0001']);
    final s = game.state;
    final pa = s.tiles.firstWhere((t) => t.text == 'ප').id;
    game.handleAction(SinhalaAction.dropOnLine, {'tileId': pa, 'index': 0});
    final aa = s.tiles.firstWhere((t) => t.text == 'ා').id; // ා
    final uu = s.tiles.firstWhere((t) => t.text == 'ූ').id; // ූ
    game.handleAction(SinhalaAction.dropOnAkshara, {'tileId': aa, 'lineIndex': 0});
    expect(s.lineTexts, ['පා']);
    game.handleAction(SinhalaAction.dropOnAkshara, {'tileId': uu, 'lineIndex': 0});
    expect(s.lineTexts, ['පූ']);
    expect(s.isPlaced(aa), isFalse);
    game.handleAction(SinhalaAction.dropOnTray, {'tileId': uu});
    expect(s.lineTexts, ['ප']);
    // Taking the letter off takes its pillas with it.
    game.handleAction(SinhalaAction.dropOnAkshara, {'tileId': uu, 'lineIndex': 0});
    game.handleAction(SinhalaAction.dropOnTray, {'tileId': pa});
    expect(s.line, isEmpty);
    expect(s.isPlaced(uu), isFalse);
    await _finish(game, tester);
  });

  testWidgets('a wrong pilla: right aksharas stay, the wrong one goes back; 3 tries shows the word', (tester) async {
    final game = await _newGame(tester, ['SI0001']);
    final s = game.state;
    // පුසා instead of පූසා: the look-alike pilla ු is in the tray.
    final wrong = [Akshara('ප', const ['ු']), Akshara('ස', const ['ා'])];
    _build(game, wrong);
    expect(s.answer, 'පුසා');
    game.handleAction(SinhalaAction.checkPressed);
    expect(s.feedback, WordFeedback.tryAgain);
    await tester.pump(const Duration(seconds: 1));
    expect(s.lineTexts, ['සා']);

    for (var i = 0; i < 2; i++) {
      game.handleAction(SinhalaAction.checkPressed);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(s.feedback, WordFeedback.revealed);
    expect(s.answer, 'පූසා');
    expect(s.outcomes.first, WordOutcome.revealed);
    await _finish(game, tester);
  });

  testWidgets('tapping a pilla says nothing; tapping a letter says it', (tester) async {
    final game = await _newGame(tester, ['SI0001']);
    final voice = game.voice as _SilentVoice;
    final s = game.state;
    voice.played.clear();
    game.handleAction(SinhalaAction.tapTile, {'tileId': s.tiles.firstWhere((t) => t.isMark).id});
    expect(voice.played, isEmpty);
    game.handleAction(SinhalaAction.tapTile, {'tileId': s.tiles.firstWhere((t) => t.text == 'ප').id});
    expect(voice.played.single, endsWith('/tiles/0DB4.mp3'));
    await _finish(game, tester);
  });

  test('your own .m4a or .wav recording plays instead of the generated mp3', () {
    const mp3 = 'assets/spelling/sinhala/audio/SI0001.mp3';
    expect(SinhalaVoice.recordingFor(mp3, {mp3}), mp3);
    expect(SinhalaVoice.recordingFor(mp3, {mp3, 'assets/spelling/sinhala/audio/SI0001.m4a'}),
        'assets/spelling/sinhala/audio/SI0001.m4a');
    expect(SinhalaVoice.recordingFor(mp3, {'assets/spelling/sinhala/audio/SI0001.wav'}),
        'assets/spelling/sinhala/audio/SI0001.wav');
    expect(SinhalaVoice.recordingFor(mp3, {}), isNull);
  });

  group('mistake checker', () {
    List<Akshara> w(String aksharas) => [for (final a in aksharas.split('|')) Akshara.parse(a)];
    Map<String, int> errors(String target, String answer) =>
        analyzeSinhala(w(target), w(answer)).counts..removeWhere((_, n) => n == 0);

    test('names each kind of Sinhala mistake', () {
      expect(errors('පූ|සා', 'පු|සා'), {SinhalaError.pillaLength: 1}); // ූ → ු
      expect(errors('පූ|සා', 'ප|සා'), {SinhalaError.pillaMissing: 1});
      expect(errors('පූ|සා', 'පා|සා'), {SinhalaError.pillaWrong: 1});
      expect(errors('බ|ත්', 'බ|ත'), {SinhalaError.hal: 1});
      expect(errors('ළ|ම|යා', 'ල|ම|යා'), {SinhalaError.lookalike: 1});
      expect(errors('ළ|ම|යා', 'ක|ම|යා'), {SinhalaError.otherLetter: 1});
      expect(errors('පූ|සා', 'පූ'), {SinhalaError.missing: 1});
      expect(errors('පූ|සා', 'පූ|සා|සා'), {SinhalaError.extra: 1});
      expect(errors('පූ|සා', 'සා|පූ'), {SinhalaError.order: 1});
      expect(errors('පූ|සා', 'පූ|සා'), isEmpty);
    });
  });

  testWidgets('every word is saved; a shown word comes back two rounds later', (tester) async {
    final store = InMemorySinhalaProgressStore();
    final game = await _newGame(tester, ['SI0001'], store: store);
    final s = game.state;
    _build(game, [Akshara('ප', const ['\u0DD4']), Akshara('ස', const ['\u0DCF'])]); // පුසා
    for (var i = 0; i < 3; i++) {
      game.handleAction(SinhalaAction.checkPressed);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(s.feedback, WordFeedback.revealed);
    await tester.pump(const Duration(seconds: 8));

    final saved = await store.load();
    final r = saved.results.single;
    expect(r.wordId, 'SI0001');
    expect(r.correctFirstTry, isFalse);
    expect(r.finalCorrect, isFalse);
    expect(r.firstWrongAnswer, 'පුසා');
    expect(r.errors, {SinhalaError.pillaLength: 1});
    expect(saved.retryDue['SI0001'], 3);
    expect(saved.rounds.single.shown, 1);
    expect(saved.warmUpDone, isTrue);
    // The word's feature row: logged behaviour, mistakes, model before/after, prediction.
    final f = r.features;
    expect(f['mode'], 'placement');
    expect(f['attempts'], 3);
    expect(f['pilla_length'], 1);
    expect(f['n_insertions'], greaterThanOrEqualTo(4));
    expect(f['n_aksharas'], 2);
    expect(f['p_before'], SinhalaLearner.pStart);
    expect(f['clf_source'], 'fallback');
    expect(f.keys, containsAll(sinhalaFeatureColumns));
    // The first game found a weak area, and the next round is already planned.
    expect(SinhalaLearner.isWeak(saved, r.skill), isTrue);
    expect(saved.pendingPlan, isNotEmpty);
    game.dispose();
  });

  group('learner model and word choice', () {
    Map<String, Object?> row(SinhalaWord w, {required bool firstTry, bool solved = true, double hes = 1.0}) => {
          'phonics_skill': w.skill,
          'skill_stage': w.stage,
          'correct_first_try': firstTry,
          'final_correct': firstTry || solved,
          'attempts': firstTry ? 1 : 2,
          'hesitation_ratio': hes,
          'corrections': 0,
          'n_aksharas': w.aksharas.length,
        };

    /// The warm-up with every word right except the stage-[failStage] one.
    SinhalaProgress afterWarmUp(int failStage) {
      final p = SinhalaProgress();
      final rows = [for (final w in _bank.placement) row(w, firstTry: w.stage != failStage, solved: false)];
      for (final f in rows) {
        SinhalaLearner.applyWord(p, f, roundNo: 1, warmUp: true);
      }
      SinhalaLearner.applyPlacement(p, rows, _bank);
      p.warmUpDone = true;
      return p;
    }

    test('the first game (warm-up) finds the weak area', () {
      final failStage = _bank.placement[3].stage;
      final p = afterWarmUp(failStage);
      final weak = _bank.placement[3].skill;
      expect(SinhalaLearner.isWeak(p, weak), isTrue);
      expect(p.skill(weak).pL, 0.15);
      // Earlier stages are assumed known; later untried ones are not open yet.
      expect(p.skill(_bank.placement.first.skill).pL, 0.6);
      final later = _bank.skills.firstWhere((k) => k.stage > failStage && !_bank.placement.any((w) => w.skill == k.id));
      expect(p.unlocked.contains(later.id), isFalse);
      expect(p.skill(later.id).pL, SinhalaLearner.pStart);
    });

    test('the next round focuses on the weak stage, at the level the classifier says', () {
      final p = afterWarmUp(_bank.placement[3].stage);
      final weak = _bank.placement[3].skill;
      final plan = SinhalaSelector.plan(_bank, p);
      expect(plan.kind, 'adaptive');
      expect(plan.focusSkill, weak);
      expect(plan.words, hasLength(10));
      expect(plan.words.where((w) => w.skill == weak).length, greaterThanOrEqualTo(4));
      expect(plan.reason, contains('needs more practice'));

      // Classifier said "hard" → the easiest (difficulty 1) words of that stage first.
      DifficultyPrediction hard() => DifficultyPrediction(
          label: 'hard', probs: const {'easy': 0.1, 'medium': 0.2, 'hard': 0.7}, source: 'ml', at: DateTime(2026));
      p.predictions[weak] = [hard(), hard()];
      final easyFirst = SinhalaSelector.plan(_bank, p).words.firstWhere((w) => w.skill == weak);
      final lowest = _bank.practiceInOrder.where((w) => w.skill == weak).map((w) => w.difficulty).reduce((a, b) => a < b ? a : b);
      expect(easyFirst.difficulty, lowest);
      expect(SinhalaSelector.plan(_bank, p).reason, contains('chosen by the difficulty model'));
    });

    test('a mistake habit adds words that practise it; missed words come back', () {
      final p = afterWarmUp(_bank.placement[3].stage)
        ..errorRates[SinhalaError.pillaLength] = 0.6
        ..retryDue[_bank.practiceInOrder[5].id] = 1;
      final plan = SinhalaSelector.plan(_bank, p);
      expect(plan.words.first.id, _bank.practiceInOrder[5].id);
      expect(plan.words.where((w) => w.marks.any(SinhalaError.lengthPairs.containsKey)), isNotEmpty);
      expect(plan.reason, contains('long pillas'));
      expect(plan.reason, contains('another go at 1 word'));
    });

    test('BKT: a fluent right answer raises the estimate, a miss lowers it', () {
      final w = _bank.practiceInOrder.first;
      final p = SinhalaProgress()..skill(w.skill).pL = 0.5;
      final (b1, a1) = SinhalaLearner.applyWord(p, row(w, firstTry: true, hes: 0.8), roundNo: 2, warmUp: false);
      expect(a1, greaterThan(b1));
      final (b2, a2) = SinhalaLearner.applyWord(p, row(w, firstTry: false, solved: false), roundNo: 2, warmUp: false);
      expect(a2, lessThan(b2));
      expect(SinhalaLearner.evidenceWeight(row(w, firstTry: true, hes: 2.0)), SinhalaLearner.wHesitant);
    });

    test('features: timing, edits and slips from the event log', () {
      final w = _bank.words.firstWhere((w) => w.id == 'SI0001'); // පූසා
      final events = [
        const SpellingEvent(SpellingEventType.audioStart, 0),
        const SpellingEvent(SpellingEventType.audioEnd, 1000),
        const SpellingEvent(SpellingEventType.tilePlace, 3000, {'tile': 'ප', 'index': 0}),
        const SpellingEvent(SpellingEventType.tilePlace, 4000, {'tile': 'ඵ', 'index': 1}), // look-alike
        const SpellingEvent(SpellingEventType.tileRemove, 4500, {'tile': 'ඵ', 'msSincePlaced': 500}), // slip
        const SpellingEvent(SpellingEventType.tilePlace, 6000, {'tile': 'ස', 'index': 1}),
        const SpellingEvent(SpellingEventType.tilePlace, 7000, {'tile': '\u0DD4', 'onAkshara': 0, 'replaced': 0}),
        const SpellingEvent(SpellingEventType.tilePlace, 8000, {'tile': '\u0DD6', 'onAkshara': 0, 'replaced': 1}),
        const SpellingEvent(SpellingEventType.tilePlace, 9000, {'tile': '\u0DCF', 'onAkshara': 1, 'replaced': 0}),
        const SpellingEvent(SpellingEventType.check, 10000, {'answer': 'පූසා', 'correct': true, 'aksharas': 2}),
      ];
      final f = featurizeSinhala(
        events: events, word: w, progress: SinhalaProgress(), sessionId: 's', roundNo: 2, wordIndex: 0,
        mode: 'adaptive', errors: const {});
      expect(f['first_input_ms'], 2000);
      expect(f['total_ms'], 10000);
      expect(f['motor_slips'], 1);
      expect(f['n_replacements'], 1);
      expect(f['corrections'], 1);
      expect(f['distractor_picks'], 2); // ඵ and the short ු
      expect(f['correct_first_try'], isTrue);
      expect(f['hesitation_ratio'], 2000 / SinhalaLearner.defaultMedianMs);
    });
  });

  group('teacher view', () {
    SinhalaWordResult result(SinhalaWord w, {required bool firstTry, String? wrote, Map<String, int>? errors}) =>
        SinhalaWordResult(
          wordId: w.id,
          word: w.word,
          skill: w.skill,
          stage: w.stage,
          roundNo: 1,
          tries: firstTry ? 1 : 2,
          correctFirstTry: firstTry,
          finalCorrect: true,
          at: DateTime(2026, 10, 19),
          firstWrongAnswer: wrote,
          errors: errors,
        );

    /// 4 words of one stage wrong with a long/short pilla mix-up, then 6 right;
    /// the learner model says stage 6 is weak and stage 1 is mastered.
    SinhalaProgress played() {
      final weak = _bank.words.where((w) => w.stage == 6).take(4).toList();
      final good = _bank.words.where((w) => w.stage == 1).take(6).toList();
      return SinhalaProgress(warmUpDone: true, skills: {
        weak.first.skill: SinhalaSkillState(pL: 0.2, seen: 4, rounds: {1}),
        good.first.skill: SinhalaSkillState(pL: 0.92, seen: 6, correct: 6, rounds: {1, 2}),
      }, unlocked: {
        weak.first.skill,
        good.first.skill,
      }, errorRates: {
        SinhalaError.pillaLength: 0.59, // 4 mix-ups in a row
      }, pendingFocus: weak.first.skill, pendingReason: 'Next practice: more words (needs more practice).', results: [
        for (final w in weak) result(w, firstTry: false, wrote: '${w.word}x', errors: {SinhalaError.pillaLength: 1}),
        for (final w in good) result(w, firstTry: true),
      ], rounds: [
        SinhalaRound(
          roundNo: 1,
          sessionId: 'a',
          wordIds: [...weak.map((w) => w.id), ...good.map((w) => w.id)],
          firstTry: 6,
          afterRetry: 4,
          shown: 0,
          finishedAt: DateTime(2026, 10, 19),
        ),
      ]);
    }

    test('weak stage, mistake habit with examples, and no model numbers', () {
      final i = SinhalaInsights(progress: played(), bank: _bank, now: DateTime(2026, 10, 19));
      final weakSkill = _bank.skills.firstWhere((s) => s.stage == 6);
      expect(i.status(weakSkill.id), SkillStatus.needsHelp);
      expect(i.status(_bank.skills.firstWhere((s) => s.stage == 1).id), SkillStatus.mastered);
      expect(i.status(_bank.skills.firstWhere((s) => s.stage == 19).id), SkillStatus.notStarted);
      expect(i.needsHelp.single.sentence, startsWith('${weakSkill.label} — wrote "'));
      expect(i.habits.single.type, SinhalaError.pillaLength);
      expect(i.habits.single.countText, '4 of the last 10 words');
      expect(i.tips.single, contains('Clap'));
      expect(i.roundsPlayed, 1);
      expect(i.lastPlayed, 'today');
      expect(i.stageText, startsWith('Stage '));
      expect(i.nextSentence, startsWith('Next practice:'));
    });

    testWidgets('shows the cards, and "Reset all data" clears everything', (tester) async {
      final store = InMemorySinhalaProgressStore();
      await store.save(played());
      final game = SinhalaGameController(
        voice: _SilentVoice(),
        sounds: _SilentSounds(),
        loadBank: () async => _bank,
        store: store,
        loadClassifier: false,
      );
      await tester.runAsync(game.init);
      await tester.pumpWidget(MaterialApp(home: SinhalaTeacherScreen(controller: game)));
      await tester.pumpAndSettle();

      expect(find.text('Panda'), findsOneWidget);
      expect(find.text('right first time'), findsOneWidget);
      for (final title in ['Needs help with', 'Mistake habits', 'Letters and pillas', 'Progress', 'What\'s next']) {
        await tester.scrollUntilVisible(find.text(title), 200);
        expect(find.text(title), findsOneWidget);
      }
      expect(tester.takeException(), isNull);

      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset all data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pumpAndSettle();
      expect(store.saved, isNull);
      expect(game.progress.results, isEmpty);
      expect(find.textContaining('Nothing played yet'), findsOneWidget);
      game.dispose();
    });
  });

  testWidgets('the longest word fits a narrow phone (360 dp), also with every tile on the line', (tester) async {
    tester.view
      ..physicalSize = const Size(720, 1610)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final game = await _newGame(tester, ['SI0054']); // සිප්පිකටුව: 6 letters + 4 pillas + look-alikes
    Widget view() => MaterialApp(
          home: Scaffold(body: SafeArea(child: SinhalaGameView(state: game.state, act: game.handleAction))),
        );
    await tester.pumpWidget(view());
    await tester.pump();
    expect(tester.takeException(), isNull);
    // Every letter on the line (one too many), with its pillas.
    _build(game, game.state.word.aksharas);
    final extra = game.state.tiles.firstWhere((t) => !t.isMark && !game.state.isPlaced(t.id));
    game.handleAction(SinhalaAction.dropOnLine, {'tileId': extra.id, 'index': 0});
    await tester.pumpWidget(view());
    await tester.pump();
    expect(tester.takeException(), isNull);
    await _finish(game, tester);
  });

  test('a pilla shown on its own gets a dotted circle; pillas on letters do not', () {
    expect(Akshara.showMarks('ඉස්පිල්ල ි'), 'ඉස්පිල්ල ◌ි');
    expect(Akshara.showMarks('ෝ'), '◌ෝ');
    expect(Akshara.showMarks('පූසා'), 'පූසා');
    expect(Akshara.showMarks('ශිෂ්‍යයා'), 'ශිෂ්‍යයා');
    expect(Akshara.showMarks('pillas (ි / ී)'), 'pillas (◌ි / ◌ී)');
  });

  test('every spoken prompt has Sinhala text', () {
    for (final key in [...SinhalaPrompts.praise, 'listen', 'almost', 'try_again', 'together']) {
      expect(SinhalaPrompts.lines[key], isNotEmpty, reason: key);
    }
    expect(SinhalaClip.tileKey(Akshara.yansaya), '0DCA-200D-0DBA');
  });
}
