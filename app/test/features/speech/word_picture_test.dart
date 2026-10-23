import 'dart:io';

import 'package:akurin/features/speech/data/speech_words.dart';
import 'package:akurin/features/speech/screens/speech_result_screen.dart';
import 'package:akurin/features/speech/ui/speech_theme.dart';
import 'package:akurin/features/speech/ui/word_picture.dart';
import 'package:akurin/features/speech/ui/word_tile.dart';
import 'package:akurin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_voice.dart';

Widget _wrap(Widget child) => ProviderScope(
      overrides: [FakeVoice().override],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, c) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: c!),
        home: SpeechThemed(child: Scaffold(body: Center(child: child))),
      ),
    );

void main() {
  test('every practice word has a picture file (run fetch_word_pictures.py)',
      () {
    // `flutter test` runs with app/ as the working directory.
    final missing = [
      for (final w in speechDemoWords)
        if (!File(WordPicture.assetPath(w.id)).existsSync())
          '${w.id} ${w.text}',
    ];
    expect(missing, isEmpty);
    expect(File('assets/speech/pictures/ATTRIBUTION.md').existsSync(), isTrue);
  });

  testWidgets('word cards show the picture', (tester) async {
    await tester.pumpWidget(_wrap(SizedBox(
        width: 180,
        height: 116,
        child:
            WordTile(wordId: 'w_005', text: 'cat', level: 1, onTap: () {}))));
    await tester.pumpAndSettle();
    expect(find.byType(WordPicture), findsOneWidget);
    expect(find.text('cat'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the result screen shows the picture beside the word',
      (tester) async {
    await tester.pumpWidget(_wrap(const SpeechResultScreen(
        word: SpeechWord(id: 'w_005', text: 'cat', language: 'en', level: 1),
        mastered: true)));
    await tester.pumpAndSettle();
    final pic = tester.widget<WordPicture>(find.byType(WordPicture));
    expect(pic.wordId, 'w_005');
  });

  testWidgets('a missing picture shows a placeholder instead of failing',
      (tester) async {
    await tester.pumpWidget(_wrap(const WordPicture(wordId: 'w_999')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(DecoratedBox), findsWidgets);
  });
}
