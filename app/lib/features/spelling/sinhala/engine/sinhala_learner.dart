import 'dart:math' as math;

import '../data/sinhala_progress.dart';
import '../data/sinhala_word_bank.dart';
import 'sinhala_errors.dart';

/// The Sinhala learner model: Bayesian Knowledge Tracing per skill (stage),
/// the same equations and settings as the English game (learner_model.dart)
/// and the Python simulator (ml/spelling/spell_common.py, si_* functions).
///
/// - After the warm-up (the first game), [applyPlacement] sets every stage's
///   starting estimate from the 10 warm-up words: weak areas are known from
///   the first game on.
/// - After every later word, [applyWord] updates that stage's estimate.
class SinhalaLearner {
  const SinhalaLearner._();

  static const pStart = 0.1;
  static const pLearn = 0.05;
  static const pSlip = 0.10;
  static const guessScale = 1.2;
  static const fluentHesitation = 1.2;
  static const wFluent = 1.0, wHesitant = 0.6, wSecondTry = 0.25, wThirdTry = 0.1;

  /// Mastered: at least 85% after at least 5 words in at least 2 rounds.
  static const masteredAt = 0.85;
  static const masteredMinSeen = 5;
  static const masteredMinRounds = 2;

  /// Needs help: below 45% once the skill has been tried.
  static const weakBelow = 0.45;

  /// Mistake habits: share of recent words with that mistake (newer count more).
  static const habitDecay = 0.8;
  static const habitThreshold = 0.3;

  static const defaultMedianMs = 3000.0;
  static const minWordsForMedian = 5;
  static const historyLength = 50;

  /// Guess chance by number of aksharas (more aksharas, less luck).
  static double pGuess(int aksharas) {
    final base = aksharas <= 2 ? 0.35 : (aksharas == 3 ? 0.25 : 0.15);
    return (base * guessScale).clamp(0.01, 0.9);
  }

  static double bayes(double p, bool correct, double guess) => correct
      ? p * (1 - pSlip) / (p * (1 - pSlip) + (1 - p) * guess)
      : p * pSlip / (p * pSlip + (1 - p) * (1 - guess));

  static double update(double p, double weight, int aksharas) {
    final g = pGuess(aksharas);
    final post = weight * bayes(p, true, g) + (1 - weight) * bayes(p, false, g);
    return post + (1 - post) * pLearn;
  }

  /// How much a word counts as "knows it": right first time and fluent = 1,
  /// right first time but hesitant or with many fixes = 0.6, right on the
  /// 2nd / 3rd try = 0.25 / 0.1, not solved = 0.
  static double evidenceWeight(Map<String, Object?> f) {
    if (f['correct_first_try'] == true) {
      final fluent = (f['hesitation_ratio']! as num) < fluentHesitation && (f['corrections']! as num) <= 1;
      return fluent ? wFluent : wHesitant;
    }
    if (f['final_correct'] != true) return 0;
    return (f['attempts']! as num) <= 2 ? wSecondTry : wThirdTry;
  }

  static double median(List<double> values) {
    if (values.length < minWordsForMedian) return defaultMedianMs;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    final m = sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
    return m > 0 ? m : defaultMedianMs;
  }

  static double medianFirstInput(SinhalaProgress p) => median(p.firstInputs);
  static double medianMaxGap(SinhalaProgress p) => median(p.maxGaps);

  /// Adds the word's timing to the child's history (after its features were
  /// worked out, so a word is compared with the child's earlier words only).
  static void recordTiming(SinhalaProgress p, double firstInputMs, double maxGapMs) {
    void push(List<double> list, double v) {
      list.add(v);
      if (list.length > historyLength) list.removeAt(0);
    }

    push(p.firstInputs, firstInputMs);
    push(p.maxGaps, maxGapMs);
  }

  /// Updates the word's skill (not during the warm-up, which is handled by
  /// [applyPlacement]) and the mistake-habit rates. Returns (before, after).
  static (double, double) applyWord(
    SinhalaProgress p,
    Map<String, Object?> f, {
    required int roundNo,
    required bool warmUp,
  }) {
    final s = p.skill(f['phonics_skill']! as String);
    final before = s.pL;
    s.seen++;
    if (f['correct_first_try'] == true) s.correct++;
    s.rounds.add(roundNo);
    if (!warmUp) s.pL = update(before, evidenceWeight(f), (f['n_aksharas'] as num?)?.toInt() ?? 3);
    for (final t in SinhalaError.all) {
      final hit = ((f[t] as num?) ?? 0) > 0 ? 1.0 : 0.0;
      p.errorRates[t] = (p.errorRates[t] ?? 0) * habitDecay + (1 - habitDecay) * hit;
    }
    return (before, s.pL);
  }

  /// After the warm-up: tried stages start at 60% (right first time), 40%
  /// (right later) or 15% (not solved). Untried stages below the first stage
  /// with a mistake start at 60%, that stage at 30%, later ones at 10%.
  /// The child may practise every stage up to the first one with a mistake
  /// (and the tried ones); later stages unlock as earlier ones improve.
  static void applyPlacement(SinhalaProgress p, List<Map<String, Object?>> warmUp, SinhalaWordBank bank) {
    if (warmUp.isEmpty) return;
    final tested = <String, double>{};
    int? errorStage;
    var maxTested = 0;
    for (final f in warmUp) {
      final skill = f['phonics_skill']! as String;
      final stage = (f['skill_stage']! as num).toInt();
      tested[skill] = f['correct_first_try'] == true ? 0.6 : (f['final_correct'] == true ? 0.4 : 0.15);
      if (f['correct_first_try'] != true && (errorStage == null || stage < errorStage)) errorStage = stage;
      maxTested = math.max(maxTested, stage);
    }
    for (final k in bank.skills) {
      final s = p.skill(k.id);
      bool unlocked;
      if (errorStage == null) {
        s.pL = tested[k.id] ?? (k.stage <= maxTested ? 0.6 : 0.3);
        unlocked = k.stage <= maxTested + 1;
      } else if (k.stage < errorStage) {
        s.pL = tested[k.id] ?? 0.6;
        unlocked = true;
      } else if (k.stage == errorStage) {
        s.pL = tested[k.id] ?? 0.3;
        unlocked = true;
      } else {
        s.pL = tested[k.id] ?? pStart;
        unlocked = tested.containsKey(k.id);
      }
      if (unlocked) p.unlocked.add(k.id);
    }
  }

  static bool bktMastered(SinhalaProgress p, String skill) {
    final s = p.skills[skill];
    return s != null && s.pL >= masteredAt && s.seen >= masteredMinSeen && s.rounds.length >= masteredMinRounds;
  }

  static bool isMastered(SinhalaProgress p, String skill) => bktMastered(p, skill) && !p.skill(skill).masteryHeld;

  /// A weak area: tried at least once and below 45%.
  static bool isWeak(SinhalaProgress p, String skill) {
    final s = p.skills[skill];
    return s != null && s.seen > 0 && s.pL < weakBelow;
  }

  /// Mistake habits (rate above 30%), most frequent first.
  static List<String> habits(SinhalaProgress p) => [
        for (final t in SinhalaError.all)
          if ((p.errorRates[t] ?? 0) > habitThreshold) t,
      ]..sort((a, b) => p.errorRates[b]!.compareTo(p.errorRates[a]!));
}
