import 'package:akurin/core/sync/sync_service.dart';
import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/home_shell/home_shell_screen.dart';
import 'package:akurin/features/profile/providers/profile_providers.dart';
import 'package:akurin/features/math_memory/widgets/math_game_intro_scaffold.dart';
import 'package:akurin/features/spelling/ui/widgets/mascot.dart';
import 'package:akurin/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../speech/fake_voice.dart';

/// Skips the real offline sync, which needs the on-device database.
class _NoopSyncService implements SyncService {
  @override
  Future<void> flushPendingResults() async {}
}

/// The tabs stay mounted and some (spelling mascot, speech parrot) loop their animations on
/// purpose, so pumpAndSettle never settles; pump long enough for page transitions instead.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  Widget buildShell() {
    return ProviderScope(
      overrides: [
        syncServiceProvider.overrideWithValue(_NoopSyncService()),
        syncTriggerProvider.overrideWithValue(null),
        currentProfileProvider.overrideWith((ref) => Stream.value(null)),
        FakeVoice().override,
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        // The always-mounted Speech tab's parrot animates forever otherwise.
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: const HomeShellScreen(),
      ),
    );
  }

  testWidgets('bottom bar switches between all four components',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildShell());
    await tester.pump();

    expect(find.text('What would you like to practice today?'), findsOneWidget);

    await tester.tap(find.text('Math'));
    await settle(tester);
    expect(find.text("Let's Play & Learn!"), findsOneWidget);

    await tester.tap(find.text('Spelling'));
    await settle(tester);
    // The spelling picker has no title bar; all tabs stay mounted, so look only at the visible one.
    expect(find.byType(Mascot).hitTestable(), findsOneWidget);
    expect(find.text("Let's Play & Learn!"), findsNothing);

    await tester.tap(find.text('Writing'));
    await settle(tester);
    expect(find.text('Choose a Language'), findsOneWidget);

    await tester.tap(find.text('Speech'));
    await settle(tester);
    expect(find.widgetWithText(AppBar, 'Say it!'), findsOneWidget);
  });

  testWidgets(
      'game screens open over the shell and back returns to the Math tab',
      (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(buildShell());
    await tester.pump();

    await tester.tap(find.text('Math'));
    await settle(tester);
    await tester.tap(find.text('Play Now').first);
    await settle(tester);
    expect(find.byKey(MathGameIntroScaffold.startGameKey), findsOneWidget);

    await tester.pageBack();
    await settle(tester);
    expect(find.text("Let's Play & Learn!"), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
