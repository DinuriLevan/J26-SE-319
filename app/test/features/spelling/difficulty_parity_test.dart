import 'dart:convert';
import 'dart:io';

import 'package:akurin/features/spelling/engine/feature_extractor.dart';
import 'package:akurin/features/spelling/model/difficulty_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

/// Python (ml/spelling/spell_export.py) and Dart must give the same class
/// and the same probabilities for the same 50 rows. Re-run spell_export.py
/// after retraining; it rewrites the fixture and runs this test.
void main() {
  test('Dart model + preprocessing match Python on 50 sample rows', () {
    Map<String, Object?> json(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
    final spec = ModelSpec.fromJson(
      json('assets/spelling/model/preprocessing.json'),
      (jsonDecode(File('assets/spelling/model/feature_order.json').readAsStringSync()) as List).cast<String>(),
    );
    final classifier = MlDifficultyClassifier(spec);
    final rows = (json('test/features/spelling/fixtures/difficulty_parity.json')['rows']! as List).cast<Map>();
    expect(rows, hasLength(50));

    var worst = 0.0;
    for (final r in rows) {
      final values = (r['values'] as Map).cast<String, Object?>();
      final prediction = classifier.predict(FeatureRow(Map.of(values)));
      expect(prediction.source, 'ml');
      expect(prediction.label, r['label']);
      final expected = (r['probs'] as List).cast<num>();
      for (var i = 0; i < spec.classes.length; i++) {
        final diff = (prediction.probs[spec.classes[i]]! - expected[i]).abs();
        if (diff > worst) worst = diff;
      }
    }
    // XGBoost predicts in float32 internally; the exported code uses doubles.
    expect(worst, lessThan(1e-6), reason: 'largest probability difference $worst');
  });
}
