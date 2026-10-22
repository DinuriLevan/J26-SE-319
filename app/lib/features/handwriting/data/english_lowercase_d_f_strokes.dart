import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';

const englishLowercaseDFStrokes = <String, CharacterStrokeDefinition>{
  'd': CharacterStrokeDefinition(
    character: 'd',
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
          start: Offset(0.64, 0.14),
          segments: [StrokeSegment.line(Offset(0.64, 0.82))],
          instruction: 'Draw the tall line down on the right.'),
    ],
  ),
  'e': CharacterStrokeDefinition(
    character: 'e',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.28, 0.58),
          segments: [
            StrokeSegment.line(Offset(0.68, 0.58)),
            StrokeSegment.cubic(
                control1: Offset(0.66, 0.34),
                control2: Offset(0.26, 0.34),
                end: Offset(0.24, 0.60)),
            StrokeSegment.cubic(
                control1: Offset(0.22, 0.84),
                control2: Offset(0.52, 0.86),
                end: Offset(0.70, 0.72))
          ],
          instruction: 'Go across, loop left, and curve around.')
    ],
  ),
  'f': CharacterStrokeDefinition(
    character: 'f',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.68, 0.20),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.52, 0.08),
                control2: Offset(0.40, 0.20),
                end: Offset(0.40, 0.34)),
            StrokeSegment.line(Offset(0.40, 0.88))
          ],
          instruction: 'Curve over at the top and draw down.'),
      StrokeDefinition(
          start: Offset(0.22, 0.46),
          segments: [StrokeSegment.line(Offset(0.64, 0.46))],
          instruction: 'Draw the short cross line.'),
    ],
  ),
};
