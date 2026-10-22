import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class HandwritingFeedbackSpeechClient {
  Future<void> speakSuccess();

  Future<void> speakRetry();

  Future<void> stop();

  Future<void> dispose();
}

/// Small adapter that keeps the platform plugin out of the result UI and
/// makes the speech behaviour independently testable.
abstract interface class HandwritingTextToSpeechEngine {
  Future<dynamic> setLanguage(String language);

  Future<dynamic> setSpeechRate(double rate);

  Future<dynamic> setVolume(double volume);

  Future<dynamic> setPitch(double pitch);

  Future<dynamic> speak(String text);

  Future<dynamic> stop();
}

class FlutterHandwritingTextToSpeechEngine
    implements HandwritingTextToSpeechEngine {
  FlutterHandwritingTextToSpeechEngine({FlutterTts? flutterTts})
      : _flutterTts = flutterTts ?? FlutterTts();

  final FlutterTts _flutterTts;

  @override
  Future<dynamic> setLanguage(String language) =>
      _flutterTts.setLanguage(language);

  @override
  Future<dynamic> setSpeechRate(double rate) => _flutterTts.setSpeechRate(rate);

  @override
  Future<dynamic> setVolume(double volume) => _flutterTts.setVolume(volume);

  @override
  Future<dynamic> setPitch(double pitch) => _flutterTts.setPitch(pitch);

  @override
  Future<dynamic> speak(String text) => _flutterTts.speak(text);

  @override
  Future<dynamic> stop() => _flutterTts.stop();
}

/// Speaks short, supportive English handwriting-result messages using the
/// device TTS engine. No text or audio is sent to AkuRin's backend.
class HandwritingFeedbackSpeechService
    implements HandwritingFeedbackSpeechClient {
  HandwritingFeedbackSpeechService({HandwritingTextToSpeechEngine? engine})
      : _engine = engine ?? FlutterHandwritingTextToSpeechEngine();

  static const String language = 'en-US';
  static const double speechRate = 0.45;
  static const double volume = 0.8;
  static const double pitch = 1.0;
  static const String successMessage = 'Great job!';
  static const String retryMessage = 'Let’s try again!';

  final HandwritingTextToSpeechEngine _engine;
  Future<void>? _initialization;
  var _requestToken = 0;
  var _disposed = false;

  @override
  Future<void> speakSuccess() => _speak(successMessage);

  @override
  Future<void> speakRetry() => _speak(retryMessage);

  Future<void> _speak(String message) async {
    final token = ++_requestToken;
    try {
      await (_initialization ??= _initialize());
      if (_disposed || token != _requestToken) return;
      await _engine.stop();
      if (_disposed || token != _requestToken) return;
      await _engine.speak(message);
    } catch (error, stackTrace) {
      _debugLog('Could not speak "$message".', error, stackTrace);
    }
  }

  Future<void> _initialize() async {
    // Keep the system's preferred installed English voice. This gives the
    // device control over the most natural locally available voice.
    await _engine.setLanguage(language);
    await _engine.setSpeechRate(speechRate);
    await _engine.setVolume(volume);
    await _engine.setPitch(pitch);
  }

  @override
  Future<void> stop() async {
    _requestToken++;
    try {
      await _engine.stop();
    } catch (error, stackTrace) {
      _debugLog('Could not stop handwriting feedback.', error, stackTrace);
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await stop();
  }

  void _debugLog(String message, Object error, StackTrace stackTrace) {
    if (!kDebugMode) return;
    debugPrint('[Handwriting speech] $message Error: $error');
    debugPrintStack(stackTrace: stackTrace);
  }
}
