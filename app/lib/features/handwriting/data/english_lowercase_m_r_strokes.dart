import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';

const englishLowercaseMRStrokes = <String, CharacterStrokeDefinition>{
  'm': CharacterStrokeDefinition(
    character: 'm',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.20, 0.42),
          segments: [StrokeSegment.line(Offset(0.20, 0.84))],
          instruction: 'Draw the short line down.'),
      StrokeDefinition(
          start: Offset(0.20, 0.54),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.30, 0.38),
                control2: Offset(0.46, 0.42),
                end: Offset(0.46, 0.58)),
            StrokeSegment.line(Offset(0.46, 0.84)),
            StrokeSegment.line(Offset(0.46, 0.56)),
            StrokeSegment.cubic(
                control1: Offset(0.56, 0.38),
                control2: Offset(0.74, 0.42),
                end: Offset(0.74, 0.58)),
            StrokeSegment.line(Offset(0.74, 0.84))
          ],
          instruction: 'Make two rounded humps from left to right.'),
    ],
  ),
  'n': CharacterStrokeDefinition(
    character: 'n',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.28, 0.42),
          segments: [StrokeSegment.line(Offset(0.28, 0.84))],
          instruction: 'Draw the short line down.'),
      StrokeDefinition(
          start: Offset(0.28, 0.54),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.42, 0.36),
                control2: Offset(0.68, 0.40),
                end: Offset(0.68, 0.58)),
            StrokeSegment.line(Offset(0.68, 0.84))
          ],
          instruction: 'Make one rounded hump and draw down.'),
    ],
  ),
  'o': CharacterStrokeDefinition(
    character: 'o',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.50, 0.40),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.22, 0.38),
                control2: Offset(0.20, 0.82),
                end: Offset(0.50, 0.84)),
            StrokeSegment.cubic(
                control1: Offset(0.80, 0.82),
                control2: Offset(0.78, 0.38),
                end: Offset(0.50, 0.40))
          ],
          instruction: 'Start at the top and make a small oval.')
    ],
  ),
  'p': CharacterStrokeDefinition(
    character: 'p',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.30, 0.42),
          segments: [StrokeSegment.line(Offset(0.30, 0.98))],
          instruction: 'Draw down below the writing line.'),
      StrokeDefinition(
          start: Offset(0.30, 0.48),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.66, 0.34),
                control2: Offset(0.78, 0.76),
                end: Offset(0.30, 0.78))
          ],
          instruction: 'Curve right and around to make the bowl.'),
    ],
  ),
  'q': CharacterStrokeDefinition(
    character: 'q',
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
          start: Offset(0.64, 0.42),
          segments: [StrokeSegment.line(Offset(0.64, 0.98))],
          instruction: 'Draw the right line down below the writing line.'),
    ],
  ),
  'r': CharacterStrokeDefinition(
    character: 'r',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.30, 0.42),
          segments: [StrokeSegment.line(Offset(0.30, 0.84))],
          instruction: 'Draw the short line down.'),
      StrokeDefinition(
          start: Offset(0.30, 0.54),
          segments: [
            StrokeSegment.cubic(
                control1: Offset(0.42, 0.38),
                control2: Offset(0.62, 0.40),
                end: Offset(0.66, 0.50))
          ],
          instruction: 'Curve up and over to make the shoulder.'),
    ],
  ),
};
