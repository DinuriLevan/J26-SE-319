import 'package:akurin/core/db/app_database.dart';
import 'package:akurin/core/sync/sync_service.dart';
import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/math_memory/data/math_progress_repository.dart';
import 'package:akurin/features/math_memory/engine/attempt.dart';
import 'package:akurin/features/math_memory/ml/next_attempt_planner.dart';
import 'package:akurin/features/math_memory/widgets/math_tutorial_scaffold.dart';
import 'package:akurin/features/profile/providers/profile_providers.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const testChildId = '11111111-1111-4111-8111-111111111111';

AnswerOutcome firstTry({int ms = 3000}) =>
    AnswerOutcome(correct: true, tries: 1, firstResponseMs: ms);

AnswerOutcome afterHint({int ms = 3000}) =>
    AnswerOutcome(correct: true, tries: 2, firstResponseMs: ms);

AnswerOutcome missed({int ms = 3000}) =>
    AnswerOutcome(correct: false, tries: 2, firstResponseMs: ms);

/// A clock tests can move forward by hand.
class FakeClock {
  DateTime now = DateTime.utc(2026, 10, 18, 9);

  void advance(Duration d) => now = now.add(d);

  DateTime call() => now;
}

/// Skips network sync in tests.
class NoopSyncService implements SyncService {
  int flushes = 0;

  @override
  Future<void> flushPendingResults() async => flushes++;
}

AppDatabase createTestDatabase() => AppDatabase(NativeDatabase.memory());

/// Hosts [home] with an in-memory database, a fixed child, a fixed seed and
/// no network.
Widget buildMathTestApp({
  required AppDatabase db,
  required Widget home,
  int seed = 7,
  FakeClock? clock,
  NoopSyncService? sync,
  MathModelLoader? modelLoader,
}) {
  final fakeClock = clock ?? FakeClock();
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      activeChildIdProvider.overrideWith((ref) => testChildId),
      syncServiceProvider.overrideWithValue(sync ?? NoopSyncService()),
      mathGameSeedProvider.overrideWithValue(() => seed),
      mathGameClockProvider.overrideWithValue(fakeClock.call),
      if (modelLoader != null) mathModelLoaderProvider.overrideWithValue(modelLoader),
    ],
    child: MaterialApp(theme: AppTheme.light, home: home),
  );
}

/// A typical low-cost Android phone: 360x640 dp.
void usePhoneScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(720, 1280);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

/// Lets real database work finish (drift doesn't run under the test's fake
/// clock), then lets page transitions finish. Advances fake time by only
/// ~1 s, so Memory Match's look timer (≥3 s) keeps running.
Future<void> settleDb(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pump();
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

/// The "how to play" screen for [title] ("Number Quest" / "Memory Match").
Finder tutorialScreen(String title) =>
    find.byWidgetPredicate((w) => w is MathTutorialScaffold && w.title == title);
