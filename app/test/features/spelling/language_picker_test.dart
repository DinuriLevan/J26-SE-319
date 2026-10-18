import 'package:akurin/features/spelling/spelling_stub_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the spelling tab offers English and Sinhala; Sinhala opens its placeholder', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: SpellingStubScreen())));

    expect(find.text('English'), findsOneWidget);
    expect(find.text('සිංහල'), findsOneWidget);

    await tester.ensureVisible(find.text('සිංහල'));
    await tester.tap(find.text('සිංහල'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Coming soon'), findsOneWidget);
  });
}
