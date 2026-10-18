import 'dart:typed_data';

import 'package:akurin/features/handwriting/services/handwriting_image_preprocessor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const preprocessor = HandwritingImagePreprocessor();

  test('creates centered 224 RGB input without stretching handwriting', () {
    const width = 40;
    const height = 20;
    final rgba = Uint8List(width * height * 4);
    for (var pixel = 0; pixel < width * height; pixel++) {
      final index = pixel * 4;
      rgba[index] = 255;
      rgba[index + 1] = 255;
      rgba[index + 2] = 255;
      rgba[index + 3] = 255;
    }
    for (var y = 6; y <= 13; y++) {
      for (var x = 8; x <= 31; x++) {
        final index = (y * width + x) * 4;
        rgba[index] = 20;
        rgba[index + 1] = 80;
        rgba[index + 2] = 200;
      }
    }

    final result = preprocessor.preprocessRgba(
      rgba,
      sourceWidth: width,
      sourceHeight: height,
    );

    expect(result.width, 224);
    expect(result.height, 224);
    expect(result.rgbBytes, hasLength(224 * 224 * 3));
    expect(result.rgbBytes.take(3), everyElement(255));

    var left = 224;
    var top = 224;
    var right = -1;
    var bottom = -1;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        if (result.rgbBytes[(y * 224 + x) * 3] >= 245) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }
    final inkWidth = right - left + 1;
    final inkHeight = bottom - top + 1;
    expect((left + right) / 2, closeTo(111.5, 2));
    expect((top + bottom) / 2, closeTo(111.5, 2));
    expect(inkWidth / inkHeight, closeTo(3, 0.35));
    expect(inkWidth, lessThanOrEqualTo(176));
  });

  test('rejects a blank canvas', () {
    final white = Uint8List(20 * 20 * 4);
    for (var pixel = 0; pixel < 20 * 20; pixel++) {
      white[pixel * 4] = 255;
      white[pixel * 4 + 1] = 255;
      white[pixel * 4 + 2] = 255;
      white[pixel * 4 + 3] = 255;
    }

    expect(
      () => preprocessor.preprocessRgba(
        white,
        sourceWidth: 20,
        sourceHeight: 20,
      ),
      throwsA(isA<HandwritingPreprocessingException>()),
    );
  });
}
