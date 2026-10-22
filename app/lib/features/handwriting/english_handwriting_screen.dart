import 'package:flutter/material.dart';

import 'models/character_stroke_definition.dart';
import 'screens/character_demonstration_screen.dart';
import 'screens/english_handwriting_result_screen.dart';
import 'services/handwriting_classifier.dart';
import 'widgets/character_selection_view.dart';

const _englishLetters = [
  'A',
  'B',
  'C',
  'D',
  'E',
  'F',
  'G',
  'H',
  'I',
  'J',
  'K',
  'L',
  'M',
  'N',
  'O',
  'P',
  'Q',
  'R',
  'S',
  'T',
  'U',
  'V',
  'W',
  'X',
  'Y',
  'Z',
];

const _letterEmojis = [
  '🍎',
  '⚽',
  '🐱',
  '🐶',
  '🥚',
  '🐟',
  '🍇',
  '🎩',
  '🍦',
  '🫙',
  '🪁',
  '🦁',
  '🌙',
  '🪺',
  '🍊',
  '🐷',
  '👸',
  '🌧️',
  '☀️',
  '🌳',
  '☂️',
  '🚐',
  '⌚',
  '🩻',
  '🪀',
  '🦓',
];

const _letterWords = [
  'Apple',
  'Ball',
  'Cat',
  'Dog',
  'Egg',
  'Fish',
  'Grapes',
  'Hat',
  'Ice cream',
  'Jar',
  'Kite',
  'Lion',
  'Moon',
  'Nest',
  'Orange',
  'Pig',
  'Queen',
  'Rain',
  'Sun',
  'Tree',
  'Umbrella',
  'Van',
  'Watch',
  'X-ray',
  'Yo-yo',
  'Zebra',
];

class EnglishHandwritingScreen extends StatelessWidget {
  const EnglishHandwritingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('English Handwriting')),
      body: SafeArea(
        child: CharacterSelectionView(
          sections: [
            const CharacterSectionData(
              title: 'Uppercase',
              characters: _englishLetters,
              emojis: _letterEmojis,
            ),
            CharacterSectionData(
              title: 'Lowercase',
              characters: _englishLetters
                  .map((letter) => letter.toLowerCase())
                  .toList(growable: false),
              emojis: _letterEmojis,
            ),
          ],
          onCharacterSelected: (character) =>
              _openDemonstration(context, character),
        ),
      ),
    );
  }

  Future<void> _openDemonstration(
    BuildContext context,
    String character,
  ) async {
    final letterIndex = _englishLetters.indexOf(character.toUpperCase());
    final action =
        await Navigator.of(context).push<EnglishHandwritingResultAction>(
      MaterialPageRoute<EnglishHandwritingResultAction>(
        builder: (_) => CharacterDemonstrationScreen(
          character: character,
          language: HandwritingLanguage.english,
          modelType: character == character.toUpperCase()
              ? HandwritingModelType.englishUppercase
              : HandwritingModelType.englishLowercase,
          emoji: _letterEmojis[letterIndex],
          exampleWord: _letterWords[letterIndex],
        ),
      ),
    );
    if (!context.mounted ||
        action != EnglishHandwritingResultAction.nextLetter) {
      return;
    }
    final nextCharacter = _nextCharacter(character);
    if (nextCharacter != null) {
      await _openDemonstration(context, nextCharacter);
    }
  }

  String? _nextCharacter(String character) {
    final uppercase = character == character.toUpperCase();
    final letters = uppercase
        ? _englishLetters
        : _englishLetters
            .map((letter) => letter.toLowerCase())
            .toList(growable: false);
    final index = letters.indexOf(character);
    return index >= 0 && index < letters.length - 1 ? letters[index + 1] : null;
  }
}
