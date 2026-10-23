import 'dart:ui';

import 'package:akurin/features/handwriting/data/sinhala_strokes.dart';
import 'package:akurin/features/handwriting/models/character_stroke_definition.dart';
import 'package:akurin/features/handwriting/models/handwriting_animation_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps English timing and slows only Sinhala strokes', () {
    final english = HandwritingAnimationConfig.forLanguage(
      HandwritingLanguage.english,
    );
    final sinhala = HandwritingAnimationConfig.forLanguage(
      HandwritingLanguage.sinhala,
    );

    expect(english.strokeDuration, const Duration(milliseconds: 1400));
    expect(english.strokePauseDuration, const Duration(milliseconds: 450));
    expect(sinhala.strokeDuration, const Duration(milliseconds: 2400));
    expect(sinhala.strokePauseDuration, const Duration(milliseconds: 300));
    expect(sinhala.referenceStrokeLength, 1.75);
    expect(
      sinhala.strokeDuration.inMilliseconds /
          english.strokeDuration.inMilliseconds,
      closeTo(1.71, 0.01),
    );
  });

  test('uses one shared distance-based pace for long Sinhala strokes', () {
    const config = HandwritingAnimationConfig.sinhala;
    final rates = <double>[];

    for (final character in ['ක', 'ග', 'අ']) {
      final stroke = sinhalaStrokes[character]!.strokes.single;
      final length = stroke
          .buildPath(const Size.square(1))
          .computeMetrics()
          .fold<double>(0, (total, metric) => total + metric.length);
      final duration = config.durationForStroke(stroke);
      rates.add(length / duration.inMilliseconds);
    }

    final expectedRate =
        config.referenceStrokeLength! / config.strokeDuration.inMilliseconds;
    for (final rate in rates) {
      expect(rate, closeTo(expectedRate, 0.000001));
    }
  });
}
