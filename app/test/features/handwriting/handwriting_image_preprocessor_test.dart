import 'dart:typed_data';
import 'dart:ui';

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

  test('renders stored strokes onto a centered clean model canvas', () async {
    expect(HandwritingImagePreprocessor.modelPaddingRatio, 0.136);
    final result = await preprocessor.preprocessStrokes(
      sourceSize: const Size(300, 400),
      strokes: const [
        [Offset(80, 300), Offset(150, 80), Offset(220, 300)],
        [Offset(112, 205), Offset(188, 205)],
      ],
    );

    expect(result.width, 224);
    expect(result.height, 224);
    expect(result.rgbBytes, hasLength(224 * 224 * 3));
    expect(result.rgbBytes.take(3), everyElement(255));

    var left = 224;
    var top = 224;
    var right = -1;
    var bottom = -1;
    var nonGreyPixelFound = false;
    for (var y = 0; y < 224; y++) {
      for (var x = 0; x < 224; x++) {
        final index = (y * 224 + x) * 3;
        final red = result.rgbBytes[index];
        final green = result.rgbBytes[index + 1];
        final blue = result.rgbBytes[index + 2];
        if (red != green || red != blue) nonGreyPixelFound = true;
        if (red >= 245) continue;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }

    expect(nonGreyPixelFound, isFalse);
    expect((left + right) / 2, closeTo(111.5, 2));
    expect((top + bottom) / 2, closeTo(111.5, 2));
    final inkWidth = right - left + 1;
    final inkHeight = bottom - top + 1;
    final longestInkDimension = inkWidth > inkHeight ? inkWidth : inkHeight;
    expect(longestInkDimension, inInclusiveRange(161, 165));
  });

  test('rejects an extremely tiny stroke', () async {
    expect(
      () => preprocessor.preprocessStrokes(
        sourceSize: const Size(300, 400),
        strokes: const [
          [Offset(100, 100), Offset(104, 104)],
        ],
      ),
      throwsA(
        isA<HandwritingPreprocessingException>().having(
          (error) => error.failure,
          'failure',
          HandwritingPreprocessingFailure.tooSmall,
        ),
      ),
    );
  });

  test('preserves left-right orientation of a d-like character', () async {
    final result = await preprocessor.preprocessStrokes(
      sourceSize: const Size(300, 400),
      strokes: const [
        [
          Offset(210, 45),
          Offset(210, 330),
        ],
        [
          Offset(210, 175),
          Offset(175, 145),
          Offset(115, 150),
          Offset(80, 205),
          Offset(82, 275),
          Offset(125, 325),
          Offset(210, 330),
        ],
      ],
    );

    var upperInkXTotal = 0;
    var upperInkPixels = 0;
    for (var y = 0; y < result.height ~/ 3; y++) {
      for (var x = 0; x < result.width; x++) {
        if (result.rgbBytes[(y * result.width + x) * 3] >= 128) continue;
        upperInkXTotal += x;
        upperInkPixels++;
      }
    }
    expect(upperInkPixels, greaterThan(0));
    expect(upperInkXTotal / upperInkPixels, greaterThan(112));
  });

  test('uses the fixed training-matched model stroke width', () async {
    expect(HandwritingImagePreprocessor.modelStrokeWidth, 18);
    final result = await preprocessor.preprocessStrokes(
      sourceSize: const Size(300, 400),
      strokes: const [
        [Offset(150, 60), Offset(150, 340)],
      ],
    );

    var darkPixelsAcrossCenter = 0;
    for (var x = 0; x < result.width; x++) {
      if (result.rgbBytes[(112 * result.width + x) * 3] < 128) {
        darkPixelsAcrossCenter++;
      }
    }
    expect(darkPixelsAcrossCenter, closeTo(18, 2));
  });

  test('uses the configured lowercase model stroke width', () async {
    expect(HandwritingImagePreprocessor.englishLowercaseModelStrokeWidth, 18);
    final result = await preprocessor.preprocessStrokes(
      sourceSize: const Size(300, 400),
      outputStrokeWidth:
          HandwritingImagePreprocessor.englishLowercaseModelStrokeWidth,
      strokes: const [
        [Offset(150, 60), Offset(150, 340)],
      ],
    );

    var darkPixelsAcrossCenter = 0;
    for (var x = 0; x < result.width; x++) {
      if (result.rgbBytes[(112 * result.width + x) * 3] < 128) {
        darkPixelsAcrossCenter++;
      }
    }
    expect(darkPixelsAcrossCenter, closeTo(18, 2));
  });
}
