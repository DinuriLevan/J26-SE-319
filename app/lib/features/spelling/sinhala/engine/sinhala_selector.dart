import '../../model/difficulty_prediction.dart';
import '../data/akshara.dart';
import '../data/sinhala_progress.dart';
import '../data/sinhala_word_bank.dart';
import 'sinhala_errors.dart';
import 'sinhala_learner.dart';

/// The next round's 10 words, and why (for the Teacher View).
class SinhalaPlan {
  SinhalaPlan({required this.words, required this.kind, required this.reason, this.focusSkill});

  final List<SinhalaWord> words;

  /// "warmup" or "adaptive".
  final String kind;
  final String? focusSkill;
  final String reason;
}

/// Chooses the next words (FR6). BKT says WHICH stage to practise (the
/// weakest one the child may practise); the difficulty classifier says HOW
/// HARD the words should be (average of its last 3 predictions for that
/// stage: hard → difficulty 1, medium → 2, easy → 3). Added to that:
/// 2 words for the child's top mistake habit, 1 review word, 1 word of the
/// next stage once the focus stage is going well, and up to 2 words whose
/// answer was shown two rounds ago.
class SinhalaSelector {
  const SinhalaSelector._();

  static const roundSize = 10;
  static const focusWords = 6;
  static const habitWords = 2;
  static const maxReturning = 2;

  static const levelForLabel = {'hard': 1, 'medium': 2, 'easy': 3};
  static const levelNames = {1: 'easy', 2: 'medium', 3: 'harder'};

  /// Plans (and does not change [p] except unlocking the stretch stage).
  static SinhalaPlan plan(SinhalaWordBank bank, SinhalaProgress p, {bool useClassifier = true}) {
    if (!p.warmUpDone && bank.placement.isNotEmpty) {
      return SinhalaPlan(
        words: bank.placement.take(roundSize).toList(),
        kind: 'warmup',
        reason: 'Next: a short warm-up of 10 words to find the right starting level.',
      );
    }
    final roundNo = p.nextRoundNo;
    final picked = <SinhalaWord>[];
    final timesSeen = <String, int>{};
    for (final r in p.results) {
      timesSeen[r.wordId] = (timesSeen[r.wordId] ?? 0) + 1;
    }
    final recent = {for (final r in p.results) if (r.roundNo >= roundNo - 2) r.wordId};

    bool fresh(SinhalaWord w) => !picked.contains(w) && !recent.contains(w.id);
    List<SinhalaWord> pool(bool Function(SinhalaWord) test) {
      final list = [for (final w in bank.practiceInOrder) if (test(w) && fresh(w)) w];
      // Least-practised words first, then the bank's order.
      list.sort((a, b) => (timesSeen[a.id] ?? 0).compareTo(timesSeen[b.id] ?? 0));
      return list;
    }

    // 1. Words whose answer was shown, now due again.
    final returning = [
      for (final e in p.retryDue.entries)
        if (e.value <= roundNo) bank.byId(e.key),
    ].whereType<SinhalaWord>().take(maxReturning).toList();
    picked.addAll(returning);

    // 2. Focus: the weakest stage the child may practise (not yet mastered).
    final skills = bank.skills;
    final open = [
      for (final k in skills)
        if (p.unlocked.contains(k.id) && !SinhalaLearner.isMastered(p, k.id) && _hasWords(bank, k.id)) k,
    ];
    SinhalaSkill? focus;
    var newStage = false;
    if (open.isNotEmpty) {
      open.sort((a, b) {
        final c = p.skill(a.id).pL.compareTo(p.skill(b.id).pL);
        return c != 0 ? c : a.stage.compareTo(b.stage);
      });
      focus = open.first;
    } else {
      focus = skills.where((k) => !p.unlocked.contains(k.id) && _hasWords(bank, k.id)).firstOrNull;
      newStage = focus != null;
      if (focus != null) p.unlocked.add(focus.id);
    }

    // 3. How hard: classifier (average of its last 3), else the BKT rule.
    var level = 2;
    var levelFrom = 'bkt';
    if (focus != null) {
      final preds = p.predictions[focus.id];
      if (useClassifier && preds != null && preds.isNotEmpty) {
        final avg = DifficultyPrediction.average(preds);
        level = levelForLabel[avg.label]!;
        levelFrom = avg.source == 'ml' ? 'model' : 'bkt';
      } else {
        final pl = p.skill(focus.id).pL;
        level = pl < SinhalaLearner.weakBelow ? 1 : (pl < 0.7 ? 2 : 3);
      }
      final words = pool((w) => w.skill == focus!.id)
        ..sort((a, b) => (a.difficulty - level).abs().compareTo((b.difficulty - level).abs()));
      picked.addAll(words.take(focusWords));
    }

    // 4. The top mistake habit: words that give the chance to practise it.
    final habit = SinhalaLearner.habits(p).firstOrNull;
    if (habit != null) {
      final test = _habitTest(habit);
      picked.addAll(pool((w) => p.unlocked.contains(w.skill) && test(w)).take(habitWords));
    }

    // 5. A first look at the next stage once the focus stage is going well.
    SinhalaSkill? stretch;
    if (focus != null && !newStage && p.skill(focus.id).pL >= 0.6) {
      stretch = skills.where((k) => !p.unlocked.contains(k.id) && _hasWords(bank, k.id)).firstOrNull;
      if (stretch != null) {
        p.unlocked.add(stretch.id);
        picked.addAll(pool((w) => w.skill == stretch!.id).take(1));
      }
    }

    // 6. One review word from another stage, then fill up with the focus stage.
    final others = [for (final k in skills) if (p.unlocked.contains(k.id) && k.id != focus?.id) k]
      ..sort((a, b) => p.skill(b.id).pL.compareTo(p.skill(a.id).pL));
    if (others.isNotEmpty) picked.addAll(pool((w) => w.skill == others.first.id).take(1));
    for (final test in <bool Function(SinhalaWord)>[
      (w) => w.skill == focus?.id,
      (w) => p.unlocked.contains(w.skill),
      (_) => true,
    ]) {
      if (picked.length >= roundSize) break;
      picked.addAll(pool(test).take(roundSize - picked.length));
    }
    // Words seen in the last rounds only if nothing else is left.
    for (final source in [bank.practiceInOrder, bank.words]) {
      if (picked.length >= roundSize) break;
      picked.addAll(source.where((w) => !picked.contains(w)).take(roundSize - picked.length));
    }

    return SinhalaPlan(
      words: picked.take(roundSize).toList(),
      kind: 'adaptive',
      focusSkill: focus?.id,
      reason: _reason(bank, p, focus, newStage, level, levelFrom, habit, stretch, returning.length),
    );
  }

  static bool _hasWords(SinhalaWordBank bank, String skill) =>
      bank.practiceInOrder.any((w) => w.skill == skill);

  static bool Function(SinhalaWord) _habitTest(String habit) => switch (habit) {
        SinhalaError.pillaLength => (w) => w.marks.any(SinhalaError.lengthPairs.containsKey),
        SinhalaError.hal => (w) => w.marks.contains(Akshara.hal),
        SinhalaError.lookalike =>
          (w) => w.letters.any((l) => SinhalaError.confusableGroups.any((g) => g.contains(l))),
        SinhalaError.pillaMissing || SinhalaError.pillaWrong => (w) => w.marks.length >= 2,
        _ => (w) => w.aksharas.length >= 4,
      };

  static const _habitPhrases = {
    SinhalaError.pillaMissing: 'words with several pillas (they often leave one out)',
    SinhalaError.pillaWrong: 'words with several pillas (they often pick the wrong one)',
    SinhalaError.pillaLength: 'words with long pillas (they mix up short and long)',
    SinhalaError.hal: 'words with the hal kirima',
    SinhalaError.lookalike: 'words with look-alike letters',
    SinhalaError.otherLetter: 'longer words to listen to carefully',
    SinhalaError.missing: 'longer words, to hear every akshara',
    SinhalaError.extra: 'longer words, to hear every akshara',
    SinhalaError.order: 'longer words, to hear the order',
  };

  static String _reason(
    SinhalaWordBank bank,
    SinhalaProgress p,
    SinhalaSkill? focus,
    bool newStage,
    int level,
    String levelFrom,
    String? habit,
    SinhalaSkill? stretch,
    int returning,
  ) {
    final parts = <String>[];
    if (focus != null) {
      final why = newStage
          ? 'a new stage'
          : (SinhalaLearner.isWeak(p, focus.id) ? 'needs more practice' : 'still practising');
      parts.add('more ${focus.label} words ($why) at the ${levelNames[level]} level');
    }
    if (habit != null) parts.add('a few ${_habitPhrases[habit]}');
    if (stretch != null) parts.add('a first look at ${stretch.label}');
    if (returning > 0) parts.add('another go at $returning word${returning == 1 ? '' : 's'} they missed');
    if (parts.isEmpty) return 'Next practice: a mix of words they know.';
    if (parts.length > 1) parts[parts.length - 1] = 'and ${parts.last}';
    final how = levelFrom == 'model' ? ' The level was chosen by the difficulty model.' : '';
    return 'Next practice: ${parts.join(parts.length > 2 ? ', ' : ' ')}.$how';
  }
}
