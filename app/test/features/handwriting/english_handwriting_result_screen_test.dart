import 'package:akurin/core/theme/app_theme.dart';
import 'package:akurin/features/handwriting/screens/english_handwriting_result_screen.dart';
import 'package:akurin/features/handwriting/services/handwriting_feedback_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeFeedbackSpeechService implements HandwritingFeedbackSpeechClient {
  int successCalls = 0;
  int retryCalls = 0;
  int stopCalls = 0;

  @override
  Future<void> speakSuccess() async => successCalls++;

  @override
  Future<void> speakRetry() async => retryCalls++;

  @override
  Future<void> stop() async => stopCalls++;

  @override
  Future<void> dispose() async {}
}

void main() {
  testWidgets('success page is simple, speaks once, and returns Next Letter', (
    tester,
  ) async {
    final speech = _FakeFeedbackSpeechService();
    EnglishHandwritingResultAction? action;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              action = await Navigator.of(context)
                  .push<EnglishHandwritingResultAction>(
                MaterialPageRoute<EnglishHandwritingResultAction>(
                  builder: (_) => EnglishHandwritingResultScreen(
                    isCorrect: true,
                    feedbackSpeechService: speech,
                  ),
                ),
              );
            },
            child: const Text('Open result'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open result'));
    await tester.pumpAndSettle();

    expect(find.text('Great job!'), findsOneWidget);
    expect(find.byKey(const ValueKey('success-animation')), findsOneWidget);
    expect(find.text('Next Letter'), findsOneWidget);
    expect(find.text('Back to Letters'), findsOneWidget);
    expect(find.textContaining('Target:'), findsNothing);
    expect(find.textContaining('Prediction:'), findsNothing);
    expect(find.textContaining('Confidence:'), findsNothing);
    expect(speech.successCalls, 1);

    await tester.pump(const Duration(seconds: 1));
    expect(speech.successCalls, 1, reason: 'Rebuilds must not repeat speech.');

    final stopsBeforeLeaving = speech.stopCalls;
    await tester.tap(find.byKey(const ValueKey('next-letter')));
    await tester.pumpAndSettle();

    expect(action, EnglishHandwritingResultAction.nextLetter);
    expect(speech.stopCalls, greaterThan(stopsBeforeLeaving));
  });

  testWidgets('retry page speaks once and returns Try Again', (tester) async {
    final speech = _FakeFeedbackSpeechService();
    EnglishHandwritingResultAction? action;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              action = await Navigator.of(context)
                  .push<EnglishHandwritingResultAction>(
                MaterialPageRoute<EnglishHandwritingResultAction>(
                  builder: (_) => EnglishHandwritingResultScreen(
                    isCorrect: false,
                    feedbackSpeechService: speech,
                  ),
                ),
              );
            },
            child: const Text('Open result'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open result'));
    await tester.pumpAndSettle();

    expect(find.text('Let’s try again!'), findsOneWidget);
    expect(find.byKey(const ValueKey('retry-animation')), findsOneWidget);
    expect(find.text('Try Again'), findsOneWidget);
    expect(find.text('Next Letter'), findsNothing);
    expect(speech.retryCalls, 1);

    final stopsBeforeLeaving = speech.stopCalls;
    await tester.tap(find.byKey(const ValueKey('try-again')));
    await tester.pumpAndSettle();

    expect(action, EnglishHandwritingResultAction.tryAgain);
    expect(speech.stopCalls, greaterThan(stopsBeforeLeaving));
  });

  testWidgets('Back to Letters and system back both stop feedback', (
    tester,
  ) async {
    final speech = _FakeFeedbackSpeechService();
    EnglishHandwritingResultAction? action;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () async {
              action = await Navigator.of(context)
                  .push<EnglishHandwritingResultAction>(
                MaterialPageRoute<EnglishHandwritingResultAction>(
                  builder: (_) => EnglishHandwritingResultScreen(
                    isCorrect: true,
                    feedbackSpeechService: speech,
                  ),
                ),
              );
            },
            child: const Text('Open result'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open result'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('back-to-letters')));
    await tester.pumpAndSettle();
    expect(action, EnglishHandwritingResultAction.backToLetters);
    expect(speech.stopCalls, greaterThan(0));

    action = null;
    final stopsBeforeBack = speech.stopCalls;
    await tester.tap(find.text('Open result'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(action, isNull);
    expect(speech.stopCalls, greaterThan(stopsBeforeBack));
  });
}
