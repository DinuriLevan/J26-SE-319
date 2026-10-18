import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/handwriting_prediction.dart';
import '../services/handwriting_classifier.dart';
import '../services/handwriting_image_preprocessor.dart';

class HandwritingPracticeScreen extends StatefulWidget {
  const HandwritingPracticeScreen({
    super.key,
    required this.character,
    required this.modelType,
    this.classifier,
  });

  final String character;
  final HandwritingModelType modelType;
  final HandwritingClassifierClient? classifier;

  @override
  State<HandwritingPracticeScreen> createState() =>
      _HandwritingPracticeScreenState();
}

class _HandwritingPracticeScreenState extends State<HandwritingPracticeScreen> {
  final List<List<Offset>> _penStrokes = [];
  final GlobalKey _canvasBoundaryKey = GlobalKey();
  final HandwritingImagePreprocessor _preprocessor =
      const HandwritingImagePreprocessor();

  late final HandwritingClassifierClient _classifier;
  late final bool _ownsClassifier;
  HandwritingPrediction? _prediction;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _ownsClassifier = widget.classifier == null;
    _classifier = widget.classifier ?? HandwritingClassifier();
  }

  @override
  void dispose() {
    if (_ownsClassifier) _classifier.dispose();
    super.dispose();
  }

  void _startStroke(DragStartDetails details) {
    if (_isSubmitting) return;
    setState(() {
      _prediction = null;
      _errorMessage = null;
      _penStrokes.add([details.localPosition]);
    });
  }

  void _continueStroke(DragUpdateDetails details) {
    if (_isSubmitting || _penStrokes.isEmpty) return;
    setState(() => _penStrokes.last.add(details.localPosition));
  }

  void _clear() {
    if (_isSubmitting) return;
    setState(() {
      _penStrokes.clear();
      _prediction = null;
      _errorMessage = null;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (_penStrokes.isEmpty) {
      const message = 'Write the letter first.';
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(message)));
      return;
    }

    setState(() {
      _isSubmitting = true;
      _prediction = null;
      _errorMessage = null;
    });

    ui.Image? canvasImage;
    try {
      final boundary = _canvasBoundaryKey.currentContext?.findRenderObject();
      if (boundary is! RenderRepaintBoundary) {
        throw StateError('The handwriting canvas is not available.');
      }
      canvasImage = await boundary.toImage(pixelRatio: 1);
      final handwriting = await _preprocessor.preprocess(canvasImage);
      final prediction = await _classifier.predict(
        modelType: widget.modelType,
        handwriting: handwriting,
        expectedCharacter: widget.character,
      );
      if (!mounted) return;
      setState(() => _prediction = prediction);
    } on HandwritingPreprocessingException catch (error, stackTrace) {
      debugPrint('[Handwriting] Canvas preprocessing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _errorMessage = 'Write the letter first.');
    } on HandwritingClassifierException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } catch (error, stackTrace) {
      debugPrint('[Handwriting] Submit failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) {
        setState(
          () => _errorMessage =
              'We couldn’t check that writing. Please try again.',
        );
      }
    } finally {
      canvasImage?.dispose();
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prediction = _prediction;
    final errorMessage = _errorMessage;

    return Scaffold(
      appBar: AppBar(title: const Text('Practice Time!')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                'Write ${widget.character}',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Use your finger to write the letter.',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.3,
                        ),
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: GestureDetector(
                      key: const ValueKey('handwriting-practice-canvas'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: _isSubmitting ? null : _startStroke,
                      onPanUpdate: _isSubmitting ? null : _continueStroke,
                      child: RepaintBoundary(
                        key: _canvasBoundaryKey,
                        child: ColoredBox(
                          color: Colors.white,
                          child: CustomPaint(
                            painter: _PracticePainter(
                              penStrokes: _penStrokes,
                              inkColor: Colors.black,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: prediction != null
                    ? _PredictionResultCard(
                        key: const ValueKey('prediction-result'),
                        target: widget.character,
                        prediction: prediction,
                      )
                    : errorMessage != null
                        ? _PracticeMessage(
                            key: const ValueKey('prediction-error'),
                            message: errorMessage,
                          )
                        : const SizedBox.shrink(),
              ),
              if (_prediction != null || _errorMessage != null)
                const SizedBox(height: 12),
              Column(
                children: [
                  OutlinedButton.icon(
                    onPressed:
                        _penStrokes.isEmpty || _isSubmitting ? null : _clear,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Clear and Try Again'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    key: const ValueKey('handwriting-submit'),
                    onPressed: _isSubmitting ? null : _submit,
                    icon: _isSubmitting
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(_isSubmitting ? 'Checking…' : 'Submit'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(56),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PredictionResultCard extends StatelessWidget {
  const _PredictionResultCard({
    super.key,
    required this.target,
    required this.prediction,
  });

  final String target;
  final HandwritingPrediction prediction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCorrect = prediction.character == target &&
        prediction.confidence >= HandwritingClassifier.confidenceThreshold;
    final statusColor =
        isCorrect ? Colors.green.shade700 : Colors.orange.shade800;

    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: statusColor.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Text(
              'Target: $target   Prediction: ${prediction.character}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              'Confidence: ${(prediction.confidence * 100).round()}%',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            Text(
              isCorrect ? '✓ Correct!' : 'Needs Practice — Try Again',
              style: theme.textTheme.titleMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeMessage extends StatelessWidget {
  const _PracticeMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.errorContainer,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _PracticePainter extends CustomPainter {
  const _PracticePainter({
    required this.penStrokes,
    required this.inkColor,
  });

  final List<List<Offset>> penStrokes;
  final Color inkColor;

  @override
  void paint(Canvas canvas, Size size) {
    final inkPaint = Paint()
      ..color = inkColor
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    for (final points in penStrokes) {
      if (points.length == 1) {
        canvas.drawCircle(points.first, inkPaint.strokeWidth / 2, inkPaint);
        continue;
      }
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, inkPaint);
    }
  }

  @override
  bool shouldRepaint(_PracticePainter oldDelegate) => true;
}
