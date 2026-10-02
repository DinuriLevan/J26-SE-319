import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/sync_service.dart';
import '../home/home_screen.dart';
import '../settings/settings_screen.dart';
import 'providers/nav_providers.dart';

/// Root app shell: Home (greeting + component cards) and Settings tabs.
/// The four feature components are reached via Home's cards, not as
/// top-level tabs — see docs/decision-log.md.
class HomeShellScreen extends ConsumerStatefulWidget {
  const HomeShellScreen({super.key});

  @override
  ConsumerState<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends ConsumerState<HomeShellScreen> {
  static const _tabs = [
    (title: 'Home', icon: Icons.home, screen: HomeScreen()),
    (title: 'Settings', icon: Icons.settings, screen: SettingsScreen()),
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

    return Scaffold(
      body: IndexedStack(
        index: selectedIndex,
        children: [for (final tab in _tabs) tab.screen],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => ref.read(selectedTabProvider.notifier).state = index,
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(icon: Icon(tab.icon), label: tab.title),
        ],
      ),
    );
  }
}
