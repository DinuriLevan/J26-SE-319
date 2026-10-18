import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/handwriting/models/handwriting_prediction.dart';
import 'package:akurin/features/handwriting/screens/handwriting_practice_screen.dart';
import 'package:akurin/features/handwriting/services/handwriting_classifier.dart';
import 'package:akurin/features/handwriting/services/handwriting_image_preprocessor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClassifier implements HandwritingClassifierClient {
  _FakeClassifier(this.prediction);

  final HandwritingPrediction prediction;
  HandwritingModelType? receivedModelType;
  String? receivedExpectedCharacter;

  @override
  Future<HandwritingPrediction> predict({
    required HandwritingModelType modelType,
    required PreprocessedHandwriting handwriting,
    required String expectedCharacter,
  }) async {
    receivedModelType = modelType;
    receivedExpectedCharacter = expectedCharacter;
    expect(handwriting.width, 224);
    expect(handwriting.height, 224);
    return prediction;
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets('empty canvas asks the child to write first', (tester) async {
    final classifier = _FakeClassifier(
      const HandwritingPrediction(
        character: 'A',
        confidence: 0.96,
        predictedIndex: 0,
        rawScores: [0.96],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HandwritingPracticeScreen(
          character: 'A',
          modelType: HandwritingModelType.englishUppercase,
          classifier: classifier,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('handwriting-submit')));
    await tester.pump();

    expect(find.text('Write the letter first.'), findsWidgets);
    expect(classifier.receivedModelType, isNull);
  });

  testWidgets('Submit preprocesses strokes and displays prediction', (
    tester,
  ) async {
    final classifier = _FakeClassifier(
      const HandwritingPrediction(
        character: 'A',
        confidence: 0.96,
        predictedIndex: 0,
        rawScores: [0.96],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HandwritingPracticeScreen(
          character: 'A',
          modelType: HandwritingModelType.englishUppercase,
          classifier: classifier,
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('handwriting-practice-canvas')),
      const Offset(80, 120),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('handwriting-submit')));
    await tester.pump();
    await tester.runAsync(() async {
      for (var attempt = 0;
          attempt < 100 && classifier.receivedModelType == null;
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pump();
    await tester.pumpAndSettle();

    expect(classifier.receivedModelType, HandwritingModelType.englishUppercase);
    expect(classifier.receivedExpectedCharacter, 'A');
    expect(find.text('Target: A   Prediction: A'), findsOneWidget);
    expect(find.text('Confidence: 96%'), findsOneWidget);
    expect(find.text('✓ Correct!'), findsOneWidget);
  });
}
