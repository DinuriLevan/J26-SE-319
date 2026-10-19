import '../../teacher/teacher_insights.dart' show SkillStatus;
import '../data/sinhala_progress.dart';
import '../data/sinhala_word_bank.dart';
import '../engine/sinhala_errors.dart';
import '../game/sinhala_game_controller.dart';

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

/// Everything the Sinhala Teacher View shows, worked out from the saved
/// results. No model numbers.
class SinhalaInsights {
  SinhalaInsights({required this.progress, required this.bank, DateTime? now}) : now = now ?? DateTime.now();

  final SinhalaProgress progress;
  final SinhalaWordBank bank;
  final DateTime now;

  /// A skill is judged on its last few words.
  static const recentPerSkill = 6;
  static const habitWindow = 10;
  static const habitMinCount = 3;

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

  List<SinhalaWordResult> _ofSkill(String skill) => [for (final r in results) if (r.skill == skill) r];

  SkillStatus status(String skill) {
    final all = _ofSkill(skill);
    if (all.isEmpty) return SkillStatus.notStarted;
    final recent = all.length <= recentPerSkill ? all : all.sublist(all.length - recentPerSkill);
    final rate = recent.where((r) => r.correctFirstTry).length / recent.length;
    if (all.length >= 4 && rate >= 0.8) return SkillStatus.mastered;
    if (all.length >= 3 && rate < 0.5) return SkillStatus.needsHelp;
    return SkillStatus.gettingThere;
  }

  List<SinhalaSkill> skillsWith(SkillStatus s) => [for (final k in bank.skills) if (status(k.id) == s) k];

  /// Up to 3 skills that need help (weakest first), with real wrong answers.
  List<SinhalaNeedsHelp> get needsHelp {
    double rate(String skill) {
      final all = _ofSkill(skill);
      final recent = all.length <= recentPerSkill ? all : all.sublist(all.length - recentPerSkill);
      return recent.where((r) => r.correctFirstTry).length / recent.length;
    }

    final weak = skillsWith(SkillStatus.needsHelp)..sort((a, b) => rate(a.id).compareTo(rate(b.id)));
    return [
      for (final s in weak.take(3))
        SinhalaNeedsHelp(s.label, [
          for (final r in results.reversed.where((r) => r.skill == s.id && r.firstWrongAnswer != null).take(2))
            (r.word, r.firstWrongAnswer!),
        ]),
    ];
  }

  /// Kinds of mistake seen in at least 3 of the last 10 words.
  List<SinhalaHabit> get habits {
    final last = results.length <= habitWindow ? results : results.sublist(results.length - habitWindow);
    final out = [
      for (final t in SinhalaError.all)
        if (last.where((r) => (r.errors[t] ?? 0) > 0).length >= habitMinCount)
          SinhalaHabit(t, last.where((r) => (r.errors[t] ?? 0) > 0).length, last.length),
    ];
    return out..sort((a, b) => b.inLast.compareTo(a.inLast));
  }

  // ----------------------------------------------------------- progress

  /// Words right first time per round, last 10 rounds.
  List<(int, int)> get progressChart => [
        for (final r in progress.rounds.skip(progress.rounds.length > 10 ? progress.rounds.length - 10 : 0))
          (r.roundNo, r.firstTry),
      ];

  List<SinhalaWord> get nextWords => SinhalaGameController.previewNext(bank, progress);

  bool get nextIsWarmUp => !progress.warmUpDone && bank.placement.isNotEmpty;

  /// The stage most of the next round's new words come from.
  int get currentStage {
    final counts = <int, int>{};
    for (final w in nextWords) {
      if (!progress.retryDue.containsKey(w.id)) counts[w.stage] = (counts[w.stage] ?? 0) + 1;
    }
    if (counts.isEmpty) return 1;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
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

  String get nextSentence {
    if (nextIsWarmUp) return 'Next: a short warm-up of 10 words.';
    final returning = nextWords.where((w) => progress.retryDue.containsKey(w.id)).length;
    final parts = ['words with ${_stageLabel(currentStage)}'];
    if (returning > 0) parts.add('another go at $returning word${returning == 1 ? '' : 's'} they missed');
    return 'Next practice: ${parts.join(' and ')}.';
  }

  /// One tip for the most common mistake habit.
  List<String> get tips {
    final h = habits;
    if (h.isEmpty) return const [];
    final tip = sinhalaHabitTips[h.first.type];
    return tip == null ? const [] : [tip];
  }
}
