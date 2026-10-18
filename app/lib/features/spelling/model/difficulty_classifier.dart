import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../engine/feature_extractor.dart';
import '../engine/spelling_config.dart';
import 'difficulty_model_m2cgen.dart';
import 'difficulty_prediction.dart';

/// Predicts how hard a word's skill currently is for the child (FR4).
///
/// Three parts work together: BKT keeps the learner profile (which skills
/// are known), this classifier says how hard the focus skill is right now,
/// and the selector uses both to choose the next words.
abstract class DifficultyClassifier {
  /// Never throws: on any problem it answers with the fallback rule.
  DifficultyPrediction predict(FeatureRow row);
}

/// The old rule, from the BKT estimate after the word: below 45% → hard,
/// below 70% → medium, else easy. Used when the model is missing or fails.
class FallbackDifficultyClassifier implements DifficultyClassifier {
  const FallbackDifficultyClassifier();

  static String labelFor(double pL) => pL < SpellingConfig.weakBelow ? 'hard' : (pL < 0.7 ? 'medium' : 'easy');

  @override
  DifficultyPrediction predict(FeatureRow row) {
    final p = (row.values['p_after'] ?? row.values['p_before']) as num?;
    final label = labelFor(p?.toDouble() ?? 0.1);
    return DifficultyPrediction(
      label: label,
      probs: {for (final c in DifficultyPrediction.classes) c: c == label ? 1.0 : 0.0},
      source: 'fallback',
      at: DateTime.now(),
    );
  }
}

/// How to turn a feature row into the model's input vector. Read from
/// assets/spelling/model/preprocessing.json, written by
/// ml/spelling/spell_export.py — the same recipes the Python training used.
class ModelSpec {
  ModelSpec({
    required this.recipes,
    required this.classes,
    required this.output,
    this.mean,
    this.std,
    this.model = '',
    this.featureSet = '',
  });

  final List<Map<String, Object?>> recipes;
  final List<String> classes;

  /// "probabilities", or "logits" (softmax is applied here).
  final String output;
  final List<double>? mean;
  final List<double>? std;
  final String model;
  final String featureSet;

  factory ModelSpec.fromJson(Map<String, Object?> j, List<String> featureOrder) {
    final recipes = (j['recipes']! as List).map((r) => (r as Map).cast<String, Object?>()).toList();
    final names = recipes.map((r) => r['name']).toList();
    if (names.length != featureOrder.length || [for (var i = 0; i < names.length; i++) names[i] == featureOrder[i]].contains(false)) {
      throw const FormatException('feature_order.json does not match the preprocessing recipes');
    }
    final scale = j['scale'] as Map?;
    List<double>? nums(Object? v) => (v as List?)?.map((x) => (x as num).toDouble()).toList();
    return ModelSpec(
      recipes: recipes,
      classes: (j['classes']! as List).cast<String>(),
      output: j['output']! as String,
      mean: nums(scale?['mean']),
      std: nums(scale?['std']),
      model: j['model'] as String? ?? '',
      featureSet: j['feature_set'] as String? ?? '',
    );
  }

  static bool _isTrue(Object? v) => v == true || '$v'.trim().toLowerCase() == 'true';

  /// Same rules as spell_features.py.
  List<double> vector(Map<String, Object?> values) {
    final out = <double>[];
    for (final r in recipes) {
      final v = values[r['source']];
      final kind = r['kind'];
      double x;
      switch (kind) {
        case 'bool':
          x = _isTrue(v) ? 1 : 0;
        case 'onehot':
          x = v == r['value'] ? 1 : 0;
        case 'length':
          x = '${v ?? ''}'.length.toDouble();
        case 'has_bdpq':
          x = '${v ?? ''}'.toLowerCase().split('').any('bdpq'.contains) ? 1 : 0;
        default:
          final number = v is num ? v.toDouble() : (v is bool ? (v ? 1.0 : 0.0) : double.tryParse('${v ?? ''}'));
          x = (number == null || number.isNaN) ? (r['default'] as num? ?? 0).toDouble() : number;
          if (kind == 'log1p') {
            x = math.log(1 + math.max(0, x));
          } else if (r['clip'] case final List clip) {
            x = x.clamp((clip[0] as num).toDouble(), (clip[1] as num).toDouble());
          }
      }
      out.add(x);
    }
    if (mean != null && std != null) {
      for (var i = 0; i < out.length; i++) {
        out[i] = (out[i] - mean![i]) / (std![i] == 0 ? 1 : std![i]);
      }
    }
    return out;
  }

  Map<String, double> probabilities(List<double> raw) {
    var p = raw;
    if (output == 'logits') {
      final top = raw.reduce(math.max);
      final e = raw.map((v) => math.exp(v - top)).toList();
      final sum = e.reduce((a, b) => a + b);
      p = e.map((v) => v / sum).toList();
    }
    return {for (var i = 0; i < classes.length; i++) classes[i]: p[i]};
  }
}

/// The trained classifier (exported from Python to plain Dart, offline).
class MlDifficultyClassifier implements DifficultyClassifier {
  MlDifficultyClassifier(
    this.spec, {
    List<double> Function(List<double>)? score,
    this.fallback = const FallbackDifficultyClassifier(),
  }) : _score = score ?? difficultyModelScore;

  static const assetDir = 'assets/spelling/model';

  final ModelSpec spec;
  final DifficultyClassifier fallback;
  final List<double> Function(List<double>) _score;

  /// Loads the model's JSON files; returns the fallback if they are missing
  /// or don't match.
  static Future<DifficultyClassifier> load({AssetBundle? bundle}) async {
    final b = bundle ?? rootBundle;
    try {
      final pre = jsonDecode(await b.loadString('$assetDir/preprocessing.json')) as Map<String, Object?>;
      final order = (jsonDecode(await b.loadString('$assetDir/feature_order.json')) as List).cast<String>();
      return MlDifficultyClassifier(ModelSpec.fromJson(pre, order));
    } catch (_) {
      return const FallbackDifficultyClassifier();
    }
  }

  @override
  DifficultyPrediction predict(FeatureRow row) {
    try {
      final probs = spec.probabilities(_score(spec.vector(row.values)));
      if (probs.values.any((p) => p.isNaN)) throw StateError('NaN probability');
      final label = probs.entries.reduce((a, b) => b.value > a.value ? b : a).key;
      return DifficultyPrediction(label: label, probs: probs, source: 'ml', at: DateTime.now());
    } catch (_) {
      return fallback.predict(row);
    }
  }
}
