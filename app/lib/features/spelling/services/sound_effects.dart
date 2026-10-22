import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

enum SoundEffect { pickUp, drop, backToTray, happy, softTryAgain, celebrate }

/// Gentle, satisfying sound effects synthesised in code (no audio files).
///
/// Tiles make a soft wooden "marimba" tock when dropped, and each answer slot
/// is a step higher on a pentatonic scale, so building a word plays a little
/// tune. There is deliberately no buzzer — "try again" is a soft two-note hum.
class SoundEffects {
  bool muted = false;
  final Map<String, Future<AudioPlayer>> _players = {};

  /// Pre-builds the sounds so the very first drop has no delay.
  Future<void> warmUp() async {
    for (final effect in SoundEffect.values) {
      final variants = effect == SoundEffect.drop ? _pentatonic.length : 1;
      for (var v = 0; v < variants; v++) {
        _player(effect, v);
      }
    }
  }

  /// [variant] picks the note for [SoundEffect.drop] (the slot index).
  Future<void> play(SoundEffect effect, {int variant = 0}) async {
    if (muted) return;
    try {
      final player = await _player(effect, variant % _pentatonic.length);
      await player.stop();
      await player.resume();
    } catch (_) {
      // Sound effects are optional; never break the game over them.
    }
  }

  void dispose() {
    for (final p in _players.values) {
      p.then((player) => player.dispose());
    }
  }

  Future<AudioPlayer> _player(SoundEffect effect, int variant) {
    final key = effect == SoundEffect.drop ? '${effect.name}_$variant' : effect.name;
    return _players.putIfAbsent(key, () async {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/spelling_sfx_$key.wav');
      await file.writeAsBytes(_build(effect, variant), flush: true);
      final player = AudioPlayer();
      // Mix with (don't interrupt) the spoken voice.
      await player.setAudioContext(
        AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build(),
      );
      await player.setPlayerMode(PlayerMode.lowLatency);
      await player.setReleaseMode(ReleaseMode.stop);
      await player.setSource(DeviceFileSource(file.path));
      await player.setVolume(0.8);
      return player;
    });
  }

  // ------------------------------------------------------------ synthesis

  static const _sampleRate = 44100;

  // C major pentatonic from C5: always sounds pleasant in any order.
  static const _pentatonic = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5];
  static const _c5 = 523.25, _e5 = 659.25, _g5 = 783.99, _c6 = 1046.5, _e6 = 1318.5;
  static const _g4 = 392.0, _e4 = 329.63;

  static Uint8List _build(SoundEffect effect, int variant) {
    switch (effect) {
      case SoundEffect.pickUp:
        return _render(0.12, (t) => _marimba(1568, t, decay: 30) * 0.35);
      case SoundEffect.drop:
        final f = _pentatonic[variant];
        return _render(0.6, (t) => _thock(t) * 0.55 + _marimba(f, t) * 0.75);
      case SoundEffect.backToTray:
        return _render(0.3, (t) => _bloop(t) * 0.5);
      case SoundEffect.happy:
        return _render(1.1, (t) => _notes(t, [(_c5, 0), (_e5, 0.09), (_g5, 0.18), (_c6, 0.27)]) * 0.6);
      case SoundEffect.softTryAgain:
        return _render(0.8, (t) => _notes(t, [(_g4, 0), (_e4, 0.18)], decay: 5) * 0.35);
      case SoundEffect.celebrate:
        return _render(1.8, (t) {
          final run = _notes(t, [(_c5, 0), (_e5, 0.1), (_g5, 0.2), (_c6, 0.3), (_e6, 0.4)]);
          final chord = _notes(t, [(_c5, 0.6), (_e5, 0.6), (_g5, 0.6), (_c6, 0.6)], decay: 3);
          return (run + chord * 0.6) * 0.45;
        });
    }
  }

  /// Wooden mallet tone: a fast-decaying fundamental plus brief overtones.
  static double _marimba(double f, double t, {double decay = 7}) {
    final attack = math.min(1.0, t / 0.003);
    return attack *
        (math.sin(2 * math.pi * f * t) * math.exp(-t * decay) +
            0.25 * math.sin(2 * math.pi * 4 * f * t) * math.exp(-t * decay * 4) +
            0.08 * math.sin(2 * math.pi * 10 * f * t) * math.exp(-t * decay * 9));
  }

  /// Short low "thock" (pitch falls quickly) — the feel of a tile landing.
  static double _thock(double t) {
    final phase = 2 * math.pi * (120 * t + 280 * (1 - math.exp(-40 * t)) / 40);
    return math.sin(phase) * math.exp(-t * 45) * math.min(1.0, t / 0.002);
  }

  /// Soft falling "bloop" for a tile sliding back to the tray.
  static double _bloop(double t) {
    final phase = 2 * math.pi * (260 * t + 300 * (1 - math.exp(-25 * t)) / 25);
    return math.sin(phase) * math.exp(-t * 16) * math.min(1.0, t / 0.004);
  }

  static double _notes(double t, List<(double, double)> notes, {double decay = 6}) {
    var sum = 0.0;
    for (final (f, start) in notes) {
      if (t >= start) sum += _marimba(f, t - start, decay: decay);
    }
    return sum;
  }

  /// Renders [seconds] of audio into a 16-bit mono WAV, softly limited.
  static Uint8List _render(double seconds, double Function(double t) sample) {
    final count = (_sampleRate * seconds).round();
    final data = ByteData(44 + count * 2);
    void ascii(int offset, String s) {
      for (var i = 0; i < s.length; i++) {
        data.setUint8(offset + i, s.codeUnitAt(i));
      }
    }

    ascii(0, 'RIFF');
    data.setUint32(4, 36 + count * 2, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little); // PCM
    data.setUint16(22, 1, Endian.little); // mono
    data.setUint32(24, _sampleRate, Endian.little);
    data.setUint32(28, _sampleRate * 2, Endian.little);
    data.setUint16(32, 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    ascii(36, 'data');
    data.setUint32(40, count * 2, Endian.little);

    for (var i = 0; i < count; i++) {
      final t = i / _sampleRate;
      // Fade the last 20 ms so nothing clicks; tanh keeps peaks soft.
      final fadeOut = math.min(1.0, (count - i) / (_sampleRate * 0.02));
      final v = _tanh(sample(t) * 1.2) * fadeOut;
      data.setInt16(44 + i * 2, (v * 32767 * 0.9).round(), Endian.little);
    }
    return data.buffer.asUint8List();
  }

  static double _tanh(double x) {
    final e = math.exp(2 * x);
    return (e - 1) / (e + 1);
  }
}
