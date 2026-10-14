import 'dart:ui';

import 'package:akurin/features/handwriting/data/character_stroke_repository.dart';
import 'package:akurin/features/handwriting/data/english_lowercase_strokes.dart';
import 'package:akurin/features/handwriting/data/english_uppercase_strokes.dart';
import 'package:akurin/features/handwriting/data/sinhala_strokes.dart';
import 'package:akurin/features/handwriting/models/character_stroke_definition.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const englishUppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const englishLowercase = 'abcdefghijklmnopqrstuvwxyz';
  const sinhalaCharacters = [
    'අ',
    'ආ',
    'ඇ',
    'ඈ',
    'ඉ',
    'ඊ',
    'උ',
    'ඌ',
    'එ',
    'ඒ',
    'ඔ',
    'ඕ',
    'ක',
    'ඛ',
    'ග',
    'ඝ',
    'ච',
    'ඡ',
    'ජ',
    'ට',
    'ඨ',
    'ඩ',
    'ඪ',
    'ණ',
    'ත',
    'ථ',
    'ද',
    'ධ',
    'න',
    'ප',
    'ඵ',
    'බ',
    'භ',
    'ම',
    'ඹ',
    'ය',
    'ර',
    'ල',
    'ව',
    'ශ',
    'ස',
    'හ',
    'ළ',
  ];

  test('provides all 52 English print definitions', () {
    expect(englishUppercaseStrokes, hasLength(26));
    expect(englishLowercaseStrokes, hasLength(26));

    for (final character in englishUppercase.split('')) {
      expect(
        CharacterStrokeRepository.find(
          character: character,
          language: HandwritingLanguage.english,
        ),
        isNotNull,
        reason: 'Missing uppercase $character',
      );
    }
    for (final character in englishLowercase.split('')) {
      expect(
        CharacterStrokeRepository.find(
          character: character,
          language: HandwritingLanguage.english,
        ),
        isNotNull,
        reason: 'Missing lowercase $character',
      );
    }
  });

  test('provides exactly the 43 Sinhala selection definitions', () {
    expect(sinhalaStrokes, hasLength(43));
    expect(sinhalaCharacters, hasLength(43));

    for (final character in sinhalaCharacters) {
      expect(
        CharacterStrokeRepository.find(
          character: character,
          language: HandwritingLanguage.sinhala,
        ),
        isNotNull,
        reason: 'Missing Sinhala $character',
      );
    }
  });

  test('every supported stroke is normalized and measurable', () {
    final definitions = [
      ...englishUppercaseStrokes.values,
      ...englishLowercaseStrokes.values,
      ...sinhalaStrokes.values,
    ];

    for (final definition in definitions) {
      expect(definition.strokes, isNotEmpty, reason: definition.character);
      for (final stroke in definition.strokes) {
        _expectNormalized(stroke.start, definition.character);
        for (final point in stroke.sampledPoints) {
          _expectNormalized(point, definition.character);
        }
        for (final segment in stroke.segments) {
          _expectNormalized(segment.end, definition.character);
          if (segment.control1 case final control?) {
            _expectNormalized(control, definition.character);
          }
          if (segment.control2 case final control?) {
            _expectNormalized(control, definition.character);
          }
        }

        final metrics = stroke
            .buildPath(const Size(300, 360))
            .computeMetrics()
            .toList(growable: false);
        expect(metrics, isNotEmpty, reason: definition.character);
        expect(
          metrics.first.length,
          greaterThan(0),
          reason: definition.character,
        );
      }
    }
  });

  test('approved Sinhala samples preserve continuous pen motion', () {
    for (final character in ['ක', 'ග', 'අ']) {
      final definition = sinhalaStrokes[character]!;
      expect(definition.strokes, hasLength(1));
      expect(
        definition.strokes.single.segments.length,
        greaterThanOrEqualTo(8),
      );
    }
  });

  test('unknown characters still return no definition', () {
    expect(
      CharacterStrokeRepository.find(
        character: '?',
        language: HandwritingLanguage.english,
      ),
      isNull,
    );
  });
}

void _expectNormalized(Offset point, String character) {
  expect(point.dx, inInclusiveRange(0.0, 1.0), reason: '$character x');
  expect(point.dy, inInclusiveRange(0.0, 1.0), reason: '$character y');
}
