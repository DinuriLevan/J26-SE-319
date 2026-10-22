import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'math_palette.dart';

/// Whether written instructions are shown for a parent reading along. Off by
/// default: children get picture-first screens. Shared by both games and
/// reset when the app restarts, so a child always starts in picture mode.
final parentSupportProvider = StateProvider<bool>((ref) => false);

/// Parent support switch (family icon) for the app bar.
class ParentSupportToggle extends ConsumerWidget {
  const ParentSupportToggle({super.key, required this.colors});

  static const switchKey = ValueKey('parent-support-switch');

  final MathGameColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref.watch(parentSupportProvider);
    void set(bool value) => ref.read(parentSupportProvider.notifier).state = value;

    return Tooltip(
      message: on ? 'Hide written instructions' : 'Show written instructions for a parent',
      child: MergeSemantics(
        child: Semantics(
          label: 'Parent support',
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => set(!on),
            child: Padding(
              padding: const EdgeInsets.only(left: 10, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Icon only, so the game title isn't squeezed; the tooltip
                  // and screen-reader label say "Parent support".
                  Icon(Icons.family_restroom_rounded, color: on ? colors.accent : MathPalette.ink),
                  Switch(
                    key: switchKey,
                    value: on,
                    onChanged: set,
                    activeTrackColor: colors.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
