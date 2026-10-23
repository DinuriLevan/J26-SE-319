import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

enum HandwritingPreprocessingFailure { invalidImage, empty, tooSmall }

class HandwritingPreprocessingException implements Exception {
  const HandwritingPreprocessingException(this.message, this.failure);

  final String message;
  final HandwritingPreprocessingFailure failure;

  String get userMessage => switch (failure) {
        HandwritingPreprocessingFailure.tooSmall =>
          'Please write the letter a little larger.',
        HandwritingPreprocessingFailure.empty => 'Write the letter first.',
        HandwritingPreprocessingFailure.invalidImage =>
          'We couldn’t prepare that writing. Please try again.',
      };

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
  static const double modelStrokeWidth = 18;
  static const double englishLowercaseModelStrokeWidth = 18;
  static const double modelPaddingRatio = 0.136;
  static const double _minimumExtentFraction = 0.12;
  static const double _minimumPathLengthFraction = 0.08;

  /// Builds the model input directly from touch coordinates. No widget,
  /// guide line, target glyph, or surrounding UI can enter this image.
  Future<PreprocessedHandwriting> preprocessStrokes({
    required List<List<ui.Offset>> strokes,
    required ui.Size sourceSize,
    double outputStrokeWidth = modelStrokeWidth,
    int outputSize = defaultOutputSize,
  }) async {
    if (sourceSize.isEmpty ||
        !sourceSize.width.isFinite ||
        !sourceSize.height.isFinite ||
        outputStrokeWidth <= 0 ||
        outputSize <= 0) {
      throw const HandwritingPreprocessingException(
        'The handwriting canvas has invalid dimensions.',
        HandwritingPreprocessingFailure.invalidImage,
      );
    }

    final usableStrokes = strokes
        .map(
          (stroke) => stroke
              .where((point) => point.dx.isFinite && point.dy.isFinite)
              .toList(growable: false),
        )
        .where((stroke) => stroke.isNotEmpty)
        .toList(growable: false);
    if (usableStrokes.isEmpty) {
      throw const HandwritingPreprocessingException(
        'No handwriting was detected.',
        HandwritingPreprocessingFailure.empty,
      );
    }

    var left = double.infinity;
    var top = double.infinity;
    var right = double.negativeInfinity;
    var bottom = double.negativeInfinity;
    var pathLength = 0.0;
    for (final stroke in usableStrokes) {
      for (var index = 0; index < stroke.length; index++) {
        final point = stroke[index];
        left = math.min(left, point.dx);
        top = math.min(top, point.dy);
        right = math.max(right, point.dx);
        bottom = math.max(bottom, point.dy);
        if (index > 0) pathLength += (point - stroke[index - 1]).distance;
      }
    }

    final shortestCanvasSide = math.min(sourceSize.width, sourceSize.height);
    final pointWidth = right - left;
    final pointHeight = bottom - top;
    final pointExtent = math.max(pointWidth, pointHeight);
    if (pointExtent < shortestCanvasSide * _minimumExtentFraction ||
        pathLength < shortestCanvasSide * _minimumPathLengthFraction) {
      throw const HandwritingPreprocessingException(
        'The handwriting is too small to classify reliably.',
        HandwritingPreprocessingFailure.tooSmall,
      );
    }

    // Keep a consistent white margin around the actual ink. At 224px, 13.6%
    // per side leaves about 163px for the longest ink dimension. This mirrors
    // prepare_dataset.py's 176px padded crop while preserving terminal strokes.
    final targetInkExtent = outputSize * (1 - modelPaddingRatio * 2);
    final targetCenterlineExtent = math.max(
      1.0,
      targetInkExtent - outputStrokeWidth,
    );
    final scale = targetCenterlineExtent / pointExtent;
    final destinationWidth = pointWidth * scale;
    final destinationHeight = pointHeight * scale;
    final offsetX = (outputSize - destinationWidth) / 2;
    final offsetY = (outputSize - destinationHeight) / 2;

    ui.Offset mapPoint(ui.Offset point) => ui.Offset(
          offsetX + (point.dx - left) * scale,
          offsetY + (point.dy - top) * scale,
        );

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, outputSize.toDouble(), outputSize.toDouble()),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );
    final inkPaint = ui.Paint()
      ..color = const ui.Color(0xFF000000)
      ..strokeWidth = outputStrokeWidth
      ..strokeCap = ui.StrokeCap.round
      ..strokeJoin = ui.StrokeJoin.round
      ..style = ui.PaintingStyle.stroke
      ..isAntiAlias = true;
    final dotPaint = ui.Paint()
      ..color = const ui.Color(0xFF000000)
      ..style = ui.PaintingStyle.fill
      ..isAntiAlias = true;

    for (final stroke in usableStrokes) {
      if (stroke.length == 1) {
        canvas.drawCircle(
          mapPoint(stroke.single),
          inkPaint.strokeWidth / 2,
          dotPaint,
        );
        continue;
      }
      final first = mapPoint(stroke.first);
      final path = ui.Path()..moveTo(first.dx, first.dy);
      for (final point in stroke.skip(1)) {
        final mapped = mapPoint(point);
        path.lineTo(mapped.dx, mapped.dy);
      }
      canvas.drawPath(path, inkPaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(outputSize, outputSize);
    picture.dispose();
    try {
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (byteData == null) {
        throw const HandwritingPreprocessingException(
          'The standardized handwriting image could not be read.',
          HandwritingPreprocessingFailure.invalidImage,
        );
      }
      return PreprocessedHandwriting(
        rgbBytes: _rgbaToRgb(
          byteData.buffer.asUint8List(
            byteData.offsetInBytes,
            byteData.lengthInBytes,
          ),
        ),
        width: outputSize,
        height: outputSize,
      );
    } finally {
      image.dispose();
    }
  }

  /// Produces an in-app debug preview from the exact RGB bytes sent to TFLite.
  Future<ui.Image> createDebugImage(PreprocessedHandwriting handwriting) {
    final rgba = Uint8List(handwriting.width * handwriting.height * 4);
    for (var pixel = 0;
        pixel < handwriting.width * handwriting.height;
        pixel++) {
      final rgbIndex = pixel * 3;
      final rgbaIndex = pixel * 4;
      rgba[rgbaIndex] = handwriting.rgbBytes[rgbIndex];
      rgba[rgbaIndex + 1] = handwriting.rgbBytes[rgbIndex + 1];
      rgba[rgbaIndex + 2] = handwriting.rgbBytes[rgbIndex + 2];
      rgba[rgbaIndex + 3] = 255;
    }
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      rgba,
      handwriting.width,
      handwriting.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  Future<PreprocessedHandwriting> preprocess(
    ui.Image image, {
    int outputWidth = defaultOutputSize,
    int outputHeight = defaultOutputSize,
  }) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      throw const HandwritingPreprocessingException(
        'The handwriting image could not be read.',
        HandwritingPreprocessingFailure.invalidImage,
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
        HandwritingPreprocessingFailure.invalidImage,
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
        HandwritingPreprocessingFailure.empty,
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

  Uint8List _rgbaToRgb(Uint8List rgbaBytes) {
    final rgb = Uint8List(rgbaBytes.length ~/ 4 * 3);
    for (var source = 0, destination = 0;
        source < rgbaBytes.length;
        source += 4, destination += 3) {
      rgb[destination] = rgbaBytes[source];
      rgb[destination + 1] = rgbaBytes[source + 1];
      rgb[destination + 2] = rgbaBytes[source + 2];
    }
    return rgb;
  }
}
