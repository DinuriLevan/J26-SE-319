import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../memory_match/engine/memory_match_models.dart';
import '../memory_match/engine/memory_match_session.dart';
import '../number_quest/engine/number_quest_models.dart';
import '../number_quest/engine/number_quest_session.dart';
import 'next_attempt_features.dart';
import 'tree_ensemble_model.dart';

/// Where a next-attempt configuration came from.
enum PredictionSource {
  /// The bundled trained model.
  model,

  /// The rules engine (`rules_v1`), because the model couldn't be used.
  fallback,
}

/// The next attempt's starting configuration plus how it was chosen. Stored
/// with the attempt's queued result for traceability.
class NextAttemptPlan<P> {
  const NextAttemptPlan({
    required this.progressAfter,
    required this.source,
    required this.trace,
  });

  /// Progress to save, with the next attempt's starting configuration.
  final P progressAfter;

  final PredictionSource source;

  /// `next_attempt` block for the result payload.
  final Map<String, dynamic> trace;
}

typedef MathModelLoader = Future<TreeEnsembleModel> Function(String modelId);

/// After each completed attempt, predicts the next attempt's starting
/// configuration with the trained model — on the device, no network. If the
/// model can't be loaded or used, keeps the rules engine's configuration
/// (already in the attempt result) and records why.
class NextAttemptPlanner {
  NextAttemptPlanner(this._loadModel);

  static const numberQuestModelId = 'number_quest_next_level';
  static const memoryMatchModelId = 'memory_match_next_config';

  final MathModelLoader _loadModel;

  Future<NextAttemptPlan<NumberQuestProgress>> planNumberQuest(NumberQuestAttemptResult result) async {
    final rulesProgress = result.progressAfter;
    final features = NextAttemptFeatures.numberQuest(result);
    try {
      final model = await _usableModel(numberQuestModelId, NextAttemptFeatures.numberQuestNames);
      final skills = Map.of(rulesProgress.skills);
      final perSkill = <String, dynamic>{};
      for (final skill in MathSkill.values) {
        final f = features[skill];
        if (f == null) {
          // Not asked this attempt: keep its level.
          perSkill[skill.name] = {'next_level': skills[skill]!.level, 'source': 'carried_over'};
          continue;
        }
        final (change, probs) = model.classify(NextAttemptFeatures.vector(f, model.featureNames));
        final ref = f['ref_level']!.toInt();
        // The model's classes are already ±1; clamp again as a safety net.
        final next = (ref + change.clamp(-1, 1)).clamp(1, 5);
        skills[skill] = SkillState(level: next, recent: skills[skill]!.recent);
        perSkill[skill.name] = {
          'features': f,
          'predicted_change': change,
          'probabilities': _round(probs),
          'next_level': next,
          'rules_level': rulesProgress.skills[skill]!.level,
          'source': PredictionSource.model.name,
        };
      }
      return NextAttemptPlan(
        progressAfter: rulesProgress.copyWith(skills: skills),
        source: PredictionSource.model,
        trace: _trace(model, PredictionSource.model, {'skills': perSkill}),
      );
    } catch (e) {
      debugPrint('Number Quest: model unavailable, using rules ($e)');
      return NextAttemptPlan(
        progressAfter: rulesProgress,
        source: PredictionSource.fallback,
        trace: _fallbackTrace(numberQuestModelId, e, {
          'features': {for (final e in features.entries) e.key.name: e.value},
          'skills': {
            for (final e in rulesProgress.skills.entries) e.key.name: {'next_level': e.value.level},
          },
        }),
      );
    }
  }

  Future<NextAttemptPlan<MemoryMatchProgress>> planMemoryMatch(MemoryMatchAttemptResult result) async {
    final rulesProgress = result.progressAfter;
    final features = NextAttemptFeatures.memoryMatch(result);
    try {
      final model = await _usableModel(memoryMatchModelId, NextAttemptFeatures.memoryMatchNames);
      final (change, probs) = model.classify(NextAttemptFeatures.vector(features, model.featureNames));
      final ref = features['ref_rung']!.toInt();
      final maxStep = NextAttemptFeatures.memoryMaxStep(baseline: features['is_baseline'] == 1);
      final rung = (ref + change.clamp(-maxStep, maxStep)).clamp(0, NextAttemptFeatures.memoryLadder.length - 1);
      final config = NextAttemptFeatures.memoryLadder[rung];

      final adaptive = rulesProgress.adaptive.copyWith(
        config: config,
        successStreak: 0,
        errorStreak: 0,
        cooldown: 0,
      );
      return NextAttemptPlan(
        progressAfter: rulesProgress.copyWith(adaptive: adaptive),
        source: PredictionSource.model,
        trace: _trace(model, PredictionSource.model, {
          'features': features,
          'predicted_change': change,
          'probabilities': _round(probs),
          'ref_rung': ref,
          'next_rung': rung,
          'next_configuration': config.toJson(),
          'rules_configuration': rulesProgress.adaptive.config.toJson(),
        }),
      );
    } catch (e) {
      debugPrint('Memory Match: model unavailable, using rules ($e)');
      return NextAttemptPlan(
        progressAfter: rulesProgress,
        source: PredictionSource.fallback,
        trace: _fallbackTrace(memoryMatchModelId, e, {
          'features': features,
          'next_configuration': rulesProgress.adaptive.config.toJson(),
        }),
      );
    }
  }

  Future<TreeEnsembleModel> _usableModel(String id, List<String> expectedFeatures) async {
    final model = await _loadModel(id);
    if (!listEquals(model.featureNames, expectedFeatures)) {
      throw StateError('feature mismatch: model ${model.featureNames} vs app $expectedFeatures');
    }
    return model;
  }

  static Map<String, dynamic> _trace(TreeEnsembleModel model, PredictionSource source, Map<String, dynamic> details) => {
        'source': source.name,
        'model_id': model.modelId,
        'model_version': model.modelVersion,
        'algorithm': model.algorithm,
        ...details,
      };

  static Map<String, dynamic> _fallbackTrace(String modelId, Object error, Map<String, dynamic> details) => {
        'source': PredictionSource.fallback.name,
        'model_id': modelId,
        'model_version': null,
        'fallback_engine': 'rules_v1',
        'fallback_reason': error.toString(),
        ...details,
      };

  static List<double> _round(List<double> probs) =>
      [for (final p in probs) double.parse(p.toStringAsFixed(4))];
}

/// Loads bundled model artifacts once and keeps them in memory.
class BundledMathModels {
  BundledMathModels(this._bundle);

  final AssetBundle _bundle;
  final _cache = <String, Future<TreeEnsembleModel>>{};

  Future<TreeEnsembleModel> load(String modelId) {
    return _cache.putIfAbsent(modelId, () async {
      try {
        final raw = await _bundle.loadString('assets/models/math_memory/$modelId.json');
        return TreeEnsembleModel.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
      } catch (_) {
        _cache.remove(modelId); // allow a retry next attempt
        rethrow;
      }
    });
  }
}

/// Loads a model artifact. Overridden in tests (e.g. to simulate failure).
final mathModelLoaderProvider = Provider<MathModelLoader>((ref) {
  return BundledMathModels(rootBundle).load;
});

final nextAttemptPlannerProvider = Provider<NextAttemptPlanner>((ref) {
  return NextAttemptPlanner(ref.watch(mathModelLoaderProvider));
});
