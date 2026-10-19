import '../models/formation_validation_policy.dart';

const _ambiguous = FormationValidationPolicy(
  orientationPolicy: OrientationValidationPolicy.symmetricOrAmbiguous,
);

const _mirrorSensitive = FormationValidationPolicy(
  orientationPolicy: OrientationValidationPolicy.referenceMirror,
);

const _pairedMirrorSensitive = FormationValidationPolicy(
  orientationPolicy: OrientationValidationPolicy.referenceMirror,
  useStrokeCorrespondenceForOrientation: true,
);

/// Explicit policy for every supported English lowercase character.
///
/// Direction, order, and count are intentionally diagnostic for this learning
/// flow. Only a clear geometric mirror may reject an otherwise recognized
/// letter. The ambiguous group avoids claiming orientation accuracy where a
/// horizontal reflection is visually identical or unreliable across styles.
const englishLowercaseFormationPolicies = <String, FormationValidationPolicy>{
  'a': _ambiguous,
  'b': _pairedMirrorSensitive,
  'c': _mirrorSensitive,
  'd': _pairedMirrorSensitive,
  'e': _mirrorSensitive,
  'f': _mirrorSensitive,
  'g': _mirrorSensitive,
  'h': _mirrorSensitive,
  'i': _ambiguous,
  'j': _mirrorSensitive,
  'k': _mirrorSensitive,
  'l': _ambiguous,
  'm': _mirrorSensitive,
  'n': _mirrorSensitive,
  'o': _ambiguous,
  'p': _pairedMirrorSensitive,
  'q': FormationValidationPolicy(
    orientationPolicy: OrientationValidationPolicy.referenceMirror,
    enforceShape: true,
    useStrokeCorrespondenceForOrientation: true,
  ),
  'r': _mirrorSensitive,
  's': _mirrorSensitive,
  't': _mirrorSensitive,
  'u': _ambiguous,
  'v': _ambiguous,
  'w': _ambiguous,
  'x': _ambiguous,
  'y': _mirrorSensitive,
  'z': _mirrorSensitive,
};
