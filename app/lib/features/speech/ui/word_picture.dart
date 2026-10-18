import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'speech_theme.dart';

/// The picture for a practice word: assets/speech/pictures/{wordId}.svg (Twemoji, CC-BY 4.0),
/// fetched by ml/speech/scripts/fetch_word_pictures.py. Decorative for screen readers (the word
/// itself is read out); a soft placeholder circle stands in if a picture is missing.
class WordPicture extends StatelessWidget {
  const WordPicture({super.key, required this.wordId, this.size = 64});

  final String wordId;
  final double size;

  static String assetPath(String wordId) =>
      'assets/speech/pictures/$wordId.svg';

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: SvgPicture.asset(
          assetPath(wordId),
          fit: BoxFit.contain,
          placeholderBuilder: (_) => _placeholder(),
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      ),
    );
  }

  Widget _placeholder() => DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: SpeechColors.navySoft.withValues(alpha: 0.08),
        ),
      );
}
