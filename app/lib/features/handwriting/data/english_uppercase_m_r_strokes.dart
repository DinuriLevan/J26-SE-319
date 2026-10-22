import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';

const englishUppercaseMRStrokes = <String, CharacterStrokeDefinition>{
  'M': CharacterStrokeDefinition(
    character: 'M',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.18, 0.88),
          segments: [StrokeSegment.line(Offset(0.18, 0.12))],
          instruction: 'Draw the left line upward.'),
      StrokeDefinition(
          start: Offset(0.18, 0.12),
          segments: [StrokeSegment.line(Offset(0.50, 0.58))],
          instruction: 'Draw diagonally down to the middle.'),
      StrokeDefinition(
          start: Offset(0.50, 0.58),
          segments: [StrokeSegment.line(Offset(0.82, 0.12))],
          instruction: 'Draw diagonally up to the right.'),
      StrokeDefinition(
          start: Offset(0.82, 0.12),
          segments: [StrokeSegment.line(Offset(0.82, 0.88))],
          instruction: 'Draw the right line downward.'),
    ],
  ),
  'N': CharacterStrokeDefinition(
    character: 'N',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.22, 0.88),
          segments: [StrokeSegment.line(Offset(0.22, 0.12))],
          instruction: 'Draw the left line upward.'),
      StrokeDefinition(
          start: Offset(0.22, 0.12),
          segments: [StrokeSegment.line(Offset(0.78, 0.88))],
          instruction: 'Draw diagonally down to the right.'),
      StrokeDefinition(
          start: Offset(0.78, 0.88),
          segments: [StrokeSegment.line(Offset(0.78, 0.12))],
          instruction: 'Draw the right line upward.'),
    ],
  ),
  'O': CharacterStrokeDefinition(
    character: 'O',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.50, 0.12),
        segments: [
          StrokeSegment.cubic(
              control1: Offset(0.16, 0.12),
              control2: Offset(0.14, 0.88),
              end: Offset(0.50, 0.88)),
          StrokeSegment.cubic(
              control1: Offset(0.86, 0.88),
              control2: Offset(0.84, 0.12),
              end: Offset(0.50, 0.12)),
        ],
        instruction: 'Start at the top and make one large oval.',
      ),
    ],
  ),
  'P': CharacterStrokeDefinition(
    character: 'P',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.28, 0.12),
          segments: [StrokeSegment.line(Offset(0.28, 0.88))],
          instruction: 'Draw the straight line down.'),
      StrokeDefinition(
        start: Offset(0.28, 0.12),
        segments: [
          StrokeSegment.cubic(
              control1: Offset(0.80, 0.10),
              control2: Offset(0.80, 0.52),
              end: Offset(0.28, 0.52))
        ],
        instruction: 'Curve right and around to make the top bowl.',
      ),
    ],
  ),
  'Q': CharacterStrokeDefinition(
    character: 'Q',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.50, 0.12),
        segments: [
          StrokeSegment.cubic(
              control1: Offset(0.16, 0.12),
              control2: Offset(0.14, 0.88),
              end: Offset(0.50, 0.88)),
          StrokeSegment.cubic(
              control1: Offset(0.86, 0.88),
              control2: Offset(0.84, 0.12),
              end: Offset(0.50, 0.12)),
        ],
        instruction: 'Start at the top and make one large oval.',
      ),
      StrokeDefinition(
          start: Offset(0.58, 0.68),
          segments: [StrokeSegment.line(Offset(0.82, 0.92))],
          instruction: 'Add the short diagonal tail.'),
    ],
  ),
  'R': CharacterStrokeDefinition(
    character: 'R',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.28, 0.12),
          segments: [StrokeSegment.line(Offset(0.28, 0.88))],
          instruction: 'Draw the straight line down.'),
      StrokeDefinition(
          start: Offset(0.28, 0.12),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.80, 0.10),
                control2: Offset(0.80, 0.52),
                end: Offset(0.28, 0.52))
          ],
          instruction: 'Curve right and around to make the top bowl.'),
      StrokeDefinition(
          start: Offset(0.48, 0.52),
          segments: [StrokeSegment.line(Offset(0.80, 0.88))],
          instruction: 'Draw the diagonal leg down to the right.'),
    ],
  ),
};
