import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../home_shell/home_shell_screen.dart';
import '../profile/providers/profile_providers.dart';

/// First screen shown on launch. Ensures a local profile exists (creating a
/// default one silently if not — see decision-log.md for why there's no
/// multi-profile setup here), then moves on to the main app shell.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final id = await ref.read(profileControllerProvider).ensureProfileExists();
    if (!mounted) return;
    ref.read(activeChildIdProvider.notifier).state = id;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShellScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/branding/logo.png', width: 240, height: 240),
            const SizedBox(height: 32),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
