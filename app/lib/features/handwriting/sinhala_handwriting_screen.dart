import 'package:flutter/material.dart';

import 'letter_demonstration_screen.dart';
import 'widgets/character_selection_view.dart';

// The 44 introductory Sinhala letters used by the supplied learning design.
const _sinhalaVowels = [
  'අ',
  'ආ',
  'ඇ',
  'ඈ',
  'ඉ',
  'ඊ',
  'උ',
  'ඌ',
  'එ',
  'ඒ',
  'ඔ',
  'ඕ',
];

const _sinhalaConsonants = [
  'ක',
  'ඛ',
  'ග',
  'ඝ',
  'ඞ',
  'ච',
  'ඡ',
  'ජ',
  'ඣ',
  'ඤ',
  'ට',
  'ඨ',
  'ඩ',
  'ඪ',
  'ණ',
  'ත',
  'ථ',
  'ද',
  'ධ',
  'න',
  'ප',
  'ඵ',
  'බ',
  'භ',
  'ම',
  'ය',
  'ර',
  'ල',
  'ව',
  'ස',
  'හ',
  'ළ',
];

class SinhalaHandwritingScreen extends StatelessWidget {
  const SinhalaHandwritingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('සිංහල Handwriting')),
      body: SafeArea(
        child: CharacterSelectionView(
          sections: const [
            CharacterSectionData(
              title: 'ස්වර (Vowels)',
              characters: _sinhalaVowels,
            ),
            CharacterSectionData(
              title: 'ව්‍යංජන (Consonants)',
              characters: _sinhalaConsonants,
            ),
          ],
          onCharacterSelected: (character) =>
              _openDemonstration(context, character),
        ),
      ),
    );
  }

  void _openDemonstration(BuildContext context, String character) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LetterDemonstrationScreen(character: character),
      ),
    );
  }
}
