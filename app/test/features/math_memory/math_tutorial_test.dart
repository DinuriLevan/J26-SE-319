import 'package:akurin/core/db/app_database.dart';
import 'package:akurin/features/math_memory/memory_match/memory_match_tutorial_screen.dart';
import 'package:akurin/features/math_memory/number_quest/number_quest_tutorial_screen.dart';
import 'package:akurin/features/math_memory/widgets/math_pictures.dart';
import 'package:akurin/features/math_memory/widgets/parent_support.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// The Samsung A54 used for testing: 411 × 891 dp.
void useMidRangePhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

const _instructions = [
  'Look at the pictures and count.',
  'Tap the right number.',
  'Now you try!',
];

Future<void> next(WidgetTester tester) async {
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
}

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  testWidgets('child mode: pictures and icons instead of written instructions', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestTutorialScreen()));

    final icons = [Icons.visibility_rounded, Icons.touch_app_rounded, Icons.waving_hand_rounded];
    for (var i = 0; i < 3; i++) {
      for (final text in _instructions) {
        expect(find.text(text), findsNothing, reason: '"$text" is for parents');
      }
      expect(find.byIcon(icons[i]), findsWidgets);
      if (i < 2) await next(tester);
    }
    // Practice: no question sentence, and feedback is a short title only.
    expect(find.text('How many in all?'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('practice-2')));
    await tester.pump();
    expect(find.text('Good try! Try again.'), findsOneWidget);
    expect(find.text('Count all the stars together.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('screen readers still hear each instruction', (tester) async {
    usePhoneScreen(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestTutorialScreen()));

    expect(find.bySemanticsLabel('Look at the pictures and count.'), findsOneWidget);
    expect(find.bySemanticsLabel('How to play Number Quest'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('parent support shows the written instructions', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestTutorialScreen()));

    await tester.tap(find.byKey(ParentSupportToggle.switchKey));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      expect(find.text(_instructions[i]), findsOneWidget);
      if (i < 2) await next(tester);
    }
    expect(find.text('How many in all?'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-2')));
    await tester.pump();
    expect(find.text('Count all the stars together.'), findsOneWidget);
  });

  testWidgets('pictures are scaled up to fill the screen on a bigger phone', (tester) async {
    useMidRangePhone(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestTutorialScreen()));

    // On-screen size (getSize would ignore the scaling).
    final first = find.byType(MathPictureView).first;
    final apple = tester.getBottomRight(first) - tester.getTopLeft(first);
    expect(apple.dx, greaterThan(44 * 1.2), reason: 'apples are drawn at 44 dp and scaled up');
    // The picture card sits in the middle of the free space.
    final card = tester.getCenter(find.byType(MathPictureView).first);
    expect(card.dy, greaterThan(150));
  });

  testWidgets('Back is an arrow button and works; Next becomes Let\'s Play!', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const NumberQuestTutorialScreen()));

    expect(find.text('1 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous')); // disabled on the first step
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);

    await next(tester);
    expect(find.text('2 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);

    await next(tester);
    await next(tester);
    expect(find.text("Let's Play!"), findsOneWidget);
    expect(find.text('Next'), findsNothing);
  });

  testWidgets('Memory Match practice works in child mode with no sentences', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildMathTestApp(db: db, home: const MemoryMatchTutorialScreen()));
    await next(tester);
    await next(tester);

    expect(find.text('Hide'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('practice-hide')));
    await tester.pumpAndSettle();
    expect(find.text('Where was the apple?'), findsNothing);
    expect(find.byIcon(Icons.question_mark_rounded), findsOneWidget);

    // The apple is card 2.
    await tester.tap(find.byKey(const ValueKey('memory-card-2')));
    await tester.pumpAndSettle();
    expect(find.text('Great job!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
