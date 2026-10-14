import 'character_stroke_definition.dart';

class HandwritingAnimationConfig {
  const HandwritingAnimationConfig({
    required this.strokeDuration,
    required this.strokePauseDuration,
  });

  final Duration strokeDuration;
  final Duration strokePauseDuration;

  static const english = HandwritingAnimationConfig(
    // Preserve the original English timing exactly.
    strokeDuration: Duration(milliseconds: 1400),
    strokePauseDuration: Duration(milliseconds: 450),
  );

  static const sinhala = HandwritingAnimationConfig(
    // About 1.7x the English duration, with a short inter-stroke pause.
    strokeDuration: Duration(milliseconds: 2400),
    strokePauseDuration: Duration(milliseconds: 300),
  );

  static HandwritingAnimationConfig forLanguage(
    HandwritingLanguage language,
  ) =>
      switch (language) {
        HandwritingLanguage.english => english,
        HandwritingLanguage.sinhala => sinhala,
      };
}
