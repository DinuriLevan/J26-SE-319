enum OrientationValidationPolicy {
  /// Horizontal reflection is not reliably distinguishable for this glyph.
  symmetricOrAmbiguous,

  /// Compare the child's geometry with the demonstrated glyph and its mirror.
  referenceMirror,
}

/// Declares which formation signals may affect an uppercase practice result.
///
/// Stroke metadata remains available for research/debugging even when it is
/// not enforced. This prevents a valid glyph from being rejected merely
/// because a child used a different start point, traversal, or segmentation.
class FormationValidationPolicy {
  const FormationValidationPolicy({
    required this.orientationPolicy,
    this.enforceStrokeDirection = false,
    this.enforceStrokeOrder = false,
    this.enforceStrokeCount = false,
    this.enforceShape = false,
    this.allowReverseStrokeTraversal = true,
    this.allowAlternativeStrokeOrder = true,
    this.useStrokeCorrespondenceForOrientation = false,
  });

  final OrientationValidationPolicy orientationPolicy;
  final bool enforceStrokeDirection;
  final bool enforceStrokeOrder;
  final bool enforceStrokeCount;
  final bool enforceShape;
  final bool allowReverseStrokeTraversal;
  final bool allowAlternativeStrokeOrder;
  final bool useStrokeCorrespondenceForOrientation;

  bool get validateOrientation =>
      orientationPolicy == OrientationValidationPolicy.referenceMirror;
}
