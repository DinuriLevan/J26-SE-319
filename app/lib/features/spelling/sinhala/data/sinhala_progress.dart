import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../model/difficulty_prediction.dart';

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
    Map<String, Object?>? features,
  })  : errors = errors ?? {},
        features = features ?? {};

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
        features: (j['features'] as Map?)?.cast<String, Object?>(),
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

  /// The word's feature row (sinhala_features.dart): timing, edits, mistakes,
  /// the learner model before/after and the classifier's prediction. This is
  /// the dataset exported for training.
  final Map<String, Object?> features;

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
        'features': features,
      };
}

/// The learner model's view of one skill (stage) for this child.
class SinhalaSkillState {
  SinhalaSkillState({this.pL = 0.1, this.seen = 0, this.correct = 0, Set<int>? rounds, this.masteryHeld = false})
      : rounds = rounds ?? {};

  factory SinhalaSkillState.fromJson(Map<String, Object?> j) => SinhalaSkillState(
        pL: (j['pL'] as num?)?.toDouble() ?? 0.1,
        seen: (j['seen'] as num?)?.toInt() ?? 0,
        correct: (j['correct'] as num?)?.toInt() ?? 0,
        rounds: {for (final r in j['rounds'] as List? ?? const []) (r as num).toInt()},
        masteryHeld: j['masteryHeld'] as bool? ?? false,
      );

  /// Chance the child knows the skill (BKT).
  double pL;

  /// Words of this skill spelled (the warm-up counts), and right first time.
  int seen;
  int correct;

  /// Rounds in which the skill was practised.
  final Set<int> rounds;

  /// BKT says mastered but the classifier said "hard" twice: not yet.
  bool masteryHeld;

  Map<String, Object?> toJson() => {
        'pL': pL,
        'seen': seen,
        'correct': correct,
        'rounds': rounds.toList()..sort(),
        'masteryHeld': masteryHeld,
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
    Map<String, SinhalaSkillState>? skills,
    Set<String>? unlocked,
    Map<String, double>? errorRates,
    List<double>? firstInputs,
    List<double>? maxGaps,
    Map<String, List<DifficultyPrediction>>? predictions,
    this.pendingPlan,
    this.pendingReason,
    this.pendingFocus,
  })  : retryDue = retryDue ?? {},
        rounds = rounds ?? [],
        results = results ?? [],
        createdAt = createdAt ?? DateTime.now(),
        skills = skills ?? {},
        unlocked = unlocked ?? {},
        errorRates = errorRates ?? {},
        firstInputs = firstInputs ?? [],
        maxGaps = maxGaps ?? [],
        predictions = predictions ?? {};

  factory SinhalaProgress.fromJson(Map<String, Object?> j) => SinhalaProgress(
        name: j['name'] as String?,
        avatar: j['avatar'] as String? ?? '🐼',
        warmUpDone: j['warmUpDone'] as bool? ?? false,
        cursor: (j['cursor'] as num?)?.toInt() ?? 0,
        retryDue: (j['retryDue'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toInt())),
        rounds: [for (final r in j['rounds'] as List? ?? const []) SinhalaRound.fromJson((r as Map).cast())],
        results: [for (final r in j['results'] as List? ?? const []) SinhalaWordResult.fromJson((r as Map).cast())],
        createdAt: DateTime.tryParse(j['createdAt'] as String? ?? ''),
        skills: (j['skills'] as Map?)
            ?.map((k, v) => MapEntry(k as String, SinhalaSkillState.fromJson((v as Map).cast()))),
        unlocked: {...(j['unlocked'] as List? ?? const []).cast<String>()},
        errorRates: (j['errorRates'] as Map?)?.map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        firstInputs: [for (final v in j['firstInputs'] as List? ?? const []) (v as num).toDouble()],
        maxGaps: [for (final v in j['maxGaps'] as List? ?? const []) (v as num).toDouble()],
        predictions: (j['predictions'] as Map?)?.map((k, v) => MapEntry(k as String, [
              for (final p in v as List) DifficultyPrediction.fromJson((p as Map).cast()),
            ])),
        pendingPlan: (j['pendingPlan'] as List?)?.cast<String>(),
        pendingReason: j['pendingReason'] as String?,
        pendingFocus: j['pendingFocus'] as String?,
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

  /// Learner model (sinhala_learner.dart): one state per skill, the skills
  /// the child may practise, and how often each kind of mistake happens.
  final Map<String, SinhalaSkillState> skills;
  final Set<String> unlocked;
  final Map<String, double> errorRates;

  /// The child's recent first-input times and longest pauses (ms), to
  /// compare each word with the child's own usual speed.
  final List<double> firstInputs;
  final List<double> maxGaps;

  /// The classifier's last 3 predictions per skill.
  final Map<String, List<DifficultyPrediction>> predictions;

  /// The next round, planned when the last one ended (word ids), and why.
  List<String>? pendingPlan;
  String? pendingReason;
  String? pendingFocus;

  SinhalaSkillState skill(String id) => skills.putIfAbsent(id, SinhalaSkillState.new);

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
        'skills': skills.map((k, v) => MapEntry(k, v.toJson())),
        'unlocked': unlocked.toList(),
        'errorRates': errorRates,
        'firstInputs': firstInputs,
        'maxGaps': maxGaps,
        'predictions': predictions.map((k, v) => MapEntry(k, [for (final p in v) p.toJson()])),
        'pendingPlan': pendingPlan,
        'pendingReason': pendingReason,
        'pendingFocus': pendingFocus,
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
