import '../../teacher/teacher_insights.dart' show SkillStatus;
import '../data/sinhala_progress.dart';
import '../data/sinhala_word_bank.dart';
import '../engine/sinhala_errors.dart';
import '../engine/sinhala_learner.dart';

/// Plain sentences for the teacher about each kind of mistake (English, with
/// Sinhala examples). Suggested wording — to be reviewed by an expert.
const sinhalaHabitSentences = {
  SinhalaError.pillaMissing: 'Often leaves out the pilla (vowel sign)',
  SinhalaError.pillaWrong: 'Often uses the wrong pilla',
  SinhalaError.pillaLength: 'Mixes up short and long pillas (ි / ී, ු / ූ)',
  SinhalaError.hal: 'Often leaves out or adds the hal kirima (්)',
  SinhalaError.lookalike: 'Mixes up letters that look or sound alike (බ / භ, ල / ළ, න / ණ)',
  SinhalaError.otherLetter: 'Often picks a wrong letter',
  SinhalaError.missing: 'Often leaves out a letter',
  SinhalaError.extra: 'Often adds an extra letter',
  SinhalaError.order: 'Often puts letters in the wrong order',
};

/// One classroom tip per kind of mistake. Suggested — to be reviewed by an expert.
const sinhalaHabitTips = {
  SinhalaError.pillaMissing: 'Say the word slowly, one akshara at a time, and ask which pilla each sound needs.',
  SinhalaError.pillaWrong: 'Practise one pilla at a time with picture words, then mix two pillas.',
  SinhalaError.pillaLength: 'Clap once for a short sound and stretch the hands apart for a long one: කි / කී, කු / කූ.',
  SinhalaError.hal: 'Tap once for each akshara; a letter with hal kirima has no vowel sound of its own (බත්).',
  SinhalaError.lookalike: 'Put the two letters side by side and point out the difference (බ and භ, ල and ළ).',
  SinhalaError.otherLetter: 'Say the word again and let the child point to the picture before building it.',
  SinhalaError.missing: 'Count the aksharas on fingers before building the word.',
  SinhalaError.extra: 'Read back what was built together, pointing to each akshara.',
  SinhalaError.order: 'Build the word slowly, saying each akshara as it is placed.',
};

class SinhalaNeedsHelp {
  SinhalaNeedsHelp(this.label, this.wrongAnswers);

  final String label;

  /// Up to 2 real examples: (word, what the child built).
  final List<(String, String)> wrongAnswers;

  String get sentence {
    if (wrongAnswers.isEmpty) return label;
    return '$label — ${wrongAnswers.map((w) => 'wrote "${w.$2}" for "${w.$1}"').join(', ')}';
  }
}

class SinhalaHabit {
  SinhalaHabit(this.type, this.inLast, this.of);

  final String type;
  final int inLast;
  final int of;

  String get sentence => sinhalaHabitSentences[type] ?? type;
  String get countText => '$inLast of the last $of words';
}

/// Everything the Sinhala Teacher View shows, worked out from the learner
/// model and the saved results. No model numbers.
class SinhalaInsights {
  SinhalaInsights({required this.progress, required this.bank, DateTime? now}) : now = now ?? DateTime.now();

  final SinhalaProgress progress;
  final SinhalaWordBank bank;
  final DateTime now;

  /// A skill is judged on its last few words.
  static const recentPerSkill = 6;
  static const habitWindow = 10;

  List<SinhalaWordResult> get results => progress.results;

  int get sessionsPlayed => progress.rounds.map((r) => r.sessionId).toSet().length;

  String get lastPlayed {
    if (progress.rounds.isEmpty) return 'not yet';
    final last = progress.rounds.last.finishedAt;
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(last.year, last.month, last.day)).inDays;
    if (days <= 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }

  SinhalaRound? get latest => progress.rounds.isEmpty ? null : progress.rounds.last;

  /// Change in words right first time since the round before.
  int? get trend {
    final r = progress.rounds;
    if (r.length < 2) return null;
    return r.last.firstTry - r[r.length - 2].firstTry;
  }

  String? get trendText {
    final t = trend;
    if (t == null) return null;
    if (t == 0) return 'Same as the round before';
    return '${t.abs()} ${t > 0 ? 'more' : 'fewer'} right first time than the round before';
  }

  // ------------------------------------------------------------- skills

  /// From the learner model: not tried yet / knows well / needs help (weak
  /// area: below 45% once tried; known from the first game on) / practising.
  SkillStatus status(String skill) {
    final s = progress.skills[skill];
    if (s == null || s.seen == 0) return SkillStatus.notStarted;
    if (SinhalaLearner.isMastered(progress, skill)) return SkillStatus.mastered;
    if (SinhalaLearner.isWeak(progress, skill)) return SkillStatus.needsHelp;
    return SkillStatus.gettingThere;
  }

  List<SinhalaSkill> skillsWith(SkillStatus s) => [for (final k in bank.skills) if (status(k.id) == s) k];

  /// Up to 3 weak areas (weakest first), with real wrong answers.
  List<SinhalaNeedsHelp> get needsHelp {
    final weak = skillsWith(SkillStatus.needsHelp)
      ..sort((a, b) => progress.skill(a.id).pL.compareTo(progress.skill(b.id).pL));
    return [
      for (final s in weak.take(3))
        SinhalaNeedsHelp(s.label, [
          for (final r in results.reversed.where((r) => r.skill == s.id && r.firstWrongAnswer != null).take(2))
            (r.word, r.firstWrongAnswer!),
        ]),
    ];
  }

  /// Mistake habits: the same rule the word chooser uses (the learner
  /// model's decaying mistake rate is above 30%), so a habit shown here is the
  /// habit the next words practise. Counted over the last 10 words.
  List<SinhalaHabit> get habits {
    final last = results.length <= habitWindow ? results : results.sublist(results.length - habitWindow);
    return [
      for (final t in SinhalaLearner.habits(progress))
        SinhalaHabit(t, last.where((r) => (r.errors[t] ?? 0) > 0).length, last.length),
    ];
  }

  int get roundsPlayed => progress.rounds.length;

  // ----------------------------------------------------------- progress

  /// Words right first time per round, last 10 rounds.
  List<(int, int)> get progressChart => [
        for (final r in progress.rounds.skip(progress.rounds.length > 10 ? progress.rounds.length - 10 : 0))
          (r.roundNo, r.firstTry),
      ];

  bool get nextIsWarmUp => !progress.warmUpDone && bank.placement.isNotEmpty;

  /// The stage the next round focuses on (planned when the last round ended).
  int get currentStage {
    final focus = progress.pendingFocus == null ? null : bank.skillOf(progress.pendingFocus!);
    if (focus != null) return focus.stage;
    final open = [for (final k in bank.skills) if (progress.unlocked.contains(k.id)) k];
    return open.isEmpty ? 1 : open.map((k) => k.stage).reduce((a, b) => a > b ? a : b);
  }

  String _stageLabel(int stage) {
    for (final s in bank.skills) {
      if (s.stage == stage) return s.label;
    }
    return 'stage $stage';
  }

  String get stageText => nextIsWarmUp
      ? 'Starting level not found yet (warm-up next)'
      : 'Stage $currentStage of ${bank.stageCount}: ${_stageLabel(currentStage)}';

  /// Why the next words were chosen (the selector's own reason).
  String get nextSentence {
    if (nextIsWarmUp) return 'Next: a short warm-up of 10 words to find the right starting level.';
    return progress.pendingReason ?? 'Next practice: words from ${_stageLabel(currentStage)}.';
  }

  /// One tip for the most common mistake habit.
  List<String> get tips {
    final h = habits;
    if (h.isEmpty) return const [];
    final tip = sinhalaHabitTips[h.first.type];
    return tip == null ? const [] : [tip];
  }
}
