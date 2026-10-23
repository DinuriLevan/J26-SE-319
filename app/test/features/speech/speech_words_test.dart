import 'dart:io';

import 'package:akurin/features/speech/data/speech_api.dart';
import 'package:akurin/features/speech/data/speech_words.dart';
import 'package:flutter_test/flutter_test.dart';

/// The app's word list must match the service's ml/speech/config/words.csv (ids, text, language,
/// level and easiest-first order), or the app would ask for words the service cannot score.
void main() {
  practiceWordsTests();

  test('speechDemoWords matches ml/speech/config/words.csv', () {
    final lines = File('../ml/speech/config/words.csv').readAsLinesSync();
    final header = lines.first.split(',');
    final rows = [
      for (final l in lines.skip(1).where((l) => l.trim().isNotEmpty))
        Map.fromIterables(header, l.split(',')),
    ];
    expect(speechDemoWords.length, rows.length);
    for (final (i, r) in rows.indexed) {
      final w = speechDemoWords[i];
      expect(w.id, r['word_id']);
      expect(w.text, r['text_si']!.isNotEmpty ? r['text_si'] : r['text_en']);
      expect(w.language, r['language']);
      expect(w.level, int.parse(r['level']!));
    }
  });

  test('each language lists its words easiest first, with all three levels',
      () {
    for (final lang in ['si', 'en']) {
      final levels = speechWordsFor(lang).map((w) => w.level).toList();
      expect(levels, [...levels]..sort());
      expect(levels.toSet(), {1, 2, 3});
    }
  });
}

WordInfo _info(String id, int nRefs) => WordInfo(
    wordId: id,
    units: const ['x'],
    listenUnits: const {},
    hasWordAudio: false,
    nRefs: nRefs);

void practiceWordsTests() {
  group('practiceWords', () {
    const a = SpeechWord(id: 'a', text: 'a', language: 'en', level: 1);
    const b = SpeechWord(id: 'b', text: 'b', language: 'en', level: 1);
    final info = {'a': _info('a', 4), 'b': _info('b', 3)};

    test('children only see words with enough recordings', () {
      expect(practiceWords([a, b], info, showUnready: false), [a]);
    });

    test('developers also see unready words', () {
      expect(practiceWords([a, b], info, showUnready: true), [a, b]);
    });

    test('words missing from the service are not ready', () {
      expect(
          practiceWords([a, b], {'a': _info('a', 9)}, showUnready: false), [a]);
    });

    test('without word info the static list is used', () {
      expect(practiceWords([a, b], null, showUnready: false), [a, b]);
    });
  });
}
