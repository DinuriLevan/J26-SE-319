import 'dart:math' as math;

import 'package:akurin/features/spelling/data/spelling_storage.dart';
import 'package:akurin/features/spelling/engine/event_logger.dart';
import 'package:akurin/features/spelling/engine/learner_model.dart';
import 'package:akurin/features/spelling/engine/spelling_engine.dart';
import 'package:akurin/features/spelling/game/spelling_game_controller.dart';
import 'package:akurin/features/spelling/teacher/teacher_insights.dart';
import 'package:akurin/features/spelling/teacher/teacher_view_screen.dart';
import 'package:akurin/features/spelling/ui/round_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'spelling_test_helpers.dart';

void main() {
  final bank = loadTestBank();

  /// Events where the child first writes [wrong], then gets it right.
  List<SpellingEvent> wrongThenRight(String word, String wrong) {
    final events = quickCorrectEvents(bank.entries.firstWhere((w) => w.spelling == word));
    final check = events.removeLast();
    return [
      ...events,
      SpellingEvent(SpellingEventType.check, check.t, {'answer': wrong, 'correct': false, 'attemptNo': 1}),
      SpellingEvent(SpellingEventType.check, check.t + 2000, {'answer': word, 'correct': true, 'attemptNo': 2}),
    ];
  }

  /// Plays [rounds] rounds; every "sh" word is first spelled with "s" only.
  Future<SpellingEngine> engineWithRounds(int rounds) async {
    final engine = SpellingEngine(bank: bank, storage: InMemorySpellingStorage(), random: math.Random(4));
    final child = await engine.createChild('🐼');
    engine.selectChild(child);
    for (var r = 0; r < rounds; r++) {
      final plan = engine.startRound();
      for (var i = 0; i < plan.words.length; i++) {
        final w = plan.words[i];
        final events = w.phonicsSkill == 'digraph_sh'
            ? wrongThenRight(w.spelling, w.spelling.replaceFirst('sh', 'ss'))
            : quickCorrectEvents(w);
        await engine.recordWord(word: w, wordIndex: i, events: events);
      }
      await engine.finishRound();
    }
    return engine;
  }

  group('teacher insights', () {
    test('weak skill with real wrong answers, plain sentences, and sounds still to come', () async {
      final engine = await engineWithRounds(4);
      final child = engine.child!;
      final rows = await engine.storage.loadRows(childId: child.childId);
      final i = TeacherInsights(child: child, rows: rows, bank: bank, next: engine.previewNext(child));

      expect(i.needsHelp.map((n) => n.skill), contains('digraph_sh'));
      final sh = i.needsHelp.firstWhere((n) => n.skill == 'digraph_sh');
      expect(sh.sentence, startsWith('"sh" sound (ship, fish) — wrote "'));
      expect(i.status('vowel_igh'), SkillStatus.notStarted);
      expect(i.skillsWith(SkillStatus.needsHelp), contains('digraph_sh'));
      // The round breakdown adds up, and sh words (right only on the second
      // try) count as "after another try", not first time.
      final b = i.latest!;
      expect(b.firstTry + b.afterRetry + b.shown, b.total);
      expect(child.rounds.any((r) => RoundBreakdown(r).afterRetry > 0), isTrue);
      expect(i.progress.last.$2, b.firstTry);
      expect(i.sessionsPlayed, 1);
      expect(i.lastPlayed, 'today');
      expect(i.progress.length, 4);
      expect(i.stageText, startsWith('Stage '));
      expect(i.nextSentence, startsWith('Next practice:'));
      // Nothing model-ish leaks into the teacher sentences.
      final all = [...i.needsHelp.map((n) => n.sentence), i.nextSentence, i.stageText, ...i.tips].join(' ');
      expect(all, isNot(matches(RegExp(r'\d\.\d|P\(L\)|BKT'))));
    });

    test('a mistake habit needs rate > 0.3 AND at least 3 occurrences', () {
      final child = ChildModel.create(childId: 'h', avatar: '🐶', bank: bank)..errorRates['reversal'] = 0.5;
      final bed = bank.byId['EN0025']!;
      final two = [for (var k = 0; k < 2; k++) fakeRow(bed, correctFirstTry: false, errors: {'reversal': 1})];
      final next = engineFor(bank).selector.placement();
      expect(TeacherInsights(child: child, rows: two, bank: bank, next: next).habits, isEmpty);
      final three = [...two, fakeRow(bed, correctFirstTry: false, errors: {'reversal': 1}), fakeRow(bed)];
      final habits = TeacherInsights(child: child, rows: three, bank: bank, next: next).habits;
      expect(habits.single.sentence, 'Often mixes up b and d (or p and q)');
      expect(habits.single.countText, '3 of the last 4 words');
    });
  });

  testWidgets('teacher view shows plain cards and no model numbers', (tester) async {
    final engine = (await tester.runAsync(() => engineWithRounds(3)))!;
    await tester.pumpWidget(MaterialApp(home: TeacherViewScreen(engine: engine)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(find.text('Panda'), findsOneWidget);
    expect(find.text('Latest round'), findsOneWidget);
    expect(find.text('right first time'), findsOneWidget);
    expect(find.text('answer shown'), findsOneWidget);
    expect(find.textContaining('correct'), findsNothing);
    expect(find.text('Needs help with'), findsOneWidget);
    for (final title in ['Mistake habits', 'Sounds', 'Progress', 'What\'s next']) {
      await tester.scrollUntilVisible(find.text(title), 200);
      expect(find.text(title), findsOneWidget);
    }
    expect(find.textContaining('Not checked'), findsNothing);
    expect(find.textContaining('P(L)'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the menu has the report and the training data exports', (tester) async {
    final engine = (await tester.runAsync(() => engineWithRounds(1)))!;
    await tester.pumpWidget(MaterialApp(home: TeacherViewScreen(engine: engine)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    for (final item in ['Download report', 'Word data (CSV)', 'Model state (JSON)', 'Tap log (JSON)', 'Reset all data']) {
      expect(find.text(item), findsOneWidget);
    }
  });

  testWidgets('"Reset all data" asks first, then deletes everything', (tester) async {
    final engine = (await tester.runAsync(() => engineWithRounds(1)))!;
    final storage = engine.storage as InMemorySpellingStorage;
    await tester.pumpWidget(MaterialApp(home: TeacherViewScreen(engine: engine)));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset all data'));
    await tester.pumpAndSettle();
    expect(find.text('Reset all data?'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();

    expect(engine.children, isEmpty);
    expect(engine.child, isNull);
    expect(storage.rows, isEmpty);
    expect(storage.events, isEmpty);
    expect(find.textContaining('Nothing played yet'), findsOneWidget);
  });

  test('one phone = one child: the same child every time, made on first play', () async {
    final engine = engineFor(bank);
    final first = await engine.deviceChild();
    expect(engine.children, [first]);
    expect(await engine.deviceChild(), same(first));
    // Accounts later: a given id is used (and made if new).
    final account = await engine.deviceChild(childId: 'profile-42');
    expect(account.childId, 'profile-42');
    expect(await engine.deviceChild(childId: 'profile-42'), same(account));
  });

  testWidgets('round-end screen has ▶ and a "See progress" button', (tester) async {
    var opened = false;
    final state = SpellingGameState()
      ..outcomes = List.filled(10, WordOutcome.solved)
      ..phase = GamePhase.roundEnd;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: RoundEndView(state: state, act: (_, [__ = const {}]) {}, onTeacher: () => opened = true),
      ),
    ));
    await tester.tap(find.text('👩‍🏫  See progress'));
    expect(opened, isTrue);
    expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
  });
}

SpellingEngine engineFor(bank) => SpellingEngine(bank: bank, storage: InMemorySpellingStorage());
