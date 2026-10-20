import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/handwriting/english_handwriting_screen.dart';
import 'package:akurin/features/handwriting/screens/character_demonstration_screen.dart';
import 'package:akurin/features/handwriting/screens/english_handwriting_result_screen.dart';
import 'package:akurin/features/handwriting/screens/handwriting_practice_screen.dart';
import 'package:akurin/features/handwriting/sinhala_handwriting_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(Widget screen) {
    return MaterialApp(theme: AppTheme.light, home: screen);
  }

  testWidgets('English screen contains uppercase and lowercase A to Z', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(const EnglishHandwritingScreen()));

    expect(find.text('Uppercase'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
    expect(find.text('Z'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Lowercase'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Lowercase'), findsOneWidget);
    expect(find.text('a'), findsOneWidget);
    expect(find.text('z'), findsOneWidget);
  });

  testWidgets('Sinhala screen contains only the supplied letter set', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(const SinhalaHandwritingScreen()));

    expect(find.text('ස්වර (Vowels)'), findsOneWidget);
    expect(find.text('අ'), findsOneWidget);
    expect(find.text('ඕ'), findsOneWidget);
    expect(find.text('ඍ'), findsNothing);

    await tester.scrollUntilVisible(
      find.text('ව්‍යංජන (Consonants)'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('ව්‍යංජන (Consonants)'), findsOneWidget);
    expect(find.text('ක'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ෂ'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ෂ'), findsOneWidget);
    expect(find.text('ළ'), findsOneWidget);
    for (final removedCharacter in ['ඛ', 'ඝ', 'ඡ', 'ඨ', 'ඵ', 'භ', 'ඹ']) {
      expect(find.text(removedCharacter), findsNothing);
    }
    expect(find.text('ඟ'), findsNothing);
    expect(find.text('ෆ'), findsNothing);
  });

  testWidgets('Next Letter advances without mixing English letter case', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    Future<void> verifyNext({
      required String current,
      required String next,
      required int section,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey('next-flow-$current'),
          theme: AppTheme.light,
          home: const EnglishHandwritingScreen(),
        ),
      );
      final tile = find.byKey(ValueKey('character-$section-$current'));
      await tester.tap(tile);
      await tester.pumpAndSettle();
      await tester.tap(find.text('My Turn!'));
      await tester.pumpAndSettle();
      expect(find.byType(HandwritingPracticeScreen), findsOneWidget);

      Navigator.of(
        tester.element(find.byType(HandwritingPracticeScreen)),
      ).pop(EnglishHandwritingResultAction.nextLetter);
      await tester.pumpAndSettle();

      expect(find.byType(CharacterDemonstrationScreen), findsOneWidget);
      expect(find.text('Let’s learn $next'), findsOneWidget);

      Navigator.of(
        tester.element(find.byType(CharacterDemonstrationScreen)),
      ).pop();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    }

    await verifyNext(current: 'A', next: 'B', section: 0);
    await verifyNext(current: 'a', next: 'b', section: 1);
  });

  testWidgets('Back to Letters returns to the English selection screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject(const EnglishHandwritingScreen()));
    await tester.tap(find.byKey(const ValueKey('character-0-A')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Turn!'));
    await tester.pumpAndSettle();

    Navigator.of(
      tester.element(find.byType(HandwritingPracticeScreen)),
    ).pop(EnglishHandwritingResultAction.backToLetters);
    await tester.pumpAndSettle();

    expect(find.text('English Handwriting'), findsOneWidget);
    expect(find.text('Pick a Letter!'), findsOneWidget);
    expect(find.byType(CharacterDemonstrationScreen), findsNothing);
    expect(find.byType(HandwritingPracticeScreen), findsNothing);
  });

  testWidgets('Next Letter after Z returns safely to letter selection', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject(const EnglishHandwritingScreen()));
    final zTile = find.byKey(const ValueKey('character-0-Z'));
    await tester.tap(zTile);
    await tester.pumpAndSettle();
    await tester.tap(find.text('My Turn!'));
    await tester.pumpAndSettle();

    Navigator.of(
      tester.element(find.byType(HandwritingPracticeScreen)),
    ).pop(EnglishHandwritingResultAction.nextLetter);
    await tester.pumpAndSettle();

    expect(find.text('English Handwriting'), findsOneWidget);
    expect(find.text('Pick a Letter!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
