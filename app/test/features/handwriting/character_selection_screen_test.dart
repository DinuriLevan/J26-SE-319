import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/handwriting/english_handwriting_screen.dart';
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
    expect(find.text('ළ'), findsOneWidget);
    expect(find.text('ඟ'), findsNothing);
    expect(find.text('ෆ'), findsNothing);
  });
}
