/// A practice word. Ids must match ml/speech/config/words.csv (the reference bank).
class SpeechWord {
  const SpeechWord(
      {required this.id, required this.text, required this.language});

  final String id;
  final String text;

  /// 'si' | 'en'
  final String language;
}

/// Demo list (Stage 3): frequent words from the child recordings, each with a reference bank of
/// 6-14 child recordings. Moves to a bundled/synced word list with the offline queue (Stage 6).
const speechDemoWords = [
  SpeechWord(id: 'w_001', text: 'අම්මා', language: 'si'),
  SpeechWord(id: 'w_002', text: 'මම', language: 'si'),
  SpeechWord(id: 'w_003', text: 'අපි', language: 'si'),
  SpeechWord(id: 'w_004', text: 'මට', language: 'si'),
  SpeechWord(id: 'w_005', text: 'cat', language: 'en'),
  SpeechWord(id: 'w_006', text: 'sky', language: 'en'),
  SpeechWord(id: 'w_007', text: 'she', language: 'en'),
  SpeechWord(id: 'w_008', text: 'play', language: 'en'),
];
