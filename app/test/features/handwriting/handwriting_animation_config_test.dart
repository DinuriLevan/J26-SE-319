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
    expect(
      sinhala.strokeDuration.inMilliseconds /
          english.strokeDuration.inMilliseconds,
      closeTo(1.71, 0.01),
    );
  });
}
