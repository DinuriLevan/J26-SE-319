import 'package:flutter/material.dart';

class EnglishHandwritingScreen extends StatelessWidget {
  const EnglishHandwritingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('English Handwriting')),
      body: const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'English character selection will be added here.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
