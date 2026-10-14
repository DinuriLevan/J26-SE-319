/// A practice word. Ids must match ml/speech/config/words.csv (the reference bank).
class SpeechWord {
  const SpeechWord(
      {required this.id, required this.text, required this.language});

  final String id;
  final String text;

  /// 'si' | 'en'
  final String language;
}

/// Stage 1 demo list. Moves to a bundled/synced word list when the offline queue lands (Stage 6).
const speechDemoWords = [
  SpeechWord(id: 'w_001', text: 'කමල', language: 'si'),
  SpeechWord(id: 'w_002', text: 'අම්මා', language: 'si'),
  SpeechWord(id: 'w_003', text: 'පාසල', language: 'si'),
  SpeechWord(id: 'w_004', text: 'cat', language: 'en'),
  SpeechWord(id: 'w_005', text: 'sun', language: 'en'),
];
