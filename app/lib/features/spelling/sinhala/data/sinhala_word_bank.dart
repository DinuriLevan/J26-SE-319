import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart';

import 'akshara.dart';

/// One word of the Sinhala word bank (assets/spelling/sinhala/sinhala_wordbank.json).
class SinhalaWord {
  SinhalaWord({
    required this.id,
    required this.word,
    required this.english,
    required this.aksharas,
    required this.skill,
    required this.stage,
    required this.difficulty,
    required this.role,
    required this.emoji,
    required this.imageFile,
    required this.distractors,
  });

  factory SinhalaWord.fromJson(Map<String, Object?> j) => SinhalaWord(
        id: j['word_id']! as String,
        word: (j['word']! as String).trim(),
        english: j['english'] as String? ?? '',
        aksharas: [
          for (final a in (j['aksharas']! as String).split('|'))
            if (a.trim().isNotEmpty) Akshara.parse(a),
        ],
        skill: j['primary_skill'] as String? ?? '',
        stage: (j['skill_stage'] as num?)?.toInt() ?? 0,
        difficulty: (j['difficulty'] as num?)?.toInt() ?? 1,
        role: j['role'] as String? ?? 'practice',
        emoji: j['emoji'] as String? ?? '',
        imageFile: j['image_file'] as String? ?? '',
        distractors: [
          for (final d in (j['confusable_distractors'] as String? ?? '').split(RegExp(r'\s+')))
            if (d.isNotEmpty) d,
        ],
      );

  final String id;
  final String word;
  final String english;
  final List<Akshara> aksharas;
  final String skill;
  final int stage;
  final int difficulty;
  final String role;
  final String emoji;
  final String imageFile;

  /// Look-alike letters and pillas to add to the tray.
  final List<String> distractors;

  /// Base letters, one per akshara (ප, ස for පූසා).
  List<String> get letters => [for (final a in aksharas) a.base];

  /// Every pilla mark of the word, in order (ූ, ා for පූසා).
  List<String> get marks => [for (final a in aksharas) ...a.marks];

  /// The aksharas as written (පූ, සා).
  List<String> get aksharaTexts => [for (final a in aksharas) a.text];

  /// Picture asset (Twemoji SVG), or null if the word has none.
  String? get imageAsset {
    if (imageFile.isEmpty) return null;
    return '${SinhalaWordBank.folder}/images/${imageFile.split('/').last}';
  }

  /// Recorded word (a .wav/.m4a with the same name is used, see SinhalaVoice.recordingFor).
  String get audioAsset => '${SinhalaWordBank.folder}/audio/$id.mp3';
}

/// One skill (= one stage) from sinhala_skills.json, e.g. stage 2 "ඇලපිල්ල ා".
class SinhalaSkill {
  const SinhalaSkill({required this.id, required this.stage, required this.label});

  final String id;
  final int stage;
  final String label;
}

class SinhalaWordBank {
  SinhalaWordBank(Iterable<SinhalaWord> words, {List<SinhalaSkill>? skills})
      : words = [for (final w in words) if (w.imageAsset != null && w.aksharas.isNotEmpty) w],
        skills = skills ?? _skillsFrom(words);

  static const folder = 'assets/spelling/sinhala';
  static const assetPath = '$folder/sinhala_wordbank.json';
  static const skillsPath = '$folder/sinhala_skills.json';

  /// Words that have a picture (words without one are left out).
  final List<SinhalaWord> words;

  /// The skills in teaching order (stage 1 first).
  final List<SinhalaSkill> skills;

  static Future<SinhalaWordBank> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    return SinhalaWordBank.fromJson(await b.loadString(assetPath), skillsJson: await b.loadString(skillsPath));
  }

  factory SinhalaWordBank.fromJson(String json, {String? skillsJson}) {
    final words = [
      for (final row in jsonDecode(json) as List) SinhalaWord.fromJson((row as Map).cast<String, Object?>()),
    ];
    if (skillsJson == null) return SinhalaWordBank(words);
    final stages = (jsonDecode(skillsJson) as Map)['stages'] as List;
    return SinhalaWordBank(words, skills: [
      for (final s in stages)
        SinhalaSkill(
          id: (s as Map)['skill'] as String,
          stage: (s['stage'] as num).toInt(),
          label: s['label'] as String,
        ),
    ]..sort((a, b) => a.stage.compareTo(b.stage)));
  }

  /// Without the skills file: one skill per stage, named after its id.
  static List<SinhalaSkill> _skillsFrom(Iterable<SinhalaWord> words) {
    final byStage = <int, String>{for (final w in words) w.stage: w.skill};
    return [
      for (final e in byStage.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
        SinhalaSkill(id: e.value, stage: e.key, label: e.value),
    ];
  }

  SinhalaSkill? skillOf(String id) {
    for (final s in skills) {
      if (s.id == id) return s;
    }
    return null;
  }

  String labelOf(String skillId) => skillOf(skillId)?.label ?? skillId;

  int get stageCount => skills.isEmpty ? 0 : skills.map((s) => s.stage).reduce(math.max);

  SinhalaWord? byId(String id) {
    for (final w in words) {
      if (w.id == id) return w;
    }
    return null;
  }

  /// The 10 warm-up words.
  List<SinhalaWord> get placement => [for (final w in words) if (w.role == 'placement') w];

  /// Practice words from the easiest stage up (stage, then difficulty).
  List<SinhalaWord> get practiceInOrder {
    final list = [for (final w in words) if (w.role != 'placement') w];
    final index = {for (var i = 0; i < words.length; i++) words[i].id: i};
    list.sort((a, b) {
      final s = a.stage.compareTo(b.stage);
      if (s != 0) return s;
      final d = a.difficulty.compareTo(b.difficulty);
      return d != 0 ? d : index[a.id]!.compareTo(index[b.id]!);
    });
    return list;
  }
}
