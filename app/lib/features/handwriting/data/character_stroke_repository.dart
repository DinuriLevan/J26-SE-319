import '../models/character_stroke_definition.dart';
import 'english_lowercase_strokes.dart';
import 'english_uppercase_strokes.dart';
import 'sinhala_strokes.dart';

class CharacterStrokeRepository {
  const CharacterStrokeRepository._();

  static CharacterStrokeDefinition? find({
    required String character,
    required HandwritingLanguage language,
  }) {
    return switch (language) {
      HandwritingLanguage.english => englishUppercaseStrokes[character] ??
          englishLowercaseStrokes[character],
      HandwritingLanguage.sinhala => sinhalaStrokes[character],
    };
  }
}
