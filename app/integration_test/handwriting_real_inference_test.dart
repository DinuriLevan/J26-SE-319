import 'dart:ui';

import 'package:akurin/features/handwriting/data/character_stroke_repository.dart';
import 'package:akurin/features/handwriting/models/character_stroke_definition.dart';
import 'package:akurin/features/handwriting/services/handwriting_classifier.dart';
import 'package:akurin/features/handwriting/services/handwriting_image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('runs real TFLite diagnostics for representative English input',
      (tester) async {
    const preprocessor = HandwritingImagePreprocessor();
    final classifier = HandwritingClassifier();
    addTearDown(classifier.dispose);

    const cases = <(String, HandwritingModelType)>[
      ('A', HandwritingModelType.englishUppercase),
      ('B', HandwritingModelType.englishUppercase),
      ('C', HandwritingModelType.englishUppercase),
      ('D', HandwritingModelType.englishUppercase),
      ('N', HandwritingModelType.englishUppercase),
      ('S', HandwritingModelType.englishUppercase),
      ('W', HandwritingModelType.englishUppercase),
      ('Y', HandwritingModelType.englishUppercase),
      ('Z', HandwritingModelType.englishUppercase),
      ('q', HandwritingModelType.englishLowercase),
      ('y', HandwritingModelType.englishLowercase),
      ('z', HandwritingModelType.englishLowercase),
    ];

    for (final (character, modelType) in cases) {
      final definition = CharacterStrokeRepository.find(
        character: character,
        language: HandwritingLanguage.english,
      );
      expect(definition, isNotNull, reason: 'Missing $character stroke data.');
      final handwriting = await preprocessor.preprocessStrokes(
        strokes: _sampleStrokes(definition!),
        sourceSize: _sourceSize,
      );
      final prediction = await classifier.predict(
        modelType: modelType,
        handwriting: handwriting,
        expectedCharacter: character,
      );
      expect(prediction.topPredictions, hasLength(3));
      final topThree = prediction.topPredictions
          .map(
            (score) =>
                '${score.character} ${(score.confidence * 100).toStringAsFixed(2)}%',
          )
          .join(', ');
      // Visible in `flutter test ... -d <device>` output for research review.
      // ignore: avoid_print
      print(
        'REAL_INFERENCE target=$character model=${modelType.name} '
        'prediction=${prediction.character} '
        'confidence=${(prediction.confidence * 100).toStringAsFixed(2)}% '
        'top3=[$topThree]',
      );
    }
  });
}

const _sourceSize = Size(300, 400);

List<List<Offset>> _sampleStrokes(CharacterStrokeDefinition definition) {
  return definition.strokes.map((stroke) {
    final path = stroke.buildPath(_sourceSize);
    final points = <Offset>[];
    for (final metric in path.computeMetrics()) {
      const sampleDistance = 2.0;
      for (var distance = 0.0;
          distance < metric.length;
          distance += sampleDistance) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) points.add(tangent.position);
      }
      final end = metric.getTangentForOffset(metric.length);
      if (end != null) points.add(end.position);
    }
    return points;
  }).toList(growable: false);
}
