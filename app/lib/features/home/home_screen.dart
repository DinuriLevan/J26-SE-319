import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_drawer.dart';
import '../home_shell/providers/nav_providers.dart';
import '../profile/providers/profile_providers.dart';

// Order matches the bottom bar destinations in the home shell.
const _components = [
  ('Math & Memory', Icons.extension),
  ('Spelling & Phonics', Icons.spellcheck),
  ('Handwriting', Icons.edit),
  ('Speech & Pronunciation', Icons.mic),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(leading: const DrawerMenuButton(), title: const Text('AkuRin')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              profile == null ? 'Hi!' : 'Hi, ${profile.name}!',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              'What would you like to practice today?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  for (final (i, (title, icon)) in _components.indexed)
                    _buildCard(context, ref, tab: i + 1, title: title, icon: icon),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref, {
    required int tab,
    required String title,
    required IconData icon,
  }) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => ref.read(selectedTabProvider.notifier).state = tab,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
