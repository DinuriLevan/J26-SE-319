import 'package:akurin/core/db/app_database.dart';
import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/math_memory/math_game_selection_screen.dart';
import 'package:akurin/features/math_memory/widgets/math_game_intro_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart' show buildMathTestApp, createTestDatabase, settleDb, tutorialScreen;

void main() {
  // A typical low-cost Android phone: 360x640 dp.
  void usePhoneScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);
  }

  Widget buildSubject() {
    return ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light,
        home: const MathGameSelectionScreen(),
      ),
    );
  }

  testWidgets('shows the header and both game cards', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildSubject());

    expect(find.text("Let's Play & Learn!"), findsOneWidget);
    expect(find.text('Choose a game and have fun learning!'), findsOneWidget);

    expect(find.text('Number Quest'), findsOneWidget);
    expect(find.text('Count, solve and collect stars!'), findsOneWidget);
    expect(find.text('Maths Adventure'), findsOneWidget);

    expect(find.text('Memory Match'), findsOneWidget);
    expect(find.text('Look carefully, remember and match!'), findsOneWidget);
    expect(find.text('Brain & Memory'), findsOneWidget);

    expect(find.text('Play Now'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('stacks the cards vertically on a phone', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildSubject());

    expect(
      tester.getTopLeft(find.text('Memory Match')).dy,
      greaterThan(tester.getBottomLeft(find.text('Number Quest')).dy),
    );
  });

  testWidgets('places the cards side by side on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildSubject());

    expect(
      tester.getTopLeft(find.text('Memory Match')).dx,
      greaterThan(tester.getTopRight(find.text('Number Quest')).dx),
    );
  });

  testWidgets('exposes each card as one accessible button', (tester) async {
    usePhoneScreen(tester);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(buildSubject());

    expect(
      find.bySemanticsLabel('Play Number Quest. Count, solve and collect stars!'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Play Memory Match. Look carefully, remember and match!'),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('Play Now opens Number Quest and back returns', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('Play Now').first);
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Number Quest'), findsOneWidget);
    expect(find.text('Count the objects and solve fun maths questions.'), findsNothing,
        reason: 'children see the picture version');
    expect(find.byKey(MathGameIntroScaffold.startGameKey), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text("Let's Play & Learn!"), findsOneWidget);
    expect(find.byKey(MathGameIntroScaffold.startGameKey), findsNothing);
  });

  testWidgets('tapping the Memory Match card opens it and back returns', (tester) async {
    usePhoneScreen(tester);
    await tester.pumpWidget(buildSubject());

    await tester.ensureVisible(find.text('Look carefully, remember and match!'));
    await tester.tap(find.text('Look carefully, remember and match!'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(AppBar, 'Memory Match'), findsOneWidget);
    expect(find.text('Look at the pictures and remember where they are.'), findsNothing,
        reason: 'children see the picture version');
    expect(find.byKey(MathGameIntroScaffold.startGameKey), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text("Let's Play & Learn!"), findsOneWidget);
  });

  group('Start Game', () {
    late AppDatabase db;

    setUp(() => db = createTestDatabase());
    tearDown(() => db.close());

    testWidgets('is no longer a placeholder: it opens each game', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(buildMathTestApp(db: db, home: const MathGameSelectionScreen()));

      await tester.tap(find.text('Play Now').first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(MathGameIntroScaffold.startGameKey));
      await tester.tap(find.byKey(MathGameIntroScaffold.startGameKey));
      await settleDb(tester);

      expect(find.textContaining('coming soon'), findsNothing);
      expect(tutorialScreen('Number Quest'), findsOneWidget);
    });

    testWidgets('How to play reopens the tutorial any time', (tester) async {
      usePhoneScreen(tester);
      await tester.pumpWidget(buildMathTestApp(db: db, home: const MathGameSelectionScreen()));

      await tester.ensureVisible(find.text('Look carefully, remember and match!'));
      await tester.tap(find.text('Look carefully, remember and match!'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(MathGameIntroScaffold.howToPlayKey));
      await tester.tap(find.byKey(MathGameIntroScaffold.howToPlayKey));
      await tester.pumpAndSettle();

      expect(tutorialScreen('Memory Match'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(MathGameIntroScaffold.startGameKey), findsOneWidget);
    });
  });
}
