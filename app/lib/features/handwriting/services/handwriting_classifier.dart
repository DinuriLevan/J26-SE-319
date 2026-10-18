import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import '../models/handwriting_prediction.dart';
import 'handwriting_image_preprocessor.dart';

enum HandwritingModelType {
  englishUppercase,
  englishLowercase,
  sinhala,
}

extension HandwritingModelTypeAssets on HandwritingModelType {
  String get modelAsset => switch (this) {
        HandwritingModelType.englishUppercase =>
          'assets/models/english_uppercase_model.tflite',
        HandwritingModelType.englishLowercase =>
          'assets/models/english_lowercase_model.tflite',
        HandwritingModelType.sinhala => 'assets/models/sinhala_model.tflite',
      };

  String get labelsAsset => switch (this) {
        HandwritingModelType.englishUppercase =>
          'assets/models/english_uppercase_labels.txt',
        HandwritingModelType.englishLowercase =>
          'assets/models/english_lowercase_labels.txt',
        HandwritingModelType.sinhala => 'assets/models/sinhala_labels.txt',
      };
}

class HandwritingClassifierException implements Exception {
  const HandwritingClassifierException(this.message);

  final String message;

  @override
  String toString() => 'HandwritingClassifierException: $message';
}

abstract interface class HandwritingClassifierClient {
  Future<HandwritingPrediction> predict({
    required HandwritingModelType modelType,
    required PreprocessedHandwriting handwriting,
    required String expectedCharacter,
  });

  void dispose();
}

class HandwritingClassifier implements HandwritingClassifierClient {
  HandwritingClassifier({AssetBundle? assetBundle})
      : _assetBundle = assetBundle ?? rootBundle;

  static const double confidenceThreshold = 0.70;

  final AssetBundle _assetBundle;
  final Map<HandwritingModelType, _LoadedHandwritingModel> _loadedModels = {};
  final Map<HandwritingModelType, Future<_LoadedHandwritingModel>>
      _loadingModels = {};
  bool _disposed = false;

  @override
  Future<HandwritingPrediction> predict({
    required HandwritingModelType modelType,
    required PreprocessedHandwriting handwriting,
    required String expectedCharacter,
  }) async {
    if (_disposed) {
      throw const HandwritingClassifierException(
        'The handwriting recognizer has already been closed.',
      );
    }

    final model = await _modelFor(modelType);
    if (!model.labels.contains(expectedCharacter)) {
      throw HandwritingClassifierException(
        'Recognition is not available for “$expectedCharacter” yet.',
      );
    }
    if (handwriting.width != model.inputWidth ||
        handwriting.height != model.inputHeight ||
        handwriting.rgbBytes.length !=
            model.inputWidth * model.inputHeight * 3) {
      throw HandwritingClassifierException(
        'Expected an RGB ${model.inputWidth}×${model.inputHeight} image.',
      );
    }

    final inputBytes = switch (model.inputType) {
      TensorType.float32 => _floatInputBytes(handwriting.rgbBytes),
      TensorType.uint8 => handwriting.rgbBytes,
      _ => throw HandwritingClassifierException(
          'Unsupported model input type: ${model.inputType}.',
        ),
    };

    try {
      model.interpreter.getInputTensor(0).data = inputBytes;
      model.interpreter.invoke();
      final rawScores = _readOutputScores(model);
      var predictedIndex = 0;
      for (var index = 1; index < rawScores.length; index++) {
        if (rawScores[index] > rawScores[predictedIndex]) {
          predictedIndex = index;
        }
      }
      return HandwritingPrediction(
        character: model.labels[predictedIndex],
        confidence: rawScores[predictedIndex],
        predictedIndex: predictedIndex,
        rawScores: List<double>.unmodifiable(rawScores),
      );
    } catch (error, stackTrace) {
      debugPrint('[Handwriting] TFLite inference failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (error is HandwritingClassifierException) rethrow;
      throw const HandwritingClassifierException(
        'The handwriting could not be checked. Please try again.',
      );
    }
  }

  Uint8List _floatInputBytes(Uint8List rgbBytes) {
    // The supplied models contain their own x / 127.5 - 1 rescaling layer,
    // so the FLOAT32 tensor receives RGB pixel values in the 0..255 range.
    final values = Float32List(rgbBytes.length);
    for (var index = 0; index < rgbBytes.length; index++) {
      values[index] = rgbBytes[index].toDouble();
    }
    return values.buffer.asUint8List();
  }

  List<double> _readOutputScores(_LoadedHandwritingModel model) {
    final tensor = model.interpreter.getOutputTensor(0);
    final bytes = tensor.data;
    if (model.outputType == TensorType.float32) {
      final data = ByteData.sublistView(bytes);
      return List<double>.generate(
        model.outputClasses,
        (index) => data.getFloat32(index * 4, Endian.host),
        growable: false,
      );
    }
    if (model.outputType == TensorType.uint8) {
      final parameters = tensor.params;
      return List<double>.generate(
        model.outputClasses,
        (index) => (bytes[index] - parameters.zeroPoint) * parameters.scale,
        growable: false,
      );
    }
    throw HandwritingClassifierException(
      'Unsupported model output type: ${model.outputType}.',
    );
  }

  Future<_LoadedHandwritingModel> _modelFor(
    HandwritingModelType modelType,
  ) async {
    final loaded = _loadedModels[modelType];
    if (loaded != null) return loaded;

    final existingLoad = _loadingModels[modelType];
    if (existingLoad != null) return existingLoad;

    final load = _loadModel(modelType);
    _loadingModels[modelType] = load;
    try {
      final model = await load;
      if (_disposed) {
        model.interpreter.close();
        throw const HandwritingClassifierException(
          'The handwriting recognizer was closed while loading.',
        );
      }
      _loadedModels[modelType] = model;
      return model;
    } finally {
      _loadingModels.remove(modelType);
    }
  }

  Future<_LoadedHandwritingModel> _loadModel(
    HandwritingModelType modelType,
  ) async {
    Interpreter? interpreter;
    try {
      interpreter = await Interpreter.fromAsset(modelType.modelAsset);
      final inputs = interpreter.getInputTensors();
      final outputs = interpreter.getOutputTensors();
      if (inputs.length != 1 || outputs.length != 1) {
        throw const HandwritingClassifierException(
          'The model must have exactly one input and one output.',
        );
      }

      final input = inputs.single;
      final output = outputs.single;
      if (input.shape.length != 4 ||
          input.shape[0] != 1 ||
          input.shape[3] != 3) {
        throw HandwritingClassifierException(
          'Unexpected model input shape: ${input.shape}.',
        );
      }
      if (input.type != TensorType.float32 && input.type != TensorType.uint8) {
        throw HandwritingClassifierException(
          'Unsupported model input type: ${input.type}.',
        );
      }
      if (output.shape.length != 2 || output.shape[0] != 1) {
        throw HandwritingClassifierException(
          'Unexpected model output shape: ${output.shape}.',
        );
      }
      if (output.type != TensorType.float32 &&
          output.type != TensorType.uint8) {
        throw HandwritingClassifierException(
          'Unsupported model output type: ${output.type}.',
        );
      }

      final labelsText = await _assetBundle.loadString(modelType.labelsAsset);
      final labels = labelsText
          .split(RegExp(r'\r?\n'))
          .map((label) => label.trim())
          .where((label) => label.isNotEmpty)
          .toList(growable: false);
      final outputClasses = output.shape[1];
      if (labels.length != outputClasses) {
        throw HandwritingClassifierException(
          'Label count ${labels.length} does not match the model output '
          'class count $outputClasses for ${modelType.name}.',
        );
      }

      debugPrint(
        '[Handwriting] Loaded ${modelType.name}: '
        'input=${input.shape} ${input.type}, '
        'output=${output.shape} ${output.type}.',
      );
      return _LoadedHandwritingModel(
        interpreter: interpreter,
        labels: labels,
        inputWidth: input.shape[2],
        inputHeight: input.shape[1],
        inputType: input.type,
        outputClasses: outputClasses,
        outputType: output.type,
      );
    } catch (error, stackTrace) {
      interpreter?.close();
      debugPrint('[Handwriting] Failed to load ${modelType.name}: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (error is HandwritingClassifierException) rethrow;
      throw const HandwritingClassifierException(
        'Handwriting recognition is unavailable right now.',
      );
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final model in _loadedModels.values) {
      model.interpreter.close();
    }
    _loadedModels.clear();
    for (final pending in _loadingModels.values) {
      unawaited(
        pending.then<void>((model) {
          if (!model.interpreter.isDeleted) model.interpreter.close();
        }).catchError((Object _) {}),
      );
    }
    _loadingModels.clear();
  }
}

class _LoadedHandwritingModel {
  const _LoadedHandwritingModel({
    required this.interpreter,
    required this.labels,
    required this.inputWidth,
    required this.inputHeight,
    required this.inputType,
    required this.outputClasses,
    required this.outputType,
  });

  final Interpreter interpreter;
  final List<String> labels;
  final int inputWidth;
  final int inputHeight;
  final TensorType inputType;
  final int outputClasses;
  final TensorType outputType;
}
