import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/home_shell/providers/nav_providers.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/profile/providers/profile_providers.dart';
import '../../features/settings/settings_screen.dart';

/// Hamburger button that opens the home shell's drawer from any nested screen.
class DrawerMenuButton extends ConsumerWidget {
  const DrawerMenuButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.menu),
      tooltip: 'Menu',
      onPressed: () => ref.read(shellScaffoldKeyProvider).currentState?.openDrawer(),
    );
  }
}

/// Sidebar: Home, Profile, Settings.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;
    final navigator = Navigator.of(context);

    void open(WidgetBuilder builder) {
      navigator.pop();
      navigator.push(MaterialPageRoute(builder: builder));
    }

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundImage: profile == null
                        ? null
                        : AssetImage('assets/avatars/${profile.avatarId}.png'),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      profile?.name ?? 'AkuRin',
                      style: Theme.of(context).textTheme.titleLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                ref.read(selectedTabProvider.notifier).state = 0;
                navigator.pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person),
              title: const Text('Profile'),
              onTap: () => open((_) => const ProfileScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () => open((_) => const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
