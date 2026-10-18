import 'dart:typed_data';
import 'dart:ui' as ui;

class HandwritingPreprocessingException implements Exception {
  const HandwritingPreprocessingException(this.message);

  final String message;

  @override
  String toString() => 'HandwritingPreprocessingException: $message';
}

class PreprocessedHandwriting {
  const PreprocessedHandwriting({
    required this.rgbBytes,
    required this.width,
    required this.height,
  });

  final Uint8List rgbBytes;
  final int width;
  final int height;
}

class HandwritingImagePreprocessor {
  const HandwritingImagePreprocessor();

  static const int defaultOutputSize = 224;
  static const int _trainingContentSize = 176;
  static const int _trainingCanvasSize = 224;
  static const int _minimumInkStrength = 20;

  Future<PreprocessedHandwriting> preprocess(
    ui.Image image, {
    int outputWidth = defaultOutputSize,
    int outputHeight = defaultOutputSize,
  }) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw const HandwritingPreprocessingException(
        'The handwriting image could not be read.',
      );
    }
    return preprocessRgba(
      byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ),
      sourceWidth: image.width,
      sourceHeight: image.height,
      outputWidth: outputWidth,
      outputHeight: outputHeight,
    );
  }

  PreprocessedHandwriting preprocessRgba(
    Uint8List rgbaBytes, {
    required int sourceWidth,
    required int sourceHeight,
    int outputWidth = defaultOutputSize,
    int outputHeight = defaultOutputSize,
  }) {
    if (sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        outputWidth <= 0 ||
        outputHeight <= 0 ||
        rgbaBytes.length != sourceWidth * sourceHeight * 4) {
      throw const HandwritingPreprocessingException(
        'The handwriting image has invalid dimensions.',
      );
    }

    var left = sourceWidth;
    var top = sourceHeight;
    var right = -1;
    var bottom = -1;
    var inkPixels = 0;

    for (var y = 0; y < sourceHeight; y++) {
      for (var x = 0; x < sourceWidth; x++) {
        if (_inkStrengthAt(rgbaBytes, sourceWidth, x, y) <
            _minimumInkStrength) {
          continue;
        }
        inkPixels++;
        if (x < left) left = x;
        if (x > right) right = x;
        if (y < top) top = y;
        if (y > bottom) bottom = y;
      }
    }

    if (right < left || bottom < top || inkPixels < 4) {
      throw const HandwritingPreprocessingException(
        'No handwriting was detected.',
      );
    }

    final inkWidth = right - left + 1;
    final inkHeight = bottom - top + 1;
    final cropPadding = ((inkWidth > inkHeight ? inkWidth : inkHeight) * 0.04)
        .round()
        .clamp(2, sourceWidth > sourceHeight ? sourceWidth : sourceHeight);
    final cropLeft = (left - cropPadding).clamp(0, sourceWidth - 1);
    final cropTop = (top - cropPadding).clamp(0, sourceHeight - 1);
    final cropRight = (right + cropPadding).clamp(0, sourceWidth - 1);
    final cropBottom = (bottom + cropPadding).clamp(0, sourceHeight - 1);
    final cropWidth = cropRight - cropLeft + 1;
    final cropHeight = cropBottom - cropTop + 1;

    final targetContentWidth =
        (outputWidth * _trainingContentSize / _trainingCanvasSize).round();
    final targetContentHeight =
        (outputHeight * _trainingContentSize / _trainingCanvasSize).round();
    final scaleX = targetContentWidth / cropWidth;
    final scaleY = targetContentHeight / cropHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    final resizedWidth = (cropWidth * scale).round().clamp(1, outputWidth);
    final resizedHeight = (cropHeight * scale).round().clamp(1, outputHeight);
    final offsetX = (outputWidth - resizedWidth) ~/ 2;
    final offsetY = (outputHeight - resizedHeight) ~/ 2;

    final output = Uint8List(outputWidth * outputHeight * 3)
      ..fillRange(
        0,
        outputWidth * outputHeight * 3,
        255,
      );

    for (var destinationY = 0; destinationY < resizedHeight; destinationY++) {
      final sourceY =
          cropTop + ((destinationY + 0.5) * cropHeight / resizedHeight) - 0.5;
      for (var destinationX = 0; destinationX < resizedWidth; destinationX++) {
        final sourceX =
            cropLeft + ((destinationX + 0.5) * cropWidth / resizedWidth) - 0.5;
        final inkStrength = _bilinearInkStrength(
          rgbaBytes,
          sourceWidth,
          sourceHeight,
          sourceX,
          sourceY,
        );
        final grey = (255 - inkStrength).round().clamp(0, 255);
        final outputX = offsetX + destinationX;
        final outputY = offsetY + destinationY;
        final outputIndex = (outputY * outputWidth + outputX) * 3;
        output[outputIndex] = grey;
        output[outputIndex + 1] = grey;
        output[outputIndex + 2] = grey;
      }
    }

    return PreprocessedHandwriting(
      rgbBytes: output,
      width: outputWidth,
      height: outputHeight,
    );
  }

  double _bilinearInkStrength(
    Uint8List rgbaBytes,
    int width,
    int height,
    double x,
    double y,
  ) {
    final x0 = x.floor().clamp(0, width - 1);
    final y0 = y.floor().clamp(0, height - 1);
    final x1 = (x0 + 1).clamp(0, width - 1);
    final y1 = (y0 + 1).clamp(0, height - 1);
    final xWeight = x - x.floor();
    final yWeight = y - y.floor();
    final top = _inkStrengthAt(rgbaBytes, width, x0, y0) * (1 - xWeight) +
        _inkStrengthAt(rgbaBytes, width, x1, y0) * xWeight;
    final bottom = _inkStrengthAt(rgbaBytes, width, x0, y1) * (1 - xWeight) +
        _inkStrengthAt(rgbaBytes, width, x1, y1) * xWeight;
    return top * (1 - yWeight) + bottom * yWeight;
  }

  int _inkStrengthAt(Uint8List rgbaBytes, int width, int x, int y) {
    final index = (y * width + x) * 4;
    final red = rgbaBytes[index];
    final green = rgbaBytes[index + 1];
    final blue = rgbaBytes[index + 2];
    final alpha = rgbaBytes[index + 3];
    final luminance = (red * 299 + green * 587 + blue * 114) ~/ 1000;
    return ((255 - luminance) * alpha / 255).round();
  }
}
