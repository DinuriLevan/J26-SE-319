import 'dart:convert';
import 'dart:io';

import 'package:akurin/features/spelling/engine/feature_extractor.dart';
import 'package:akurin/features/spelling/model/difficulty_classifier.dart';
import 'package:akurin/features/spelling/sinhala/model/difficulty_model_si_m2cgen.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sinhala model: Python (ml/spelling/spell_export.py --lang si) and Dart must
/// give the same class and probabilities for the same 50 rows. Re-run the
/// export after retraining; it rewrites the fixture and runs this test.
void main() {
  test('Sinhala Dart model + preprocessing match Python on 50 sample rows', () {
    const dir = 'assets/spelling/model_si';
    Map<String, Object?> json(String path) => jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
    final spec = ModelSpec.fromJson(
      json('$dir/preprocessing.json'),
      (jsonDecode(File('$dir/feature_order.json').readAsStringSync()) as List).cast<String>(),
    );
    final classifier = MlDifficultyClassifier(spec, score: difficultyModelScoreSi);
    final rows = (json('test/features/spelling/fixtures/difficulty_parity_si.json')['rows']! as List).cast<Map>();
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
    expect(worst, lessThan(1e-6), reason: 'largest probability difference $worst');
  });

  testWidgets('the game loads the trained Sinhala model from its assets', (tester) async {
    final loaded = await tester.runAsync(
      () => MlDifficultyClassifier.load(dir: 'assets/spelling/model_si', score: difficultyModelScoreSi),
    );
    expect(loaded, isA<MlDifficultyClassifier>());
    final spec = (loaded! as MlDifficultyClassifier).spec;
    expect(spec.model, 'XGBoost');
    expect(spec.featureSet, 'B');
  });
}
