import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../handwriting/handwriting_stub_screen.dart';
import '../math_memory/math_memory_stub_screen.dart';
import '../profile/providers/profile_providers.dart';
import '../speech/speech_stub_screen.dart';
import '../spelling/spelling_stub_screen.dart';

class _ComponentCard {
  const _ComponentCard(this.title, this.icon, this.screenBuilder);

  final String title;
  final IconData icon;
  final WidgetBuilder screenBuilder;
}

final _components = [
  _ComponentCard('Math & Memory', Icons.extension, (_) => const MathMemoryStubScreen()),
  _ComponentCard('Spelling & Phonics', Icons.spellcheck, (_) => const SpellingStubScreen()),
  _ComponentCard('Handwriting', Icons.edit, (_) => const HandwritingStubScreen()),
  _ComponentCard('Speech & Pronunciation', Icons.mic, (_) => const SpeechStubScreen()),
];

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('AkuRin')),
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
                children: [for (final component in _components) _buildCard(context, component)],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, _ComponentCard component) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: component.screenBuilder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(component.icon, size: 48, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                component.title,
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
