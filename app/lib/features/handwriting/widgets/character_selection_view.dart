import 'package:flutter/material.dart';

class CharacterSectionData {
  const CharacterSectionData({
    required this.title,
    required this.characters,
    this.emojis,
  });

  final String title;
  final List<String> characters;
  final List<String>? emojis;
}

class CharacterSelectionView extends StatelessWidget {
  const CharacterSelectionView({
    super.key,
    required this.sections,
    required this.onCharacterSelected,
  });

  final List<CharacterSectionData> sections;
  final ValueChanged<String> onCharacterSelected;

  static const _cardColors = [
    Color(0xFFFF686B),
    Color(0xFFFFAA4C),
    Color(0xFFFFD43B),
    Color(0xFF62D47A),
    Color(0xFF49C9BD),
    Color(0xFF4BA8EA),
    Color(0xFF8B6BEF),
    Color(0xFFEF75A5),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text(
          'Pick a Letter!',
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Tap a letter you would like to practice.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        for (final (sectionIndex, section) in sections.indexed) ...[
          Text(
            section.title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columnCount = constraints.maxWidth >= 320 ? 4 : 3;

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columnCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.82,
                ),
                itemCount: section.characters.length,
                itemBuilder: (context, index) {
                  final character = section.characters[index];
                  final emojis = section.emojis;

                  return CharacterTile(
                    key: ValueKey('character-$sectionIndex-$character'),
                    character: character,
                    emoji: emojis == null ? null : emojis[index],
                    color: _cardColors[index % _cardColors.length],
                    onTap: () => onCharacterSelected(character),
                  );
                },
              );
            },
          ),
          if (sectionIndex != sections.length - 1) const SizedBox(height: 28),
        ],
      ],
    );
  }
}

class CharacterTile extends StatelessWidget {
  const CharacterTile({
    super.key,
    required this.character,
    required this.color,
    required this.onTap,
    this.emoji,
  });

  final String character;
  final String? emoji;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Practice $character',
      child: Material(
        color: color,
        elevation: 3,
        shadowColor: color.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              if (emoji case final emoji?)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Text(emoji, style: const TextStyle(fontSize: 18)),
                ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    character,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
