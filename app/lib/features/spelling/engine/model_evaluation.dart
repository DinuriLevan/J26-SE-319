import '../data/word_bank.dart';
import 'simulator.dart';
import 'spelling_config.dart';

/// Precision / recall / F1 counts, summed over many simulated children.
class Prf {
  int tp = 0, fp = 0, fn = 0;

  void add(Set<String> detected, Set<String> truth) {
    tp += detected.intersection(truth).length;
    fp += detected.difference(truth).length;
    fn += truth.difference(detected).length;
  }

  /// Null when the model flagged nothing.
  double? get precision => tp + fp == 0 ? null : tp / (tp + fp);

  /// Null when there was nothing to find (strong child).
  double? get recall => tp + fn == 0 ? null : tp / (tp + fn);

  double? get f1 {
    final p = precision, r = recall;
    if (p == null && r == null) return null;
    if ((p ?? 0) + (r ?? 0) == 0) return 0;
    if (p == null || r == null) return 0;
    return 2 * p * r / (p + r);
  }
}

/// Results for one preset × behaviour setting × parameter set.
class EvalSummary {
  EvalSummary({
    required this.preset,
    required this.useBehaviour,
    required this.params,
    required this.children,
    required this.detection,
    required this.roundsToFocus,
    required this.falseMastered,
    required this.weakTotal,
  });

  final String preset;
  final bool useBehaviour;
  final ModelParams params;
  final int children;

  /// Round number (2, 4, 6) → weak-skill detection.
  final Map<int, Prf> detection;

  /// Per child: first round whose focus was a truly weak skill (null = never).
  final List<int?> roundsToFocus;

  /// Truly weak skills labelled "mastered" at the end, out of [weakTotal].
  final int falseMastered;
  final int weakTotal;

  double? get falseMasteredRate => weakTotal == 0 ? null : falseMastered / weakTotal;

  double? get meanRoundsToFocus {
    final hit = roundsToFocus.whereType<int>().toList();
    return hit.isEmpty ? null : hit.reduce((a, b) => a + b) / hit.length;
  }

  /// Share of children whose weak skill became the focus within the run.
  double? get focusedShare =>
      roundsToFocus.isEmpty ? null : roundsToFocus.whereType<int>().length / roundsToFocus.length;
}

/// One row of the parameter sweep (all presets together, behaviour ON).
class SweepResult {
  SweepResult(this.params, this.f1, this.falseMasteredRate);

  final ModelParams params;

  /// F1 of weak-skill detection after the last round, all presets pooled.
  final double f1;
  final double falseMasteredRate;

  double get score => f1 - falseMasteredRate;
}

/// Runs many simulated children to measure the model against the hidden
/// truth. Heavy: run it off the UI thread (Isolate.run).
class ModelEvaluation {
  ModelEvaluation(this.bank);

  final WordBank bank;

  static const checkpoints = [2, 4, 6];

  Future<EvalSummary> runPreset(
    SimulatedChildProfile profile, {
    required bool useBehaviour,
    ModelParams params = const ModelParams(),
    int children = 50,
    int rounds = 6,
    int seed = 1000,
  }) async {
    final detection = {for (final c in checkpoints) c: Prf()};
    final toFocus = <int?>[];
    var falseMastered = 0, weakTotal = 0;
    final initiallyWeak = profile.weakSkills.keys.toSet();

    for (var i = 0; i < children; i++) {
      final result = await ChildSimulator(bank, seed: seed + i).run(
        profile,
        rounds: rounds,
        settings: SpellingSettings(useBehaviour: useBehaviour),
        params: params,
      );
      for (final r in result.rounds) {
        detection[r.roundNo]?.add(r.detectedWeak, r.trulyWeak);
      }
      if (initiallyWeak.isNotEmpty) {
        toFocus.add(result.rounds.where((r) => initiallyWeak.contains(r.focusSkill)).firstOrNull?.roundNo);
      }
      final last = result.rounds.last;
      weakTotal += last.trulyWeak.length;
      falseMastered += last.mastered.intersection(last.trulyWeak).length;
    }
    return EvalSummary(
      preset: profile.name,
      useBehaviour: useBehaviour,
      params: params,
      children: children,
      detection: detection,
      roundsToFocus: toFocus,
      falseMastered: falseMastered,
      weakTotal: weakTotal,
    );
  }

  /// Every preset with behaviour ON and OFF.
  Future<List<EvalSummary>> compareBehaviour({int children = 50, ModelParams params = const ModelParams()}) async => [
        for (final p in SimulatedChildProfile.presets)
          for (final on in [true, false])
            await runPreset(p, useBehaviour: on, params: params, children: children),
      ];

  static const sweepPLearn = [0.05, 0.10, 0.15];
  static const sweepGuessScale = [0.8, 1.0, 1.2];
  static const sweepFluent = [1.2, 1.5];

  /// Small grid over pLearn × guess scale × fluent-hesitation threshold.
  Future<List<SweepResult>> sweep({int children = 20}) async {
    final out = <SweepResult>[];
    for (final pl in sweepPLearn) {
      for (final gs in sweepGuessScale) {
        for (final fh in sweepFluent) {
          final params = ModelParams(pLearn: pl, pGuessScale: gs, fluentHesitation: fh);
          final pooled = Prf();
          var fm = 0, weak = 0;
          for (final p in SimulatedChildProfile.presets) {
            final s = await runPreset(p, useBehaviour: true, params: params, children: children);
            final d = s.detection[checkpoints.last]!;
            pooled
              ..tp += d.tp
              ..fp += d.fp
              ..fn += d.fn;
            fm += s.falseMastered;
            weak += s.weakTotal;
          }
          out.add(SweepResult(params, pooled.f1 ?? 0, weak == 0 ? 0 : fm / weak));
        }
      }
    }
    return out..sort((a, b) => b.score.compareTo(a.score));
  }

  static String _f(double? v) => v == null ? '' : v.toStringAsFixed(3);

  static String toCsv(List<EvalSummary> results, List<SweepResult> sweep) {
    final lines = <String>[
      [
        'table', 'preset', 'use_behaviour', 'p_learn', 'guess_scale', 'fluent_hesitation', 'children',
        for (final c in checkpoints) ...['precision_r$c', 'recall_r$c', 'f1_r$c'],
        'mean_rounds_to_focus', 'share_focused', 'false_mastered_rate', 'f1_final', 'score',
      ].join(','),
      for (final r in results)
        [
          'behaviour', '"${r.preset.replaceAll('"', '""')}"', r.useBehaviour, r.params.pLearn,
          r.params.pGuessScale, r.params.fluentHesitation, r.children,
          for (final c in checkpoints) ...[
            _f(r.detection[c]!.precision), _f(r.detection[c]!.recall), _f(r.detection[c]!.f1),
          ],
          _f(r.meanRoundsToFocus), _f(r.focusedShare), _f(r.falseMasteredRate), '', '',
        ].join(','),
      for (final s in sweep)
        [
          'sweep', 'all presets', true, s.params.pLearn, s.params.pGuessScale, s.params.fluentHesitation, '',
          for (final _ in checkpoints) ...['', '', ''],
          '', '', _f(s.falseMasteredRate), _f(s.f1), _f(s.score),
        ].join(','),
    ];
    return '${lines.join('\n')}\n';
  }
}
