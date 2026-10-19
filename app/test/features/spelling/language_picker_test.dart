import 'package:akurin/features/spelling/sinhala_spelling_screen.dart';
import 'package:akurin/features/spelling/spelling_stub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the spelling tab offers English and Sinhala; Sinhala opens the Sinhala game', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: SpellingStubScreen())));

    expect(find.text('English'), findsOneWidget);
    expect(find.text('සිංහල'), findsOneWidget);

    await tester.ensureVisible(find.text('සිංහල'));
    await tester.tap(find.text('සිංහල'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(SinhalaSpellingScreen), findsOneWidget);
  });

  testWidgets('the language cards fit a narrow phone (360 dp wide) without overflowing', (tester) async {
    tester.view
      ..physicalSize = const Size(720, 1610)
      ..devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: SpellingStubScreen())));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('English'), findsOneWidget);
  });
}
