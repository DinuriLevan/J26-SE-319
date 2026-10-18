import 'package:flutter/material.dart';

import 'speech_theme.dart';
import 'word_picture.dart';

/// A pastel word card, coloured by level, with the level's stars in the corner. An unready word
/// (developer view only) is greyed and shows how many recordings it still needs.
class WordTile extends StatelessWidget {
  const WordTile({
    super.key,
    required this.text,
    required this.level,
    required this.onTap,
    this.wordId,
    this.ready = true,
    this.badge,
  });

  final String text;

  /// Shows the word's picture on the left when given.
  final String? wordId;
  final int level;
  final VoidCallback onTap;
  final bool ready;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colour = ready ? SpeechColors.level(level) : const Color(0xFFECE8E1);
    return Semantics(
      button: true,
      label: text,
      excludeSemantics: true,
      child: Material(
        color: colour,
        borderRadius: BorderRadius.circular(SpeechTheme.radius),
        child: InkWell(
          borderRadius: BorderRadius.circular(SpeechTheme.radius),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SpeechTheme.radius),
              border: Border.all(
                  color: ready
                      ? SpeechColors.levelDeep(level)
                      : Colors.transparent,
                  width: 2),
            ),
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < level; i++)
                        Icon(Icons.star_rounded,
                            size: 16,
                            color: ready
                                ? SpeechColors.sun
                                : SpeechColors.navySoft.withValues(alpha: 0.3)),
                    ],
                  ),
                ),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (wordId != null) ...[
                        Opacity(
                          opacity: ready ? 1 : 0.4,
                          child: WordPicture(wordId: wordId!, size: 50),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Flexible(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                text,
                                style: theme.textTheme.headlineMedium!.copyWith(
                                  fontSize: 32,
                                  color: ready
                                      ? SpeechColors.navy
                                      : SpeechColors.navySoft
                                          .withValues(alpha: 0.6),
                                ),
                              ),
                            ),
                            if (badge != null)
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(badge!,
                                    style: theme.textTheme.labelSmall),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
