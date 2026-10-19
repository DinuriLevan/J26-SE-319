import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/character_stroke_definition.dart';
import '../models/handwriting_prediction.dart';
import '../services/handwriting_classifier.dart';
import '../services/handwriting_debug_config.dart';
import '../services/handwriting_formation_validator.dart';
import '../services/handwriting_image_preprocessor.dart';

class HandwritingPracticeScreen extends StatefulWidget {
  const HandwritingPracticeScreen({
    super.key,
    required this.character,
    required this.modelType,
    this.classifier,
    this.formationValidator,
  });

  final String character;
  final HandwritingModelType modelType;
  final HandwritingClassifierClient? classifier;
  final HandwritingFormationValidatorClient? formationValidator;

  @override
  State<HandwritingPracticeScreen> createState() =>
      _HandwritingPracticeScreenState();
}

class _HandwritingPracticeScreenState extends State<HandwritingPracticeScreen> {
  final List<List<Offset>> _penStrokes = [];
  final GlobalKey _canvasKey = GlobalKey();
  final HandwritingImagePreprocessor _preprocessor =
      const HandwritingImagePreprocessor();

  late final HandwritingClassifierClient _classifier;
  late final HandwritingFormationValidatorClient _formationValidator;
  late final bool _ownsClassifier;
  HandwritingPrediction? _prediction;
  FormationValidationResult? _formationResult;
  ui.Image? _debugModelInput;
  String? _errorMessage;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _ownsClassifier = widget.classifier == null;
    _classifier = widget.classifier ?? HandwritingClassifier();
    _formationValidator =
        widget.formationValidator ?? const HandwritingFormationValidator();
  }

  @override
  void dispose() {
    _debugModelInput?.dispose();
    if (_ownsClassifier) _classifier.dispose();
    super.dispose();
  }

  void _startStroke(DragStartDetails details) {
    if (_isSubmitting) return;
    setState(() {
      _replaceDebugImage(null);
      _prediction = null;
      _formationResult = null;
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
      _replaceDebugImage(null);
      _prediction = null;
      _formationResult = null;
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
      _formationResult = null;
      _errorMessage = null;
    });

    try {
      final canvasBox = _canvasKey.currentContext?.findRenderObject();
      if (canvasBox is! RenderBox || !canvasBox.hasSize) {
        throw StateError('The handwriting canvas is not available.');
      }
      final handwriting = await _preprocessor.preprocessStrokes(
        strokes: _penStrokes,
        sourceSize: canvasBox.size,
        outputStrokeWidth: widget.modelType.modelInputStrokeWidth,
      );
      if (HandwritingDebugConfig.enabled) {
        final debugImage = await _preprocessor.createDebugImage(handwriting);
        if (!mounted) {
          debugImage.dispose();
          return;
        }
        setState(() => _replaceDebugImage(debugImage));
      }
      final prediction = await _classifier.predict(
        modelType: widget.modelType,
        handwriting: handwriting,
        expectedCharacter: widget.character,
      );
      final formation = _formationValidator.validate(
        target: widget.character,
        language: widget.modelType == HandwritingModelType.sinhala
            ? HandwritingLanguage.sinhala
            : HandwritingLanguage.english,
        strokes: _penStrokes,
        sourceSize: canvasBox.size,
      );
      final recognitionCorrect = prediction.character == widget.character &&
          prediction.confidence >= HandwritingClassifier.confidenceThreshold;
      final finalCorrect = formation.finalCorrect(
        recognitionCorrect: recognitionCorrect,
      );
      if (HandwritingDebugConfig.enabled) {
        debugPrint(
          '[HandwritingFormation] Target=${widget.character} '
          'Prediction=${prediction.character} '
          'Confidence=${prediction.confidence.toStringAsFixed(4)} '
          'RecognitionCorrect=$recognitionCorrect '
          'OrientationPolicy=${formation.orientationPolicy} '
          'OrientationEvaluated=${formation.orientationEvaluated} '
          'OrientationCorrect=${formation.orientationCorrect} '
          'StrokeDirectionCorrect=${formation.strokeDirectionCorrect} '
          'StrokeCountCorrect=${formation.strokeCountCorrect} '
          'StrokeOrderCorrect=${formation.strokeOrderCorrect} '
          'ShapeCorrect=${formation.shapeCorrect} '
          'StrokeCount=${formation.actualStrokeCount} '
          'ExpectedStrokeCount=${formation.expectedStrokeCount ?? 'not evaluated'} '
          'NormalizedBounds=${formation.normalizedBounds} '
          'CorrectFormationSimilarity='
          '${formation.correctFormationSimilarity.toStringAsFixed(4)} '
          'MirroredFormationSimilarity='
          '${formation.mirroredFormationSimilarity.toStringAsFixed(4)} '
          'StartEndScore=${formation.startEndScore.toStringAsFixed(4)} '
          'DirectionScore=${formation.directionScore.toStringAsFixed(4)} '
          'StrokeOrderScore=${formation.strokeOrderScore.toStringAsFixed(4)} '
          'OrientationScore=${formation.orientationScore.toStringAsFixed(4)} '
          'ShapeSimilarity=${formation.shapeSimilarity.toStringAsFixed(4)} '
          'MatchedValidVariant=${formation.matchedValidVariant ?? 'none'} '
          'FormationCorrect=${formation.formationCorrect} '
          'FinalCorrect=$finalCorrect '
          'FailureReason=${formation.failureReason ?? 'none'}',
        );
      }
      if (!mounted) return;
      setState(() {
        _prediction = prediction;
        _formationResult = formation;
      });
    } on HandwritingPreprocessingException catch (error, stackTrace) {
      debugPrint('[Handwriting] Canvas preprocessing failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _errorMessage = error.userMessage);
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _replaceDebugImage(ui.Image? image) {
    if (identical(_debugModelInput, image)) return;
    _debugModelInput?.dispose();
    _debugModelInput = image;
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
                        key: _canvasKey,
                        child: ColoredBox(
                          color: Colors.white,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CustomPaint(
                                painter: _PracticePainter(
                                  penStrokes: _penStrokes,
                                  inkColor: Colors.black,
                                ),
                              ),
                              if (HandwritingDebugConfig.enabled &&
                                  _debugModelInput != null)
                                Positioned(
                                  right: 10,
                                  bottom: 10,
                                  child: IgnorePointer(
                                    child: _ModelInputDebugPreview(
                                      image: _debugModelInput!,
                                    ),
                                  ),
                                ),
                            ],
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
                        formation: _formationResult!,
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
    required this.formation,
  });

  final String target;
  final HandwritingPrediction prediction;
  final FormationValidationResult formation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recognitionCorrect = prediction.character == target &&
        prediction.confidence >= HandwritingClassifier.confidenceThreshold;
    final isCorrect = formation.finalCorrect(
      recognitionCorrect: recognitionCorrect,
    );
    final statusMessage = recognitionCorrect && !formation.formationCorrect
        ? formation.feedback ?? 'Good try! Check the direction of the letter.'
        : isCorrect
            ? '✓ Correct!'
            : 'Needs Practice — Try Again';
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
              statusMessage,
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
  static const double strokeWidth = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final inkPaint = Paint()
      ..color = inkColor
      ..strokeWidth = strokeWidth
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

class _ModelInputDebugPreview extends StatelessWidget {
  const _ModelInputDebugPreview({required this.image});

  final ui.Image image;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.redAccent, width: 2),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'DEBUG 224×224 input',
              style: TextStyle(
                color: Colors.redAccent,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            RawImage(
              image: image,
              width: 112,
              height: 112,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none,
            ),
          ],
        ),
      ),
    );
  }
}
