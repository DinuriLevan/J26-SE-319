import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';
import 'english_lowercase_d_f_strokes.dart';
import 'english_lowercase_g_l_strokes.dart';
import 'english_lowercase_m_r_strokes.dart';
import 'english_lowercase_s_z_strokes.dart';

const englishLowercaseStrokes = <String, CharacterStrokeDefinition>{
  'a': CharacterStrokeDefinition(
    character: 'a',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.62, 0.42),
        segments: [
          StrokeSegment.cubic(
            control1: Offset(0.48, 0.3),
            control2: Offset(0.25, 0.36),
            end: Offset(0.25, 0.62),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.25, 0.84),
            control2: Offset(0.6, 0.86),
            end: Offset(0.62, 0.62),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.62, 0.45),
            control2: Offset(0.55, 0.38),
            end: Offset(0.45, 0.4),
          ),
        ],
        instruction: 'Start near the top and make a round circle.',
      ),
      StrokeDefinition(
        start: Offset(0.64, 0.4),
        segments: [StrokeSegment.line(Offset(0.64, 0.82))],
        instruction: 'Draw a short line down on the right.',
      ),
    ],
  ),
  'b': CharacterStrokeDefinition(
    character: 'b',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.32, 0.14),
        segments: [StrokeSegment.line(Offset(0.32, 0.84))],
        instruction: 'Start at the top and draw straight down.',
      ),
      StrokeDefinition(
        start: Offset(0.32, 0.48),
        segments: [
          StrokeSegment.cubic(
            control1: Offset(0.7, 0.34),
            control2: Offset(0.78, 0.76),
            end: Offset(0.32, 0.8),
          ),
        ],
        instruction: 'Go right and around to make the belly.',
      ),
    ],
  ),
  'c': CharacterStrokeDefinition(
    character: 'c',
    language: HandwritingLanguage.english,
    strokes: [
      StrokeDefinition(
        start: Offset(0.7, 0.45),
        segments: [
          StrokeSegment.cubic(
            control1: Offset(0.48, 0.3),
            control2: Offset(0.22, 0.4),
            end: Offset(0.24, 0.62),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.26, 0.82),
            control2: Offset(0.52, 0.86),
            end: Offset(0.7, 0.72),
          ),
        ],
        instruction: 'Start at the top right and curve around.',
      ),
    ],
  ),
  ...englishLowercaseDFStrokes,
  ...englishLowercaseGLStrokes,
  ...englishLowercaseMRStrokes,
  ...englishLowercaseSZStrokes,
};
