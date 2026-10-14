import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';
import 'sinhala_consonants_group_four_strokes.dart';
import 'sinhala_consonants_group_one_strokes.dart';
import 'sinhala_consonants_group_three_strokes.dart';
import 'sinhala_consonants_group_two_strokes.dart';
import 'sinhala_vowels_group_one_strokes.dart';
import 'sinhala_vowels_group_two_strokes.dart';

/// Enables the temporary Sinhala-only alignment overlay on the demonstration
/// canvas. Set this to false once the paths have been approved by an educator.
const bool showSinhalaReferenceGlyph = true;

/// Normalized, single-pen teaching paths for the three Sinhala samples.
///
/// Sinhala handwriting guides describe each of these base characters as one
/// continuous pen stroke. The comments below split that uninterrupted motion
/// into its teaching phases without introducing artificial pen lifts.
const sinhalaStrokes = <String, CharacterStrokeDefinition>{
  'ක': CharacterStrokeDefinition(
    character: 'ක',
    language: HandwritingLanguage.sinhala,
    strokes: [
      StrokeDefinition(
        // Begin at the right side of the small upper loop.
        start: Offset(0.43, 0.29),
        segments: [
          // Make the small upper loop clockwise.
          StrokeSegment.cubic(
            control1: Offset(0.43, 0.34),
            control2: Offset(0.34, 0.35),
            end: Offset(0.31, 0.30),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.27, 0.23),
            control2: Offset(0.34, 0.18),
            end: Offset(0.39, 0.20),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.44, 0.21),
            control2: Offset(0.46, 0.26),
            end: Offset(0.43, 0.29),
          ),
          // Continue down around the lower-right hump.
          StrokeSegment.cubic(
            control1: Offset(0.54, 0.29),
            control2: Offset(0.61, 0.39),
            end: Offset(0.61, 0.53),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.61, 0.65),
            control2: Offset(0.54, 0.72),
            end: Offset(0.48, 0.64),
          ),
          // Round the lower-left hump and make its pointed left turn.
          StrokeSegment.cubic(
            control1: Offset(0.43, 0.56),
            control2: Offset(0.42, 0.69),
            end: Offset(0.34, 0.68),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.28, 0.67),
            control2: Offset(0.27, 0.58),
            end: Offset(0.20, 0.60),
          ),
          // Rise diagonally to the top junction.
          StrokeSegment.cubic(
            control1: Offset(0.27, 0.52),
            control2: Offset(0.36, 0.41),
            end: Offset(0.43, 0.29),
          ),
          // Finish with the broad outer curve on the right.
          StrokeSegment.cubic(
            control1: Offset(0.60, 0.21),
            control2: Offset(0.77, 0.30),
            end: Offset(0.79, 0.47),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.81, 0.61),
            control2: Offset(0.75, 0.71),
            end: Offset(0.68, 0.73),
          ),
        ],
        instruction:
            'Make the small loop, form the two lower curves, then sweep around the right side without lifting the pencil.',
      ),
    ],
  ),
  'ග': CharacterStrokeDefinition(
    character: 'ග',
    language: HandwritingLanguage.sinhala,
    strokes: [
      StrokeDefinition(
        // Begin at the top centre and move left into the first bowl.
        start: Offset(0.49, 0.25),
        segments: [
          StrokeSegment.cubic(
            control1: Offset(0.40, 0.20),
            control2: Offset(0.27, 0.22),
            end: Offset(0.20, 0.32),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.12, 0.44),
            control2: Offset(0.16, 0.64),
            end: Offset(0.29, 0.71),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.40, 0.78),
            control2: Offset(0.53, 0.71),
            end: Offset(0.54, 0.59),
          ),
          // Curl into the middle and rise to begin the right bowl.
          StrokeSegment.cubic(
            control1: Offset(0.55, 0.50),
            control2: Offset(0.51, 0.45),
            end: Offset(0.45, 0.47),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.47, 0.37),
            control2: Offset(0.48, 0.29),
            end: Offset(0.55, 0.25),
          ),
          // Draw the second bowl clockwise and finish at its lower inside edge.
          StrokeSegment.cubic(
            control1: Offset(0.67, 0.19),
            control2: Offset(0.80, 0.27),
            end: Offset(0.83, 0.42),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.87, 0.57),
            control2: Offset(0.81, 0.70),
            end: Offset(0.71, 0.75),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.65, 0.78),
            control2: Offset(0.59, 0.77),
            end: Offset(0.55, 0.73),
          ),
        ],
        instruction:
            'Curve around the left bowl, rise through the middle, then draw the right bowl in one flowing movement.',
      ),
    ],
  ),
  'අ': CharacterStrokeDefinition(
    character: 'අ',
    language: HandwritingLanguage.sinhala,
    strokes: [
      StrokeDefinition(
        // Begin at the left side of the small upper loop.
        start: Offset(0.30, 0.30),
        segments: [
          // Make the upper loop clockwise.
          StrokeSegment.cubic(
            control1: Offset(0.27, 0.24),
            control2: Offset(0.31, 0.19),
            end: Offset(0.39, 0.19),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.48, 0.19),
            control2: Offset(0.52, 0.24),
            end: Offset(0.50, 0.30),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.46, 0.34),
            control2: Offset(0.36, 0.34),
            end: Offset(0.30, 0.30),
          ),
          // Extend right, turn back sharply, and form the large left bowl.
          StrokeSegment.cubic(
            control1: Offset(0.41, 0.28),
            control2: Offset(0.54, 0.28),
            end: Offset(0.62, 0.31),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.53, 0.34),
            control2: Offset(0.37, 0.32),
            end: Offset(0.26, 0.36),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.14, 0.41),
            control2: Offset(0.15, 0.63),
            end: Offset(0.27, 0.69),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.38, 0.75),
            control2: Offset(0.54, 0.71),
            end: Offset(0.62, 0.68),
          ),
          // Rise along the upright, descend it, then retrace upward.
          StrokeSegment.cubic(
            control1: Offset(0.65, 0.59),
            control2: Offset(0.64, 0.42),
            end: Offset(0.64, 0.31),
          ),
          StrokeSegment.line(Offset(0.64, 0.80)),
          StrokeSegment.line(Offset(0.64, 0.30)),
          // Finish by circling clockwise around the small right bowl.
          StrokeSegment.cubic(
            control1: Offset(0.66, 0.21),
            control2: Offset(0.72, 0.18),
            end: Offset(0.77, 0.21),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.84, 0.25),
            control2: Offset(0.84, 0.37),
            end: Offset(0.78, 0.43),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.73, 0.48),
            control2: Offset(0.66, 0.45),
            end: Offset(0.64, 0.40),
          ),
        ],
        instruction:
            'Make the top loop and left bowl, trace the upright down and back up, then finish with the small right loop.',
      ),
    ],
  ),
  ...sinhalaVowelsGroupOneStrokes,
  ...sinhalaVowelsGroupTwoStrokes,
  ...sinhalaConsonantsGroupOneStrokes,
  ...sinhalaConsonantsGroupTwoStrokes,
  ...sinhalaConsonantsGroupThreeStrokes,
  ...sinhalaConsonantsGroupFourStrokes,
};
