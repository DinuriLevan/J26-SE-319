import 'dart:typed_data';

/// A trained scikit-learn decision tree or random forest, exported to JSON by
/// `ml/math_memory/train.py` and evaluated on the device (no network).
///
/// Matches scikit-learn exactly: features are rounded to float32 before each
/// `x <= threshold` comparison (as scikit-learn does), leaf class
/// probabilities are averaged across trees, and ties go to the first class.
class TreeEnsembleModel {
  TreeEnsembleModel._({
    required this.modelId,
    required this.modelVersion,
    required this.algorithm,
    required this.featureNames,
    required this.classes,
    required List<_Tree> trees,
  }) : _trees = trees;

  factory TreeEnsembleModel.fromJson(Map<String, dynamic> json) {
    final classes = [for (final c in json['classes'] as List) (c as num).toInt()];
    final trees = [
      for (final t in json['trees'] as List) _Tree.fromJson((t as Map).cast<String, dynamic>(), classes.length),
    ];
    if (trees.isEmpty) throw const FormatException('model has no trees');
    return TreeEnsembleModel._(
      modelId: json['model_id'] as String,
      modelVersion: json['model_version'] as String,
      algorithm: json['algorithm'] as String? ?? 'unknown',
      featureNames: [for (final f in json['feature_names'] as List) f as String],
      classes: classes,
      trees: trees,
    );
  }

  final String modelId;
  final String modelVersion;
  final String algorithm;
  final List<String> featureNames;

  /// Output labels, e.g. level changes -1 / 0 / +1.
  final List<int> classes;

  final List<_Tree> _trees;

  /// Mean class probabilities for one row of features (in [featureNames] order).
  List<double> predictProba(List<double> features) {
    if (features.length != featureNames.length) {
      throw ArgumentError('expected ${featureNames.length} features, got ${features.length}');
    }
    final asFloat32 = Float32List.fromList(features);
    final total = List<double>.filled(classes.length, 0);
    for (final tree in _trees) {
      final leaf = tree.leafFor(asFloat32);
      for (var k = 0; k < classes.length; k++) {
        total[k] += leaf[k];
      }
    }
    return [for (final p in total) p / _trees.length];
  }

  /// The most likely class label.
  int predict(List<double> features) => classify(features).$1;

  /// The most likely class label and all class probabilities.
  (int, List<double>) classify(List<double> features) {
    final probs = predictProba(features);
    var best = 0;
    for (var k = 1; k < probs.length; k++) {
      if (probs[k] > probs[best]) best = k;
    }
    return (classes[best], probs);
  }
}

class _Tree {
  _Tree(this.feature, this.threshold, this.left, this.right, this.value);

  factory _Tree.fromJson(Map<String, dynamic> json, int classCount) {
    List<int> ints(String key) => [for (final v in json[key] as List) (v as num).toInt()];
    final value = [
      for (final row in json['value'] as List) [for (final p in row as List) (p as num).toDouble()],
    ];
    final tree = _Tree(
      ints('feature'),
      [for (final v in json['threshold'] as List) (v as num).toDouble()],
      ints('left'),
      ints('right'),
      value,
    );
    final n = tree.left.length;
    if (tree.right.length != n || tree.feature.length != n || tree.threshold.length != n || value.length != n) {
      throw const FormatException('tree arrays have different lengths');
    }
    if (value.any((row) => row.length != classCount)) {
      throw const FormatException('leaf values do not match class count');
    }
    return tree;
  }

  final List<int> feature;
  final List<double> threshold;
  final List<int> left;
  final List<int> right;
  final List<List<double>> value;

  List<double> leafFor(Float32List x) {
    var node = 0;
    while (left[node] != -1) {
      node = x[feature[node]] <= threshold[node] ? left[node] : right[node];
    }
    return value[node];
  }
}
