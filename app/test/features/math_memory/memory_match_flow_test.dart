import 'dart:convert';

import 'package:akurin/core/db/app_database.dart';
import 'package:akurin/features/math_memory/memory_match/engine/memory_match_models.dart';
import 'package:akurin/features/math_memory/memory_match/memory_match_game_screen.dart';
import 'package:akurin/features/math_memory/memory_match/memory_match_screen.dart';
import 'package:akurin/features/math_memory/memory_match/widgets/memory_board.dart';
import 'package:akurin/features/math_memory/widgets/reward_art.dart';
import 'package:akurin/features/math_memory/widgets/math_game_intro_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

MemoryBoard board(WidgetTester tester) => tester.widget<MemoryBoard>(find.byType(MemoryBoard));

Finder card(int number) => find.byKey(ValueKey('memory-card-$number'));

/// Plays one round: wait for the pictures to hide, pick the right card.
Future<void> playRound(WidgetTester tester) async {
  final round = board(tester).round;
  await tester.pump(Duration(seconds: round.config.memorizeSeconds));
  await tester.pump();
  await tester.ensureVisible(card(round.targetNumber));
  await tester.tap(card(round.targetNumber));
  await tester.pump();
  final next = find.text('Next').evaluate().isNotEmpty ? find.text('Next') : find.text('Finish');
  await tester.ensureVisible(next);
  await tester.tap(next);
  await settleDb(tester);
}

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('first visit opens the Memory Match tutorial', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const MemoryMatchScreen()));
    await tester.ensureVisible(find.byKey(MathGameIntroScaffold.startGameKey));
    await tester.tap(find.byKey(MathGameIntroScaffold.startGameKey));
    await settleDb(tester);
    expect(tutorialScreen('Memory Match'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
  });

  testWidgets('shows pictures, hides them as numbered cards, checks the original position', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const MemoryMatchGameScreen()));
    await settleDb(tester);

    expect(find.text(MemoryMatchGameScreen.memorizeInstruction), findsOneWidget);
    expect(find.text('Round 1 of 6'), findsOneWidget);
    final round = board(tester).round;
    expect(card(1), findsNothing, reason: 'pictures are face-up while memorizing');

    // The look timer hides them.
    await tester.pump(Duration(seconds: round.config.memorizeSeconds));
    await tester.pump(const Duration(milliseconds: 400));
    for (var n = 1; n <= round.config.positions; n++) {
      expect(card(n), findsOneWidget);
    }
    expect(find.text('Where was the ${round.target.label}?'), findsOneWidget);

    // A wrong card: supportive hint, card can't be tapped again.
    final wrong = round.activeCells.map(round.numberFor).firstWhere((n) => n != round.targetNumber)!;
    await tester.tap(card(wrong));
    await tester.pump();
    expect(find.text('Good try! Try again.'), findsOneWidget);
    await tester.tap(card(wrong));
    await tester.pump();
    expect(find.text('Good try! Try again.'), findsOneWidget);

    // The right card.
    await tester.tap(card(round.targetNumber));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('The ${round.target.label} was on card ${round.targetNumber}.'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
  });

  testWidgets("I'm ready! hides the pictures early", (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const MemoryMatchGameScreen()));
    await settleDb(tester);

    await tester.tap(find.text("I'm ready!"));
    await tester.pump(const Duration(milliseconds: 400));
    expect(card(1), findsOneWidget);
    expect(find.text("I'm ready!"), findsNothing);
  });

  testWidgets('baseline then scored attempt, each saved and queued', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const MemoryMatchGameScreen()));
    await settleDb(tester);

    for (var i = 0; i < 6; i++) {
      expect(find.text('Round ${i + 1} of 6'), findsOneWidget);
      await playRound(tester);
    }
    expect(find.text('Great exploring!'), findsOneWidget);
    expect(find.byType(StarRatingView), findsNothing);
    expect(find.textContaining('%'), findsNothing);

    // The bundled model (loaded from app assets, offline) chose the next setup.
    final baselineRow = (await tester.runAsync(() => db.pendingActivityResultDao.getUnsynced()))!.single;
    final nextAttempt = jsonDecode(baselineRow.resultPayload)['next_attempt'] as Map<String, dynamic>;
    expect(nextAttempt['source'], 'model');
    expect(nextAttempt['model_id'], 'memory_match_next_config');
    expect(nextAttempt['model_version'], '1.0.0');
    final predicted = MemoryConfig.fromJson((nextAttempt['next_configuration'] as Map).cast());

    await tester.tap(find.text('Play Again'));
    await settleDb(tester);
    // …and the second attempt starts with exactly that setup.
    expect(board(tester).round.config, predicted);
    for (var i = 0; i < 6; i++) {
      await playRound(tester);
    }
    expect(find.byType(StarRatingView), findsOneWidget);
    expect(find.text('Correct recalls'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('Amazing memory!'), findsOneWidget);

    final rows = (await tester.runAsync(() => db.pendingActivityResultDao.getUnsynced()))!;
    expect(rows.map((r) => r.activityId), ['memory_match', 'memory_match']);
    expect(
      rows.map((r) => jsonDecode(r.resultPayload)['attempt_type']),
      ['baseline', 'scored'],
    );
    expect(jsonDecode(rows.last.resultPayload)['next_attempt']['source'], 'model');
  });

  testWidgets('if the model fails, the game still works and records the fallback', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(
      db: db,
      home: const MemoryMatchGameScreen(),
      modelLoader: (_) async => throw const FormatException('broken artifact'),
    ));
    await settleDb(tester);

    for (var i = 0; i < 6; i++) {
      await playRound(tester);
    }
    expect(find.text('Great exploring!'), findsOneWidget);

    final row = (await tester.runAsync(() => db.pendingActivityResultDao.getUnsynced()))!.single;
    final nextAttempt = jsonDecode(row.resultPayload)['next_attempt'] as Map<String, dynamic>;
    expect(nextAttempt['source'], 'fallback');
    expect(nextAttempt['fallback_engine'], 'rules_v1');
    expect(nextAttempt['fallback_reason'], contains('broken artifact'));

    final progress = (await tester.runAsync(() => db.localLearnerProgressDao.getProgressData(testChildId, 'memory_match')))!;
    expect(jsonDecode(progress)['completed_attempts'], 1);
  });
}
