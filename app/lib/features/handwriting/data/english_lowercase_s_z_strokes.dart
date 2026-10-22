import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';

const englishLowercaseSZStrokes = <String, CharacterStrokeDefinition>{
  's': CharacterStrokeDefinition(
    character: 's',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.68, 0.46),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.54, 0.34),
                control2: Offset(0.28, 0.40),
                end: Offset(0.30, 0.56)),
            StrokeSegment.cubic(
                control1: Offset(0.32, 0.68),
                control2: Offset(0.70, 0.60),
                end: Offset(0.68, 0.74)),
            StrokeSegment.cubic(
                control1: Offset(0.66, 0.88),
                control2: Offset(0.34, 0.88),
                end: Offset(0.26, 0.78))
          ],
          instruction: 'Curve left, right, and left to make the small s.')
    ],
  ),
  't': CharacterStrokeDefinition(
    character: 't',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.48, 0.24),
          segments: [
            StrokeSegment.line(Offset(0.48, 0.78)),
            StrokeSegment.cubic(
                control1: Offset(0.48, 0.86),
                control2: Offset(0.60, 0.86),
                end: Offset(0.66, 0.80))
          ],
          instruction: 'Draw down and finish with a small curve.'),
      StrokeDefinition(
          start: Offset(0.28, 0.46),
          segments: [StrokeSegment.line(Offset(0.68, 0.46))],
          instruction: 'Draw the short cross line.'),
    ],
  ),
  'u': CharacterStrokeDefinition(
    character: 'u',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.28, 0.42),
          segments: [
            StrokeSegment.line(Offset(0.28, 0.68)),
            StrokeSegment.cubic(
                control1: Offset(0.28, 0.88),
                control2: Offset(0.66, 0.88),
                end: Offset(0.66, 0.68)),
            StrokeSegment.line(Offset(0.66, 0.42)),
            StrokeSegment.line(Offset(0.66, 0.84))
          ],
          instruction: 'Draw down, curve around, rise, then finish down.')
    ],
  ),
  'v': CharacterStrokeDefinition(
    character: 'v',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.24, 0.42),
          segments: [
            StrokeSegment.line(Offset(0.50, 0.84)),
            StrokeSegment.line(Offset(0.76, 0.42))
          ],
          instruction: 'Draw down to a point, then up to the right.')
    ],
  ),
  'w': CharacterStrokeDefinition(
    character: 'w',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.14, 0.42),
          segments: [
            StrokeSegment.line(Offset(0.30, 0.84)),
            StrokeSegment.line(Offset(0.50, 0.56)),
            StrokeSegment.line(Offset(0.70, 0.84)),
            StrokeSegment.line(Offset(0.86, 0.42))
          ],
          instruction: 'Draw down, up, down, and up to make the w.')
    ],
  ),
  'x': CharacterStrokeDefinition(
    character: 'x',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.28, 0.42),
          segments: [StrokeSegment.line(Offset(0.72, 0.84))],
          instruction: 'Draw diagonally down to the right.'),
      StrokeDefinition(
          start: Offset(0.72, 0.42),
          segments: [StrokeSegment.line(Offset(0.28, 0.84))],
          instruction: 'Draw diagonally down to the left.'),
    ],
  ),
  'y': CharacterStrokeDefinition(
    character: 'y',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.24, 0.42),
          segments: [
            StrokeSegment.line(Offset(0.48, 0.76)),
            StrokeSegment.line(Offset(0.70, 0.42))
          ],
          instruction: 'Draw down to the middle and up to the right.'),
      StrokeDefinition(
          start: Offset(0.70, 0.42),
          segments: [
            StrokeSegment.line(Offset(0.52, 0.86)),
            StrokeSegment.cubic(
                control1: Offset(0.46, 1.00),
                control2: Offset(0.26, 0.96),
                end: Offset(0.24, 0.86))
          ],
          instruction: 'Draw the tail down and curve left.')
    ],
  ),
  'z': CharacterStrokeDefinition(
    character: 'z',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.26, 0.42),
          segments: [
            StrokeSegment.line(Offset(0.72, 0.42)),
            StrokeSegment.line(Offset(0.26, 0.84)),
            StrokeSegment.line(Offset(0.74, 0.84))
          ],
          instruction: 'Draw right, diagonally down left, then right.')
    ],
  ),
};
