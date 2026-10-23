import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'speech_api.dart';

/// A practice word. Ids must match ml/speech/config/words.csv (the reference bank).
class SpeechWord {
  const SpeechWord(
      {required this.id,
      required this.text,
      required this.language,
      required this.level});

  final String id;
  final String text;

  /// 1 = easiest .. 3, rule-based (ml/speech/src/word_levels.py).
  final int level;

  /// 'si' | 'en'
  final String language;
}

/// Practice words, easiest first within each language. Must match ml/speech/config/words.csv
/// (test/features/speech/speech_words_test.dart checks it). Words from the child recordings have a
/// reference bank already; curated words become ready once adults record them (see practiceWords).
/// Moves to a bundled/synced list with the offline queue (Stage 6).
const speechDemoWords = [
  SpeechWord(id: 'w_002', text: 'මම', language: 'si', level: 1),
  SpeechWord(id: 'w_003', text: 'අපි', language: 'si', level: 1),
  SpeechWord(id: 'w_004', text: 'මට', language: 'si', level: 1),
  SpeechWord(id: 'w_009', text: 'කිරි', language: 'si', level: 1),
  SpeechWord(id: 'w_025', text: 'වැඩ', language: 'si', level: 1),
  SpeechWord(id: 'w_026', text: 'ඇය', language: 'si', level: 1),
  SpeechWord(id: 'w_033', text: 'ගස', language: 'si', level: 1),
  SpeechWord(id: 'w_034', text: 'අත', language: 'si', level: 1),
  SpeechWord(id: 'w_035', text: 'ඇස', language: 'si', level: 1),
  SpeechWord(id: 'w_036', text: 'ඉර', language: 'si', level: 1),
  SpeechWord(id: 'w_037', text: 'කට', language: 'si', level: 1),
  SpeechWord(id: 'w_010', text: 'බත්', language: 'si', level: 2),
  SpeechWord(id: 'w_011', text: 'මල්', language: 'si', level: 2),
  SpeechWord(id: 'w_012', text: 'පාට', language: 'si', level: 2),
  SpeechWord(id: 'w_013', text: 'ගෙදර', language: 'si', level: 2),
  SpeechWord(id: 'w_027', text: 'පොත්', language: 'si', level: 2),
  SpeechWord(id: 'w_038', text: 'වතුර', language: 'si', level: 2),
  SpeechWord(id: 'w_039', text: 'හාවා', language: 'si', level: 2),
  SpeechWord(id: 'w_040', text: 'පූසා', language: 'si', level: 2),
  SpeechWord(id: 'w_001', text: 'අම්මා', language: 'si', level: 3),
  SpeechWord(id: 'w_014', text: 'අක්කා', language: 'si', level: 3),
  SpeechWord(id: 'w_015', text: 'තාත්තා', language: 'si', level: 3),
  SpeechWord(id: 'w_016', text: 'පාසල්', language: 'si', level: 3),
  SpeechWord(id: 'w_028', text: 'මල්ලි', language: 'si', level: 3),
  SpeechWord(id: 'w_029', text: 'ලස්සන', language: 'si', level: 3),
  SpeechWord(id: 'w_030', text: 'සෙල්ලම්', language: 'si', level: 3),
  SpeechWord(id: 'w_031', text: 'පාඩම්', language: 'si', level: 3),
  SpeechWord(id: 'w_032', text: 'කියවයි', language: 'si', level: 3),
  SpeechWord(id: 'w_041', text: 'බල්ලා', language: 'si', level: 3),
  SpeechWord(id: 'w_042', text: 'කෙසෙල්', language: 'si', level: 3),
  SpeechWord(id: 'w_005', text: 'cat', language: 'en', level: 1),
  SpeechWord(id: 'w_017', text: 'hat', language: 'en', level: 1),
  SpeechWord(id: 'w_018', text: 'rat', language: 'en', level: 1),
  SpeechWord(id: 'w_019', text: 'ran', language: 'en', level: 1),
  SpeechWord(id: 'w_048', text: 'fast', language: 'en', level: 1),
  SpeechWord(id: 'w_050', text: 'runs', language: 'en', level: 1),
  SpeechWord(id: 'w_051', text: 'dog', language: 'en', level: 1),
  SpeechWord(id: 'w_052', text: 'sun', language: 'en', level: 1),
  SpeechWord(id: 'w_053', text: 'bus', language: 'en', level: 1),
  SpeechWord(id: 'w_007', text: 'she', language: 'en', level: 2),
  SpeechWord(id: 'w_006', text: 'sky', language: 'en', level: 2),
  SpeechWord(id: 'w_008', text: 'play', language: 'en', level: 2),
  SpeechWord(id: 'w_020', text: 'book', language: 'en', level: 2),
  SpeechWord(id: 'w_043', text: 'boy', language: 'en', level: 2),
  SpeechWord(id: 'w_044', text: 'toy', language: 'en', level: 2),
  SpeechWord(id: 'w_045', text: 'ball', language: 'en', level: 2),
  SpeechWord(id: 'w_046', text: 'fly', language: 'en', level: 2),
  SpeechWord(id: 'w_047', text: 'rice', language: 'en', level: 2),
  SpeechWord(id: 'w_049', text: 'birds', language: 'en', level: 2),
  SpeechWord(id: 'w_054', text: 'fish', language: 'en', level: 2),
  SpeechWord(id: 'w_055', text: 'ship', language: 'en', level: 2),
  SpeechWord(id: 'w_056', text: 'frog', language: 'en', level: 2),
  SpeechWord(id: 'w_021', text: 'school', language: 'en', level: 3),
  SpeechWord(id: 'w_022', text: 'apple', language: 'en', level: 3),
  SpeechWord(id: 'w_023', text: 'garden', language: 'en', level: 3),
  SpeechWord(id: 'w_024', text: 'tasty', language: 'en', level: 3),
  SpeechWord(id: 'w_057', text: 'rabbit', language: 'en', level: 3),
  SpeechWord(id: 'w_058', text: 'window', language: 'en', level: 3),
  SpeechWord(id: 'w_059', text: 'sister', language: 'en', level: 3),
  SpeechWord(id: 'w_060', text: 'pencil', language: 'en', level: 3),
];

/// Practice language chosen at the start of the Speech tab ('si' | 'en'); null = not chosen yet,
/// so the language question is shown. Kept for as long as the app is open.
final speechLanguageProvider = StateProvider<String?>((ref) => null);

List<SpeechWord> speechWordsFor(String language) =>
    speechDemoWords.where((w) => w.language == language).toList();

/// A word is ready to practise once its bank has this many recordings (the service's
/// min_refs_for_bank_threshold): it then gets a pass mark learned from its own references.
const speechMinRefs = 4;

bool isWordReady(WordInfo? info) => info != null && info.nRefs >= speechMinRefs;

/// The words to list for practice. Children only ever see ready words. Developers ([showUnready],
/// debug builds) also see the others so they can record adult references for them. When word info
/// could not be loaded ([info] null), the static list is used as-is.
List<SpeechWord> practiceWords(
  List<SpeechWord> words,
  Map<String, WordInfo>? info, {
  required bool showUnready,
}) {
  if (info == null || showUnready) return words;
  return words.where((w) => isWordReady(info[w.id])).toList();
}

/// Whether unready words are listed (greyed, for recording references): debug builds only.
final speechShowUnreadyWordsProvider = Provider<bool>((ref) => kDebugMode);
