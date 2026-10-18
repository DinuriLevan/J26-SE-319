import 'package:flutter/material.dart';

import 'models/character_stroke_definition.dart';
import 'screens/character_demonstration_screen.dart';
import 'services/handwriting_classifier.dart';
import 'widgets/character_selection_view.dart';

// The 43 introductory Sinhala letters used by the supplied learning design.
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
  'ච',
  'ඡ',
  'ජ',
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
  'ඹ',
  'ය',
  'ර',
  'ල',
  'ව',
  'ශ',
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
        builder: (_) => CharacterDemonstrationScreen(
          character: character,
          language: HandwritingLanguage.sinhala,
          modelType: HandwritingModelType.sinhala,
        ),
      ),
    );
  }
}
