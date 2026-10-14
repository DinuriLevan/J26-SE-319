import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

enum MicPermission { granted, denied, permanentlyDenied }

/// Records one utterance to a mono 16 kHz WAV file in the app's temp directory.
class SpeechRecorder {
  final AudioRecorder _recorder = AudioRecorder();

  static const maxDuration =
      Duration(milliseconds: 5500); // service rejects > 6 s

  Future<MicPermission> ensurePermission() async {
    final status = await Permission.microphone.request();
    if (status.isGranted) return MicPermission.granted;
    if (status.isPermanentlyDenied) return MicPermission.permanentlyDenied;
    return MicPermission.denied;
  }

  Future<void> start() async {
    final dir = await getTemporaryDirectory();
    final path =
        p.join(dir.path, 'speech_${DateTime.now().millisecondsSinceEpoch}.wav');
    await _recorder.start(
      const RecordConfig(
          encoder: AudioEncoder.wav, sampleRate: 16000, numChannels: 1),
      path: path,
    );
  }

  /// Returns the WAV file path, or null if nothing was recorded.
  Future<String?> stop() => _recorder.stop();

  Future<void> cancel() => _recorder.cancel();

  Future<void> dispose() => _recorder.dispose();
}

final speechRecorderProvider = Provider.autoDispose<SpeechRecorder>((ref) {
  final recorder = SpeechRecorder();
  ref.onDispose(recorder.dispose);
  return recorder;
});
