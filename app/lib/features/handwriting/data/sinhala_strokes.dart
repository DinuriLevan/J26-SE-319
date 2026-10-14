import 'dart:ui';

import '../models/character_stroke_definition.dart';
import '../models/stroke_definition.dart';
import 'sinhala_consonants_group_four_strokes.dart';
import 'sinhala_consonants_group_one_strokes.dart';
import 'sinhala_consonants_group_three_strokes.dart';
import 'sinhala_consonants_group_two_strokes.dart';
import 'sinhala_vowels_group_one_strokes.dart';
import 'sinhala_vowels_group_two_strokes.dart';

/// Enables the Sinhala-only alignment overlay for internal path debugging.
/// Production demonstrations must begin on a clean writing area.
const bool showSinhalaReferenceGlyph = false;

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
        // Begin at the upper loop, then continue through the entire character
        // as one natural pen movement.
        start: Offset(0.463, 0.244),
        segments: [
          // Form the compact upper loop clockwise.
          StrokeSegment.cubic(
            control1: Offset(0.495, 0.253),
            control2: Offset(0.497, 0.302),
            end: Offset(0.451, 0.313),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.414, 0.310),
            control2: Offset(0.411, 0.263),
            end: Offset(0.463, 0.244),
          ),
          // Sweep right, reverse gently, and enter the broad left bowl.
          StrokeSegment.cubic(
            control1: Offset(0.511, 0.238),
            control2: Offset(0.558, 0.270),
            end: Offset(0.570, 0.327),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.532, 0.333),
            control2: Offset(0.451, 0.334),
            end: Offset(0.405, 0.352),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.316, 0.389),
            control2: Offset(0.316, 0.519),
            end: Offset(0.405, 0.568),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.468, 0.594),
            control2: Offset(0.569, 0.574),
            end: Offset(0.626, 0.577),
          ),
          // Turn down, make the long stem, and retrace it upward.
          StrokeSegment.cubic(
            control1: Offset(0.602, 0.608),
            control2: Offset(0.575, 0.644),
            end: Offset(0.572, 0.700),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.571, 0.730),
            control2: Offset(0.570, 0.750),
            end: Offset(0.569, 0.756),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.566, 0.688),
            control2: Offset(0.570, 0.452),
            end: Offset(0.573, 0.343),
          ),
          // Finish with the rising right hook and its inward return.
          StrokeSegment.cubic(
            control1: Offset(0.576, 0.290),
            control2: Offset(0.611, 0.255),
            end: Offset(0.674, 0.238),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.674, 0.271),
            control2: Offset(0.663, 0.315),
            end: Offset(0.620, 0.331),
          ),
          StrokeSegment.cubic(
            control1: Offset(0.603, 0.336),
            control2: Offset(0.589, 0.339),
            end: Offset(0.579, 0.341),
          ),
        ],
        instruction:
            'Make the top loop, sweep around the left bowl, trace the stem down and back up, then finish with the right hook.',
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
