class PredictionScore {
  const PredictionScore({
    required this.character,
    required this.confidence,
    required this.index,
  });

  final String character;
  final double confidence;
  final int index;
}
