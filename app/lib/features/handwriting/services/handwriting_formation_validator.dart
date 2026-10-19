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
    this.orientationScore = 0,
    this.directionScore = 0,
    this.startEndScore = 0,
    this.strokeOrderScore = 0,
    this.shapeSimilarity = 0,
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
  final double orientationScore;
  final double directionScore;
  final double startEndScore;
  final double strokeOrderScore;
  final double shapeSimilarity;

  bool get formationCorrect =>
      !orientationEvaluated ||
      (orientationCorrect &&
          (strokeCountCorrect ?? true) &&
          (strokeOrderCorrect ?? true));

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
  static const double mirrorSimilarityMargin = 0.010;
  static const double _geometryDistinguishability = 0.035;
  static const double _orderedDistinguishability = 0.055;
  static const double _tangentWeight = 0.18;
  static const double _startEndTolerance = 0.34;
  static const double _minimumStartEndScore = 0.55;
  static const double _minimumDirectionScore = 0.45;
  static const double _minimumStrokeOrderScore = 0.50;
  static const double _minimumOrientationScore = 0.58;
  static const double _componentMirrorMargin = 0.04;
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
    final mirroredExpectedStrokes = expected.strokes
        .map(
          (stroke) => stroke
              .map((point) => Offset(1 - point.dx, point.dy))
              .toList(growable: false),
        )
        .toList(growable: false);
    final expectedDistance = _structuralDistance(
      child.strokes,
      expected.strokes,
    );
    final mirroredDistance = _structuralDistance(
      child.strokes,
      mirroredExpectedStrokes,
    );
    final referenceGeometrySeparation =
        _structuralDistance(expected.strokes, mirroredExpectedStrokes);
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
    if (!geometryIsDistinguishable && orderedFormationIsDistinguishable) {
      final orderedCorrect = _distanceToSimilarity(
        _orderedDistance(child.strokes, expected.strokes),
      );
      final orderedMirrored = _distanceToSimilarity(
        _orderedDistance(child.strokes, mirroredExpectedStrokes),
      );
      correctSimilarity = orderedCorrect;
      mirroredSimilarity = orderedMirrored;
    }

    final correctSignals = orderedComparisonAvailable
        ? _strokeSignals(child.strokes, expected.strokes)
        : null;
    final mirroredSignals = orderedComparisonAvailable
        ? _strokeSignals(child.strokes, mirroredExpectedStrokes)
        : null;
    final startEndScore = correctSignals?.startEndScore ?? 0;
    final directionScore = correctSignals?.directionScore ?? 0;
    final strokeOrderScore = correctSignals?.strokeOrderScore ?? 0;
    final orientationScore = correctSignals == null
        ? correctSimilarity
        : correctSimilarity * 0.30 +
            startEndScore * 0.30 +
            directionScore * 0.20 +
            strokeOrderScore * 0.20;

    final componentMirrorWins = correctSignals != null &&
        mirroredSignals != null &&
        mirroredSignals.combinedScore - correctSignals.combinedScore >=
            _componentMirrorMargin;
    final componentChecksPass = correctSignals == null ||
        (startEndScore >= _minimumStartEndScore &&
            (!correctSignals.directionEvaluated ||
                directionScore >= _minimumDirectionScore) &&
            strokeOrderScore >= _minimumStrokeOrderScore &&
            orientationScore >= _minimumOrientationScore);

    final orientationEvaluated =
        geometryIsDistinguishable || orderedFormationIsDistinguishable;
    final mirrorShapePasses =
        mirroredSimilarity - correctSimilarity < mirrorSimilarityMargin;
    final orientationCorrect = !orientationEvaluated ||
        (mirrorShapePasses && !componentMirrorWins && componentChecksPass);

    return FormationValidationResult(
      orientationEvaluated: orientationEvaluated,
      orientationCorrect: orientationCorrect,
      strokeCountCorrect: orderedComparisonAvailable,
      strokeOrderCorrect: correctSignals == null
          ? null
          : strokeOrderScore >= _minimumStrokeOrderScore,
      similarityScore: correctSimilarity,
      feedback: orientationCorrect
          ? null
          : 'Good try! Check the direction of the letter.',
      actualStrokeCount: child.strokes.length,
      expectedStrokeCount: definition.strokes.length,
      normalizedBounds: child.bounds,
      correctFormationSimilarity: correctSimilarity,
      mirroredFormationSimilarity: mirroredSimilarity,
      orientationScore: orientationScore,
      directionScore: directionScore,
      startEndScore: startEndScore,
      strokeOrderScore: strokeOrderScore,
      shapeSimilarity: correctSimilarity,
    );
  }

  _StrokeSignals _strokeSignals(
    List<List<Offset>> actual,
    List<List<Offset>> expected,
  ) {
    var endpointTotal = 0.0;
    var endpointCount = 0;
    var minimumDirection = 1.0;
    var directionCount = 0;

    for (var index = 0; index < actual.length; index++) {
      final actualStroke = actual[index];
      final expectedStroke = expected[index];
      if (actualStroke.isEmpty || expectedStroke.isEmpty) continue;

      endpointTotal += _regionScore(actualStroke.first, expectedStroke.first);
      endpointTotal += _regionScore(actualStroke.last, expectedStroke.last);
      endpointCount += 2;

      final actualDirection = actualStroke.last - actualStroke.first;
      final expectedDirection = expectedStroke.last - expectedStroke.first;
      if (actualDirection.distance >= 0.08 &&
          expectedDirection.distance >= 0.08) {
        final cosine = (actualDirection.dx * expectedDirection.dx +
                actualDirection.dy * expectedDirection.dy) /
            (actualDirection.distance * expectedDirection.distance);
        minimumDirection = math.min(
          minimumDirection,
          (cosine.clamp(-1.0, 1.0) + 1) / 2,
        );
        directionCount++;
      }
    }

    final startEndScore =
        endpointCount == 0 ? 0.0 : endpointTotal / endpointCount;
    final directionScore = directionCount == 0 ? 1.0 : minimumDirection;
    final strokeOrderScore = _distanceToSimilarity(
      _orderedDistance(actual, expected),
    );
    return _StrokeSignals(
      startEndScore: startEndScore,
      directionScore: directionScore,
      strokeOrderScore: strokeOrderScore,
      directionEvaluated: directionCount > 0,
    );
  }

  double _regionScore(Offset actual, Offset expected) =>
      (1 - (actual - expected).distance / _startEndTolerance).clamp(0.0, 1.0);

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

  /// A stroke-count-independent shape distance that also compares local line
  /// orientation. This prevents a straight stem on the wrong side from being
  /// cheaply matched to a nearby curved edge with a different tangent.
  double _structuralDistance(
    List<List<Offset>> source,
    List<List<Offset>> destination,
  ) {
    final sourcePoints = source.expand((stroke) => stroke).toList();
    final destinationPoints = destination.expand((stroke) => stroke).toList();
    final positional = _symmetricChamfer(sourcePoints, destinationPoints);
    final oriented = _symmetricOrientedDistance(source, destination);
    return positional * 0.35 + oriented * 0.65;
  }

  double _symmetricOrientedDistance(
    List<List<Offset>> left,
    List<List<Offset>> right,
  ) {
    final leftPoints = _orientedPoints(left);
    final rightPoints = _orientedPoints(right);
    if (leftPoints.isEmpty || rightPoints.isEmpty) return double.infinity;

    double directed(
      List<_OrientedPoint> source,
      List<_OrientedPoint> destination,
    ) {
      var total = 0.0;
      for (final point in source) {
        var nearest = double.infinity;
        for (final candidate in destination) {
          final spatial = (point.position - candidate.position).distance;
          final alignment = (point.tangent.dx * candidate.tangent.dx +
                  point.tangent.dy * candidate.tangent.dy)
              .abs()
              .clamp(0.0, 1.0);
          final cost = spatial + _tangentWeight * (1 - alignment);
          nearest = math.min(nearest, cost);
        }
        total += nearest;
      }
      return total / source.length;
    }

    return (directed(leftPoints, rightPoints) +
            directed(rightPoints, leftPoints)) /
        2;
  }

  List<_OrientedPoint> _orientedPoints(List<List<Offset>> strokes) {
    final result = <_OrientedPoint>[];
    for (final stroke in strokes) {
      if (stroke.length < 2) continue;
      for (var index = 0; index < stroke.length; index++) {
        final before = stroke[index == 0 ? 0 : index - 1];
        final after = stroke[index == stroke.length - 1 ? index : index + 1];
        final delta = after - before;
        final length = delta.distance;
        if (length == 0) continue;
        result.add(
          _OrientedPoint(
            stroke[index],
            Offset(delta.dx / length, delta.dy / length),
          ),
        );
      }
    }
    return result;
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

class _OrientedPoint {
  const _OrientedPoint(this.position, this.tangent);

  final Offset position;
  final Offset tangent;
}

class _StrokeSignals {
  const _StrokeSignals({
    required this.startEndScore,
    required this.directionScore,
    required this.strokeOrderScore,
    required this.directionEvaluated,
  });

  final double startEndScore;
  final double directionScore;
  final double strokeOrderScore;
  final bool directionEvaluated;

  double get combinedScore =>
      startEndScore * 0.45 + directionScore * 0.25 + strokeOrderScore * 0.30;
}
