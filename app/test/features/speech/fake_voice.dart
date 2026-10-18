import 'package:akurin/features/speech/audio/speech_voice.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Records what would have been played; nothing touches real audio plugins.
class FakePromptPlayer implements PromptPlayer {
  final List<String> played = [];

  @override
  Future<void> playAsset(String assetPath) async => played.add(assetPath);

  @override
  Future<void> playFile(String path) async => played.add('file:$path');

  @override
  Future<void> stop() async {}
}

class FakeTts implements TtsEngine {
  FakeTts({this.languages = const {'en-US'}});

  final Set<String> languages;
  final List<String> spoken = [];
  int stops = 0;

  @override
  Future<bool> isLanguageAvailable(String languageTag) async =>
      languages.contains(languageTag);

  @override
  Future<void> speak(String text, String languageTag) async =>
      spoken.add('$languageTag:$text');

  @override
  Future<void> stop() async => stops++;
}

/// A [SpeechVoice] over fakes, plus the provider override that installs it.
class FakeVoice {
  FakeVoice({Set<String> assets = const {}, Set<String>? ttsLanguages})
      : player = FakePromptPlayer(),
        tts = FakeTts(languages: ttsLanguages ?? const {'en-US'}) {
    voice =
        SpeechVoice(player: player, tts: tts, assetList: () async => assets);
  }

  final FakePromptPlayer player;
  final FakeTts tts;
  late final SpeechVoice voice;

  Override get override => speechVoiceProvider.overrideWithValue(voice);

  /// Everything said so far, recorded or TTS, in order.
  List<String> get said => [...player.played, ...tts.spoken];
}
