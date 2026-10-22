import 'dart:math' as math;

import '../data/word_bank.dart';
import '../model/difficulty_prediction.dart';
import 'error_analyzer.dart';
import 'feature_extractor.dart';
import 'spelling_config.dart';

/// Where a skill's P(L) comes from.
class PriorSource {
  const PriorSource._();

  /// A starting guess (new child, or set from other skills in placement).
  static const assumed = 'placement-assumed';

  /// The child has spelled at least one word of this skill.
  static const evidence = 'evidence';
}

/// Per-skill state: BKT mastery P(L), counts, lock and bandit Beta params.
class SkillState {
  SkillState({
    this.pL = 0.1,
    this.seen = 0,
    this.correct = 0,
    Set<int>? roundsSeen,
    this.unlocked = false,
    this.priorSource = PriorSource.assumed,
    this.alpha = 1,
    this.beta = 1,
    this.masteryHeld = false,
  }) : roundsSeen = roundsSeen ?? {};

  double pL;

  /// Words of this skill spelled (placement included).
  int seen;

  /// Of those, right on the first try.
  int correct;

  /// Round numbers in which the skill was practised.
  final Set<int> roundsSeen;
  bool unlocked;
  String priorSource;
  double alpha;
  double beta;

  /// BKT says mastered, but the difficulty classifier said "hard" for the
  /// last two words: not shown as mastered until it settles.
  bool masteryHeld;

  /// True once the child has actually attempted a word of this skill.
  bool get tested => priorSource == PriorSource.evidence;

  Map<String, Object?> toJson() => {
        'pL': pL,
        'seen': seen,
        'correct': correct,
        'roundsSeen': roundsSeen.toList()..sort(),
        'unlocked': unlocked,
        'priorSource': priorSource,
        'alpha': alpha,
        'beta': beta,
        'masteryHeld': masteryHeld,
      };

  factory SkillState.fromJson(Map<String, Object?> j) => SkillState(
        pL: (j['pL'] as num).toDouble(),
        seen: j['seen'] as int,
        correct: j['correct'] as int? ?? 0,
        roundsSeen: ((j['roundsSeen'] as List?) ?? const []).cast<int>().toSet(),
        unlocked: j['unlocked'] as bool,
        priorSource: j['priorSource'] as String? ??
            ((j['tested'] as bool? ?? false) ? PriorSource.evidence : PriorSource.assumed),
        alpha: (j['alpha'] as num).toDouble(),
        beta: (j['beta'] as num).toDouble(),
        masteryHeld: j['masteryHeld'] as bool? ?? false,
      );
}

enum MasteryLabel { mastered, learning, weak, locked }

/// One finished round, kept for the teacher view, charts and history.
class RoundRecord {
  RoundRecord({
    required this.roundNo,
    required this.mode,
    required this.focusSkill,
    required this.reason,
    required this.wordIds,
    required this.failedWordIds,
    required this.pSnapshot,
    required this.finishedAt,
    this.sessionId,
    this.correct = 0,
    this.correctFirstTry = 0,
  });

  final int roundNo;
  final String mode;
  final String? focusSkill;
  final String reason;
  final List<String> wordIds;
  final List<String> failedWordIds;
  final Map<String, double> pSnapshot;
  final DateTime finishedAt;
  final String? sessionId;

  /// Words solved (within the 3 tries) and right on the first try.
  final int correct;
  final int correctFirstTry;

  Map<String, Object?> toJson() => {
        'roundNo': roundNo,
        'mode': mode,
        'focusSkill': focusSkill,
        'reason': reason,
        'wordIds': wordIds,
        'failedWordIds': failedWordIds,
        'pSnapshot': pSnapshot,
        'finishedAt': finishedAt.toIso8601String(),
        'sessionId': sessionId,
        'correct': correct,
        'correctFirstTry': correctFirstTry,
      };

  factory RoundRecord.fromJson(Map<String, Object?> j) {
    final wordIds = (j['wordIds'] as List).cast<String>();
    final failed = (j['failedWordIds'] as List).cast<String>();
    return RoundRecord(
      roundNo: j['roundNo'] as int,
      mode: j['mode'] as String,
      focusSkill: j['focusSkill'] as String?,
      reason: j['reason'] as String,
      wordIds: wordIds,
      failedWordIds: failed,
      pSnapshot: (j['pSnapshot'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      finishedAt: DateTime.parse(j['finishedAt'] as String),
      sessionId: j['sessionId'] as String?,
      correct: j['correct'] as int? ?? wordIds.length - failed.length,
      correctFirstTry: j['correctFirstTry'] as int? ?? 0,
    );
  }
}

/// Everything the app remembers about one child (saved as JSON).
class ChildModel {
  ChildModel({
    required this.childId,
    required this.avatar,
    required this.createdAt,
    required this.skills,
    this.group = SpellingMode.adaptive,
    this.name,
    Map<String, double>? errorRates,
    List<double>? firstInputHistory,
    List<double>? maxGapHistory,
    this.placementDone = false,
    List<RoundRecord>? rounds,
    Map<String, int>? failedDue,
    Set<String>? failedReturned,
    this.fixedCursor = 0,
    this.pendingPlan,
    Map<String, List<DifficultyPrediction>>? predictions,
  })  : predictions = predictions ?? {},
        errorRates = errorRates ?? {for (final t in ErrorType.all) t: 0.0},
        firstInputHistory = firstInputHistory ?? [],
        maxGapHistory = maxGapHistory ?? [],
        rounds = rounds ?? [],
        failedDue = failedDue ?? {},
        failedReturned = failedReturned ?? {};

  /// A brand-new child: everything locked at 0.1 except sight words (0.3)
  /// until the placement round sets starting values.
  factory ChildModel.create({
    required String childId,
    required String avatar,
    required WordBank bank,
    SpellingMode group = SpellingMode.adaptive,
    String? name,
  }) {
    return ChildModel(
      childId: childId,
      avatar: avatar,
      createdAt: DateTime.now(),
      group: group,
      name: name,
      skills: {
        for (final s in bank.skillOrder)
          s: s == WordBank.sightWords ? SkillState(pL: 0.3, unlocked: true) : SkillState(),
      },
    );
  }

  final String childId;
  final String avatar;
  final DateTime createdAt;
  final Map<String, SkillState> skills;

  /// Experiment group, fixed when the child is created.
  final SpellingMode group;

  /// Optional name typed by the teacher.
  String? name;
  final Map<String, double> errorRates;
  final List<double> firstInputHistory;
  final List<double> maxGapHistory;
  bool placementDone;
  final List<RoundRecord> rounds;

  /// Failed word id → the round number in which it comes back (once).
  final Map<String, int> failedDue;
  final Set<String> failedReturned;

  /// Position in the fixed-sequence baseline.
  int fixedCursor;

  /// The next round, planned when the previous one finished (so the teacher
  /// can see it). JSON of a RoundPlan.
  Map<String, Object?>? pendingPlan;

  /// Latest difficulty-classifier predictions per skill (newest last).
  final Map<String, List<DifficultyPrediction>> predictions;
  static const keepPredictions = 3;

  void addPrediction(String skill, DifficultyPrediction p) {
    final list = predictions.putIfAbsent(skill, () => []);
    list.add(p);
    if (list.length > keepPredictions) list.removeAt(0);
  }

  /// The last (up to 3) predictions for [skill] averaged, or null if none.
  DifficultyPrediction? averagePrediction(String skill) {
    final list = predictions[skill];
    return list == null || list.isEmpty ? null : DifficultyPrediction.average(list);
  }

  /// True if the classifier called [skill] "hard" for the last two words.
  bool hardTwiceInARow(String skill) {
    final list = predictions[skill] ?? const [];
    return list.length >= 2 && list.reversed.take(2).every((p) => p.label == 'hard');
  }

  static const _animalNames = {
    '🐶': 'Puppy', '🐱': 'Kitty', '🐼': 'Panda', '🦁': 'Lion', '🐰': 'Bunny', '🐸': 'Frog',
    '🐵': 'Monkey', '🐧': 'Penguin', '🦊': 'Fox', '🐨': 'Koala', '🐯': 'Tiger', '🐻': 'Bear',
  };

  String get displayName =>
      (name != null && name!.trim().isNotEmpty) ? name!.trim() : (_animalNames[avatar] ?? 'Player');

  int get roundsCompleted => rounds.length;
  int get nextRoundNo => rounds.length + 1;

  double get medianFirstInput => _medianOrDefault(firstInputHistory);
  double get medianMaxGap => _medianOrDefault(maxGapHistory);

  static double _medianOrDefault(List<double> values) {
    if (values.length < SpellingConfig.minWordsForMedian) return SpellingConfig.defaultMedianMs;
    final m = median(values);
    return m <= 0 ? SpellingConfig.defaultMedianMs : m;
  }

  static double median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Adds the current word to the running medians. Call after featurising.
  void recordTiming(double firstInputMs, double maxGapMs) {
    firstInputHistory.add(firstInputMs);
    if (maxGapMs > 0) maxGapHistory.add(maxGapMs);
    if (firstInputHistory.length > SpellingConfig.medianWindow) firstInputHistory.removeAt(0);
    if (maxGapHistory.length > SpellingConfig.medianWindow) maxGapHistory.removeAt(0);
  }

  /// Word ids played in the last [SpellingConfig.noRepeatRounds] rounds.
  Set<String> get recentWordIds => {
        for (final r in rounds.reversed.take(SpellingConfig.noRepeatRounds)) ...r.wordIds,
      };

  /// Mastered needs a high P(L) *and* enough real words over ≥ 2 rounds, so
  /// a lucky streak or a placement guess is never shown as mastery.
  bool isMastered(String skill) => bktMastered(skill) && !skills[skill]!.masteryHeld;

  /// The BKT side of mastery alone (before any hold from the classifier).
  bool bktMastered(String skill) {
    final s = skills[skill]!;
    return s.pL >= SpellingConfig.mastered &&
        s.seen >= SpellingConfig.masteredMinSeen &&
        s.roundsSeen.length >= SpellingConfig.masteredMinRounds;
  }

  bool isWeak(String skill) {
    final s = skills[skill]!;
    return s.pL < SpellingConfig.weakBelow && s.seen >= SpellingConfig.weakMinSeen;
  }

  MasteryLabel label(String skill) {
    final s = skills[skill]!;
    if (isMastered(skill)) return MasteryLabel.mastered;
    if (isWeak(skill)) return MasteryLabel.weak;
    if (!s.unlocked) return MasteryLabel.locked;
    return MasteryLabel.learning;
  }

  String? get topErrorType {
    final top = errorRates.entries.reduce((a, b) => b.value > a.value ? b : a);
    return top.value > 0 ? top.key : null;
  }

  Map<String, Object?> toJson() => {
        'childId': childId,
        'avatar': avatar,
        'name': name,
        'group': group.name,
        'createdAt': createdAt.toIso8601String(),
        'skills': skills.map((k, v) => MapEntry(k, v.toJson())),
        'errorRates': errorRates,
        'firstInputHistory': firstInputHistory,
        'maxGapHistory': maxGapHistory,
        'placementDone': placementDone,
        'rounds': rounds.map((r) => r.toJson()).toList(),
        'failedDue': failedDue,
        'failedReturned': failedReturned.toList(),
        'fixedCursor': fixedCursor,
        'pendingPlan': pendingPlan,
        'predictions': predictions.map((k, v) => MapEntry(k, v.map((p) => p.toJson()).toList())),
      };

  factory ChildModel.fromJson(Map<String, Object?> j) => ChildModel(
        childId: j['childId'] as String,
        avatar: j['avatar'] as String,
        name: j['name'] as String?,
        group: SpellingMode.values.firstWhere((m) => m.name == j['group'], orElse: () => SpellingMode.adaptive),
        createdAt: DateTime.parse(j['createdAt'] as String),
        skills: (j['skills'] as Map)
            .map((k, v) => MapEntry(k as String, SkillState.fromJson((v as Map).cast<String, Object?>()))),
        errorRates: (j['errorRates'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        firstInputHistory: (j['firstInputHistory'] as List).map((v) => (v as num).toDouble()).toList(),
        maxGapHistory: (j['maxGapHistory'] as List).map((v) => (v as num).toDouble()).toList(),
        placementDone: j['placementDone'] as bool,
        rounds: (j['rounds'] as List).map((r) => RoundRecord.fromJson((r as Map).cast<String, Object?>())).toList(),
        failedDue: (j['failedDue'] as Map).map((k, v) => MapEntry(k as String, v as int)),
        failedReturned: (j['failedReturned'] as List).cast<String>().toSet(),
        fixedCursor: j['fixedCursor'] as int? ?? 0,
        pendingPlan: (j['pendingPlan'] as Map?)?.cast<String, Object?>(),
        predictions: ((j['predictions'] as Map?) ?? const {}).map((k, v) => MapEntry(
              k as String,
              (v as List).map((p) => DifficultyPrediction.fromJson((p as Map).cast<String, Object?>())).toList(),
            )),
      );
}

/// Online learner model: behaviour-weighted BKT, placement, error tracker.
class LearnerModel {
  const LearnerModel._();

  /// Standard BKT posterior after one observation.
  static double bayes(double p, bool correct, {required double guess, required double slip}) {
    if (correct) return p * (1 - slip) / (p * (1 - slip) + (1 - p) * guess);
    return p * slip / (p * slip + (1 - p) * (1 - guess));
  }

  /// How much a word counts as "correct" evidence (0–1).
  ///
  /// With behaviour off this is plain BKT: 1 for right first time, else 0.
  static double evidenceWeight(FeatureRow r, {required bool useBehaviour, ModelParams params = const ModelParams()}) {
    if (!useBehaviour) return r.correctFirstTry ? 1.0 : 0.0;
    if (r.correctFirstTry) {
      final fluent = r.hesitationRatio < params.fluentHesitation && r.corrections <= 1;
      return fluent ? SpellingConfig.wFluent : SpellingConfig.wHesitant;
    }
    // The first mistake didn't touch the sound being practised (e.g. "bed"
    // spelled "deb" in a short-e word): weak evidence about this skill.
    if (r.firstWrongAnswer != null && !r.targetGraphemeError) {
      return r.finalCorrect ? SpellingConfig.wOffTargetSolved : SpellingConfig.wOffTargetFailed;
    }
    if (!r.finalCorrect) return 0.0;
    return r.attempts <= 2 ? SpellingConfig.wSecondTry : SpellingConfig.wThirdTry;
  }

  /// Behaviour-weighted update followed by the learning transition.
  /// [letters] sets the guess chance (short words are easier to guess).
  static double update(double p, double w, {required int letters, ModelParams params = const ModelParams()}) {
    final g = params.pGuess(letters), s = params.pSlip;
    final posterior = w * bayes(p, true, guess: g, slip: s) + (1 - w) * bayes(p, false, guess: g, slip: s);
    return posterior + (1 - posterior) * params.pLearn;
  }

  /// Counts one played word for its skill (exactly one skill per word).
  static SkillState? _count(ChildModel child, FeatureRow row) {
    final skill = child.skills[row.skill];
    if (skill == null) return null;
    skill
      ..seen += 1
      ..correct += row.correctFirstTry ? 1 : 0
      ..priorSource = PriorSource.evidence;
    skill.roundsSeen.add(row.roundNo);
    return skill;
  }

  /// Updates the child after one practice word. Fills `evidence_weight`,
  /// `p_before` and `p_after` on the row. Returns any newly unlocked skill.
  static String? applyWord(
    ChildModel child,
    FeatureRow row,
    WordBank bank, {
    required bool useBehaviour,
    ModelParams params = const ModelParams(),
  }) {
    _updateErrorRates(child, row, bank);
    final skill = _count(child, row);
    if (skill == null) return null;

    final before = skill.pL;
    final w = evidenceWeight(row, useBehaviour: useBehaviour, params: params);
    skill.pL = update(before, w, letters: row.wordLength, params: params);

    // Bandit reward = learning progress on this skill.
    final reward = ((skill.pL - before).abs() * 5).clamp(0.0, 1.0);
    skill
      ..alpha += reward
      ..beta += 1 - reward;

    row.values['evidence_weight'] = w;
    row.values['p_before'] = before;
    row.values['p_after'] = skill.pL;

    if (before < SpellingConfig.unlockAt && skill.pL >= SpellingConfig.unlockAt) {
      return unlockNext(child, bank);
    }
    return null;
  }

  /// Placement words update the error tracker and the counts; the starting
  /// P(L) values are set from the whole round in [applyPlacement].
  static void applyPlacementWord(ChildModel child, FeatureRow row, WordBank bank) {
    _updateErrorRates(child, row, bank);
    final skill = _count(child, row);
    // No BKT update here, but record the estimate so the difficulty
    // classifier always has its "P(L) before" input.
    row.values['p_before'] = skill?.pL;
    row.values['p_after'] = skill?.pL;
  }

  /// Letters a child can actually reverse (b/d, p/q).
  static const _reversible = {'b', 'd', 'p', 'q'};

  /// Decayed rate per error type. The reversal rate only moves on words
  /// that give a chance to reverse (contain b/d/p/q), otherwise a child who
  /// flips b/d every time would look fine because most words have none.
  static void _updateErrorRates(ChildModel child, FeatureRow row, WordBank bank) {
    final word = bank.byId[row.wordId];
    final canReverse = word == null || word.letters.any(_reversible.contains);
    for (final type in ErrorType.all) {
      final occurred = row.errorCount(type) > 0 ? 1.0 : 0.0;
      if (type == ErrorType.reversal && !canReverse && occurred == 0) continue;
      child.errorRates[type] =
          SpellingConfig.errorDecay * child.errorRates[type]! + (1 - SpellingConfig.errorDecay) * occurred;
    }
  }

  /// Sets starting P(L) for every skill from the placement round. Tested
  /// skills get a value from their word; the rest are assumed from the
  /// stage of the first mistake and stay "placement-assumed".
  static void applyPlacement(ChildModel child, List<FeatureRow> rows, WordBank bank) {
    final tested = <String, double>{};
    int? errorStage;
    for (final r in rows) {
      tested[r.skill] = r.correctFirstTry ? 0.6 : (r.finalCorrect ? 0.4 : 0.15);
      if (!r.correctFirstTry && (errorStage == null || r.stage < errorStage)) errorStage = r.stage;
    }
    final testedStages = rows.map((r) => r.stage).toSet();
    final maxTestedStage = testedStages.isEmpty ? 0 : testedStages.reduce(math.max);

    for (final entry in child.skills.entries) {
      final skill = entry.key, s = entry.value;
      final stage = bank.skillStage[skill] ?? 0;
      if (skill == WordBank.sightWords) {
        s
          ..pL = 0.3
          ..unlocked = true;
        continue;
      }
      if (errorStage == null) {
        // No placement errors: stages up to the last tested one start as
        // known, later stages open as "learning".
        s
          ..pL = tested[skill] ?? (stage <= maxTestedStage ? 0.6 : 0.3)
          ..unlocked = true;
      } else if (stage < errorStage) {
        s
          ..pL = tested[skill] ?? 0.6
          ..unlocked = true;
      } else if (stage == errorStage) {
        s
          ..pL = tested[skill] ?? 0.3
          ..unlocked = true;
      } else {
        s
          ..pL = tested[skill] ?? 0.1
          ..unlocked = false;
      }
    }
    child.placementDone = true;
  }

  /// Unlocks the next locked skill in stage order. A newly opened skill
  /// starts at 0.3 at least, so the selector can choose it.
  static String? unlockNext(ChildModel child, WordBank bank) {
    for (final skill in bank.skillOrder) {
      final s = child.skills[skill]!;
      if (!s.unlocked) {
        s
          ..unlocked = true
          ..pL = math.max(s.pL, SpellingConfig.candidateMin);
        return skill;
      }
    }
    return null;
  }
}
