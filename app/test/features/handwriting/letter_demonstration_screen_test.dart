import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/handwriting/data/sinhala_strokes.dart';
import 'package:akurin/features/handwriting/english_handwriting_screen.dart';
import 'package:akurin/features/handwriting/models/character_stroke_definition.dart';
import 'package:akurin/features/handwriting/models/handwriting_animation_config.dart';
import 'package:akurin/features/handwriting/screens/character_demonstration_screen.dart';
import 'package:akurin/features/handwriting/sinhala_handwriting_screen.dart';
import 'package:akurin/features/handwriting/widgets/stroke_demonstration_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject(Widget screen) {
    return MaterialApp(theme: AppTheme.light, home: screen);
  }

  testWidgets('selecting an English letter opens its demonstration', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(const EnglishHandwritingScreen()));

    await tester.tap(find.byKey(const ValueKey('character-0-A')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Letter Time!'), findsOneWidget);
    expect(find.text('Let’s learn A'), findsOneWidget);
    expect(find.text('🍎  Apple'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Step 3 of 3'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Step 3 of 3'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Replay'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -100));
    await tester.pumpAndSettle();

    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('Previous Step'), findsOneWidget);
    expect(find.text('Next Step'), findsOneWidget);
    expect(find.text('My Turn!'), findsOneWidget);

    await tester.tap(find.text('Previous Step'));
    await tester.pump();
    expect(find.text('Step 2 of 3'), findsOneWidget);

    await tester.tap(find.text('Previous Step'));
    await tester.pump();
    expect(find.text('Step 1 of 3'), findsOneWidget);

    await tester.tap(find.text('Next Step'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 3'), findsOneWidget);

    await tester.tap(find.text('Replay'));
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Letter Time!'), findsOneWidget);

    await tester.tap(find.text('My Turn!'));
    await tester.pumpAndSettle();

    expect(find.text('Practice Time!'), findsOneWidget);
    expect(find.text('Write A'), findsOneWidget);
    expect(find.text('Use your finger to write the letter.'), findsOneWidget);
    expect(find.text('Use your finger to follow the letter.'), findsNothing);

    await tester.drag(
      find.byKey(const ValueKey('handwriting-practice-canvas')),
      const Offset(80, 120),
    );
    await tester.pump();

    final clearButton = find.widgetWithText(
      OutlinedButton,
      'Clear and Try Again',
    );
    expect(tester.widget<OutlinedButton>(clearButton).onPressed, isNotNull);
  });

  testWidgets('selecting a Sinhala letter opens its demonstration', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(const SinhalaHandwritingScreen()));

    await tester.tap(find.byKey(const ValueKey('character-0-අ')));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('Letter Time!'), findsOneWidget);
    expect(find.text('Let’s learn අ'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Step 1 of 1'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Step 1 of 1'), findsOneWidget);
    expect(
      tester
          .widget<StrokeDemonstrationCanvas>(
            find.byType(StrokeDemonstrationCanvas),
          )
          .showReferenceGlyph,
      isFalse,
    );

    await tester.scrollUntilVisible(
      find.text('Replay'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('Replay'), findsOneWidget);
    expect(find.text('Previous Step'), findsOneWidget);
    expect(find.text('Next Step'), findsOneWidget);
    expect(find.text('My Turn!'), findsOneWidget);

    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Previous Step'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Next Step'),
          )
          .onPressed,
      isNull,
    );

    await tester.tap(find.text('Replay'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Step 1 of 1'), findsOneWidget);

    await tester.tap(find.text('My Turn!'));
    await tester.pumpAndSettle();
    expect(find.text('Practice Time!'), findsOneWidget);
    expect(find.text('Write අ'), findsOneWidget);
    expect(find.text('Use your finger to write the letter.'), findsOneWidget);
    expect(find.text('Use your finger to follow the letter.'), findsNothing);
  });

  testWidgets('Sinhala multi-stroke timing and step controls work', (
    tester,
  ) async {
    final firstStrokeDuration = HandwritingAnimationConfig.sinhala
        .durationForStroke(sinhalaStrokes['ආ']!.strokes.first);

    await tester.pumpWidget(
      buildSubject(
        const CharacterDemonstrationScreen(
          character: 'ආ',
          language: HandwritingLanguage.sinhala,
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('Step 1 of 2'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.pump(
      firstStrokeDuration - const Duration(milliseconds: 1),
    );
    expect(find.text('Step 1 of 2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 298));
    expect(find.text('Step 1 of 2'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 2));
    expect(find.text('Step 2 of 2'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Replay'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Previous Step'));
    await tester.pump();
    expect(find.text('Step 1 of 2'), findsOneWidget);

    await tester.tap(find.text('Next Step'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Step 2 of 2'), findsOneWidget);

    await tester.tap(find.text('Replay'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Step 1 of 2'), findsOneWidget);
  });

  testWidgets('unsupported letters show a safe fallback', (tester) async {
    await tester.pumpWidget(
      buildSubject(
        const CharacterDemonstrationScreen(
          character: '?',
          language: HandwritingLanguage.english,
        ),
      ),
    );

    expect(find.text('Let’s learn ?'), findsOneWidget);
    expect(
      find.text('Demonstration is not available for this character yet.'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('My Turn!'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('My Turn!'), findsOneWidget);
  });
}
