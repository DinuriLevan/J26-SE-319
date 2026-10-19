import 'dart:math' as math;
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
      ('F', HandwritingModelType.englishUppercase),
      ('G', HandwritingModelType.englishUppercase),
      ('K', HandwritingModelType.englishUppercase),
      ('M', HandwritingModelType.englishUppercase),
      ('N', HandwritingModelType.englishUppercase),
      ('S', HandwritingModelType.englishUppercase),
      ('W', HandwritingModelType.englishUppercase),
      ('Y', HandwritingModelType.englishUppercase),
      ('Z', HandwritingModelType.englishUppercase),
      ('a', HandwritingModelType.englishLowercase),
      ('b', HandwritingModelType.englishLowercase),
      ('c', HandwritingModelType.englishLowercase),
      ('d', HandwritingModelType.englishLowercase),
      ('e', HandwritingModelType.englishLowercase),
      ('g', HandwritingModelType.englishLowercase),
      ('j', HandwritingModelType.englishLowercase),
      ('m', HandwritingModelType.englishLowercase),
      ('p', HandwritingModelType.englishLowercase),
      ('q', HandwritingModelType.englishLowercase),
      ('s', HandwritingModelType.englishLowercase),
      ('w', HandwritingModelType.englishLowercase),
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
        outputStrokeWidth: modelType.modelInputStrokeWidth,
      );
      final prediction = await classifier.predict(
        modelType: modelType,
        handwriting: handwriting,
        expectedCharacter: character,
      );
      expect(prediction.topPredictions, hasLength(5));
      final topFive = prediction.topPredictions
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
        'top5=[$topFive]',
      );
    }

    for (final diagnostic in _scConfusionCases) {
      final definition = CharacterStrokeRepository.find(
        character: diagnostic.character,
        language: HandwritingLanguage.english,
      )!;
      var strokes = _sampleStrokes(definition);
      strokes = _reshapeStrokes(
        strokes,
        scaleX: diagnostic.scaleX,
        scaleY: diagnostic.scaleY,
      );
      if (diagnostic.inwardEnds) strokes = _addInwardEnds(strokes);
      final handwriting = await preprocessor.preprocessStrokes(
        strokes: strokes,
        sourceSize: _sourceSize,
        outputStrokeWidth: diagnostic.modelType.modelInputStrokeWidth,
      );
      final prediction = await classifier.predict(
        modelType: diagnostic.modelType,
        handwriting: handwriting,
        expectedCharacter: diagnostic.character,
      );
      final s = diagnostic.modelType == HandwritingModelType.englishUppercase
          ? 'S'
          : 's';
      final c = diagnostic.modelType == HandwritingModelType.englishUppercase
          ? 'C'
          : 'c';
      final topFive = prediction.topPredictions
          .map(
            (score) =>
                '${score.character} ${(score.confidence * 100).toStringAsFixed(2)}%',
          )
          .join(', ');
      // ignore: avoid_print
      print(
        'SC_DIAGNOSTIC variation=${diagnostic.name} '
        'target=${diagnostic.character} prediction=${prediction.character} '
        'confidence=${(prediction.confidence * 100).toStringAsFixed(2)}% '
        '$s=${prediction.rawScores[_labelIndex(s)].toStringAsFixed(6)} '
        '$c=${prediction.rawScores[_labelIndex(c)].toStringAsFixed(6)} '
        'top5=[$topFive]',
      );
    }
  });
}

typedef _DiagnosticCase = ({
  String name,
  String character,
  HandwritingModelType modelType,
  double scaleX,
  double scaleY,
  bool inwardEnds,
});

const _scConfusionCases = <_DiagnosticCase>[
  (
    name: 'uppercase_s_narrow',
    character: 'S',
    modelType: HandwritingModelType.englishUppercase,
    scaleX: 0.75,
    scaleY: 1,
    inwardEnds: false
  ),
  (
    name: 'uppercase_s_wide',
    character: 'S',
    modelType: HandwritingModelType.englishUppercase,
    scaleX: 1.25,
    scaleY: 1,
    inwardEnds: false
  ),
  (
    name: 'uppercase_s_tall',
    character: 'S',
    modelType: HandwritingModelType.englishUppercase,
    scaleX: 0.85,
    scaleY: 1.25,
    inwardEnds: false
  ),
  (
    name: 'uppercase_s_round',
    character: 'S',
    modelType: HandwritingModelType.englishUppercase,
    scaleX: 1.1,
    scaleY: 0.9,
    inwardEnds: false
  ),
  (
    name: 'uppercase_s_inward_ends',
    character: 'S',
    modelType: HandwritingModelType.englishUppercase,
    scaleX: 1,
    scaleY: 1,
    inwardEnds: true
  ),
  (
    name: 'uppercase_c_normal',
    character: 'C',
    modelType: HandwritingModelType.englishUppercase,
    scaleX: 1,
    scaleY: 1,
    inwardEnds: false
  ),
  (
    name: 'lowercase_s_compact',
    character: 's',
    modelType: HandwritingModelType.englishLowercase,
    scaleX: 0.9,
    scaleY: 0.85,
    inwardEnds: false
  ),
  (
    name: 'lowercase_s_tall',
    character: 's',
    modelType: HandwritingModelType.englishLowercase,
    scaleX: 0.8,
    scaleY: 1.25,
    inwardEnds: false
  ),
  (
    name: 'lowercase_s_round',
    character: 's',
    modelType: HandwritingModelType.englishLowercase,
    scaleX: 1.15,
    scaleY: 0.9,
    inwardEnds: false
  ),
  (
    name: 'lowercase_c_normal',
    character: 'c',
    modelType: HandwritingModelType.englishLowercase,
    scaleX: 1,
    scaleY: 1,
    inwardEnds: false
  ),
];

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

List<List<Offset>> _reshapeStrokes(
  List<List<Offset>> strokes, {
  required double scaleX,
  required double scaleY,
}) {
  final points = strokes.expand((stroke) => stroke).toList(growable: false);
  final left = points.map((point) => point.dx).reduce(math.min);
  final right = points.map((point) => point.dx).reduce(math.max);
  final top = points.map((point) => point.dy).reduce(math.min);
  final bottom = points.map((point) => point.dy).reduce(math.max);
  final center = Offset((left + right) / 2, (top + bottom) / 2);
  return strokes
      .map(
        (stroke) => stroke
            .map(
              (point) => Offset(
                center.dx + (point.dx - center.dx) * scaleX,
                center.dy + (point.dy - center.dy) * scaleY,
              ),
            )
            .toList(growable: true),
      )
      .toList(growable: false);
}

List<List<Offset>> _addInwardEnds(List<List<Offset>> strokes) {
  final result = strokes
      .map((stroke) => List<Offset>.of(stroke, growable: true))
      .toList(growable: false);
  final stroke = result.firstWhere((candidate) => candidate.isNotEmpty);
  stroke.insert(0, stroke.first.translate(-18, 0));
  stroke.add(stroke.last.translate(18, 0));
  return result;
}

int _labelIndex(String character) =>
    character.toLowerCase().codeUnitAt(0) - 'a'.codeUnitAt(0);
