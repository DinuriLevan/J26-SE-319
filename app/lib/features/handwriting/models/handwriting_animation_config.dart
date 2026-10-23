import 'dart:ui';

import 'character_stroke_definition.dart';
import 'stroke_definition.dart';

class HandwritingAnimationConfig {
  const HandwritingAnimationConfig({
    required this.strokeDuration,
    required this.strokePauseDuration,
    this.referenceStrokeLength,
  });

  final Duration strokeDuration;
  final Duration strokePauseDuration;

  /// Normalized path length covered by [strokeDuration].
  ///
  /// English leaves this unset to preserve its original fixed duration.
  /// Sinhala uses it to keep the pen velocity consistent for both compact and
  /// long continuous strokes without adding per-character timing overrides.
  final double? referenceStrokeLength;

  static const english = HandwritingAnimationConfig(
    // Preserve the original English timing exactly.
    strokeDuration: Duration(milliseconds: 1400),
    strokePauseDuration: Duration(milliseconds: 450),
  );

  static const sinhala = HandwritingAnimationConfig(
    // Shared by every Sinhala character. Longer continuous paths receive a
    // proportional duration so their visible pen speed remains consistent.
    strokeDuration: Duration(milliseconds: 2400),
    strokePauseDuration: Duration(milliseconds: 300),
    referenceStrokeLength: 1.75,
  );

  Duration durationForStroke(StrokeDefinition stroke) {
    final referenceLength = referenceStrokeLength;
    if (referenceLength == null) return strokeDuration;

    final pathLength = stroke
        .buildPath(const Size.square(1))
        .computeMetrics()
        .fold<double>(0, (total, metric) => total + metric.length);
    final lengthFactor = (pathLength / referenceLength).clamp(1.0, 2.0);
    return Duration(
      milliseconds: (strokeDuration.inMilliseconds * lengthFactor).round(),
    );
  }

  static HandwritingAnimationConfig forLanguage(
    HandwritingLanguage language,
  ) =>
      switch (language) {
        HandwritingLanguage.english => english,
        HandwritingLanguage.sinhala => sinhala,
      };
}
