import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';

const englishLowercaseGLStrokes = <String, CharacterStrokeDefinition>{
  'g': CharacterStrokeDefinition(
    character: 'g',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.62, 0.42),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.48, 0.30),
                control2: Offset(0.24, 0.36),
                end: Offset(0.24, 0.62)),
            StrokeSegment.cubic(
                control1: Offset(0.24, 0.84),
                control2: Offset(0.60, 0.86),
                end: Offset(0.62, 0.62)),
            StrokeSegment.cubic(
                control1: Offset(0.62, 0.46),
                control2: Offset(0.54, 0.38),
                end: Offset(0.44, 0.40))
          ],
          instruction: 'Make the round bowl.'),
      StrokeDefinition(
          start: Offset(0.64, 0.40),
          segments: [
            StrokeSegment.line(Offset(0.64, 0.84)),
            StrokeSegment.cubic(
                control1: Offset(0.64, 0.98),
                control2: Offset(0.32, 1.00),
                end: Offset(0.30, 0.84))
          ],
          instruction: 'Draw down below the line and curve left.'),
    ],
  ),
  'h': CharacterStrokeDefinition(
    character: 'h',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.28, 0.14),
          segments: [StrokeSegment.line(Offset(0.28, 0.84))],
          instruction: 'Draw the tall line down.'),
      StrokeDefinition(
          start: Offset(0.28, 0.52),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.44, 0.34),
                control2: Offset(0.68, 0.40),
                end: Offset(0.68, 0.58)),
            StrokeSegment.line(Offset(0.68, 0.84))
          ],
          instruction: 'Curve over the hump, then draw down.'),
    ],
  ),
  'i': CharacterStrokeDefinition(
    character: 'i',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.50, 0.42),
          segments: [StrokeSegment.line(Offset(0.50, 0.82))],
          instruction: 'Draw the short line down.'),
      StrokeDefinition(
          start: Offset(0.50, 0.25),
          segments: [StrokeSegment.line(Offset(0.50, 0.27))],
          instruction: 'Add the dot above.'),
    ],
  ),
  'j': CharacterStrokeDefinition(
    character: 'j',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.58, 0.42),
          segments: [
            StrokeSegment.line(Offset(0.58, 0.80)),
            StrokeSegment.cubic(
                control1: Offset(0.58, 0.98),
                control2: Offset(0.30, 0.98),
                end: Offset(0.28, 0.82))
          ],
          instruction: 'Draw down below the line and curve left.'),
      StrokeDefinition(
          start: Offset(0.58, 0.25),
          segments: [StrokeSegment.line(Offset(0.58, 0.27))],
          instruction: 'Add the dot above.'),
    ],
  ),
  'k': CharacterStrokeDefinition(
    character: 'k',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.28, 0.14),
          segments: [StrokeSegment.line(Offset(0.28, 0.84))],
          instruction: 'Draw the tall line down.'),
      StrokeDefinition(
          start: Offset(0.68, 0.40),
          segments: [StrokeSegment.line(Offset(0.28, 0.62))],
          instruction: 'Draw diagonally down to the middle.'),
      StrokeDefinition(
          start: Offset(0.38, 0.56),
          segments: [StrokeSegment.line(Offset(0.72, 0.84))],
          instruction: 'Draw diagonally down to the right.'),
    ],
  ),
  'l': CharacterStrokeDefinition(
    character: 'l',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.50, 0.14),
          segments: [StrokeSegment.line(Offset(0.50, 0.84))],
          instruction: 'Draw the tall line straight down.')
    ],
  ),
};
