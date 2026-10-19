import 'dart:math' as math;
import 'dart:ui';

import '../data/character_stroke_repository.dart';
import '../models/character_stroke_definition.dart';

class FormationValidationResult {
  const FormationValidationResult({
    required this.orientationEvaluated,
    required this.orientationCorrect,
    required this.strokeCountCorrect,
    required this.strokeOrderCorrect,
    required this.similarityScore,
    required this.feedback,
    required this.actualStrokeCount,
    required this.expectedStrokeCount,
    required this.normalizedBounds,
    this.correctFormationSimilarity = 0,
    this.mirroredFormationSimilarity = 0,
  });

  final bool orientationEvaluated;
  final bool orientationCorrect;

  /// Null means that this validator did not evaluate that formation property.
  final bool? strokeCountCorrect;
  final bool? strokeOrderCorrect;
  final double similarityScore;
  final String? feedback;
  final int actualStrokeCount;
  final int? expectedStrokeCount;
  final Rect normalizedBounds;
  final double correctFormationSimilarity;
  final double mirroredFormationSimilarity;

  bool get formationCorrect => !orientationEvaluated || orientationCorrect;

  bool finalCorrect({required bool recognitionCorrect}) =>
      recognitionCorrect && formationCorrect;
}

abstract interface class HandwritingFormationValidatorClient {
  FormationValidationResult validate({
    required String target,
    required HandwritingLanguage language,
    required List<List<Offset>> strokes,
    required Size sourceSize,
  });
}

/// Validates how a supported character was formed independently of CNN scores.
///
/// The comparison uses the existing demonstration path as the reference. The
/// child's normalized geometry is compared with both that reference and its
/// horizontal mirror. No coordinate is flipped while normalizing child input.
class HandwritingFormationValidator
    implements HandwritingFormationValidatorClient {
  const HandwritingFormationValidator();

  /// A mirrored score must win by this much before the child is rejected.
  /// Small/noisy differences are deliberately treated as inconclusive.
  static const double mirrorSimilarityMargin = 0.035;
  static const double _geometryDistinguishability = 0.035;
  static const double _orderedDistinguishability = 0.055;
  static const double _geometryWeight = 0.70;
  static const int _samplesPerStroke = 72;

  @override
  FormationValidationResult validate({
    required String target,
    required HandwritingLanguage language,
    required List<List<Offset>> strokes,
    required Size sourceSize,
  }) {
    final child = _normalize(strokes);
    final definition = CharacterStrokeRepository.find(
      character: target,
      language: language,
    );
    final shouldEvaluate =
        language == HandwritingLanguage.english && definition != null;

    if (!shouldEvaluate || child.strokes.isEmpty) {
      return FormationValidationResult(
        orientationEvaluated: shouldEvaluate,
        orientationCorrect: !shouldEvaluate,
        strokeCountCorrect: definition == null
            ? null
            : child.strokes.length == definition.strokes.length,
        strokeOrderCorrect: null,
        similarityScore: 0,
        feedback: shouldEvaluate
            ? 'Good try! Check the direction of the letter.'
            : null,
        actualStrokeCount: child.strokes.length,
        expectedStrokeCount: definition?.strokes.length,
        normalizedBounds: child.bounds,
      );
    }

    final expected = _normalize(_sampleDefinition(definition, sourceSize));
    final childPoints = child.strokes.expand((stroke) => stroke).toList();
    final expectedPoints = expected.strokes.expand((stroke) => stroke).toList();
    final mirroredExpectedStrokes = expected.strokes
        .map(
          (stroke) => stroke
              .map((point) => Offset(1 - point.dx, point.dy))
              .toList(growable: false),
        )
        .toList(growable: false);
    final mirroredExpected =
        mirroredExpectedStrokes.expand((stroke) => stroke).toList();
    final expectedDistance = _symmetricChamfer(childPoints, expectedPoints);
    final mirroredDistance = _symmetricChamfer(childPoints, mirroredExpected);
    final referenceGeometrySeparation =
        _symmetricChamfer(expectedPoints, mirroredExpected);
    final geometryIsDistinguishable =
        referenceGeometrySeparation >= _geometryDistinguishability;

    final orderedComparisonAvailable =
        child.strokes.length == expected.strokes.length;
    final referenceOrderedSeparation = _orderedDistance(
      expected.strokes,
      mirroredExpectedStrokes,
    );
    final orderedFormationIsDistinguishable = orderedComparisonAvailable &&
        referenceOrderedSeparation >= _orderedDistinguishability;

    var correctSimilarity = _distanceToSimilarity(expectedDistance);
    var mirroredSimilarity = _distanceToSimilarity(mirroredDistance);
    if (orderedFormationIsDistinguishable) {
      final orderedCorrect = _distanceToSimilarity(
        _orderedDistance(child.strokes, expected.strokes),
      );
      final orderedMirrored = _distanceToSimilarity(
        _orderedDistance(child.strokes, mirroredExpectedStrokes),
      );
      if (geometryIsDistinguishable) {
        correctSimilarity = _geometryWeight * correctSimilarity +
            (1 - _geometryWeight) * orderedCorrect;
        mirroredSimilarity = _geometryWeight * mirroredSimilarity +
            (1 - _geometryWeight) * orderedMirrored;
      } else {
        correctSimilarity = orderedCorrect;
        mirroredSimilarity = orderedMirrored;
      }
    }

    final orientationEvaluated =
        geometryIsDistinguishable || orderedFormationIsDistinguishable;
    final orientationCorrect = !orientationEvaluated ||
        mirroredSimilarity - correctSimilarity < mirrorSimilarityMargin;

    return FormationValidationResult(
      orientationEvaluated: orientationEvaluated,
      orientationCorrect: orientationCorrect,
      strokeCountCorrect: orderedComparisonAvailable,
      strokeOrderCorrect: null,
      similarityScore: correctSimilarity,
      feedback: orientationCorrect
          ? null
          : 'Good try! Check the direction of the letter.',
      actualStrokeCount: child.strokes.length,
      expectedStrokeCount: definition.strokes.length,
      normalizedBounds: child.bounds,
      correctFormationSimilarity: correctSimilarity,
      mirroredFormationSimilarity: mirroredSimilarity,
    );
  }

  List<List<Offset>> _sampleDefinition(
    CharacterStrokeDefinition definition,
    Size sourceSize,
  ) {
    final referenceSize =
        sourceSize.isEmpty ? const Size(1000, 1000) : sourceSize;
    return definition.strokes.map((stroke) {
      final path = stroke.buildPath(referenceSize);
      final points = <Offset>[];
      for (final metric in path.computeMetrics()) {
        for (var index = 0; index < _samplesPerStroke; index++) {
          final distance = metric.length * index / (_samplesPerStroke - 1);
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) points.add(tangent.position);
        }
      }
      return points;
    }).toList(growable: false);
  }

  _NormalizedStrokes _normalize(List<List<Offset>> source) {
    final usable = source
        .map(
          (stroke) => stroke
              .where((point) => point.dx.isFinite && point.dy.isFinite)
              .toList(growable: false),
        )
        .where((stroke) => stroke.isNotEmpty)
        .toList(growable: false);
    if (usable.isEmpty) return const _NormalizedStrokes([], Rect.zero);

    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    for (final point in usable.expand((stroke) => stroke)) {
      left = math.min(left, point.dx);
      top = math.min(top, point.dy);
      right = math.max(right, point.dx);
      bottom = math.max(bottom, point.dy);
    }
    final width = right - left;
    final height = bottom - top;
    final extent = math.max(width, height);
    if (extent <= 0) return const _NormalizedStrokes([], Rect.zero);
    final horizontalInset = (1 - width / extent) / 2;
    final verticalInset = (1 - height / extent) / 2;

    // Positive scale and translation only: orientation, sequence, and travel
    // direction remain exactly as the child produced them.
    final normalized = usable.map((stroke) {
      final points = stroke
          .map(
            (point) => Offset(
              horizontalInset + (point.dx - left) / extent,
              verticalInset + (point.dy - top) / extent,
            ),
          )
          .toList(growable: false);
      return _resample(points, _samplesPerStroke);
    }).toList(growable: false);
    return _NormalizedStrokes(
      normalized,
      Rect.fromLTRB(
        horizontalInset,
        verticalInset,
        horizontalInset + width / extent,
        verticalInset + height / extent,
      ),
    );
  }

  List<Offset> _resample(List<Offset> points, int sampleCount) {
    if (points.length < 2) return points;
    final cumulative = <double>[0];
    for (var index = 1; index < points.length; index++) {
      cumulative
          .add(cumulative.last + (points[index] - points[index - 1]).distance);
    }
    final total = cumulative.last;
    if (total <= 0) return [points.first];
    final result = <Offset>[];
    var segment = 1;
    for (var sample = 0; sample < sampleCount; sample++) {
      final target = total * sample / (sampleCount - 1);
      while (segment < cumulative.length - 1 && cumulative[segment] < target) {
        segment++;
      }
      final startDistance = cumulative[segment - 1];
      final segmentLength = cumulative[segment] - startDistance;
      final fraction =
          segmentLength == 0 ? 0.0 : (target - startDistance) / segmentLength;
      result.add(Offset.lerp(points[segment - 1], points[segment], fraction)!);
    }
    return result;
  }

  double _symmetricChamfer(List<Offset> left, List<Offset> right) {
    if (left.isEmpty || right.isEmpty) return double.infinity;
    double directed(List<Offset> source, List<Offset> destination) {
      var total = 0.0;
      for (final point in source) {
        var nearestSquared = double.infinity;
        for (final candidate in destination) {
          final dx = point.dx - candidate.dx;
          final dy = point.dy - candidate.dy;
          nearestSquared = math.min(nearestSquared, dx * dx + dy * dy);
        }
        total += math.sqrt(nearestSquared);
      }
      return total / source.length;
    }

    return (directed(left, right) + directed(right, left)) / 2;
  }

  double _orderedDistance(
    List<List<Offset>> source,
    List<List<Offset>> destination,
  ) {
    if (source.length != destination.length || source.isEmpty) {
      return double.infinity;
    }
    var total = 0.0;
    var compared = 0;
    for (var strokeIndex = 0; strokeIndex < source.length; strokeIndex++) {
      final sourceStroke = source[strokeIndex];
      final destinationStroke = destination[strokeIndex];
      if (sourceStroke.isEmpty || destinationStroke.isEmpty) continue;
      final samples = math.min(sourceStroke.length, destinationStroke.length);
      for (var sample = 0; sample < samples; sample++) {
        final sourceIndex = samples == 1
            ? 0
            : (sample * (sourceStroke.length - 1) / (samples - 1)).round();
        final destinationIndex = samples == 1
            ? 0
            : (sample * (destinationStroke.length - 1) / (samples - 1)).round();
        total +=
            (sourceStroke[sourceIndex] - destinationStroke[destinationIndex])
                .distance;
        compared++;
      }
    }
    return compared == 0 ? double.infinity : total / compared;
  }

  double _distanceToSimilarity(double distance) =>
      distance.isFinite ? (1 - distance / math.sqrt2).clamp(0.0, 1.0) : 0;
}

class _NormalizedStrokes {
  const _NormalizedStrokes(this.strokes, this.bounds);

  final List<List<Offset>> strokes;
  final Rect bounds;
}
