import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/splash/splash_screen.dart';

void main() {
  runApp(const ProviderScope(child: AkuRinApp()));
}

class AkuRinApp extends StatelessWidget {
  const AkuRinApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AkuRin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const SplashScreen(),
    );
  }
}
