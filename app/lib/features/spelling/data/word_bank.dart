import 'package:flutter/services.dart' show rootBundle;

/// One row of `assets/spelling/english_wordbank.csv`.
class WordEntry {
  const WordEntry({
    required this.id,
    required this.word,
    required this.phonicsSkill,
    required this.stage,
    required this.targetGrapheme,
    required this.difficulty,
    required this.emoji,
    required this.audioSentence,
    required this.homophoneOf,
    required this.confusableLetters,
    required this.role,
  });

  final String id;
  final String word;
  final String phonicsSkill;

  /// 0 = sight words, 1–8 = phonics stages.
  final int stage;

  /// "|"-separated options, e.g. "ai|ay"; "a_e" means a split digraph.
  final String targetGrapheme;
  final int difficulty;
  final String emoji;
  final String audioSentence;
  final String homophoneOf;

  /// Letters in the word that have a mirror twin (b/d, p/q), e.g. "bd".
  final String confusableLetters;

  /// "placement" or "practice".
  final String role;

  bool get isPlacement => role == 'placement';

  /// Tiles are always lowercase (e.g. "June" is built as j-u-n-e).
  String get spelling => word.toLowerCase();

  List<String> get letters => spelling.split('');

  /// Picture shown to the child, or null when the word has no emoji (no
  /// placeholder: a wrong or unrelated picture would confuse the child).
  String? get picture => emoji.isEmpty ? null : emoji;
}

/// The whole word bank plus the phonics skill order used for unlocking.
class WordBank {
  WordBank(this.entries)
      : byId = {for (final e in entries) e.id: e},
        skillOrder = _skillOrder(entries),
        skillStage = {for (final e in entries) e.phonicsSkill: e.stage};

  static const assetPath = 'assets/spelling/english_wordbank.csv';
  static const sightWords = 'sight_words';

  final List<WordEntry> entries;
  final Map<String, WordEntry> byId;

  /// Skills in teaching order: sight words, then stage 1 → 8 (CSV order
  /// within a stage).
  final List<String> skillOrder;
  final Map<String, int> skillStage;

  static Future<WordBank> load() async => WordBank.parse(await rootBundle.loadString(assetPath));

  factory WordBank.parse(String csv) {
    final rows = parseCsv(csv.replaceFirst('﻿', ''));
    final header = rows.first;
    int col(String name) => header.indexOf(name);
    final c = {
      for (final name in [
        'word_id', 'word', 'phonics_skill', 'skill_stage', 'target_grapheme', 'difficulty',
        'emoji', 'audio_sentence', 'homophone_of', 'confusable_letters', 'role',
      ])
        name: col(name),
    };
    String cell(List<String> row, String name) {
      final i = c[name]!;
      return i >= 0 && i < row.length ? row[i].trim() : '';
    }

    final entries = <WordEntry>[];
    for (final row in rows.skip(1)) {
      if (row.length < 2 || cell(row, 'word').isEmpty) continue;
      entries.add(WordEntry(
        id: cell(row, 'word_id'),
        word: cell(row, 'word'),
        phonicsSkill: cell(row, 'phonics_skill'),
        stage: int.tryParse(cell(row, 'skill_stage')) ?? 0,
        targetGrapheme: cell(row, 'target_grapheme'),
        difficulty: int.tryParse(cell(row, 'difficulty')) ?? 1,
        emoji: cell(row, 'emoji'),
        audioSentence: cell(row, 'audio_sentence'),
        homophoneOf: cell(row, 'homophone_of'),
        confusableLetters: cell(row, 'confusable_letters'),
        role: cell(row, 'role'),
      ));
    }
    return WordBank(entries);
  }

  List<WordEntry> wordsOfSkill(String skill) =>
      entries.where((e) => e.phonicsSkill == skill).toList();

  /// The placement words in stage order.
  List<WordEntry> get placementWords =>
      entries.where((e) => e.isPlacement).toList()..sort((a, b) => a.stage.compareTo(b.stage));

  List<String> skillsOfStage(int stage) => skillOrder.where((s) => skillStage[s] == stage).toList();

  List<int> get stages => skillStage.values.toSet().toList()..sort();

  static List<String> _skillOrder(List<WordEntry> entries) {
    final seen = <String>[];
    for (final e in entries) {
      if (!seen.contains(e.phonicsSkill)) seen.add(e.phonicsSkill);
    }
    final stageOf = {for (final e in entries) e.phonicsSkill: e.stage};
    final indexed = seen.asMap().entries.toList()
      ..sort((a, b) {
        final s = stageOf[a.value]!.compareTo(stageOf[b.value]!);
        return s != 0 ? s : a.key.compareTo(b.key);
      });
    return indexed.map((e) => e.value).toList();
  }
}

/// Minimal RFC-4180 CSV parser (quoted fields, "" escapes, CRLF or LF).
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final field = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (inQuotes) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          field.write('"');
          i++;
        } else {
          inQuotes = false;
        }
      } else {
        field.write(ch);
      }
    } else if (ch == '"') {
      inQuotes = true;
    } else if (ch == ',') {
      row.add(field.toString());
      field.clear();
    } else if (ch == '\n' || ch == '\r') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(field.toString());
      field.clear();
      rows.add(row);
      row = <String>[];
    } else {
      field.write(ch);
    }
  }
  if (field.isNotEmpty || row.isNotEmpty) {
    row.add(field.toString());
    rows.add(row);
  }
  return rows;
}
