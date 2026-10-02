import 'package:flutter/material.dart';

import '../../shared/widgets/stub_screen_scaffold.dart';

class MathMemoryStubScreen extends StatelessWidget {
  const MathMemoryStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StubScreenScaffold(title: 'Math & Memory', icon: Icons.extension);
  }
}
