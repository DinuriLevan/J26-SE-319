import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/handwriting/models/character_stroke_definition.dart';
import 'package:akurin/features/handwriting/models/handwriting_prediction.dart';
import 'package:akurin/features/handwriting/screens/handwriting_practice_screen.dart';
import 'package:akurin/features/handwriting/services/handwriting_classifier.dart';
import 'package:akurin/features/handwriting/services/handwriting_feedback_speech_service.dart';
import 'package:akurin/features/handwriting/services/handwriting_formation_validator.dart';
import 'package:akurin/features/handwriting/services/handwriting_image_preprocessor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeClassifier implements HandwritingClassifierClient {
  _FakeClassifier(this.prediction);

  final HandwritingPrediction prediction;
  HandwritingModelType? receivedModelType;
  String? receivedExpectedCharacter;
  PreprocessedHandwriting? receivedHandwriting;

  @override
  Future<HandwritingPrediction> predict({
    required HandwritingModelType modelType,
    required PreprocessedHandwriting handwriting,
    required String expectedCharacter,
  }) async {
    receivedModelType = modelType;
    receivedExpectedCharacter = expectedCharacter;
    receivedHandwriting = handwriting;
    expect(handwriting.width, 224);
    expect(handwriting.height, 224);
    return prediction;
  }

  @override
  void dispose() {}
}

class _FakeFormationValidator implements HandwritingFormationValidatorClient {
  const _FakeFormationValidator(this.result);

  final FormationValidationResult result;

  @override
  FormationValidationResult validate({
    required String target,
    required HandwritingLanguage language,
    required List<List<Offset>> strokes,
    required Size sourceSize,
  }) =>
      result;
}

class _FakeFeedbackSpeechService implements HandwritingFeedbackSpeechClient {
  _FakeFeedbackSpeechService({this.failWhenSpeaking = false});

  final bool failWhenSpeaking;
  int successCalls = 0;
  int retryCalls = 0;
  int stopCalls = 0;
  int disposeCalls = 0;

  @override
  Future<void> speakSuccess() async {
    successCalls++;
    if (failWhenSpeaking) throw StateError('TTS unavailable');
  }

  @override
  Future<void> speakRetry() async {
    retryCalls++;
    if (failWhenSpeaking) throw StateError('TTS unavailable');
  }

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async => disposeCalls++;
}

void main() {
  testWidgets('empty canvas asks the child to write first', (tester) async {
    final speech = _FakeFeedbackSpeechService();
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
          feedbackSpeechService: speech,
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('handwriting-submit')));
    await tester.pump();

    expect(find.text('Write the letter first.'), findsWidgets);
    expect(classifier.receivedModelType, isNull);
    expect(speech.successCalls, 0);
    expect(speech.retryCalls, 0);
  });

  testWidgets('English Submit opens a technical-data-free success page', (
    tester,
  ) async {
    final speech = _FakeFeedbackSpeechService();
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
          feedbackSpeechService: speech,
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
    final modelInput = classifier.receivedHandwriting!;
    expect(modelInput.rgbBytes.take(3), everyElement(255));
    expect(
      modelInput.rgbBytes.any((channel) => channel < 10),
      isTrue,
      reason: 'The hidden model canvas should contain black stroke pixels.',
    );
    expect(find.textContaining('Target:'), findsNothing);
    expect(find.textContaining('Prediction:'), findsNothing);
    expect(find.textContaining('Confidence:'), findsNothing);
    expect(find.text('Great job!'), findsOneWidget);
    expect(find.byKey(const ValueKey('success-animation')), findsOneWidget);
    expect(speech.successCalls, 1);
    expect(speech.retryCalls, 0);

    await tester.pump(const Duration(seconds: 1));
    expect(speech.successCalls, 1, reason: 'Rebuilds must not repeat speech.');

    expect(find.text('Next Letter'), findsOneWidget);
    expect(find.text('Back to Letters'), findsOneWidget);
  });

  testWidgets(
    'high-confidence target prediction is rejected when formation is mirrored',
    (tester) async {
      final speech = _FakeFeedbackSpeechService();
      final classifier = _FakeClassifier(
        const HandwritingPrediction(
          character: 'B',
          confidence: 1,
          predictedIndex: 1,
          rawScores: [0, 1],
        ),
      );
      const mirroredFormation = FormationValidationResult(
        orientationEvaluated: true,
        orientationCorrect: false,
        strokeCountCorrect: null,
        strokeOrderCorrect: null,
        similarityScore: 0.3,
        feedback: 'Good try! Check the direction of the letter.',
        actualStrokeCount: 1,
        expectedStrokeCount: 3,
        normalizedBounds: Rect.fromLTWH(0, 0, 1, 1),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HandwritingPracticeScreen(
            character: 'B',
            modelType: HandwritingModelType.englishUppercase,
            classifier: classifier,
            formationValidator:
                const _FakeFormationValidator(mirroredFormation),
            feedbackSpeechService: speech,
          ),
        ),
      );

      await tester.drag(
        find.byKey(const ValueKey('handwriting-practice-canvas')),
        const Offset(80, 120),
      );
      await tester.tap(find.byKey(const ValueKey('handwriting-submit')));
      await tester.runAsync(() async {
        for (var attempt = 0;
            attempt < 100 && classifier.receivedModelType == null;
            attempt++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();

      expect(find.textContaining('Target:'), findsNothing);
      expect(find.textContaining('Prediction:'), findsNothing);
      expect(find.textContaining('Confidence:'), findsNothing);
      expect(find.text('Great job!'), findsNothing);
      expect(find.text('Let’s try again!'), findsOneWidget);
      expect(find.byKey(const ValueKey('retry-animation')), findsOneWidget);
      expect(speech.successCalls, 0);
      expect(speech.retryCalls, 1);

      final stopsBeforeRetry = speech.stopCalls;
      await tester.tap(find.byKey(const ValueKey('try-again')));
      await tester.pumpAndSettle();

      expect(speech.stopCalls, greaterThan(stopsBeforeRetry));
      expect(find.text('Write B'), findsOneWidget);
      expect(find.text('Let’s try again!'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('handwriting-submit')));
      await tester.pump();
      expect(find.text('Write the letter first.'), findsWidgets);
    },
  );

  testWidgets('English result remains visible when speech fails', (
    tester,
  ) async {
    final speech = _FakeFeedbackSpeechService(failWhenSpeaking: true);
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
          feedbackSpeechService: speech,
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('handwriting-practice-canvas')),
      const Offset(80, 120),
    );
    await tester.tap(find.byKey(const ValueKey('handwriting-submit')));
    await tester.runAsync(() async {
      for (var attempt = 0;
          attempt < 100 && classifier.receivedModelType == null;
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('Great job!'), findsOneWidget);
    expect(speech.successCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Sinhala result keeps its existing visual flow and stays silent',
      (
    tester,
  ) async {
    final speech = _FakeFeedbackSpeechService();
    final classifier = _FakeClassifier(
      const HandwritingPrediction(
        character: 'අ',
        confidence: 0.96,
        predictedIndex: 0,
        rawScores: [0.96],
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HandwritingPracticeScreen(
          character: 'අ',
          modelType: HandwritingModelType.sinhala,
          classifier: classifier,
          feedbackSpeechService: speech,
        ),
      ),
    );

    await tester.drag(
      find.byKey(const ValueKey('handwriting-practice-canvas')),
      const Offset(80, 120),
    );
    await tester.tap(find.byKey(const ValueKey('handwriting-submit')));
    await tester.runAsync(() async {
      for (var attempt = 0;
          attempt < 100 && classifier.receivedModelType == null;
          attempt++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    await tester.pumpAndSettle();

    expect(find.text('✓ Correct!'), findsOneWidget);
    expect(find.text('Great job!'), findsNothing);
    expect(speech.successCalls, 0);
    expect(speech.retryCalls, 0);
  });
}
