import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';

const englishUppercaseSZStrokes = <String, CharacterStrokeDefinition>{
  'S': CharacterStrokeDefinition(
    character: 'S',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.76, 0.22),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.56, 0.04),
                control2: Offset(0.20, 0.14),
                end: Offset(0.24, 0.40)),
            StrokeSegment.cubic(
                control1: Offset(0.28, 0.58),
                control2: Offset(0.78, 0.44),
                end: Offset(0.76, 0.70)),
            StrokeSegment.cubic(
                control1: Offset(0.74, 0.94),
                control2: Offset(0.32, 0.96),
                end: Offset(0.20, 0.78))
          ],
          instruction: 'Curve left, then right, then left to make the S.')
    ],
  ),
  'T': CharacterStrokeDefinition(
    character: 'T',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.18, 0.12),
          segments: [StrokeSegment.line(Offset(0.82, 0.12))],
          instruction: 'Draw the top line to the right.'),
      StrokeDefinition(
          start: Offset(0.50, 0.12),
          segments: [StrokeSegment.line(Offset(0.50, 0.88))],
          instruction: 'Draw straight down the middle.'),
    ],
  ),
  'U': CharacterStrokeDefinition(
    character: 'U',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.22, 0.12),
          segments: [
            StrokeSegment.line(Offset(0.22, 0.66)),
            StrokeSegment.cubic(
                control1: Offset(0.22, 0.96),
                control2: Offset(0.78, 0.96),
                end: Offset(0.78, 0.66)),
            StrokeSegment.line(Offset(0.78, 0.12))
          ],
          instruction:
              'Draw down, curve around the bottom, and rise on the right.')
    ],
  ),
  'V': CharacterStrokeDefinition(
    character: 'V',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.18, 0.12),
          segments: [StrokeSegment.line(Offset(0.50, 0.88))],
          instruction: 'Draw diagonally down to the middle.'),
      StrokeDefinition(
          start: Offset(0.50, 0.88),
          segments: [StrokeSegment.line(Offset(0.82, 0.12))],
          instruction: 'Draw diagonally up to the right.'),
    ],
  ),
  'W': CharacterStrokeDefinition(
    character: 'W',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.12, 0.12),
          segments: [
            StrokeSegment.line(Offset(0.30, 0.88)),
            StrokeSegment.line(Offset(0.50, 0.48)),
            StrokeSegment.line(Offset(0.70, 0.88)),
            StrokeSegment.line(Offset(0.88, 0.12))
          ],
          instruction: 'Draw down, up, down, and up to make the W.')
    ],
  ),
  'X': CharacterStrokeDefinition(
    character: 'X',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.20, 0.12),
          segments: [StrokeSegment.line(Offset(0.80, 0.88))],
          instruction: 'Draw diagonally down to the right.'),
      StrokeDefinition(
          start: Offset(0.80, 0.12),
          segments: [StrokeSegment.line(Offset(0.20, 0.88))],
          instruction: 'Draw diagonally down to the left.'),
    ],
  ),
  'Y': CharacterStrokeDefinition(
    character: 'Y',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.18, 0.12),
          segments: [StrokeSegment.line(Offset(0.50, 0.50))],
          instruction: 'Draw diagonally down to the middle.'),
      StrokeDefinition(
          start: Offset(0.82, 0.12),
          segments: [StrokeSegment.line(Offset(0.50, 0.50))],
          instruction: 'Draw diagonally down from the right.'),
      StrokeDefinition(
          start: Offset(0.50, 0.50),
          segments: [StrokeSegment.line(Offset(0.50, 0.88))],
          instruction: 'Draw the stem straight down.'),
    ],
  ),
  'Z': CharacterStrokeDefinition(
    character: 'Z',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.20, 0.12),
          segments: [
            StrokeSegment.line(Offset(0.80, 0.12)),
            StrokeSegment.line(Offset(0.20, 0.88)),
            StrokeSegment.line(Offset(0.80, 0.88))
          ],
          instruction: 'Draw right, diagonally down left, then right.')
    ],
  ),
};
