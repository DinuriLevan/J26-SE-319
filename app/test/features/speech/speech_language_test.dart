import 'package:akurin/features/speech/data/speech_api.dart';
import 'package:akurin/features/speech/data/speech_words.dart';
import 'package:akurin/features/speech/speech_stub_screen.dart';
import 'package:akurin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Word info as the service would report it: every word ready unless listed in [unready].
Map<String, WordInfo> _wordInfo({Set<String> unready = const {}}) => {
      for (final w in speechDemoWords)
        w.id: WordInfo(
            wordId: w.id,
            units: const ['x'],
            listenUnits: const {},
            hasWordAudio: false,
            nRefs: unready.contains(w.id) ? 1 : 6),
    };

Widget _app(String locale,
        {Map<String, WordInfo>? info, bool showUnready = false}) =>
    ProviderScope(
      key: ValueKey(showUnready), // a fresh app (and language choice) per view
      overrides: [
        speechWordsProvider.overrideWith((ref) async => info ?? _wordInfo()),
        speechShowUnreadyWordsProvider.overrideWithValue(showUnready),
      ],
      child: MaterialApp(
        locale: Locale(locale),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // Reduce motion (as a child's device might): every speech animation must settle.
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
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
    // Easiest English word first, grouped by level; no Sinhala words.
    expect(find.text('cat'), findsOneWidget);
    expect(find.text('Level 1'), findsOneWidget);
    for (final w in speechWordsFor('si')) {
      expect(find.text(w.text), findsNothing);
    }
    // The hardest word is further down the list.
    await tester.scrollUntilVisible(find.text('tasty'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Level 3'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('cat'), -200,
        scrollable: find.byType(Scrollable).first);

    await tester.tap(find.byTooltip('Change language'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('සිංහල'));
    await tester.pumpAndSettle();
    expect(find.text('මම'), findsOneWidget); // first Level 1 Sinhala word
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

  testWidgets('children never see words that are not ready; developers do',
      (tester) async {
    final info = _wordInfo(unready: {'w_017'}); // hat
    await tester.pumpWidget(_app('en', info: info));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('cat'), findsOneWidget);
    expect(find.text('hat'), findsNothing);

    await tester.pumpWidget(_app('en', info: info, showUnready: true));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('hat'), findsOneWidget);
    expect(find.text('needs recordings 1/4'), findsOneWidget);
  });
}
