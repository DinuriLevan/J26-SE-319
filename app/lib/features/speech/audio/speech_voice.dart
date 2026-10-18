import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';

/// One spoken line: an l10n key (also the name of its recording) and the text shown in the
/// bubble (read aloud by text-to-speech if there is no recording).
class VoiceLine {
  const VoiceLine(this.key, this.text, {this.recordedAlternative = const []});

  final String key;
  final String text;

  /// Recordings to play instead when [key] has none of its own (e.g. a message with a placeholder,
  /// "We'll practise ම again later", is played as "Great effort!" + "Let's practise this word").
  final List<String> recordedAlternative;
}

/// Plays a recorded prompt; completes when it has finished.
abstract class PromptPlayer {
  Future<void> playAsset(String assetPath);
  Future<void> stop();
}

/// The device's text-to-speech; [speak] completes when done.
abstract class TtsEngine {
  Future<bool> isLanguageAvailable(String languageTag);
  Future<void> speak(String text, String languageTag);
  Future<void> stop();
}

/// Speaks the parrot's instructions in the app language: a recorded adult voice from
/// `assets/speech/prompts/<lang>/<key>.wav` when available, else text-to-speech if the device has
/// that language, else nothing (silently).
class SpeechVoice {
  SpeechVoice({
    required PromptPlayer player,
    required TtsEngine tts,
    required Future<Set<String>> Function() assetList,
  })  : _player = player,
        _tts = tts,
        _assetList = assetList;

  final PromptPlayer _player;
  final TtsEngine _tts;
  final Future<Set<String>> Function() _assetList;
  Future<Set<String>>? _assets;
  final Map<String, bool> _ttsAvailable = {};
  int _generation = 0;

  /// Speak automatically on new instructions (the mute toggle switches this off).
  bool autoSpeak = true;

  /// True while a line is playing (the parrot moves its beak).
  final ValueNotifier<bool> speaking = ValueNotifier(false);

  static String assetPath(String lang, String key) =>
      'assets/speech/prompts/$lang/$key.wav';

  static String ttsTag(String lang) => lang == 'si' ? 'si-LK' : 'en-US';

  /// Speaks [lines] in order, replacing anything still being said. With [auto] (the default)
  /// nothing is said when auto-speech is muted; a replay tap passes `auto: false`.
  Future<void> say(List<VoiceLine> lines, String lang,
      {bool auto = true}) async {
    if (auto && !autoSpeak) return;
    await stop();
    final gen = _generation;
    final assets = await (_assets ??= _assetList());
    try {
      for (final line in lines) {
        if (gen != _generation) return;
        final own = assetPath(lang, line.key);
        final alt = [
          for (final k in line.recordedAlternative) assetPath(lang, k)
        ];
        speaking.value = true;
        if (assets.contains(own)) {
          await _player.playAsset(own);
        } else if (alt.isNotEmpty && alt.every(assets.contains)) {
          for (final a in alt) {
            if (gen != _generation) return;
            await _player.playAsset(a);
          }
        } else if (await _hasTts(lang)) {
          if (gen != _generation) return;
          await _tts.speak(line.text, ttsTag(lang));
        }
      }
    } finally {
      if (gen == _generation) speaking.value = false;
    }
  }

  Future<void> stop() async {
    _generation++;
    speaking.value = false;
    await _player.stop();
    await _tts.stop();
  }

  Future<bool> _hasTts(String lang) async {
    final known = _ttsAvailable[lang];
    if (known != null) return known;
    final ok = await _tts.isLanguageAvailable(ttsTag(lang));
    debugPrint(
        'SpeechVoice: text-to-speech for ${ttsTag(lang)} available: $ok');
    return _ttsAvailable[lang] = ok;
  }
}

class JustAudioPromptPlayer implements PromptPlayer {
  final AudioPlayer _player = AudioPlayer();

  @override
  Future<void> playAsset(String assetPath) async {
    await _player.setAsset(assetPath);
    await _player.play(); // completes when playback ends or is stopped
  }

  @override
  Future<void> stop() => _player.stop();

  Future<void> dispose() => _player.dispose();
}

class FlutterTtsEngine implements TtsEngine {
  FlutterTtsEngine() {
    _tts.awaitSpeakCompletion(true);
    _tts.setSpeechRate(0.42); // a little slower for young children
  }

  final FlutterTts _tts = FlutterTts();

  @override
  Future<bool> isLanguageAvailable(String languageTag) async {
    try {
      return (await _tts.isLanguageAvailable(languageTag)) == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> speak(String text, String languageTag) async {
    try {
      await _tts.setLanguage(languageTag);
      await _tts.speak(text);
    } catch (_) {
      // No voice for this language on this device: stay silent.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Auto-speech on/off (the speaker toggle in the speech app bars).
final speechAutoSpeakProvider = StateProvider<bool>((ref) => true);

final speechVoiceProvider = Provider<SpeechVoice>((ref) {
  final player = JustAudioPromptPlayer();
  final voice = SpeechVoice(
    player: player,
    tts: FlutterTtsEngine(),
    assetList: () async => (await AssetManifest.loadFromAssetBundle(rootBundle))
        .listAssets()
        .toSet(),
  );
  voice.autoSpeak = ref.read(speechAutoSpeakProvider);
  ref.listen<bool>(speechAutoSpeakProvider, (_, on) {
    voice.autoSpeak = on;
    if (!on) voice.stop();
  });
  ref.onDispose(() {
    voice.stop();
    player.dispose();
  });
  return voice;
});
