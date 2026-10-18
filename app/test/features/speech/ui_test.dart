import 'package:akurin/features/speech/data/speech_words.dart';
import 'package:akurin/features/speech/screens/speech_result_screen.dart';
import 'package:akurin/features/speech/ui/celebration.dart';
import 'package:akurin/features/speech/ui/parrot.dart';
import 'package:akurin/features/speech/ui/speech_theme.dart';
import 'package:akurin/features/speech/ui/speech_widgets.dart';
import 'package:akurin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_voice.dart';

Widget _wrap(Widget child, {bool reduceMotion = true, FakeVoice? voice}) =>
    ProviderScope(
        overrides: [(voice ?? FakeVoice()).override],
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
              data: MediaQuery.of(context)
                  .copyWith(disableAnimations: reduceMotion),
              child: c!),
          home: SpeechThemed(child: Scaffold(body: Center(child: child))),
        ));

void main() {
  testWidgets('the parrot draws every mood', (tester) async {
    for (final mood in ParrotMood.values) {
      await tester.pumpWidget(_wrap(ParrotBuddy(mood: mood)));
      await tester.pumpAndSettle();
      expect(find.byType(ParrotBuddy), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('the parrot animates normally but is still with reduce motion',
      (tester) async {
    await tester.pumpWidget(_wrap(const ParrotBuddy(), reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.hasRunningAnimations, isTrue);

    await tester.pumpWidget(_wrap(const ParrotBuddy()));
    await tester.pump();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('syllable tiles highlight exactly the target span',
      (tester) async {
    await tester.pumpWidget(_wrap(const SyllableTiles(
        units: ['s', 'ch', 'oo', 'l'], targetStart: 1, targetEnd: 2)));
    await tester.pumpAndSettle();
    Color colourOf(int i) =>
        ((tester.widget<Container>(find.byKey(ValueKey('tile_$i')))).decoration
                as BoxDecoration)
            .color!;
    expect([
      for (var i = 0; i < 4; i++) colourOf(i)
    ], [
      SpeechColors.paper,
      SpeechColors.peach,
      SpeechColors.peach,
      SpeechColors.paper,
    ]);
  });

  testWidgets('tapping a hearable syllable tile plays that unit',
      (tester) async {
    final taps = <int>[];
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(SyllableTiles(
      units: const ['c', 'a', 't'],
      onTapUnit: taps.add,
      canTapUnit: (i) => i != 2, // e.g. no adult recording for "t"
      hearLabel: 'Hear',
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tap_tile_1')));
    expect(taps, [1]);
    expect(find.byKey(const ValueKey('tap_tile_2')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tile_2')), warnIfMissed: false);
    expect(taps, [1]);
    expect(find.bySemanticsLabel('Hear a'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('tiles are plain (not tappable) without onTapUnit',
      (tester) async {
    await tester.pumpWidget(_wrap(const SyllableTiles(units: ['ම', 'ම'])));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tap_tile_0')), findsNothing);
  });

  testWidgets('mic button has a screen-reader label and recording state',
      (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_wrap(
        MicButton(recording: true, onPressed: () {}, label: 'Say the word')));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.bySemanticsLabel('Say the word')),
      matchesSemantics(
          label: 'Say the word',
          value: 'recording',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true),
    );
    handle.dispose();
  });

  testWidgets('confetti plays once and then stops', (tester) async {
    await tester.pumpWidget(_wrap(
        const SizedBox(width: 300, height: 300, child: ConfettiBurst()),
        reduceMotion: false));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.hasRunningAnimations, isTrue);
    await tester.pump(const Duration(seconds: 2));
    expect(tester.hasRunningAnimations, isFalse);
  });

  group('result screen', () {
    const word = SpeechWord(id: 'w_005', text: 'cat', language: 'en', level: 1);

    testWidgets('celebrates only when the word is mastered', (tester) async {
      await tester.pumpWidget(
          _wrap(const SpeechResultScreen(word: word, mastered: true)));
      await tester.pumpAndSettle();
      expect(find.byType(ConfettiBurst), findsOneWidget);
      expect(find.byType(StarRow), findsOneWidget);

      await tester.pumpWidget(_wrap(const SpeechResultScreen(
          word: word, mastered: false, practiseLater: ['c'])));
      await tester.pumpAndSettle();
      expect(find.byType(ConfettiBurst), findsNothing);
      expect(find.byType(StarRow), findsNothing);
      final parrot = tester.widget<ParrotBuddy>(find.byType(ParrotBuddy));
      expect(parrot.mood, ParrotMood.encourage);
    });
  });

  testWidgets('the result screen says its title and message', (tester) async {
    final voice = FakeVoice();
    await tester.pumpWidget(_wrap(
        const SpeechResultScreen(
            word:
                SpeechWord(id: 'w_005', text: 'cat', language: 'en', level: 1),
            mastered: true,
            cardUnlocked: true),
        voice: voice));
    await tester.pumpAndSettle();
    expect(voice.tts.spoken, [
      'en-US:Great job!',
      'en-US:You said it really well.',
      'en-US:You unlocked a new card!',
    ]);
  });
}
