import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('About', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('AkuRin v0.1.0'),
          const SizedBox(height: 4),
          const Text(
            'AI-Driven Learning Platform for Literacy Development in Children with Dyslexia.',
          ),
        ],
      ),
    );
  }
}
