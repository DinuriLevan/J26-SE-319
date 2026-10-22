import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_service.dart';
import '../../shared/widgets/app_drawer.dart';
import '../handwriting/handwriting_language_selection_screen.dart';
import '../home/home_screen.dart';
import '../math_memory/math_game_selection_screen.dart';
import '../speech/speech_stub_screen.dart';
import '../spelling/spelling_stub_screen.dart';
import 'providers/nav_providers.dart';

/// Root app shell: bottom bar with the four components, plus a drawer with
/// Home, Profile and Settings — see docs/decision-log.md.
class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  static const _pages = [
    HomeScreen(),
    MathGameSelectionScreen(),
    SpellingStubScreen(),
    HandwritingLanguageSelectionScreen(),
    SpeechStubScreen(),
  ];

  static const _destinations = [
    (title: 'Math', icon: Icons.extension),
    (title: 'Spelling', icon: Icons.spellcheck),
    (title: 'Writing', icon: Icons.edit),
    (title: 'Speech', icon: Icons.mic),
  ];

  @override
  void initState() {
    super.initState();
    // Best-effort flush attempt on app start — see core/sync/sync_service.dart.
    Future.microtask(() => ref.read(syncServiceProvider).flushPendingResults());
  }

  @override
  Widget build(BuildContext context) {
    // Wires up the connectivity-triggered sync flush.
    ref.watch(syncTriggerProvider);

    final selectedIndex = ref.watch(selectedTabProvider);

    final onHome = selectedIndex == 0;

    return Scaffold(
      key: ref.watch(shellScaffoldKeyProvider),
      drawer: const AppDrawer(),
      body: IndexedStack(index: selectedIndex, children: _pages),
      bottomNavigationBar: NavigationBarTheme(
        // On Home no component is selected, so hide the selection pill.
        data: NavigationBarTheme.of(context).copyWith(
          indicatorColor: onHome ? Colors.transparent : null,
        ),
        child: NavigationBar(
          selectedIndex: onHome ? 0 : selectedIndex - 1,
          onDestinationSelected: (index) =>
              ref.read(selectedTabProvider.notifier).state = index + 1,
          destinations: [
            for (final d in _destinations)
              NavigationDestination(icon: Icon(d.icon), label: d.title),
          ],
        ),
      ),
    );
  }
}
