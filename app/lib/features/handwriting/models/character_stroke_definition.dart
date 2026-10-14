import 'stroke_definition.dart';

enum HandwritingLanguage { english, sinhala }

class CharacterStrokeDefinition {
  const CharacterStrokeDefinition({
    required this.character,
    required this.language,
    required this.strokes,
  });

  final String character;
  final HandwritingLanguage language;
  final List<StrokeDefinition> strokes;
}
