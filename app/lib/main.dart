import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/profile/providers/profile_providers.dart';
import 'features/splash/splash_screen.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: AkuRinApp()));
}

class AkuRinApp extends ConsumerWidget {
  const AkuRinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // UI language follows the child profile's preferred language ('si' | 'en').
    final language =
        ref.watch(currentProfileProvider).valueOrNull?.preferredLanguage;

    return MaterialApp(
      title: 'AkuRin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: language == null ? null : Locale(language),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SplashScreen(),
    );
  }
}
