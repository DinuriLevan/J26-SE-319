import 'prediction_score.dart';

class HandwritingPrediction {
  const HandwritingPrediction({
    required this.character,
    required this.confidence,
    required this.predictedIndex,
    required this.rawScores,
    this.topPredictions = const [],
  });

  final String character;
  final double confidence;
  final int predictedIndex;
  final List<double> rawScores;
  final List<PredictionScore> topPredictions;
}
