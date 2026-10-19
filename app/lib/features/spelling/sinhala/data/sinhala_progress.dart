import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// How one word went.
class SinhalaWordResult {
  SinhalaWordResult({
    required this.wordId,
    required this.word,
    required this.skill,
    required this.stage,
    required this.roundNo,
    required this.tries,
    required this.correctFirstTry,
    required this.finalCorrect,
    required this.at,
    this.firstWrongAnswer,
    Map<String, int>? errors,
  }) : errors = errors ?? {};

  factory SinhalaWordResult.fromJson(Map<String, Object?> j) => SinhalaWordResult(
        wordId: j['wordId']! as String,
        word: j['word']! as String,
        skill: j['skill'] as String? ?? '',
        stage: (j['stage'] as num?)?.toInt() ?? 0,
        roundNo: (j['roundNo'] as num?)?.toInt() ?? 0,
        tries: (j['tries'] as num?)?.toInt() ?? 1,
        correctFirstTry: j['correctFirstTry'] as bool? ?? false,
        finalCorrect: j['finalCorrect'] as bool? ?? false,
        at: DateTime.parse(j['at']! as String),
        firstWrongAnswer: j['firstWrongAnswer'] as String?,
        errors: (j['errors'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );

  final String wordId;
  final String word;
  final String skill;
  final int stage;
  final int roundNo;
  final int tries;
  final bool correctFirstTry;
  final bool finalCorrect;
  final DateTime at;

  /// What the child built on the first try, when it was wrong.
  final String? firstWrongAnswer;

  /// Mistakes in the first wrong try (see SinhalaError).
  final Map<String, int> errors;

  Map<String, Object?> toJson() => {
        'wordId': wordId,
        'word': word,
        'skill': skill,
        'stage': stage,
        'roundNo': roundNo,
        'tries': tries,
        'correctFirstTry': correctFirstTry,
        'finalCorrect': finalCorrect,
        'at': at.toIso8601String(),
        'firstWrongAnswer': firstWrongAnswer,
        'errors': errors,
      };
}

/// One finished round of 10 words.
class SinhalaRound {
  SinhalaRound({
    required this.roundNo,
    required this.sessionId,
    required this.wordIds,
    required this.firstTry,
    required this.afterRetry,
    required this.shown,
    required this.finishedAt,
  });

  factory SinhalaRound.fromJson(Map<String, Object?> j) => SinhalaRound(
        roundNo: (j['roundNo']! as num).toInt(),
        sessionId: j['sessionId'] as String? ?? '',
        wordIds: (j['wordIds'] as List? ?? const []).cast<String>(),
        firstTry: (j['firstTry'] as num?)?.toInt() ?? 0,
        afterRetry: (j['afterRetry'] as num?)?.toInt() ?? 0,
        shown: (j['shown'] as num?)?.toInt() ?? 0,
        finishedAt: DateTime.parse(j['finishedAt']! as String),
      );

  final int roundNo;
  final String sessionId;
  final List<String> wordIds;

  /// Right on the first try / right on the 2nd or 3rd try / answer shown.
  final int firstTry;
  final int afterRetry;
  final int shown;
  final DateTime finishedAt;

  int get total => wordIds.length;

  Map<String, Object?> toJson() => {
        'roundNo': roundNo,
        'sessionId': sessionId,
        'wordIds': wordIds,
        'firstTry': firstTry,
        'afterRetry': afterRetry,
        'shown': shown,
        'finishedAt': finishedAt.toIso8601String(),
      };
}

/// Everything the Sinhala game remembers about the phone's child.
class SinhalaProgress {
  SinhalaProgress({
    this.name,
    this.avatar = '🐼',
    this.warmUpDone = false,
    this.cursor = 0,
    Map<String, int>? retryDue,
    List<SinhalaRound>? rounds,
    List<SinhalaWordResult>? results,
    DateTime? createdAt,
  })  : retryDue = retryDue ?? {},
        rounds = rounds ?? [],
        results = results ?? [],
        createdAt = createdAt ?? DateTime.now();

  factory SinhalaProgress.fromJson(Map<String, Object?> j) => SinhalaProgress(
        name: j['name'] as String?,
        avatar: j['avatar'] as String? ?? '🐼',
        warmUpDone: j['warmUpDone'] as bool? ?? false,
        cursor: (j['cursor'] as num?)?.toInt() ?? 0,
        retryDue: (j['retryDue'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())),
        rounds: [for (final r in j['rounds'] as List? ?? const []) SinhalaRound.fromJson((r as Map).cast())],
        results: [for (final r in j['results'] as List? ?? const []) SinhalaWordResult.fromJson((r as Map).cast())],
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
      );

  String? name;
  String avatar;
  bool warmUpDone;

  /// Next practice word (index into the bank's practice order).
  int cursor;

  /// Words whose answer was shown → round in which they come back.
  final Map<String, int> retryDue;
  final List<SinhalaRound> rounds;
  final List<SinhalaWordResult> results;
  final DateTime createdAt;

  int get nextRoundNo => rounds.length + 1;

  String get displayName => name ?? _animalNames[avatar] ?? 'Player';

  static const _animalNames = {'🐼': 'Panda', '🐶': 'Puppy', '🐱': 'Kitty', '🐸': 'Frog'};

  Map<String, Object?> toJson() => {
        'name': name,
        'avatar': avatar,
        'warmUpDone': warmUpDone,
        'cursor': cursor,
        'retryDue': retryDue,
        'rounds': [for (final r in rounds) r.toJson()],
        'results': [for (final r in results) r.toJson()],
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Where the Sinhala progress is saved. Separate from the English data.
abstract class SinhalaProgressStore {
  Future<SinhalaProgress> load();
  Future<void> save(SinhalaProgress progress);

  /// Deletes everything (Teacher View → Reset all data).
  Future<void> clear();
}

/// `<app documents>/spelling_si/progress.json` (works offline).
class FileSinhalaProgressStore implements SinhalaProgressStore {
  Future<File> get _file async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = await Directory('${docs.path}/spelling_si').create(recursive: true);
    return File('${dir.path}/progress.json');
  }

  @override
  Future<SinhalaProgress> load() async {
    try {
      final f = await _file;
      if (!await f.exists()) return SinhalaProgress();
      return SinhalaProgress.fromJson((jsonDecode(await f.readAsString()) as Map).cast());
    } catch (_) {
      return SinhalaProgress(); // a damaged file never stops the game
    }
  }

  @override
  Future<void> save(SinhalaProgress progress) async {
    final f = await _file;
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(progress.toJson()), flush: true);
    await tmp.rename(f.path);
  }

  @override
  Future<void> clear() async {
    final f = await _file;
    if (await f.exists()) await f.delete();
  }
}

/// For tests.
class InMemorySinhalaProgressStore implements SinhalaProgressStore {
  Map<String, Object?>? saved;

  @override
  Future<SinhalaProgress> load() async =>
      saved == null ? SinhalaProgress() : SinhalaProgress.fromJson(jsonDecode(jsonEncode(saved)) as Map<String, Object?>);

  @override
  Future<void> save(SinhalaProgress progress) async => saved = progress.toJson();

  @override
  Future<void> clear() async => saved = null;
}
