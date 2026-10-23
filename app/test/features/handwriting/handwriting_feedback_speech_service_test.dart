import 'package:akurin/features/handwriting/services/handwriting_feedback_speech_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTextToSpeechEngine implements HandwritingTextToSpeechEngine {
  String? language;
  double? rate;
  double? volume;
  double? pitch;
  final List<String> spoken = [];
  int stopCalls = 0;

  @override
  Future<void> setLanguage(String value) async => language = value;

  @override
  Future<void> setSpeechRate(double value) async => rate = value;

  @override
  Future<void> setVolume(double value) async => volume = value;

  @override
  Future<void> setPitch(double value) async => pitch = value;

  @override
  Future<void> speak(String text) async => spoken.add(text);

  @override
  Future<void> stop() async => stopCalls++;
}

void main() {
  test('configures local English feedback and speaks exact messages', () async {
    final engine = _FakeTextToSpeechEngine();
    final service = HandwritingFeedbackSpeechService(engine: engine);

    await service.speakSuccess();
    await service.speakRetry();

    expect(engine.language, 'en-US');
    expect(engine.rate, 0.45);
    expect(engine.volume, 0.8);
    expect(engine.pitch, 1.0);
    expect(engine.spoken, ['Great job!', 'Let’s try again!']);
    expect(engine.stopCalls, 2);
  });

  test('stop and dispose cancel queued/current feedback safely', () async {
    final engine = _FakeTextToSpeechEngine();
    final service = HandwritingFeedbackSpeechService(engine: engine);

    await service.stop();
    await service.dispose();
    await service.dispose();

    expect(engine.stopCalls, 2);
  });
}
