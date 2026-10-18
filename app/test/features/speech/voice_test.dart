import 'package:akurin/features/speech/audio/speech_voice.dart';
import 'package:akurin/features/speech/ui/speech_theme.dart';
import 'package:akurin/features/speech/ui/speech_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_voice.dart';

void main() {
  group('SpeechVoice', () {
    test('plays the recorded prompt when it exists, otherwise TTS', () async {
      final f =
          FakeVoice(assets: {SpeechVoice.assetPath('en', 'speechListen')});
      await f.voice.say(const [
        VoiceLine('speechListen', 'Listen carefully'),
        VoiceLine('speechSaySound', 'Now you say it!'),
      ], 'en');
      expect(f.player.played, ['assets/speech/prompts/en/speechListen.wav']);
      expect(f.tts.spoken, ['en-US:Now you say it!']);
    });

    test('stays silent in Sinhala when the device has no Sinhala voice',
        () async {
      final f = FakeVoice(); // TTS only knows en-US, no recordings
      await f.voice
          .say(const [VoiceLine('speechListen', 'හොඳින් අහන්න')], 'si');
      expect(f.said, isEmpty);
    });

    test('uses Sinhala TTS when the device has it', () async {
      final f = FakeVoice(ttsLanguages: {'si-LK'});
      await f.voice
          .say(const [VoiceLine('speechListen', 'හොඳින් අහන්න')], 'si');
      expect(f.tts.spoken, ['si-LK:හොඳින් අහන්න']);
    });

    test('plays the recorded alternative for messages with placeholders',
        () async {
      final f = FakeVoice(
          assets: {SpeechVoice.assetPath('en', 'speechPractiseBody')});
      await f.voice.say(const [
        VoiceLine('speechFallbackBody', "We'll practise c again later.",
            recordedAlternative: ['speechPractiseBody']),
      ], 'en');
      expect(
          f.player.played, ['assets/speech/prompts/en/speechPractiseBody.wav']);
      expect(f.tts.spoken, isEmpty);
    });

    test('muted: auto-speech is skipped, a replay still plays', () async {
      final f = FakeVoice()..voice.autoSpeak = false;
      const lines = [VoiceLine('speechTapToRecord', 'Tap the mic')];
      await f.voice.say(lines, 'en');
      expect(f.said, isEmpty);
      await f.voice.say(lines, 'en', auto: false);
      expect(f.tts.spoken, ['en-US:Tap the mic']);
    });

    test('a new say replaces the previous one and stop() resets speaking',
        () async {
      final f = FakeVoice();
      final first = f.voice.say(const [VoiceLine('a', 'first')], 'en');
      await f.voice.say(const [VoiceLine('b', 'second')], 'en');
      await first;
      expect(f.tts.spoken.last, 'en-US:second');
      await f.voice.stop();
      expect(f.voice.speaking.value, isFalse);
      expect(f.tts.stops, greaterThan(0));
    });
  });

  testWidgets('the bubble replay button calls onReplay and is labelled',
      (tester) async {
    var replays = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      builder: (context, c) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: c!),
      home: SpeechThemed(
        child: Scaffold(
          body: ParrotSays(
              text: 'Listen carefully',
              onReplay: () => replays++,
              replayLabel: 'Hear again'),
        ),
      ),
    ));
    await tester.tap(find.bySemanticsLabel('Hear again'));
    expect(replays, 1);
    handle.dispose();
  });
}
