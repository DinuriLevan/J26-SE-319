import 'package:flutter/material.dart';

import 'models/character_stroke_definition.dart';
import 'screens/character_demonstration_screen.dart';
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

  void _openDemonstration(BuildContext context, String character) {
    final letterIndex = _englishLetters.indexOf(character.toUpperCase());
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CharacterDemonstrationScreen(
          character: character,
          language: HandwritingLanguage.english,
          emoji: _letterEmojis[letterIndex],
          exampleWord: _letterWords[letterIndex],
        ),
      ),
    );
  }
}
