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
  const symmetricUppercase = {
    'A',
    'H',
    'I',
    'M',
    'O',
    'T',
    'U',
    'V',
    'W',
    'X',
    'Y'
  };
  const ambiguousLowercase = {'a', 'i', 'l', 'o', 'u', 'v', 'w', 'x'};

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
        character == character.toUpperCase()
            ? !symmetricUppercase.contains(character)
            : !ambiguousLowercase.contains(character),
      );
      expect(result.orientationCorrect, isTrue);
      expect(result.formationCorrect, isTrue);
      expect(result.strokeCountCorrect, isTrue);
      expect(result.strokeOrderCorrect, isTrue);
    });

    test('handles horizontally mirrored $character according to policy', () {
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

      final distinguishable = character == character.toUpperCase()
          ? !symmetricUppercase.contains(character)
          : !ambiguousLowercase.contains(character);
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
      'BCDEFGJKLNPQRSZbcdefghjkmnpqrstyz',
    );
    expect(notDistinguishable, [
      'A',
      'H',
      'I',
      'M',
      'O',
      'T',
      'U',
      'V',
      'W',
      'X',
      'Y',
      'a',
      'i',
      'l',
      'o',
      'u',
      'v',
      'w',
      'x',
    ]);
  });

  for (final character in ['B', 'E', 'J']) {
    test('rejects joined-stroke mirrored $character like real canvas input',
        () {
      final mirroredStrokes = _realisticMirroredStrokes(character);
      final result = validator.validate(
        target: character,
        language: HandwritingLanguage.english,
        strokes: mirroredStrokes,
        sourceSize: sourceSize,
      );

      expect(result.orientationEvaluated, isTrue);
      expect(
        result.orientationCorrect,
        isFalse,
        reason: '$character mirror score '
            '${result.mirroredFormationSimilarity} should beat correct score '
            '${result.correctFormationSimilarity}.',
      );
    });

    test('accepts joined-stroke correctly oriented $character', () {
      final correctStrokes = _realisticCorrectStrokes(character, sourceSize);
      final result = validator.validate(
        target: character,
        language: HandwritingLanguage.english,
        strokes: correctStrokes,
        sourceSize: sourceSize,
      );

      expect(result.orientationEvaluated, isTrue);
      expect(result.orientationCorrect, isTrue);
    });
  }

  test('rejects a clearly mirrored trajectory D', () {
    final result = validator.validate(
      target: 'D',
      language: HandwritingLanguage.english,
      strokes: _realisticDStrokes().first,
      sourceSize: sourceSize,
    );

    expect(result.orientationEvaluated, isTrue);
    expect(result.orientationCorrect, isFalse);
    expect(result.formationCorrect, isFalse);
  });

  test('does not call a normal inset D mirrored', () {
    final result = validator.validate(
      target: 'D',
      language: HandwritingLanguage.english,
      strokes: _realisticDStrokes().last,
      sourceSize: sourceSize,
    );

    expect(result.orientationEvaluated, isTrue);
    expect(
      result.orientationCorrect,
      isTrue,
      reason: 'correct=${result.correctFormationSimilarity} '
          'mirror=${result.mirroredFormationSimilarity} '
          'variant=${result.matchedValidVariant}',
    );
    expect(result.formationCorrect, isTrue);
  });

  test('accepts D when a stroke is travelled backwards', () {
    final strokes =
        _referenceStrokes('D', sourceSize).map((stroke) => stroke).toList();
    strokes[0] = strokes[0].reversed.toList(growable: false);
    final result = validator.validate(
      target: 'D',
      language: HandwritingLanguage.english,
      strokes: strokes,
      sourceSize: sourceSize,
    );

    expect(result.strokeDirectionCorrect, isFalse);
    expect(result.orientationCorrect, isTrue);
    expect(result.formationCorrect, isTrue);
  });

  test('rejects Q with its tail on the wrong side', () {
    final strokes =
        _referenceStrokes('Q', sourceSize).map((stroke) => stroke).toList();
    strokes[1] = strokes[1]
        .map((point) => Offset(sourceSize.width - point.dx, point.dy))
        .toList(growable: false);
    final result = validator.validate(
      target: 'Q',
      language: HandwritingLanguage.english,
      strokes: strokes,
      sourceSize: sourceSize,
    );

    expect(
      result.orientationCorrect,
      isFalse,
      reason: 'correct=${result.correctFormationSimilarity} '
          'mirror=${result.mirroredFormationSimilarity} '
          'shape=${result.shapeSimilarity}',
    );
  });

  test('accepts Q when the visible tail is travelled backwards', () {
    final strokes =
        _referenceStrokes('Q', sourceSize).map((stroke) => stroke).toList();
    strokes[1] = strokes[1].reversed.toList(growable: false);
    final result = validator.validate(
      target: 'Q',
      language: HandwritingLanguage.english,
      strokes: strokes,
      sourceSize: sourceSize,
    );

    expect(result.strokeDirectionCorrect, isFalse);
    expect(result.orientationCorrect, isTrue);
    expect(result.formationCorrect, isTrue);
  });

  test('rejects real-canvas Q tail in the upper-left region', () {
    final result = validator.validate(
      target: 'Q',
      language: HandwritingLanguage.english,
      strokes: _realisticWrongQStrokes(),
      sourceSize: sourceSize,
    );

    expect(result.startEndScore, lessThan(0.55));
    expect(result.orientationCorrect, isFalse);
  });

  for (final character in 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'.split('')) {
    test('accepts a natural reverse-traversal $character variant', () {
      final strokes = _referenceStrokes(character, sourceSize)
          .map((stroke) => stroke.reversed.toList(growable: false))
          .toList(growable: false);
      final result = validator.validate(
        target: character,
        language: HandwritingLanguage.english,
        strokes: strokes,
        sourceSize: sourceSize,
      );

      expect(result.orientationCorrect, isTrue);
      expect(result.formationCorrect, isTrue);
    });

    test('accepts a slightly imperfect handwritten $character', () {
      final strokes = _jitterStrokes(
        _referenceStrokes(character, sourceSize),
      );
      final result = validator.validate(
        target: character,
        language: HandwritingLanguage.english,
        strokes: strokes,
        sourceSize: sourceSize,
      );

      expect(
        result.formationCorrect,
        isTrue,
        reason: '$character failed with ${result.failureReason}',
      );
    });

    final referenceStrokeCount = CharacterStrokeRepository.find(
      character: character,
      language: HandwritingLanguage.english,
    )!
        .strokes
        .length;
    if (referenceStrokeCount > 1) {
      test('accepts an alternative stroke order for $character', () {
        final strokes = _referenceStrokes(character, sourceSize)
            .reversed
            .toList(growable: false);
        final result = validator.validate(
          target: character,
          language: HandwritingLanguage.english,
          strokes: strokes,
          sourceSize: sourceSize,
        );

        expect(result.orientationCorrect, isTrue);
        expect(result.formationCorrect, isTrue);
      });
    }
  }

  for (final character in 'abcdefghijklmnopqrstuvwxyz'.split('')) {
    test('accepts a lowercase reverse-traversal $character variant', () {
      final strokes = _referenceStrokes(character, sourceSize)
          .map((stroke) => stroke.reversed.toList(growable: false))
          .toList(growable: false);
      final result = validator.validate(
        target: character,
        language: HandwritingLanguage.english,
        strokes: strokes,
        sourceSize: sourceSize,
      );

      expect(result.orientationCorrect, isTrue);
      expect(result.formationCorrect, isTrue);
    });

    test('accepts a slightly imperfect lowercase $character', () {
      final result = validator.validate(
        target: character,
        language: HandwritingLanguage.english,
        strokes: _jitterStrokes(_referenceStrokes(character, sourceSize)),
        sourceSize: sourceSize,
      );

      expect(
        result.formationCorrect,
        isTrue,
        reason: '$character failed with ${result.failureReason}',
      );
    });

    final reference = _referenceStrokes(character, sourceSize);
    if (reference.length > 1) {
      test('accepts an alternative lowercase stroke order for $character', () {
        final result = validator.validate(
          target: character,
          language: HandwritingLanguage.english,
          strokes: reference.reversed.toList(growable: false),
          sourceSize: sourceSize,
        );

        expect(result.orientationCorrect, isTrue);
        expect(result.formationCorrect, isTrue);
      });

      test('accepts a continuous lowercase $character formation', () {
        final result = validator.validate(
          target: character,
          language: HandwritingLanguage.english,
          strokes: [_joinForTest(reference)],
          sourceSize: sourceSize,
        );

        expect(
          result.formationCorrect,
          isTrue,
          reason: '$character failed with ${result.failureReason}',
        );
      });
    } else if (reference.single.length >= 6) {
      test('accepts a segmented lowercase $character formation', () {
        final midpoint = reference.single.length ~/ 2;
        final result = validator.validate(
          target: character,
          language: HandwritingLanguage.english,
          strokes: [
            reference.single.sublist(0, midpoint + 1),
            reference.single.sublist(midpoint),
          ],
          sourceSize: sourceSize,
        );

        expect(result.orientationCorrect, isTrue);
        expect(result.formationCorrect, isTrue);
      });
    }
  }

  test('accepts lowercase d loop-first, stem-first, and reverse-loop', () {
    final variants = <List<List<Offset>>>[
      _realisticLowercaseD(),
      _realisticLowercaseD().reversed.toList(growable: false),
      [
        _realisticLowercaseD().first.reversed.toList(growable: false),
        _realisticLowercaseD().last,
      ],
    ];

    for (final strokes in variants) {
      final result = validator.validate(
        target: 'd',
        language: HandwritingLanguage.english,
        strokes: strokes,
        sourceSize: sourceSize,
      );
      expect(result.orientationCorrect, isTrue);
      expect(result.formationCorrect, isTrue);
    }
  });

  test('accepts a continuous lowercase d', () {
    final result = validator.validate(
      target: 'd',
      language: HandwritingLanguage.english,
      strokes: [_joinForTest(_realisticLowercaseD())],
      sourceSize: sourceSize,
    );

    expect(result.orientationCorrect, isTrue);
    expect(result.formationCorrect, isTrue);
    expect(result.matchedValidVariant, contains('continuous'));
  });

  test('rejects a clearly mirrored lowercase d', () {
    final result = validator.validate(
      target: 'd',
      language: HandwritingLanguage.english,
      strokes: _mirrorHorizontally(
        _realisticLowercaseD(),
        sourceSize.width,
      ),
      sourceSize: sourceSize,
    );

    expect(result.orientationState, 'MIRRORED');
    expect(result.orientationCorrect, isFalse);
    expect(result.formationCorrect, isFalse);
    expect(result.feedback, contains('direction'));
  });

  test('accepts continuous, multi-stroke, and imperfect lowercase m', () {
    final variants = <List<List<Offset>>>[
      [_realisticContinuousLowercaseM()],
      _realisticMultiStrokeLowercaseM(),
      _jitterStrokes(_realisticMultiStrokeLowercaseM()),
    ];

    for (final strokes in variants) {
      final result = validator.validate(
        target: 'm',
        language: HandwritingLanguage.english,
        strokes: strokes,
        sourceSize: sourceSize,
      );
      expect(
        result.orientationCorrect,
        isTrue,
        reason: 'm state=${result.orientationState} '
            'correct=${result.correctFormationSimilarity} '
            'mirror=${result.mirroredFormationSimilarity}',
      );
      expect(result.formationCorrect, isTrue);
    }
  });

  test('accepts Z as one continuous stroke', () {
    final result = validator.validate(
      target: 'Z',
      language: HandwritingLanguage.english,
      strokes: [_zContinuous()],
      sourceSize: sourceSize,
    );

    expect(result.orientationCorrect, isTrue);
    expect(result.shapeCorrect, isTrue);
    expect(result.formationCorrect, isTrue);
    expect(result.matchedValidVariant, 'Z_CONTINUOUS');
  });

  test('accepts Z as three separate strokes', () {
    final result = validator.validate(
      target: 'Z',
      language: HandwritingLanguage.english,
      strokes: _zThreeStroke(),
      sourceSize: sourceSize,
    );

    expect(result.orientationCorrect, isTrue);
    expect(result.shapeCorrect, isTrue);
    expect(result.formationCorrect, isTrue);
    expect(result.matchedValidVariant, 'Z_THREE_STROKE');
    expect(result.strokeCountCorrect, isTrue);
  });

  test('accepts reverse traversal of a correctly shaped Z', () {
    final result = validator.validate(
      target: 'Z',
      language: HandwritingLanguage.english,
      strokes: [_zContinuous().reversed.toList(growable: false)],
      sourceSize: sourceSize,
    );

    expect(result.orientationCorrect, isTrue);
    expect(result.formationCorrect, isTrue);
    expect(result.matchedValidVariant, 'Z_REVERSE_TRAVERSAL');
  });

  test('accepts a slightly imperfect but recognizable Z', () {
    final result = validator.validate(
      target: 'Z',
      language: HandwritingLanguage.english,
      strokes: const [
        [
          Offset(58, 55),
          Offset(145, 50),
          Offset(239, 58),
          Offset(205, 115),
          Offset(152, 201),
          Offset(105, 278),
          Offset(63, 344),
          Offset(151, 349),
          Offset(242, 343),
        ],
      ],
      sourceSize: sourceSize,
    );

    expect(result.orientationCorrect, isTrue);
    expect(result.shapeCorrect, isTrue);
    expect(result.formationCorrect, isTrue);
  });

  test('rejects malformed non-Z geometry without direction feedback', () {
    final result = validator.validate(
      target: 'Z',
      language: HandwritingLanguage.english,
      strokes: const [
        [Offset(60, 50), Offset(240, 50)],
        [Offset(240, 50), Offset(240, 350)],
        [Offset(60, 350), Offset(240, 350)],
      ],
      sourceSize: sourceSize,
    );

    expect(result.orientationCorrect, isTrue);
    expect(
      result.shapeCorrect,
      isFalse,
      reason: 'shapeSimilarity=${result.shapeSimilarity}',
    );
    expect(result.formationCorrect, isFalse);
    expect(result.feedback, isNot(contains('direction')));
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

List<List<Offset>> _jitterStrokes(List<List<Offset>> strokes) {
  var pointIndex = 0;
  return strokes.map((stroke) {
    return stroke.map((point) {
      final dx = (pointIndex % 5 - 2) * 0.7;
      final dy = (pointIndex % 7 - 3) * 0.55;
      pointIndex++;
      return Offset(point.dx + dx, point.dy + dy);
    }).toList(growable: false);
  }).toList(growable: false);
}

List<Offset> _joinForTest(List<List<Offset>> strokes) =>
    strokes.expand((stroke) => stroke).toList(growable: false);

List<List<Offset>> _realisticLowercaseD() => const [
      [
        Offset(198, 170),
        Offset(168, 150),
        Offset(122, 153),
        Offset(88, 185),
        Offset(82, 235),
        Offset(105, 282),
        Offset(151, 298),
        Offset(193, 279),
        Offset(199, 230),
        Offset(198, 170),
      ],
      [
        Offset(202, 66),
        Offset(201, 130),
        Offset(200, 206),
        Offset(201, 296),
      ],
    ];

List<Offset> _realisticContinuousLowercaseM() => const [
      Offset(60, 330),
      Offset(60, 175),
      Offset(61, 320),
      Offset(70, 245),
      Offset(91, 194),
      Offset(118, 181),
      Offset(143, 207),
      Offset(145, 330),
      Offset(145, 238),
      Offset(164, 193),
      Offset(193, 181),
      Offset(219, 208),
      Offset(220, 330),
    ];

List<List<Offset>> _realisticMultiStrokeLowercaseM() => const [
      [Offset(61, 175), Offset(60, 250), Offset(60, 330)],
      [
        Offset(61, 235),
        Offset(91, 184),
        Offset(119, 181),
        Offset(144, 210),
        Offset(145, 330),
        Offset(145, 235),
        Offset(172, 183),
        Offset(196, 184),
        Offset(220, 211),
        Offset(220, 330),
      ],
    ];

List<Offset> _zContinuous() => const [
      Offset(60, 48),
      Offset(120, 48),
      Offset(180, 48),
      Offset(240, 48),
      Offset(195, 124),
      Offset(150, 200),
      Offset(105, 276),
      Offset(60, 352),
      Offset(120, 352),
      Offset(180, 352),
      Offset(240, 352),
    ];

List<List<Offset>> _zThreeStroke() => const [
      [Offset(60, 48), Offset(150, 48), Offset(240, 48)],
      [Offset(240, 48), Offset(150, 200), Offset(60, 352)],
      [Offset(60, 352), Offset(150, 352), Offset(240, 352)],
    ];

List<List<Offset>> _realisticMirroredStrokes(String character) {
  return switch (character) {
    'B' => const [
        [
          Offset(205, 70),
          Offset(150, 70),
          Offset(105, 78),
          Offset(72, 105),
          Offset(64, 145),
          Offset(78, 170),
          Offset(118, 185),
          Offset(205, 185),
          Offset(142, 190),
          Offset(92, 210),
          Offset(66, 246),
          Offset(67, 282),
          Offset(92, 316),
          Offset(145, 338),
          Offset(205, 338),
          Offset(205, 70),
        ],
      ],
    'E' => const [
        [
          Offset(72, 78),
          Offset(205, 78),
          Offset(205, 322),
          Offset(88, 322),
        ],
        [Offset(118, 198), Offset(205, 198)],
      ],
    'J' => const [
        [Offset(62, 72), Offset(225, 72)],
        [
          Offset(145, 72),
          Offset(145, 270),
          Offset(154, 306),
          Offset(176, 326),
          Offset(205, 326),
          Offset(224, 300),
          Offset(228, 272),
        ],
      ],
    _ => throw ArgumentError.value(character, 'character'),
  };
}

List<List<Offset>> _realisticCorrectStrokes(String character, Size size) {
  final strokes = _mirrorHorizontally(
    _realisticMirroredStrokes(character),
    size.width,
  ).map((stroke) => stroke).toList();
  // The screenshot-style J top bar was travelled left-to-right before its
  // geometry was mirrored. Restore the demonstration's left-to-right travel
  // direction as well as its correct appearance.
  if (character == 'J') {
    strokes[0] = strokes[0].reversed.toList(growable: false);
  }
  return strokes;
}

List<List<List<Offset>>> _realisticDStrokes() => const [
      [
        [
          Offset(218, 84),
          Offset(166, 64),
          Offset(125, 68),
          Offset(88, 105),
          Offset(65, 156),
          Offset(67, 226),
          Offset(94, 286),
          Offset(137, 326),
          Offset(204, 326),
        ],
        [Offset(176, 103), Offset(176, 292)],
      ],
      [
        [
          Offset(76, 116),
          Offset(80, 82),
          Offset(124, 48),
          Offset(185, 48),
          Offset(225, 74),
          Offset(252, 123),
          Offset(259, 195),
          Offset(238, 261),
          Offset(196, 305),
          Offset(124, 311),
          Offset(76, 282),
        ],
        [Offset(112, 96), Offset(112, 280)],
      ],
    ];

List<List<Offset>> _realisticWrongQStrokes() => const [
      [
        Offset(154, 91),
        Offset(112, 88),
        Offset(78, 111),
        Offset(60, 158),
        Offset(62, 224),
        Offset(88, 281),
        Offset(132, 315),
        Offset(185, 316),
        Offset(224, 279),
        Offset(245, 217),
        Offset(241, 153),
        Offset(213, 109),
        Offset(172, 91),
        Offset(154, 91),
      ],
      [
        Offset(91, 54),
        Offset(94, 81),
        Offset(109, 119),
        Offset(130, 158),
      ],
    ];
