import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../speech/parent/speech_parent_section.dart';

/// One component's part of the parent dashboard. [build] gets the active child's id.
class ParentSection {
  const ParentSection({
    required this.title,
    required this.icon,
    required this.build,
  });

  final String Function(AppLocalizations l10n) title;
  final IconData icon;
  final Widget Function(BuildContext context, String childId) build;
}

/// The dashboard's tabs, one per component, in the same order as the home screen.
/// TEAMS: replace your component's `ParentSectionPlaceholder` with your own section widget
/// (keep it inside your feature folder, as speech does in features/speech/parent/).
final parentSections = <ParentSection>[
  ParentSection(
    title: (l10n) => l10n.parentTabMath,
    icon: Icons.extension,
    build: (_, __) => const ParentSectionPlaceholder(icon: Icons.extension),
  ),
  ParentSection(
    title: (l10n) => l10n.parentTabSpelling,
    icon: Icons.spellcheck,
    build: (_, __) => const ParentSectionPlaceholder(icon: Icons.spellcheck),
  ),
  ParentSection(
    title: (l10n) => l10n.parentTabHandwriting,
    icon: Icons.edit,
    build: (_, __) => const ParentSectionPlaceholder(icon: Icons.edit),
  ),
  ParentSection(
    title: (l10n) => l10n.parentTabSpeech,
    icon: Icons.mic,
    build: (_, childId) => SpeechParentSection(childId: childId),
  ),
];

/// Shown for a component that has not added its section yet.
class ParentSectionPlaceholder extends StatelessWidget {
  const ParentSectionPlaceholder({super.key, required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context).parentComingSoon,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
