import '../data/skill_labels.dart';
import '../data/word_bank.dart';
import '../engine/feature_extractor.dart';
import '../engine/learner_model.dart';
import '../engine/selector.dart';
import '../engine/spelling_config.dart';

/// Plain-language status of one skill for the teacher.
enum SkillStatus { mastered, needsHelp, gettingThere, notStarted }

extension SkillStatusText on SkillStatus {
  String get text => switch (this) {
        SkillStatus.mastered => 'Knows well',
        SkillStatus.needsHelp => 'Needs more practice',
        SkillStatus.gettingThere => 'Practising',
        SkillStatus.notStarted => 'Coming later',
      };
}

/// How the words of one round went. Every word ends solved or shown, so
/// "solved" alone says little; how many tries it took is what matters.
class RoundBreakdown {
  RoundBreakdown(this.round)
      : firstTry = round.correctFirstTry,
        afterRetry = round.correct - round.correctFirstTry,
        shown = round.wordIds.length - round.correct;

  final RoundRecord round;

  /// Right on the first try.
  final int firstTry;

  /// Right on the second or third try.
  final int afterRetry;

  /// Not solved in 3 tries, so the game showed the answer.
  final int shown;

  int get total => round.wordIds.length;
}

class NeedsHelp {
  NeedsHelp(this.skill, this.wrongAnswers);

  final String skill;

  /// Up to 2 real examples: (word, what the child wrote).
  final List<(String, String)> wrongAnswers;

  String get sentence {
    final label = skillLabel(skill).full;
    if (wrongAnswers.isEmpty) return label;
    return '$label — ${wrongAnswers.map((w) => 'wrote "${w.$2}" for "${w.$1}"').join(', ')}';
  }
}

class Habit {
  Habit(this.errorType, this.inLast10, this.of);

  final String errorType;
  final int inLast10;
  final int of;

  String get sentence => habitSentences[errorType] ?? errorType;
  String get countText => '$inLast10 of the last $of words';
}

/// Everything the teacher view shows, worked out from the child model and
/// the child's saved word rows. No model numbers leak out of this class.
class TeacherInsights {
  TeacherInsights({
    required this.child,
    required this.rows,
    required this.bank,
    required this.next,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  final ChildModel child;

  /// This child's feature rows, oldest first.
  final List<FeatureRow> rows;
  final WordBank bank;
  final RoundPlan next;
  final DateTime now;

  // ------------------------------------------------------------- header

  int get sessionsPlayed => child.rounds.map((r) => r.sessionId ?? 'r${r.roundNo}').toSet().length;

  String get lastPlayed {
    if (child.rounds.isEmpty) return 'not yet';
    final last = child.rounds.last.finishedAt;
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(last.year, last.month, last.day)).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  RoundRecord? get latestRound => child.rounds.isEmpty ? null : child.rounds.last;

  RoundBreakdown? get latest => latestRound == null ? null : RoundBreakdown(latestRound!);

  /// Change in words right first time since the round before; null if there
  /// is no round before.
  int? get trend {
    if (child.rounds.length < 2) return null;
    return child.rounds.last.correctFirstTry - child.rounds[child.rounds.length - 2].correctFirstTry;
  }

  String? get trendText {
    final t = trend;
    if (t == null) return null;
    if (t == 0) return 'Same as the round before';
    final n = t.abs();
    return '$n ${t > 0 ? 'more' : 'fewer'} right first time than the round before';
  }

  // ----------------------------------------------------------- statuses

  SkillStatus status(String skill) {
    final s = child.skills[skill]!;
    if (s.seen == 0) return SkillStatus.notStarted;
    if (child.isMastered(skill)) return SkillStatus.mastered;
    if (child.isWeak(skill)) return SkillStatus.needsHelp;
    return SkillStatus.gettingThere;
  }

  /// Skills with [status], in teaching order.
  List<String> skillsWith(SkillStatus status) => [for (final s in bank.skillOrder) if (this.status(s) == status) s];

  /// Up to 3 weak skills, weakest first, with real wrong answers.
  List<NeedsHelp> get needsHelp {
    final weak = [for (final s in bank.skillOrder) if (child.isWeak(s)) s]
      ..sort((a, b) => child.skills[a]!.pL.compareTo(child.skills[b]!.pL));
    return [
      for (final s in weak.take(3))
        NeedsHelp(s, [
          for (final r in rows.reversed.where((r) => r.skill == s && r.firstWrongAnswer != null).take(2))
            (r.word.toLowerCase(), r.firstWrongAnswer!),
        ]),
    ];
  }

  /// Error types with a recent rate > 0.3 and at least 3 occurrences.
  List<Habit> get habits {
    final last = rows.length <= 10 ? rows : rows.sublist(rows.length - 10);
    return [
      for (final t in habitSentences.keys)
        if (child.errorRates[t]! > SpellingConfig.errorFocusThreshold &&
            rows.where((r) => r.errorCount(t) > 0).length >= SpellingConfig.habitMinCount)
          Habit(t, last.where((r) => r.errorCount(t) > 0).length, last.length),
    ];
  }

  /// Skills the child is slow to start (median hesitation > 1.5, seen ≥ 3).
  List<String> get slowStartSkills => [
        for (final s in bank.skillOrder)
          if (child.skills[s]!.seen >= SpellingConfig.weakMinSeen &&
              _medianHesitation(s) > SpellingConfig.slowStartRatio)
            s,
      ];

  double _medianHesitation(String skill) {
    final values = [for (final r in rows) if (r.skill == skill) r.hesitationRatio];
    return values.isEmpty ? 0 : ChildModel.median(values);
  }

  List<String> get hesitationNotes => [
        for (final s in slowStartSkills)
          'Takes longer to start ${skillLabel(s).short} words — may need the word repeated.',
      ];

  List<String> get mastered => [for (final s in bank.skillOrder) if (child.isMastered(s)) s];

  /// Skills whose estimate rose by ≥ 0.15 over the last 2 rounds.
  List<String> get improving {
    if (child.rounds.length < 2) return [];
    final base = child.rounds[child.rounds.length >= 3 ? child.rounds.length - 3 : 0].pSnapshot;
    return [
      for (final s in bank.skillOrder)
        if (child.skills[s]!.seen >= SpellingConfig.weakMinSeen &&
            !child.isMastered(s) &&
            child.skills[s]!.pL - (base[s] ?? child.skills[s]!.pL) >= SpellingConfig.improvingRise)
          s,
    ];
  }

  // ------------------------------------------------------------ progress

  /// Words right first time per round, last 10 rounds: (round number, count).
  List<(int, int)> get progress => [
        for (final r in child.rounds.skip(child.rounds.length > 10 ? child.rounds.length - 10 : 0))
          (r.roundNo, r.correctFirstTry),
      ];

  /// Stage the child is working on: the next round's focus, else the most
  /// common stage among the next words.
  int get currentStage {
    final focus = next.focusSkill;
    if (focus != null && (bank.skillStage[focus] ?? 0) > 0) return bank.skillStage[focus]!;
    final counts = <int, int>{};
    for (final w in next.words) {
      if (w.stage > 0) counts[w.stage] = (counts[w.stage] ?? 0) + 1;
    }
    if (counts.isEmpty) return 1;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  static const stageCount = 8;

  String get stageText => next.isPlacement
      ? 'Starting level not found yet (warm-up next)'
      : 'Stage $currentStage of $stageCount: ${stageNames[currentStage]}';

  String get nextSentence => next.teacherSentence;

  /// 1–2 classroom tips: the top mistake habit, then the current stage.
  List<String> get tips {
    final out = <String>[];
    final h = habits;
    if (h.isNotEmpty) {
      final top = h.reduce((a, b) => child.errorRates[b.errorType]! > child.errorRates[a.errorType]! ? b : a);
      final tip = errorTips[top.errorType];
      if (tip != null) out.add(tip);
    }
    final weak = needsHelp;
    final stage = weak.isNotEmpty ? (bank.skillStage[weak.first.skill] ?? currentStage) : currentStage;
    final stageTip = stageTips[stage];
    if (stageTip != null && !next.isPlacement) out.add(stageTip);
    return out.take(2).toList();
  }
}
