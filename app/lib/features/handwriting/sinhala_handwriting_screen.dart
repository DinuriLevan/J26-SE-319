import 'package:flutter/material.dart';

class SinhalaHandwritingScreen extends StatelessWidget {
  const SinhalaHandwritingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('සිංහල Handwriting')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Sinhala character selection will be added here.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
