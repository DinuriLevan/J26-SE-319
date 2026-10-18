class HandwritingPrediction {
  const HandwritingPrediction({
    required this.character,
    required this.confidence,
    required this.predictedIndex,
    required this.rawScores,
  });

  final String character;
  final double confidence;
  final int predictedIndex;
  final List<double> rawScores;
}
