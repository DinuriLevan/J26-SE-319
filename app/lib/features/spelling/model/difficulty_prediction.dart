/// One difficulty prediction for a skill: how hard the skill currently is
/// for the child (easy / medium / hard), from one word's behaviour.
class DifficultyPrediction {
  DifficultyPrediction({
    required this.label,
    required this.probs,
    required this.source,
    required this.at,
  });

  static const classes = ['easy', 'medium', 'hard'];

  /// "easy", "medium" or "hard".
  final String label;

  /// Probability per class (sums to 1).
  final Map<String, double> probs;

  /// "ml" = the trained classifier; "fallback" = the BKT rule (model
  /// missing or failed).
  final String source;
  final DateTime at;

  double get confidence => probs[label] ?? 0;

  /// Average of several predictions (probabilities averaged, then the most
  /// likely class). Smooths out one odd word.
  static DifficultyPrediction average(List<DifficultyPrediction> ps) {
    final probs = {
      for (final c in classes) c: ps.fold<double>(0, (s, p) => s + (p.probs[c] ?? 0)) / ps.length,
    };
    final label = probs.entries.reduce((a, b) => b.value > a.value ? b : a).key;
    return DifficultyPrediction(
      label: label,
      probs: probs,
      source: ps.any((p) => p.source == 'ml') ? 'ml' : 'fallback',
      at: ps.last.at,
    );
  }

  Map<String, Object?> toJson() => {'label': label, 'probs': probs, 'source': source, 'at': at.toIso8601String()};

  factory DifficultyPrediction.fromJson(Map<String, Object?> j) => DifficultyPrediction(
        label: j['label']! as String,
        probs: (j['probs']! as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
        source: j['source']! as String,
        at: DateTime.parse(j['at']! as String),
      );
}
