import 'dart:convert';

import 'package:akurin/core/db/app_database.dart';
import 'package:akurin/features/math_memory/number_quest/number_quest_screen.dart';
import 'package:akurin/features/math_memory/number_quest/widgets/answer_choice_button.dart';
import 'package:akurin/features/math_memory/widgets/game_progress_header.dart';
import 'package:akurin/features/math_memory/widgets/reward_art.dart';
import 'package:akurin/features/math_memory/widgets/math_game_intro_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Answers the current question (any answer) and moves on.
Future<void> answerAndContinue(WidgetTester tester) async {
  for (var tries = 0; tries < 2; tries++) {
    final enabled = find.byWidgetPredicate((w) => w is AnswerChoiceButton && w.onTap != null);
    if (enabled.evaluate().isEmpty) break;
    await tester.ensureVisible(enabled.first);
    await tester.tap(enabled.first);
    await tester.pump();
    if (find.text('Next').evaluate().isNotEmpty || find.text('Finish').evaluate().isNotEmpty) break;
  }
  final next = find.text('Next').evaluate().isNotEmpty ? find.text('Next') : find.text('Finish');
  await tester.ensureVisible(next);
  await tester.tap(next);
  await settleDb(tester);
}

Future<void> playQuestions(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    expect(find.text('Question ${i + 1} of $count'), findsOneWidget);
    await answerAndContinue(tester);
  }
}

Future<List<PendingActivityResult>> pending(WidgetTester tester, AppDatabase db) async =>
    (await tester.runAsync(() => db.pendingActivityResultDao.getUnsynced()))!;

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('first visit: tutorial, practice, ungraded baseline, then a scored attempt', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestScreen()));

    // Tutorial on first visit.
    await tester.ensureVisible(find.byKey(MathGameIntroScaffold.startGameKey));
    await tester.tap(find.byKey(MathGameIntroScaffold.startGameKey));
    await settleDb(tester);
    expect(tutorialScreen('Number Quest'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('3 of 3'), findsOneWidget);

    // Practice: a wrong then right answer. Not recorded anywhere.
    await tester.ensureVisible(find.byKey(const ValueKey('practice-2')));
    await tester.tap(find.byKey(const ValueKey('practice-2')));
    await tester.pump();
    expect(find.text('Good try! Try again.'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-3')));
    await tester.pump();
    expect(find.text('Great job!'), findsOneWidget);
    expect(await pending(tester, db), isEmpty);

    await tester.tap(find.text("Let's Play!"));
    await settleDb(tester);

    // Baseline: no points shown while playing.
    expect(find.text('Question 1 of 10'), findsOneWidget);
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    await playQuestions(tester, 10);

    // Baseline completion: no score, percentage or stars.
    expect(find.text('Great exploring!'), findsOneWidget);
    expect(find.text("Let's find the activities that suit you."), findsOneWidget);
    expect(find.byType(StarRatingView), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    expect(find.text('Points'), findsNothing);

    final afterBaseline = await pending(tester, db);
    expect(afterBaseline, hasLength(1));
    expect(jsonDecode(afterBaseline.single.resultPayload)['attempt_type'], 'baseline');

    // Second attempt: no tutorial, scored, with stars at the end.
    await tester.tap(find.text('Play Again'));
    await settleDb(tester);
    expect(find.text('Question 1 of 10'), findsOneWidget);
    expect(find.descendant(of: find.byType(GameProgressHeader), matching: find.text('0')), findsOneWidget,
        reason: 'points pill');
    await playQuestions(tester, 10);

    expect(find.byType(StarRatingView), findsOneWidget);
    expect(find.text('Correct answers'), findsOneWidget);
    expect(find.textContaining('%'), findsOneWidget);
    expect(find.text('Points'), findsOneWidget);
    expect(find.text('Play Again'), findsOneWidget);
    expect(find.text('Back to Games'), findsOneWidget);

    final all = await pending(tester, db);
    expect(all, hasLength(2));
    final scored = jsonDecode(all.last.resultPayload) as Map<String, dynamic>;
    expect(scored['attempt_type'], 'scored');
    expect(scored['attempt_number'], 2);
    expect(scored['score'], isNotNull);
    // Both attempts' next-attempt levels came from the bundled model.
    for (final row in all) {
      final next = jsonDecode(row.resultPayload)['next_attempt'] as Map<String, dynamic>;
      expect(next['source'], 'model');
      expect(next['model_id'], 'number_quest_next_level');
      expect(next['model_version'], '1.0.0');
      expect((next['skills'] as Map).keys, containsAll(['counting', 'division']));
    }
    final saved = jsonDecode((await tester.runAsync<String?>(
      () => db.localLearnerProgressDao.getProgressData(testChildId, 'number_quest'),
    ))!) as Map<String, dynamic>;
    final predictedLevels = {
      for (final e in (jsonDecode(all.last.resultPayload)['next_attempt']['skills'] as Map).entries)
        e.key: e.value['next_level'],
    };
    expect({for (final e in (saved['skills'] as Map).entries) e.key: e.value['level']}, predictedLevels);
    // The baseline row is untouched by the scored attempt.
    expect(jsonDecode(all.first.resultPayload)['score'], isNull);
  });

  testWidgets('leaving mid-attempt does not count as the baseline', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestScreen()));

    await tester.ensureVisible(find.byKey(MathGameIntroScaffold.howToPlayKey));
    await tester.tap(find.byKey(MathGameIntroScaffold.howToPlayKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Let's Play!"));
    await settleDb(tester);

    await answerAndContinue(tester);
    await answerAndContinue(tester);

    await tester.tap(find.byTooltip('Stop playing'));
    await tester.pumpAndSettle();
    expect(find.text('Stop playing?'), findsOneWidget);
    await tester.tap(find.text('Keep Playing'));
    await tester.pumpAndSettle();
    expect(find.text('Question 3 of 10'), findsOneWidget);

    await tester.tap(find.byTooltip('Stop playing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop'));
    await settleDb(tester);
    expect(find.byKey(MathGameIntroScaffold.startGameKey), findsOneWidget);

    final rows = await pending(tester, db);
    expect(rows, hasLength(1));
    expect(jsonDecode(rows.single.resultPayload)['completion_status'], 'abandoned');

    // Starting again goes straight to the game (tutorial seen) and is still the baseline.
    await tester.ensureVisible(find.byKey(MathGameIntroScaffold.startGameKey));
    await tester.tap(find.byKey(MathGameIntroScaffold.startGameKey));
    await settleDb(tester);
    expect(find.text('Question 1 of 10'), findsOneWidget);
    expect(find.descendant(of: find.byType(GameProgressHeader), matching: find.text('0')), findsNothing,
        reason: 'baseline shows no points');
  });
}
