/// Tunable constants for the learner model, features and selector.
///
/// The model defaults (pLearn, pSlip, guess chance, fluent hesitation) were
/// chosen with the simulated parameter sweep in engine/model_evaluation.dart.
class SpellingConfig {
  const SpellingConfig._();

  /// A tile removed within this many ms of being placed is a motor slip,
  /// not a real correction.
  static const double slipMs = 1000;

  // Bayesian Knowledge Tracing.
  static const double pLearn = 0.05;
  static const double pSlip = 0.10;

  /// Chance of a lucky right answer by word length. Drag-and-drop with only
  /// the word's letters plus 2 distractors makes guessing much easier than
  /// free spelling, especially for short words.
  static double pGuessForLength(int letters) => letters <= 3 ? 0.35 : (letters == 4 ? 0.25 : 0.15);

  /// Multiplier on [pGuessForLength] (sweep winner: 0.42 / 0.30 / 0.18).
  static const double pGuessScale = 1.2;

  /// A correct first try counts as full evidence only when the child started
  /// within this × their usual time (and made ≤ 1 correction).
  static const double fluentHesitation = 1.2;

  // Evidence weights with "use behaviour" on (1 = counts as fully right).
  static const double wFluent = 1.0;
  static const double wHesitant = 0.6;

  /// Right on the 2nd / 3rd try. Kept low: a right answer after a mistake
  /// mostly shows the skill is *not* secure yet (0.6 / 0.4 made weak skills
  /// rise and hid them — see engine/model_evaluation.dart).
  static const double wSecondTry = 0.25;
  static const double wThirdTry = 0.1;

  /// First mistake was outside the target sound (e.g. a b/d flip in a
  /// short-vowel word).
  static const double wOffTargetSolved = 0.6;
  static const double wOffTargetFailed = 0.3;

  static const int roundSize = 10;
  static const int roundsPerSession = 3;
  static const int maxAttempts = 3;

  /// Default for the running medians until a child has [minWordsForMedian] words.
  static const double defaultMedianMs = 3000;
  static const int minWordsForMedian = 5;
  static const int medianWindow = 50;

  // Mastery labels and selector bounds.
  static const double mastered = 0.85;
  static const int masteredMinSeen = 5;
  static const int masteredMinRounds = 2;
  static const double weakBelow = 0.45;
  static const int weakMinSeen = 3;
  static const double candidateMin = 0.3;
  static const double unlockAt = 0.6;

  /// ZPDES-style active window: Thompson sampling only chooses among this
  /// many candidate skills (struggling tested skills first, then stage order).
  static const int zpdWindow = 4;

  /// The same skill is the focus at most this many rounds in a row.
  static const int maxFocusStreak = 2;

  // Error-pattern tracker.
  static const double errorDecay = 0.9;
  static const double errorFocusThreshold = 0.3;

  /// Rounds a word is kept out after being played; failed words return once
  /// after [failedReturnAfter] rounds.
  static const int noRepeatRounds = 3;
  static const int failedReturnAfter = 2;

  // Teacher view.
  static const int habitMinCount = 3;
  static const double slowStartRatio = 1.5;
  static const double improvingRise = 0.15;
}

/// The model's tunable numbers, so the simulator can try other values.
class ModelParams {
  const ModelParams({
    this.pLearn = SpellingConfig.pLearn,
    this.pSlip = SpellingConfig.pSlip,
    this.pGuessScale = SpellingConfig.pGuessScale,
    this.fluentHesitation = SpellingConfig.fluentHesitation,
  });

  final double pLearn;
  final double pSlip;

  /// Multiplies [SpellingConfig.pGuessForLength].
  final double pGuessScale;
  final double fluentHesitation;

  double pGuess(int letters) => (SpellingConfig.pGuessForLength(letters) * pGuessScale).clamp(0.01, 0.9);

  String get label => 'learn ${pLearn.toStringAsFixed(2)} · guess ×${pGuessScale.toStringAsFixed(1)}'
      ' · fluent < ${fluentHesitation.toStringAsFixed(1)}×';

  Map<String, Object?> toJson() => {
        'pLearn': pLearn,
        'pSlip': pSlip,
        'pGuessScale': pGuessScale,
        'fluentHesitation': fluentHesitation,
      };
}

/// Experiment group: adaptive word choice or the fixed-sequence baseline.
enum SpellingMode { adaptive, fixed }

/// Which group a newly created child joins.
enum NewChildGroup { adaptive, fixed, alternate }

/// Research settings (persisted).
class SpellingSettings {
  SpellingSettings({
    this.useBehaviour = true,
    this.newChildGroup = NewChildGroup.adaptive,
    this.useClassifier = true,
  });

  /// false = the model only uses right/wrong on the first try, for comparison.
  bool useBehaviour;
  NewChildGroup newChildGroup;

  /// true = the trained difficulty classifier sets how hard the focus words
  /// are; false = the old rule (the BKT estimate alone), for comparison.
  bool useClassifier;

  Map<String, Object?> toJson() =>
      {'useBehaviour': useBehaviour, 'newChildGroup': newChildGroup.name, 'useClassifier': useClassifier};

  factory SpellingSettings.fromJson(Map<String, Object?> json) => SpellingSettings(
        useBehaviour: json['useBehaviour'] as bool? ?? true,
        newChildGroup: NewChildGroup.values.firstWhere(
          (g) => g.name == json['newChildGroup'],
          orElse: () => NewChildGroup.adaptive,
        ),
        useClassifier: json['useClassifier'] as bool? ?? true,
      );
}
