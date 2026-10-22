import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../data/sinhala_word_bank.dart';

/// One recorded line to play: a word, a spoken prompt or a tile's sound.
class SinhalaClip {
  const SinhalaClip(this.asset, {this.fallbackMs = 900});

  /// The word itself (assets/spelling/sinhala/audio/SI0001.mp3).
  factory SinhalaClip.word(SinhalaWord w) => SinhalaClip(w.audioAsset, fallbackMs: 1200);

  /// A spoken prompt, e.g. "listen", "try_again" (see [SinhalaPrompts]).
  factory SinhalaClip.prompt(String key) => SinhalaClip('${SinhalaWordBank.folder}/audio/prompts/$key.mp3');

  /// The sound of one letter (ප) or one akshara (පූ). Pillas have no sound.
  factory SinhalaClip.tile(String tile) => SinhalaClip(
        '${SinhalaWordBank.folder}/audio/tiles/${tileKey(tile)}.mp3',
        fallbackMs: 500,
      );

  /// File name for a tile: its code points, e.g. "0DB4" for ප, "0DCA-200D-0DBA" for ්‍ය.
  static String tileKey(String tile) =>
      tile.runes.map((r) => r.toRadixString(16).toUpperCase().padLeft(4, '0')).join('-');

  final String asset;

  /// How long to wait instead when the recording does not exist yet.
  final int fallbackMs;
}

/// Plays the recorded Sinhala audio (recorded by a person, checked with
/// ml/spelling/spell_si_audio.py). No text-to-speech: every line is a
/// recording inside the app, so it works offline on any phone.
///
/// Like the English voice, a new [say] cancels the one in progress. A line
/// without a recording yet waits a short while instead, so the game flow is
/// the same before and after the audio is made.
class SinhalaVoice {
  AudioPlayer? _player;
  int _generation = 0;
  Future<Set<String>>? _assets;

  Future<Set<String>> _available() => _assets ??= () async {
        try {
          final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
          return manifest.listAssets().toSet();
        } catch (_) {
          return <String>{};
        }
      }();

  /// Plays [clips] one after another. Returns false if a newer [say] or
  /// [stop] interrupted it.
  Future<bool> say(List<SinhalaClip> clips, {Duration gap = const Duration(milliseconds: 300)}) async {
    final generation = ++_generation;
    await _stopPlayer();
    final assets = await _available();
    for (var i = 0; i < clips.length; i++) {
      if (generation != _generation) return false;
      final clip = clips[i];
      final file = recordingFor(clip.asset, assets);
      if (file != null) {
        await _play(file);
      } else {
        await Future<void>.delayed(Duration(milliseconds: clip.fallbackMs));
      }
      if (i < clips.length - 1) await Future<void>.delayed(gap);
    }
    return generation == _generation;
  }

  /// Own recordings first: for "SI0001.mp3" a "SI0001.m4a" or "SI0001.wav"
  /// (what phone recorders and Audacity save) wins over the generated mp3.
  static String? recordingFor(String mp3, Set<String> assets) {
    final stem = mp3.substring(0, mp3.length - '.mp3'.length);
    for (final file in ['$stem.m4a', '$stem.wav', mp3]) {
      if (assets.contains(file)) return file;
    }
    return null;
  }

  /// Completes when the clip that is playing ends or is stopped.
  Completer<void>? _playing;

  Future<void> _play(String asset) async {
    final player = _player ??= AudioPlayer();
    final playing = _playing = Completer<void>();
    final sub = player.onPlayerComplete.listen((_) {
      if (!playing.isCompleted) playing.complete();
    });
    try {
      // AssetSource paths are relative to the assets/ folder.
      await player.play(AssetSource(asset.replaceFirst('assets/', '')));
      await playing.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    } catch (e) {
      debugPrint('SinhalaVoice: could not play $asset ($e)');
    } finally {
      await sub.cancel();
    }
  }

  Future<void> stop() async {
    _generation++;
    await _stopPlayer();
  }

  Future<void> _stopPlayer() async {
    final playing = _playing;
    if (playing != null && !playing.isCompleted) playing.complete();
    try {
      await _player?.stop();
    } catch (_) {}
  }

  void dispose() {
    _generation++;
    _player?.dispose();
    _player = null;
  }
}

/// Every spoken prompt the Sinhala game uses: key → the Sinhala text.
/// ml/spelling/spell_si_audio.py turns each into `audio/prompts/<key>.mp3`.
/// The script reads this map, so this is the only list to edit.
class SinhalaPrompts {
  const SinhalaPrompts._();

  static const lines = <String, String>{
    'listen': 'අහන්න!',
    'demo_1': 'වචනය හොඳින් අහන්න.',
    'demo_2': 'අකුරු ඇදලා ඉර උඩ තියන්න.',
    'demo_3': 'පිල්ල අකුර උඩට ඇදලා දාන්න.',
    'praise_3': 'හරියටම හරි!',
    'praise_4': 'හරිම හොඳයි!',
    'almost': 'ආසන්නයි!',
    'try_again': 'ආයෙත් උත්සාහ කරමු.',
    'together': 'හොඳ උත්සාහයක්! අපි එකට හදමු.',
    'doing_great': 'ඔයා හොඳට කරනවා!',
    'round_done': 'ඔයා වචන දහයම ඉවර කළා!',
    'goodbye_1': 'අද ඔයා හොඳට මහන්සි වුණා!',
    'goodbye_2': 'ආයෙත් හම්බවෙමු!',
    'explain_play': 'අපි සෙල්ලම් කරමු!',
    'explain_play_again': 'ඊළඟ වචන!',
    'explain_replay': 'වචනය ආයෙත් අහන්න.',
    'explain_check': 'මගේ උත්තරය බලන්න.',
    'explain_home': 'මුලට යන්න.',
    'explain_back': 'ආපසු යන්න.',
    'explain_mute': 'ශබ්ද නවත්වන්න, නැත්නම් ආයෙත් දාන්න.',
  };

  static const praise = ['praise_3', 'praise_4'];
}
