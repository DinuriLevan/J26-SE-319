import 'package:flutter/material.dart';

import '../../shared/widgets/stub_screen_scaffold.dart';

class SpeechStubScreen extends StatelessWidget {
  const SpeechStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StubScreenScaffold(title: 'Speech & Pronunciation', icon: Icons.mic);
  }
}
