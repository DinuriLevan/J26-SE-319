import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Child-friendly English voice built on the device's text-to-speech engine.
///
/// Every spoken line goes through [say]. Starting a new line cancels the one
/// in progress, so sequences ("Listen! … cat … Spell cat.") never overlap.
/// If no TTS engine/English voice is available, [available] is false and
/// [say] just waits a similar amount of time so the game flow stays the same.
class VoiceService {
  final FlutterTts _tts = FlutterTts();
  bool available = false;
  bool _ready = false;
  int _generation = 0;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    try {
      await _tts.awaitSpeakCompletion(true);
      const candidates = ['en-US', 'en-GB', 'en-IN', 'en-AU'];
      for (final lang in candidates) {
        final ok = await _tts.isLanguageAvailable(lang);
        if (ok == true || ok == 1) {
          await _tts.setLanguage(lang);
          available = true;
          break;
        }
      }
      // On Android 0.5 is normal speed, so 0.4 is roughly 0.8x.
      await _tts.setSpeechRate(0.4);
      await _tts.setPitch(1.15);
    } catch (e) {
      debugPrint('VoiceService: TTS unavailable ($e)');
      available = false;
    }
  }

  /// Speaks [lines] one after another with a short pause between them.
  /// Returns false if it was interrupted by a newer [say] or [stop].
  Future<bool> say(List<String> lines, {Duration gap = const Duration(milliseconds: 350)}) async {
    final generation = ++_generation;
    await init();
    await _stopEngine();
    for (var i = 0; i < lines.length; i++) {
      if (generation != _generation) return false;
      if (available) {
        try {
          await _tts.speak(lines[i]);
        } catch (_) {
          await _fallbackWait(lines[i]);
        }
      } else {
        await _fallbackWait(lines[i]);
      }
      if (i < lines.length - 1) await Future<void>.delayed(gap);
    }
    return generation == _generation;
  }

  Future<void> stop() async {
    _generation++;
    await _stopEngine();
  }

  Future<void> _stopEngine() async {
    if (!available) return;
    try {
      await _tts.stop();
    } catch (_) {}
  }

  Future<void> _fallbackWait(String line) =>
      Future<void>.delayed(Duration(milliseconds: 400 + 70 * line.length));
}
