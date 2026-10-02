import 'package:flutter/material.dart';

/// Fixed set of local placeholder avatars. Shared between first-run profile
/// creation and the Settings screen's edit-profile section.
const avatarIds = ['avatar_1', 'avatar_2', 'avatar_3', 'avatar_4', 'avatar_5', 'avatar_6'];

class AvatarPicker extends StatelessWidget {
  const AvatarPicker({super.key, required this.selectedAvatarId, required this.onSelected});

  final String selectedAvatarId;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final avatarId in avatarIds)
          _AvatarOption(
            avatarId: avatarId,
            selected: avatarId == selectedAvatarId,
            onTap: () => onSelected(avatarId),
          ),
      ],
    );
  }
}

class _AvatarOption extends StatelessWidget {
  const _AvatarOption({required this.avatarId, required this.selected, required this.onTap});

  final String avatarId;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 32,
        backgroundColor: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
        child: CircleAvatar(
          radius: 28,
          backgroundImage: AssetImage('assets/avatars/$avatarId.png'),
        ),
      ),
    );
  }
}
