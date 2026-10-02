import 'package:flutter/material.dart';

import '../../shared/widgets/stub_screen_scaffold.dart';

class SpellingStubScreen extends StatelessWidget {
  const SpellingStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StubScreenScaffold(title: 'Spelling & Phonics', icon: Icons.spellcheck);
  }
}
