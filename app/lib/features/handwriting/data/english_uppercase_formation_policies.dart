import '../models/formation_validation_policy.dart';

const _symmetric = FormationValidationPolicy(
  orientationPolicy: OrientationValidationPolicy.symmetricOrAmbiguous,
);

const _mirrorSensitive = FormationValidationPolicy(
  orientationPolicy: OrientationValidationPolicy.referenceMirror,
);

/// Explicit policy for every supported English uppercase character.
///
/// A/H/I/M/O/T/U/V/W/X/Y are horizontally symmetric (or too close to
/// symmetric for a reliable child-facing rejection). Uppercase S is also
/// treated as ambiguous because natural differences between its two lobes can
/// make a correct child-written S score closer to the mirrored reference.
/// N/Z retain meaningful handed geometry, in addition to the clearly
/// asymmetric letters.
const englishUppercaseFormationPolicies = <String, FormationValidationPolicy>{
  'A': _symmetric,
  'B': _mirrorSensitive,
  'C': _mirrorSensitive,
  'D': FormationValidationPolicy(
    orientationPolicy: OrientationValidationPolicy.referenceMirror,
    useStrokeCorrespondenceForOrientation: true,
  ),
  'E': _mirrorSensitive,
  'F': _mirrorSensitive,
  'G': _mirrorSensitive,
  'H': _symmetric,
  'I': _symmetric,
  'J': _mirrorSensitive,
  'K': _mirrorSensitive,
  'L': _mirrorSensitive,
  'M': _symmetric,
  'N': _mirrorSensitive,
  'O': _symmetric,
  'P': _mirrorSensitive,
  'Q': FormationValidationPolicy(
    orientationPolicy: OrientationValidationPolicy.referenceMirror,
    enforceShape: true,
    useStrokeCorrespondenceForOrientation: true,
  ),
  'R': _mirrorSensitive,
  'S': _symmetric,
  'T': _symmetric,
  'U': _symmetric,
  'V': FormationValidationPolicy(
    orientationPolicy: OrientationValidationPolicy.symmetricOrAmbiguous,
    enforceShape: true,
  ),
  'W': _symmetric,
  'X': _symmetric,
  'Y': _symmetric,
  'Z': FormationValidationPolicy(
    orientationPolicy: OrientationValidationPolicy.referenceMirror,
    enforceShape: true,
    useStrokeCorrespondenceForOrientation: true,
  ),
};
