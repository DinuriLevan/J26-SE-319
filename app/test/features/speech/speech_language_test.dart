import 'package:akurin/features/speech/data/speech_words.dart';
import 'package:akurin/features/speech/speech_stub_screen.dart';
import 'package:akurin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(String locale) => ProviderScope(
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SpeechStubScreen(),
      ),
    );

void main() {
  testWidgets('asks for the language first, then shows only its words',
      (tester) async {
    await tester.pumpWidget(_app('en'));
    await tester.pumpAndSettle();
    expect(
        find.text('Which language do you want to practise?'), findsOneWidget);
    expect(find.text('සිංහල'), findsOneWidget);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('cat'), findsNothing);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    for (final w in speechWordsFor('en')) {
      expect(find.text(w.text), findsOneWidget);
    }
    for (final w in speechWordsFor('si')) {
      expect(find.text(w.text), findsNothing);
    }

    await tester.tap(find.byTooltip('Change language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('සිංහල'));
    await tester.pumpAndSettle();
    expect(find.text('අම්මා'), findsOneWidget);
    expect(find.text('cat'), findsNothing);
  });

  testWidgets('the question is in Sinhala for a Sinhala profile',
      (tester) async {
    await tester.pumpWidget(_app('si'));
    await tester.pumpAndSettle();
    expect(find.text('ඔයා පුහුණු වෙන්න කැමති කුමන භාෂාවෙන්ද?'), findsOneWidget);
  });

  test('every demo word belongs to exactly one practice language', () {
    expect(speechWordsFor('si').length + speechWordsFor('en').length,
        speechDemoWords.length);
    expect(speechWordsFor('si'), isNotEmpty);
    expect(speechWordsFor('en'), isNotEmpty);
  });
}
