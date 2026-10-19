import 'dart:ui';

import 'package:akurin/features/handwriting/data/character_stroke_repository.dart';
import 'package:akurin/features/handwriting/models/character_stroke_definition.dart';
import 'package:akurin/features/handwriting/services/handwriting_formation_validator.dart';
import 'package:akurin/features/handwriting/services/handwriting_image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const validator = HandwritingFormationValidator();
  const sourceSize = Size(300, 400);
  const allEnglish = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz';
  const geometryAndDirectionIndistinguishable = {'i', 'l'};

  for (final character in allEnglish.split('')) {
    test('correct $character formation passes orientation validation', () {
      final strokes = _referenceStrokes(character, sourceSize);

      final result = validator.validate(
        target: character,
        language: HandwritingLanguage.english,
        strokes: strokes,
        sourceSize: sourceSize,
      );

      expect(
        result.orientationEvaluated,
        !geometryAndDirectionIndistinguishable.contains(character),
      );
      expect(result.orientationCorrect, isTrue);
      expect(result.formationCorrect, isTrue);
      expect(result.strokeCountCorrect, isTrue);
      expect(result.strokeOrderCorrect, isNull);
    });

    test('horizontally mirrored $character fails orientation validation', () {
      final strokes = _mirrorHorizontally(
        _referenceStrokes(character, sourceSize),
        sourceSize.width,
      );

      final result = validator.validate(
        target: character,
        language: HandwritingLanguage.english,
        strokes: strokes,
        sourceSize: sourceSize,
      );

      final distinguishable =
          !geometryAndDirectionIndistinguishable.contains(character);
      expect(result.orientationEvaluated, distinguishable);
      expect(result.orientationCorrect, !distinguishable);
      expect(result.formationCorrect, !distinguishable);
      expect(result.finalCorrect(recognitionCorrect: true), !distinguishable);
      if (distinguishable) {
        expect(
          result.feedback,
          'Good try! Check the direction of the letter.',
        );
      }
    });
  }

  test('evaluates correct and mirrored formations across English A-Z/a-z', () {
    const requiredMirrorSensitive = {
      'B',
      'C',
      'D',
      'E',
      'F',
      'G',
      'J',
      'K',
      'L',
      'P',
      'Q',
      'R',
      'b',
      'd',
      'p',
      'q',
      'c',
      'e',
      'f',
      'g',
      'j',
      'k',
      'r',
      's',
      't',
      'y',
      'm',
    };
    final activelyValidated = <String>[];
    final notDistinguishable = <String>[];

    for (final character in allEnglish.split('')) {
      final correctStrokes = _referenceStrokes(character, sourceSize);
      final correct = validator.validate(
        target: character,
        language: HandwritingLanguage.english,
        strokes: correctStrokes,
        sourceSize: sourceSize,
      );
      expect(
        correct.orientationCorrect,
        isTrue,
        reason: 'Correct $character formation must pass.',
      );

      final mirrored = validator.validate(
        target: character,
        language: HandwritingLanguage.english,
        strokes: _mirrorHorizontally(correctStrokes, sourceSize.width),
        sourceSize: sourceSize,
      );
      if (mirrored.orientationEvaluated) {
        activelyValidated.add(character);
        expect(
          mirrored.orientationCorrect,
          isFalse,
          reason: 'Mirrored $character formation must fail.',
        );
      } else {
        notDistinguishable.add(character);
        expect(
          mirrored.orientationCorrect,
          isTrue,
          reason: '$character must remain accepted when mirror orientation '
              'cannot be distinguished reliably.',
        );
      }
    }

    expect(activelyValidated, containsAll(requiredMirrorSensitive));
    expect(
      activelyValidated.join(),
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghjkmnopqrstuvwxyz',
    );
    expect(notDistinguishable, ['i', 'l']);
  });

  test('unsupported characters retain recognition-only behavior', () {
    final result = validator.validate(
      target: 'අ',
      language: HandwritingLanguage.sinhala,
      strokes: const [
        [Offset(20, 20), Offset(40, 80)],
      ],
      sourceSize: sourceSize,
    );

    expect(result.orientationEvaluated, isFalse);
    expect(result.formationCorrect, isTrue);
    expect(result.finalCorrect(recognitionCorrect: true), isTrue);
  });

  test(
    '224 model input preserves the visible left-right orientation for B/C/D/E/F',
    () async {
      const preprocessor = HandwritingImagePreprocessor();
      for (final character in ['B', 'C', 'D', 'E', 'F']) {
        final correctStrokes = _referenceStrokes(character, sourceSize);
        final mirroredStrokes =
            _mirrorHorizontally(correctStrokes, sourceSize.width);
        final correct = await preprocessor.preprocessStrokes(
          strokes: correctStrokes,
          sourceSize: sourceSize,
        );
        final mirrored = await preprocessor.preprocessStrokes(
          strokes: mirroredStrokes,
          sourceSize: sourceSize,
        );

        var difference = 0;
        var samples = 0;
        for (var y = 0; y < correct.height; y += 2) {
          for (var x = 0; x < correct.width; x += 2) {
            final correctIndex = (y * correct.width + x) * 3;
            final mirroredIndex =
                (y * mirrored.width + (mirrored.width - 1 - x)) * 3;
            difference += (correct.rgbBytes[correctIndex] -
                    mirrored.rgbBytes[mirroredIndex])
                .abs();
            samples++;
          }
        }
        expect(
          difference / samples,
          lessThan(8),
          reason: '$character model input should mirror exactly when the '
              'stored touch coordinates are mirrored.',
        );
      }
    },
  );
}

List<List<Offset>> _referenceStrokes(String character, Size size) {
  final definition = CharacterStrokeRepository.find(
    character: character,
    language: HandwritingLanguage.english,
  )!;
  return definition.strokes.map((stroke) {
    final points = <Offset>[];
    for (final metric in stroke.buildPath(size).computeMetrics()) {
      for (var distance = 0.0; distance < metric.length; distance += 2) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) points.add(tangent.position);
      }
      final end = metric.getTangentForOffset(metric.length);
      if (end != null) points.add(end.position);
    }
    return points;
  }).toList(growable: false);
}

List<List<Offset>> _mirrorHorizontally(
  List<List<Offset>> strokes,
  double width,
) {
  return strokes
      .map(
        (stroke) => stroke
            .map((point) => Offset(width - point.dx, point.dy))
            .toList(growable: false),
      )
      .toList(growable: false);
}
