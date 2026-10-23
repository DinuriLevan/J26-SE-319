import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../profile/providers/profile_providers.dart';
import 'parent_sections.dart';

/// Opens the parent dashboard (main menu entry).
Future<void> openParentDashboard(BuildContext context) async {
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => const ParentDashboardScreen()));
}

/// Progress for grown-ups, one tab per component (parent_sections.dart). Each component team
/// owns its own tab; the speech tab opens first while it is the only one built.
class ParentDashboardScreen extends ConsumerWidget {
  const ParentDashboardScreen({super.key});

  static int get initialTab =>
      parentSections.length - 1; // speech, the first section built

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final childId = ref.watch(activeChildIdProvider);
    final name = ref.watch(currentProfileProvider).valueOrNull?.name;
    return DefaultTabController(
      length: parentSections.length,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: Text(name == null
              ? l10n.parentDashboardTitle
              : '${l10n.parentDashboardTitle} · $name'),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              for (final s in parentSections)
                Tab(icon: Icon(s.icon), text: s.title(l10n)),
            ],
          ),
        ),
        body: childId == null
            ? Center(child: Text(l10n.parentComingSoon))
            : TabBarView(
                children: [
                  for (final s in parentSections) s.build(context, childId),
                ],
              ),
      ),
    );
  }
}
