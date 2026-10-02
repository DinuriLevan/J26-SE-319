import 'package:flutter/material.dart';

import '../../shared/widgets/stub_screen_scaffold.dart';

class HandwritingStubScreen extends StatelessWidget {
  const HandwritingStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const StubScreenScaffold(title: 'Handwriting', icon: Icons.edit);
  }
}
