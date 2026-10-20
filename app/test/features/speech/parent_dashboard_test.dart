import 'package:akurin/core/db/app_database.dart';
import 'package:akurin/features/parent_dashboard/parent_dashboard_screen.dart';
import 'package:akurin/features/parent_dashboard/parent_sections.dart';
import 'package:akurin/features/profile/providers/profile_providers.dart';
import 'package:akurin/features/speech/data/speech_api.dart';
import 'package:akurin/features/speech/data/speech_progress_store.dart';
import 'package:akurin/features/speech/data/speech_words.dart';
import 'package:akurin/features/speech/parent/speech_parent_section.dart';
import 'package:akurin/features/speech/parent/speech_parent_stats.dart';
import 'package:akurin/l10n/app_localizations.dart';
import 'package:akurin/shared/widgets/app_drawer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_voice.dart';

final _w = {for (final w in speechDemoWords) w.text: w};
final _now = DateTime(2026, 10, 21, 12);

List<SpeechWordResult> _results() => [
      SpeechWordResult(
          at: _now.subtract(const Duration(days: 8)),
          word: _w['cat']!,
          mastered: false,
          fullWordTries: 3,
          practiseLater: ['c', 't']),
      SpeechWordResult(
          at: _now.subtract(const Duration(days: 1)),
          word: _w['cat']!,
          mastered: true,
          fullWordTries: 2),
      SpeechWordResult(
          at: _now.subtract(const Duration(days: 1)),
          word: _w['මම']!,
          mastered: true,
          fullWordTries: 1),
    ];

Widget _app(Widget home, {List<SpeechWordResult>? results, FakeVoice? voice}) =>
    ProviderScope(
      overrides: [
        activeChildIdProvider.overrideWith((ref) => 'child-1'),
        currentProfileProvider
            .overrideWith((ref) => Stream<ChildProfile?>.value(null)),
        speechWordResultsProvider
            .overrideWith((ref, id) async => results ?? _results()),
        speechWordsProvider.overrideWith((ref) async => {
              'w_005': const WordInfo(
                  wordId: 'w_005',
                  units: ['c', 'a', 't'],
                  listenUnits: {0, 1, 2},
                  hasWordAudio: true,
                  nRefs: 17,
                  nSpeakers: 8),
            }),
        (voice ?? FakeVoice()).override,
      ],
      child: MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: home,
      ),
    );

void main() {
  testWidgets('menu -> dashboard', (tester) async {
    await tester.pumpWidget(_app(const Scaffold(drawer: AppDrawer())));
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('drawer_parent_dashboard')));
    await tester.pumpAndSettle();
    expect(find.byType(ParentDashboardScreen), findsOneWidget);
  });

  testWidgets('four component tabs; speech opens first, others coming soon',
      (tester) async {
    await tester.pumpWidget(_app(const ParentDashboardScreen()));
    await tester.pumpAndSettle();
    for (final t in [
      'Math & Memory',
      'Spelling & Phonics',
      'Handwriting',
      'Speech & Pronunciation'
    ]) {
      expect(find.text(t), findsOneWidget);
    }
    expect(parentSections.length, 4);
    expect(find.byType(SpeechParentSection), findsOneWidget);

    DefaultTabController.of(tester.element(find.byType(TabBarView)))
        .animateTo(0);
    await tester.pumpAndSettle();
    expect(find.text('This section is coming soon.'), findsOneWidget);
  });

  testWidgets('speech section shows progress, sounds, charts and tips',
      (tester) async {
    final voice = FakeVoice();
    await tester.pumpWidget(_app(
        Scaffold(body: SpeechParentSection(childId: 'child-1', now: _now)),
        voice: voice));
    await tester.pumpAndSettle();

    expect(find.text('2 mastered'), findsOneWidget);
    expect(find.text('Words mastered'), findsOneWidget);
    expect(find.text('“t”'), findsOneWidget); // sound to practise from cat
    final footnote =
        find.textContaining('A practice aid, not a clinical assessment');
    await tester.scrollUntilVisible(footnote, 300);
    expect(footnote, findsOneWidget);
    expect(find.text('Tips for grown-ups'), findsOneWidget);
    expect(find.textContaining('score'), findsNothing); // no raw scores

    // "Hear" plays the adult recording of the sound (cut from cat).
    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('hear_sound_w_005_t')), -200);
    expect(tester.takeException(), isNull);
  });

  testWidgets('language switch filters the words', (tester) async {
    await tester.pumpWidget(_app(
        Scaffold(body: SpeechParentSection(childId: 'child-1', now: _now))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('සිංහල'));
    await tester.pumpAndSettle();
    expect(find.text('1 mastered'), findsOneWidget);
    expect(find.text('Nothing to practise right now. Great work!'),
        findsOneWidget);
  });

  testWidgets('empty state when nothing was practised', (tester) async {
    await tester.pumpWidget(_app(
        Scaffold(body: SpeechParentSection(childId: 'child-1', now: _now)),
        results: const []));
    await tester.pumpAndSettle();
    expect(find.text('No speech practice on this device yet.'), findsOneWidget);
  });

  testWidgets('fits a small phone (360 x 640) without overflow',
      (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const ParentDashboardScreen()));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView), const Offset(0, -2000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
