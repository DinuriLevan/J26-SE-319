import 'dart:math' as math;

import '../data/skill_labels.dart';
import '../data/word_bank.dart';
import 'error_analyzer.dart';
import 'learner_model.dart';
import 'spelling_config.dart';

/// The words for one round and why they were chosen.
class RoundPlan {
  const RoundPlan({
    required this.words,
    required this.focusSkill,
    required this.reason,
    required this.kind,
    this.errorFocus,
    this.stretchSkill,
    this.returnedWordIds = const [],
  });

  final List<WordEntry> words;
  final String? focusSkill;

  /// Plain-English explanation, saved with each round.
  final String reason;

  /// "placement", "adaptive" or "fixed".
  final String kind;

  /// Error type the 2 extra words target (e.g. "reversal"), if any.
  final String? errorFocus;

  /// Skill of the 2 "stretch" words, if any.
  final String? stretchSkill;

  /// Earlier misses brought back in this round.
  final List<String> returnedWordIds;

  bool get isPlacement => kind == 'placement';

  /// One sentence for the teacher view.
  String get teacherSentence {
    if (isPlacement) return 'Next: a short warm-up of 10 words to find the right starting level.';
    if (kind == 'fixed') {
      final stages = words.map((w) => w.stage).where((s) => s > 0).toList();
      final stage = stages.isEmpty ? 0 : stages.first;
      return 'Next practice: the next 10 words in the set order (${stageNames[stage]}).';
    }
    final parts = <String>[];
    if (focusSkill != null) parts.add('more ${skillLabel(focusSkill!).short} words');
    if (errorFocus != null) {
      parts.add(switch (errorFocus) {
        ErrorType.reversal => 'a few b/d words',
        ErrorType.omission => 'a few longer words to practise hearing every sound',
        ErrorType.vowelSub => 'a few short-vowel words',
        _ => 'a few words for their mistake habit',
      });
    } else if (stretchSkill != null) {
      parts.add('a first look at ${skillLabel(stretchSkill!).short} words');
    }
    if (returnedWordIds.isNotEmpty) parts.add('another go at words they missed');
    if (parts.length > 1) parts[parts.length - 1] = 'and ${parts.last}';
    return 'Next practice: ${parts.join(parts.length > 2 ? ', ' : ' ')}.';
  }

  Map<String, Object?> toJson() => {
        'wordIds': words.map((w) => w.id).toList(),
        'focusSkill': focusSkill,
        'reason': reason,
        'kind': kind,
        'errorFocus': errorFocus,
        'stretchSkill': stretchSkill,
        'returnedWordIds': returnedWordIds,
      };

  /// Null if a word id is no longer in the bank.
  static RoundPlan? fromJson(Map<String, Object?> j, WordBank bank) {
    final words = <WordEntry>[];
    for (final id in (j['wordIds'] as List).cast<String>()) {
      final w = bank.byId[id];
      if (w == null) return null;
      words.add(w);
    }
    return RoundPlan(
      words: words,
      focusSkill: j['focusSkill'] as String?,
      reason: j['reason'] as String,
      kind: j['kind'] as String,
      errorFocus: j['errorFocus'] as String?,
      stretchSkill: j['stretchSkill'] as String?,
      returnedWordIds: ((j['returnedWordIds'] as List?) ?? const []).cast<String>(),
    );
  }
}

String _pct(double p) => '${(p * 100).round()}%';

/// Classifier label → focus-word difficulty (word bank difficulty 1–3).
const difficultyForLabel = {'hard': 1, 'medium': 2, 'easy': 3};

/// Chooses rounds: placement, ZPDES-style Thompson-sampling bandit, or the
/// fixed-sequence baseline.
class Selector {
  Selector(this.bank, {math.Random? random}) : _random = random ?? math.Random();

  final WordBank bank;
  final math.Random _random;

  RoundPlan placement() => RoundPlan(
        words: bank.placementWords.take(SpellingConfig.roundSize).toList(),
        focusSkill: null,
        reason: 'Warm-up round: one word from each stage, to find where to start.',
        kind: 'placement',
      );

  /// [useClassifier]: the difficulty classifier decides how hard the focus
  /// words are (else the BKT estimate alone, the old rule).
  RoundPlan next(ChildModel child, {bool useClassifier = true}) {
    if (!child.placementDone) return placement();
    return child.group == SpellingMode.fixed ? fixed(child) : adaptive(child, useClassifier: useClassifier);
  }

  // ------------------------------------------------------------------ fixed

  /// Same sequence for every child: stages 1→8 (then sight words), each by
  /// difficulty. Ignores the model.
  List<WordEntry> get fixedSequence {
    int stageKey(int s) => s == 0 ? 99 : s;
    return bank.entries.where((e) => !e.isPlacement).toList()
      ..sort((a, b) {
        final s = stageKey(a.stage).compareTo(stageKey(b.stage));
        if (s != 0) return s;
        final d = a.difficulty.compareTo(b.difficulty);
        return d != 0 ? d : a.id.compareTo(b.id);
      });
  }

  RoundPlan fixed(ChildModel child) {
    final seq = fixedSequence;
    final start = child.fixedCursor % seq.length;
    final words = [for (var i = 0; i < SpellingConfig.roundSize; i++) seq[(start + i) % seq.length]];
    return RoundPlan(
      words: words,
      focusSkill: null,
      reason: 'Fixed group: words ${start + 1}–${start + words.length} of the same '
          '${seq.length}-word list that every fixed-group child gets. The model still updates, '
          'but it does not choose the words.',
      kind: 'fixed',
    );
  }

  // --------------------------------------------------------------- adaptive

  /// Skills the bandit may focus on: unlocked and not truly mastered, and
  /// either in the learning zone (P ≥ 0.3) or already tested (so skills the
  /// child failed are still practised rather than skipped).
  List<String> candidates(ChildModel child) => [
        for (final skill in bank.skillOrder)
          if (_isCandidate(child, skill)) skill,
      ];

  bool _isCandidate(ChildModel child, String skill) {
    final s = child.skills[skill]!;
    return s.unlocked && !child.isMastered(skill) && (s.pL >= SpellingConfig.candidateMin || s.tested);
  }

  /// The active window the bandit samples from. Remediation first: if the
  /// child has tested skills they are struggling with (P < 0.45), only those
  /// are in the window — except a skill that was already the focus for the
  /// last [SpellingConfig.maxFocusStreak] rounds gets a break. Otherwise the
  /// window is the first [SpellingConfig.zpdWindow] candidates in stage order.
  List<String> window(ChildModel child) {
    final all = candidates(child);
    final recentFocus = child.rounds.reversed.take(SpellingConfig.maxFocusStreak).map((r) => r.focusSkill).toList();
    bool onStreak(String s) =>
        recentFocus.length == SpellingConfig.maxFocusStreak && recentFocus.every((f) => f == s);
    bool struggling(String s) => child.skills[s]!.tested && child.skills[s]!.pL < SpellingConfig.weakBelow;
    final weak = all.where((s) => struggling(s) && !onStreak(s)).toList()
      ..sort((a, b) => child.skills[a]!.pL.compareTo(child.skills[b]!.pL));
    if (weak.isNotEmpty) return weak.take(SpellingConfig.zpdWindow).toList();
    return all.where((s) => !onStreak(s) || all.length == 1).take(SpellingConfig.zpdWindow).toList();
  }

  /// BKT decides WHICH skill to focus on; the difficulty classifier (when
  /// [useClassifier]) decides HOW HARD the focus words are: predicted hard →
  /// difficulty 1, medium → 2, easy → 3, averaged over the last 3
  /// predictions so it doesn't jump around.
  RoundPlan adaptive(ChildModel child, {bool useClassifier = true}) {
    final notes = <String>[];
    var pool = window(child);
    if (pool.isEmpty) {
      final opened = LearnerModel.unlockNext(child, bank);
      if (opened != null) {
        notes.add('Opened a new sound, ${skillLabel(opened).name}, because nothing else was left to practise.');
      }
      pool = window(child);
    }

    // Thompson sampling: highest Beta(α, β) draw wins.
    String focus;
    if (pool.isEmpty) {
      focus = child.skills.entries
          .where((e) => e.value.unlocked)
          .reduce((a, b) => b.value.pL < a.value.pL ? b : a)
          .key;
    } else {
      focus = pool.first;
      var best = -1.0;
      for (final skill in pool) {
        final s = child.skills[skill]!;
        final draw = sampleBeta(s.alpha, s.beta);
        if (draw > best) {
          best = draw;
          focus = skill;
        }
      }
    }
    final p = child.skills[focus]!.pL;
    final bktDifficulty = p < SpellingConfig.weakBelow ? 1 : (p < 0.7 ? 2 : 3);
    final prediction = useClassifier ? child.averagePrediction(focus) : null;
    final focusDifficulty = prediction == null ? bktDifficulty : difficultyForLabel[prediction.label]!;

    final roundNo = child.nextRoundNo;
    final recent = child.recentWordIds;
    final chosen = <WordEntry>[];
    bool allowed(WordEntry w, {bool ignoreRecent = false}) =>
        !chosen.any((c) => c.id == w.id) && (ignoreRecent || !recent.contains(w.id));

    // Failed words come back once, two rounds later.
    final due = [
      for (final e in child.failedDue.entries)
        if (e.value <= roundNo && !child.failedReturned.contains(e.key) && bank.byId[e.key] != null)
          bank.byId[e.key]!,
    ].take(2).toList();
    chosen.addAll(due);

    // 6 focus words (fewer if failed words took their place).
    final focusCount = math.max(0, 6 - due.length);
    chosen.addAll(_pick(focusCount, (w) => w.phonicsSkill == focus, focusDifficulty, allowed));
    final level = const {1: 'easy', 2: 'medium', 3: 'harder'}[focusDifficulty];
    final others = pool.where((s) => s != focus).map((s) => skillLabel(s).short).toList();
    final n = child.predictions[focus]?.length ?? 0;
    final levelReason = prediction != null
        ? 'The difficulty classifier says this sound is currently ${prediction.label} for the child '
            '(${_pct(prediction.confidence)} sure, average of the last $n word${n == 1 ? '' : 's'}'
            '${prediction.source == 'fallback' ? ', from the fallback rule' : ''}), so it chose $level words '
            '(BKT ${p.toStringAsFixed(2)}; classifier: ${prediction.label} (${prediction.confidence.toStringAsFixed(2)}) '
            '→ difficulty $focusDifficulty).'
        : useClassifier
            ? 'No classifier prediction for it yet, so the know-it chance chose $level words.'
            : 'Classifier switched off: the know-it chance alone chose $level words.';
    final focusNote = 'Main practice: ${skillLabel(focus).full}. The model estimates a ${_pct(p)} chance '
        'the child already knows it. $levelReason '
        '${others.isEmpty ? 'It was the only sound being worked on.' : 'It was picked by a weighted lucky draw '
            'among the sounds being worked on (also ${others.join(', ')}); sounds where the child has been '
            'improving get picked more often.'}';
    if (due.isNotEmpty) {
      notes.add('${due.length} word${due.length > 1 ? 's' : ''} missed 2 rounds ago came back for another try: '
          '${due.map((w) => w.word).join(', ')}.');
    }

    // 2 review words: first from skills BKT calls mastered but the classifier
    // keeps finding hard (not shown as mastered yet), else from mastered skills.
    final held = [
      for (final skill in bank.skillOrder)
        if (child.skills[skill]!.masteryHeld) skill,
    ];
    final mastered = [
      for (final skill in bank.skillOrder)
        if (child.isMastered(skill)) skill,
    ];
    if (held.isNotEmpty) {
      chosen.addAll(_pick(2, (w) => w.phonicsSkill == held.first, 1, allowed));
      notes.add('2 review words of ${skillLabel(held.first).name}: the know-it chance says mastered, but the '
          'classifier found it hard twice in a row, so it is not called mastered yet.');
    } else if (mastered.isNotEmpty) {
      chosen.addAll(_pick(2, (w) => mastered.contains(w.phonicsSkill), 1, allowed, shuffle: true));
      notes.add('2 review words from sounds already mastered, so they are not forgotten.');
    } else {
      chosen.addAll(_pick(2, (w) => w.phonicsSkill == focus, 1, allowed));
      notes.add('2 extra easy ${skillLabel(focus).short} words (nothing is mastered yet to review).');
    }

    // 2 error-focus words, or 2 stretch words.
    final topError = child.topErrorType;
    final topRate = topError == null ? 0.0 : child.errorRates[topError]!;
    bool unlocked(WordEntry w) => child.skills[w.phonicsSkill]?.unlocked ?? false;
    bool Function(WordEntry)? errorPool;
    String? errorLabel;
    if (topError != null && topRate > SpellingConfig.errorFocusThreshold) {
      switch (topError) {
        case ErrorType.reversal:
          errorPool = (w) => w.confusableLetters.isNotEmpty && unlocked(w);
          errorLabel = 'b/d words';
        case ErrorType.omission:
          errorPool = (w) =>
              unlocked(w) && (w.phonicsSkill.startsWith('blend_') || w.spelling.length >= 5);
          errorLabel = 'blend or longer words';
        case ErrorType.vowelSub:
          errorPool = (w) => w.stage == 1;
          errorLabel = 'short-vowel words';
      }
    }
    String? errorFocus, stretchSkill;
    final before = chosen.length;
    if (errorPool != null) {
      chosen.addAll(_pick(2, errorPool, 1, allowed, shuffle: true));
      errorFocus = topError;
      notes.add('${chosen.length - before} $errorLabel, because "${errorNames[topError]}" happened in about '
          '${_pct(topRate)} of recent chances (recent words count more).');
    } else {
      stretchSkill = _nextSkillAfter(child, focus);
      if (stretchSkill != null) {
        final s = stretchSkill;
        chosen.addAll(_pick(2, (w) => w.phonicsSkill == s, 1, allowed));
        notes.add('2 "stretch" words from the next sound, ${skillLabel(s).full}, as a preview.');
      }
    }

    // Top up if the bank ran short anywhere.
    if (chosen.length < SpellingConfig.roundSize) {
      chosen.addAll(_pick(SpellingConfig.roundSize - chosen.length,
          (w) => child.skills[w.phonicsSkill]?.unlocked ?? false, focusDifficulty, allowed));
    }

    return RoundPlan(
      words: _order(chosen.take(SpellingConfig.roundSize).toList()),
      focusSkill: focus,
      reason: [...notes.where((n) => n.startsWith('Opened')), focusNote, ...notes.where((n) => !n.startsWith('Opened'))]
          .join(' '),
      kind: 'adaptive',
      errorFocus: errorFocus,
      stretchSkill: stretchSkill,
      returnedWordIds: due.map((w) => w.id).toList(),
    );
  }

  /// Picks [n] words matching [where], closest to [difficulty] first. Falls
  /// back to recently played words only if the pool is too small.
  List<WordEntry> _pick(
    int n,
    bool Function(WordEntry) where,
    int difficulty,
    bool Function(WordEntry, {bool ignoreRecent}) allowed, {
    bool shuffle = false,
  }) {
    if (n <= 0) return [];
    List<WordEntry> poolOf({required bool ignoreRecent}) {
      final pool = bank.entries.where((w) => where(w) && allowed(w, ignoreRecent: ignoreRecent)).toList()
        ..shuffle(_random);
      if (!shuffle) {
        pool.sort((a, b) => (a.difficulty - difficulty).abs().compareTo((b.difficulty - difficulty).abs()));
      }
      return pool;
    }

    final picked = poolOf(ignoreRecent: false).take(n).toList();
    if (picked.length < n) {
      for (final w in poolOf(ignoreRecent: true)) {
        if (picked.length >= n) break;
        if (!picked.any((p) => p.id == w.id)) picked.add(w);
      }
    }
    return picked;
  }

  /// The first locked skill in stage order, else the skill after [focus].
  String? _nextSkillAfter(ChildModel child, String focus) {
    for (final skill in bank.skillOrder) {
      if (!child.skills[skill]!.unlocked) return skill;
    }
    final i = bank.skillOrder.indexOf(focus);
    return i >= 0 && i + 1 < bank.skillOrder.length ? bank.skillOrder[i + 1] : null;
  }

  /// Easiest word first, second-easiest last, the rest shuffled between.
  List<WordEntry> _order(List<WordEntry> words) {
    if (words.length < 3) return words;
    final sorted = [...words]..shuffle(_random);
    sorted.sort((a, b) => a.difficulty.compareTo(b.difficulty));
    final first = sorted.removeAt(0);
    final last = sorted.removeAt(0);
    sorted.shuffle(_random);
    return [first, ...sorted, last];
  }

  // ------------------------------------------------------- Beta sampling

  double sampleBeta(double a, double b) {
    final x = _sampleGamma(a), y = _sampleGamma(b);
    return x / (x + y);
  }

  /// Marsaglia–Tsang gamma sampler (shape k > 0, scale 1).
  double _sampleGamma(double k) {
    if (k < 1) return _sampleGamma(k + 1) * math.pow(_random.nextDouble(), 1 / k);
    final d = k - 1 / 3, c = 1 / math.sqrt(9 * d);
    while (true) {
      double x, v;
      do {
        x = _normal();
        v = 1 + c * x;
      } while (v <= 0);
      v = v * v * v;
      final u = _random.nextDouble();
      if (u < 1 - 0.0331 * x * x * x * x) return d * v;
      if (math.log(u) < 0.5 * x * x + d * (1 - v + math.log(v))) return d * v;
    }
  }

  double _normal() {
    final u1 = 1 - _random.nextDouble(), u2 = _random.nextDouble();
    return math.sqrt(-2 * math.log(u1)) * math.cos(2 * math.pi * u2);
  }
}
