import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';

const englishUppercaseDFStrokes = <String, CharacterStrokeDefinition>{
  'D': CharacterStrokeDefinition(
    character: 'D',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.28, 0.12),
        segments: [StrokeSegment.line(Offset(0.28, 0.88))],
        instruction: 'Draw the straight line down.',
      ),
      StrokeDefinition(
        start: Offset(0.28, 0.12),
        segments: [
          StrokeSegment.cubic(
            control1: Offset(0.82, 0.10),
            control2: Offset(0.86, 0.88),
            end: Offset(0.28, 0.88),
          ),
        ],
        instruction: 'Curve from the top around to the bottom.',
      ),
    ],
  ),
  'E': CharacterStrokeDefinition(
    character: 'E',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.30, 0.12),
          segments: [StrokeSegment.line(Offset(0.30, 0.88))],
          instruction: 'Draw the straight line down.'),
      StrokeDefinition(
          start: Offset(0.30, 0.12),
          segments: [StrokeSegment.line(Offset(0.76, 0.12))],
          instruction: 'Draw the top line to the right.'),
      StrokeDefinition(
          start: Offset(0.30, 0.50),
          segments: [StrokeSegment.line(Offset(0.68, 0.50))],
          instruction: 'Draw the middle line to the right.'),
      StrokeDefinition(
          start: Offset(0.30, 0.88),
          segments: [StrokeSegment.line(Offset(0.76, 0.88))],
          instruction: 'Draw the bottom line to the right.'),
    ],
  ),
  'F': CharacterStrokeDefinition(
    character: 'F',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
          start: Offset(0.30, 0.12),
          segments: [StrokeSegment.line(Offset(0.30, 0.88))],
          instruction: 'Draw the straight line down.'),
      StrokeDefinition(
          start: Offset(0.30, 0.12),
          segments: [StrokeSegment.line(Offset(0.76, 0.12))],
          instruction: 'Draw the top line to the right.'),
      StrokeDefinition(
          start: Offset(0.30, 0.50),
          segments: [StrokeSegment.line(Offset(0.68, 0.50))],
          instruction: 'Draw the middle line to the right.'),
    ],
  ),
};
