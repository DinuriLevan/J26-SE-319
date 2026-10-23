import 'package:akurin/core/sync/sync_service.dart';
import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/home_shell/home_shell_screen.dart';
import 'package:akurin/features/profile/providers/profile_providers.dart';
import 'package:akurin/features/math_memory/widgets/math_game_intro_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Skips the real offline sync, which needs the on-device database.
class _NoopSyncService implements SyncService {
  @override
  Future<void> flushPendingResults() async {}
}

void main() {
  Widget buildShell() {
    return ProviderScope(
      overrides: [
        syncServiceProvider.overrideWithValue(_NoopSyncService()),
        syncTriggerProvider.overrideWithValue(null),
        currentProfileProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp(theme: AppTheme.light, home: const HomeShellScreen()),
    );
  }

  testWidgets('bottom bar switches between all four components', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildShell());
    await tester.pump();

    expect(find.text('What would you like to practice today?'), findsOneWidget);

    await tester.tap(find.text('Math'));
    await tester.pumpAndSettle();
    expect(find.text("Let's Play & Learn!"), findsOneWidget);

    await tester.tap(find.text('Spelling'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Spelling & Phonics'), findsOneWidget);
    expect(find.text("Let's Play & Learn!"), findsNothing);

    await tester.tap(find.text('Writing'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a Language'), findsOneWidget);

    await tester.tap(find.text('Speech'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'Speech & Pronunciation'), findsOneWidget);
  });

  testWidgets('game screens open over the shell and back returns to the Math tab',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildShell());
    await tester.pump();

    await tester.tap(find.text('Math'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Play Now').first);
    await tester.pumpAndSettle();
    expect(find.byKey(MathGameIntroScaffold.startGameKey), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text("Let's Play & Learn!"), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
