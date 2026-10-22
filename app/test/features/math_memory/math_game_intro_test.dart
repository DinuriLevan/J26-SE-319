import 'package:akurin/core/db/app_database.dart';
import 'package:akurin/features/math_memory/math_game_selection_screen.dart';
import 'package:akurin/features/math_memory/memory_match/memory_match_screen.dart';
import 'package:akurin/features/math_memory/number_quest/number_quest_screen.dart';
import 'package:akurin/features/math_memory/widgets/kid_intro_view.dart';
import 'package:akurin/features/math_memory/widgets/math_game_intro_scaffold.dart';
import 'package:akurin/features/math_memory/widgets/parent_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Long written text that should only appear with Parent support on.
const _numberQuestText = [
  'Ready for a maths adventure?',
  'Count the objects and solve fun maths questions.',
  'Count the objects',
  'Solve the question',
  'Start Game',
  'How to play',
];

Future<void> toggleParentSupport(WidgetTester tester) async {
  await tester.tap(find.byKey(ParentSupportToggle.switchKey));
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('children see a picture-first page with almost no words', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestScreen()));

    expect(find.byType(KidIntroView), findsOneWidget);
    for (final text in _numberQuestText) {
      expect(find.text(text), findsNothing, reason: '"$text" is for parents');
    }
    // The only words: the title, "Play" and step numbers.
    expect(find.text('Play'), findsOneWidget);
    expect(find.byKey(ParentSupportToggle.switchKey), findsOneWidget);
    expect(find.byKey(MathGameIntroScaffold.startGameKey), findsOneWidget);
    expect(find.byKey(MathGameIntroScaffold.howToPlayKey), findsOneWidget);
  });

  testWidgets('the whole child page fits on a small phone without scrolling', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestScreen()));

    final playBottom = tester.getBottomLeft(find.byKey(MathGameIntroScaffold.startGameKey)).dy;
    expect(playBottom, lessThanOrEqualTo(640));
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers still hear the instructions', (tester) async {
    usePhoneScreen(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildMathTestApp(db: db, home: const MemoryMatchScreen()));

    expect(find.bySemanticsLabel('Step 1: Look at the pictures'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 3: Find the right card'), findsOneWidget);
    expect(find.bySemanticsLabel('Start Game'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Can you remember them all?')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('picture steps react when tapped', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestScreen()));

    final tile = find.byType(BounceOnTap).at(1);
    await tester.tap(tile);
    await tester.pump(); // the bounce starts on the next frame
    await tester.pump(const Duration(milliseconds: 140));
    final scale = tester.widget<ScaleTransition>(
      find.descendant(of: tile, matching: find.byType(ScaleTransition)).first,
    );
    expect(scale.scale.value, greaterThan(1.0));
    await tester.pumpAndSettle();
    expect(scale.scale.value, 1.0);
  });

  testWidgets('Parent support shows the written instructions and hides them again', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestScreen()));

    await toggleParentSupport(tester);
    expect(find.byType(KidIntroView), findsNothing);
    for (final text in _numberQuestText) {
      await tester.ensureVisible(find.text(text).first);
      expect(find.text(text), findsWidgets);
    }

    await toggleParentSupport(tester);
    expect(find.byType(KidIntroView), findsOneWidget);
    expect(find.text('Ready for a maths adventure?'), findsNothing);
  });

  testWidgets('the setting is shared by both games', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const MathGameSelectionScreen()));

    await tester.tap(find.text('Play Now').first);
    await tester.pumpAndSettle();
    await toggleParentSupport(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Look carefully, remember and match!'));
    await tester.tap(find.text('Look carefully, remember and match!'));
    await tester.pumpAndSettle();
    expect(find.text('Look at the pictures and remember where they are.'), findsOneWidget);
  });

  for (final parent in [false, true]) {
    testWidgets('Play and "?" open the tutorial (parent support: $parent)', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(buildMathTestApp(db: db, home: const MemoryMatchScreen()));
      if (parent) await toggleParentSupport(tester);

      await tester.ensureVisible(find.byKey(MathGameIntroScaffold.howToPlayKey));
      await tester.tap(find.byKey(MathGameIntroScaffold.howToPlayKey));
      await tester.pumpAndSettle();
      expect(tutorialScreen('Memory Match'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byKey(MathGameIntroScaffold.startGameKey));
      await tester.tap(find.byKey(MathGameIntroScaffold.startGameKey));
      await settleDb(tester);
      expect(tutorialScreen('Memory Match'), findsOneWidget, reason: 'first visit');
    });
  }
}
