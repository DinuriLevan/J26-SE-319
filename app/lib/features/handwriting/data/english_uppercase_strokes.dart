import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';
import 'english_uppercase_d_f_strokes.dart';
import 'english_uppercase_g_l_strokes.dart';
import 'english_uppercase_m_r_strokes.dart';
import 'english_uppercase_s_z_strokes.dart';

const englishUppercaseStrokes = <String, CharacterStrokeDefinition>{
  'A': CharacterStrokeDefinition(
    character: 'A',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.5, 0.12),
        segments: [StrokeSegment.line(Offset(0.2, 0.88))],
        instruction: 'Start at the top and draw down to the left.',
      ),
      StrokeDefinition(
        start: Offset(0.5, 0.12),
        segments: [StrokeSegment.line(Offset(0.8, 0.88))],
        instruction: 'Start at the top and draw down to the right.',
      ),
      StrokeDefinition(
        start: Offset(0.32, 0.6),
        segments: [StrokeSegment.line(Offset(0.68, 0.6))],
        instruction: 'Draw the middle line from left to right.',
      ),
    ],
  ),
  'B': CharacterStrokeDefinition(
    character: 'B',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.28, 0.12),
        segments: [StrokeSegment.line(Offset(0.28, 0.88))],
        instruction: 'Start at the top and draw straight down.',
      ),
      StrokeDefinition(
        start: Offset(0.28, 0.12),
        segments: [
          StrokeSegment.cubic(
            control1: Offset(0.78, 0.1),
            control2: Offset(0.78, 0.49),
            end: Offset(0.28, 0.5),
          ),
        ],
        instruction: 'Go right and around to make the top curve.',
      ),
      StrokeDefinition(
        start: Offset(0.28, 0.5),
        segments: [
          StrokeSegment.cubic(
            control1: Offset(0.84, 0.5),
            control2: Offset(0.84, 0.9),
            end: Offset(0.28, 0.88),
          ),
        ],
        instruction: 'Go right and around to make the bottom curve.',
      ),
    ],
  ),
  'C': CharacterStrokeDefinition(
    character: 'C',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.78, 0.25),
        segments: [
          StrokeSegment.cubic(
            control1: Offset(0.62, 0.08),
            control2: Offset(0.25, 0.1),
            end: Offset(0.2, 0.48),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.15, 0.8),
            control2: Offset(0.48, 0.96),
            end: Offset(0.78, 0.76),
          ),
        ],
        instruction:
            'Start at the top right and curve around to the bottom right.',
      ),
    ],
  ),
  ...englishUppercaseDFStrokes,
  ...englishUppercaseGLStrokes,
  ...englishUppercaseMRStrokes,
  ...englishUppercaseSZStrokes,
};
