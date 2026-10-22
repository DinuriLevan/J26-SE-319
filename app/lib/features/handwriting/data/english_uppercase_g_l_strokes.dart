import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';

const englishUppercaseGLStrokes = <String, CharacterStrokeDefinition>{
  'G': CharacterStrokeDefinition(
    character: 'G',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.78, 0.25),
        segments: [
          StrokeSegment.cubic(
              control1: Offset(0.62, 0.08),
              control2: Offset(0.25, 0.10),
              end: Offset(0.20, 0.48)),
          StrokeSegment.cubic(
              control1: Offset(0.15, 0.80),
              control2: Offset(0.48, 0.96),
              end: Offset(0.78, 0.76)),
        ],
        instruction: 'Curve around from the top right to the bottom right.',
      ),
      StrokeDefinition(
        start: Offset(0.78, 0.76),
        segments: [
          StrokeSegment.line(Offset(0.78, 0.54)),
          StrokeSegment.line(Offset(0.56, 0.54))
        ],
        instruction: 'Draw up, then left to finish the G.',
      ),
    ],
  ),
  'H': CharacterStrokeDefinition(
    character: 'H',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.25, 0.12),
          segments: [StrokeSegment.line(Offset(0.25, 0.88))],
          instruction: 'Draw the left line down.'),
      StrokeDefinition(
          start: Offset(0.75, 0.12),
          segments: [StrokeSegment.line(Offset(0.75, 0.88))],
          instruction: 'Draw the right line down.'),
      StrokeDefinition(
          start: Offset(0.25, 0.50),
          segments: [StrokeSegment.line(Offset(0.75, 0.50))],
          instruction: 'Join the sides across the middle.'),
    ],
  ),
  'I': CharacterStrokeDefinition(
    character: 'I',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.30, 0.12),
          segments: [StrokeSegment.line(Offset(0.70, 0.12))],
          instruction: 'Draw the top line to the right.'),
      StrokeDefinition(
          start: Offset(0.50, 0.12),
          segments: [StrokeSegment.line(Offset(0.50, 0.88))],
          instruction: 'Draw straight down the middle.'),
      StrokeDefinition(
          start: Offset(0.30, 0.88),
          segments: [StrokeSegment.line(Offset(0.70, 0.88))],
          instruction: 'Draw the bottom line to the right.'),
    ],
  ),
  'J': CharacterStrokeDefinition(
    character: 'J',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.28, 0.12),
          segments: [StrokeSegment.line(Offset(0.76, 0.12))],
          instruction: 'Draw the top line to the right.'),
      StrokeDefinition(
        start: Offset(0.66, 0.12),
        segments: [
          StrokeSegment.line(Offset(0.66, 0.70)),
          StrokeSegment.cubic(
              control1: Offset(0.66, 0.92),
              control2: Offset(0.26, 0.94),
              end: Offset(0.24, 0.70)),
        ],
        instruction: 'Draw down and curve left at the bottom.',
      ),
    ],
  ),
  'K': CharacterStrokeDefinition(
    character: 'K',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.28, 0.12),
          segments: [StrokeSegment.line(Offset(0.28, 0.88))],
          instruction: 'Draw the straight line down.'),
      StrokeDefinition(
          start: Offset(0.76, 0.12),
          segments: [StrokeSegment.line(Offset(0.28, 0.52))],
          instruction: 'Draw diagonally down to the middle.'),
      StrokeDefinition(
          start: Offset(0.28, 0.52),
          segments: [StrokeSegment.line(Offset(0.78, 0.88))],
          instruction: 'Draw diagonally down to the right.'),
    ],
  ),
  'L': CharacterStrokeDefinition(
    character: 'L',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.30, 0.12),
        segments: [
          StrokeSegment.line(Offset(0.30, 0.88)),
          StrokeSegment.line(Offset(0.76, 0.88))
        ],
        instruction: 'Draw down, then across to the right.',
      ),
    ],
  ),
};
