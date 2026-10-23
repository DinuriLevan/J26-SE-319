import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/handwriting/handwriting_language_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildSubject() {
    return MaterialApp(
      theme: AppTheme.light,
      home: const HandwritingLanguageSelectionScreen(),
    );
  }

  testWidgets('shows both handwriting language choices', (tester) async {
    await tester.pumpWidget(buildSubject());

    expect(find.text('Handwriting'), findsOneWidget);
    expect(find.text('Choose a Language'), findsOneWidget);
    expect(
      find.text('Which language would you like to practice?'),
      findsOneWidget,
    );
    expect(find.text('English'), findsOneWidget);
    expect(find.text('සිංහල'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('සිංහල')).dy,
      greaterThan(tester.getTopLeft(find.text('English')).dy),
    );
  });

  testWidgets('opens the English character selection screen', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('English Handwriting'), findsOneWidget);
    expect(find.text('Pick a Letter!'), findsOneWidget);
    expect(find.text('Uppercase'), findsOneWidget);
    expect(find.text('A'), findsOneWidget);
  });

  testWidgets('opens the Sinhala character selection screen', (tester) async {
    await tester.pumpWidget(buildSubject());

    await tester.ensureVisible(find.text('සිංහල'));
    await tester.tap(find.text('සිංහල'));
    await tester.pumpAndSettle();

    expect(find.text('සිංහල Handwriting'), findsOneWidget);
    expect(find.text('Pick a Letter!'), findsOneWidget);
    expect(find.text('ස්වර (Vowels)'), findsOneWidget);
    expect(find.text('අ'), findsOneWidget);
  });
}
