import 'package:flutter/material.dart';

import '../data/character_stroke_repository.dart';
import '../data/sinhala_strokes.dart';
import '../models/character_stroke_definition.dart';
import '../models/handwriting_animation_config.dart';
import '../services/handwriting_classifier.dart';
import '../widgets/demonstration_controls.dart';
import '../widgets/stroke_demonstration_canvas.dart';
import 'handwriting_practice_screen.dart';

class CharacterDemonstrationScreen extends StatefulWidget {
  const CharacterDemonstrationScreen({
    super.key,
    required this.character,
    required this.language,
    this.emoji,
    this.exampleWord,
    this.modelType,
  });

  final String character;
  final HandwritingLanguage language;
  final String? emoji;
  final String? exampleWord;
  final HandwritingModelType? modelType;

  @override
  State<CharacterDemonstrationScreen> createState() =>
      _CharacterDemonstrationScreenState();
}

class _CharacterDemonstrationScreenState
    extends State<CharacterDemonstrationScreen>
    with SingleTickerProviderStateMixin {
  late final CharacterStrokeDefinition? _definition;
  late final HandwritingAnimationConfig _animationConfig;
  late final AnimationController _controller;

  int _currentStrokeIndex = 0;
  int _transitionToken = 0;
  bool _autoPlay = true;

  @override
  void initState() {
    super.initState();
    _definition = CharacterStrokeRepository.find(
      character: widget.character,
      language: widget.language,
    );
    _animationConfig = HandwritingAnimationConfig.forLanguage(widget.language);
    if (_definition == null) {
      debugPrint(
        '[Handwriting] Missing ${widget.language.name} stroke definition for "${widget.character}".',
      );
    }
    _controller = AnimationController(
      vsync: this,
      duration: _durationForStroke(0),
    )..addStatusListener(_handleAnimationStatus);
    if (_definition != null) _controller.forward();
  }

  @override
  void dispose() {
    _transitionToken++;
    _controller
      ..removeStatusListener(_handleAnimationStatus)
      ..dispose();
    super.dispose();
  }

  void _handleAnimationStatus(AnimationStatus status) {
    final definition = _definition;
    if (status != AnimationStatus.completed ||
        !_autoPlay ||
        definition == null ||
        _currentStrokeIndex >= definition.strokes.length - 1) {
      return;
    }

    final token = ++_transitionToken;
    Future<void>.delayed(_animationConfig.strokePauseDuration, () {
      if (!mounted || !_autoPlay || token != _transitionToken) return;
      setState(() => _currentStrokeIndex++);
      _controller.duration = _durationForStroke(_currentStrokeIndex);
      _controller.forward(from: 0);
    });
  }

  void _replay() {
    if (_definition == null) return;
    _transitionToken++;
    _autoPlay = true;
    setState(() => _currentStrokeIndex = 0);
    _controller.duration = _durationForStroke(0);
    _controller.forward(from: 0);
  }

  void _previousStep() {
    if (_definition == null || _currentStrokeIndex == 0) return;
    _transitionToken++;
    _autoPlay = false;
    _controller.stop();
    setState(() => _currentStrokeIndex--);
    _controller.duration = _durationForStroke(_currentStrokeIndex);
    _controller.value = 1;
  }

  void _nextStep() {
    final definition = _definition;
    if (definition == null ||
        _currentStrokeIndex >= definition.strokes.length - 1) {
      return;
    }
    _transitionToken++;
    _autoPlay = false;
    _controller.stop();
    setState(() => _currentStrokeIndex++);
    _controller.duration = _durationForStroke(_currentStrokeIndex);
    _controller.forward(from: 0);
  }

  Duration _durationForStroke(int index) {
    final definition = _definition;
    if (definition == null || definition.strokes.isEmpty) {
      return _animationConfig.strokeDuration;
    }
    return _animationConfig.durationForStroke(definition.strokes[index]);
  }

  void _openPractice() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HandwritingPracticeScreen(
          character: widget.character,
          modelType: widget.modelType ?? _modelTypeForSelection(),
        ),
      ),
    );
  }

  HandwritingModelType _modelTypeForSelection() {
    if (widget.language == HandwritingLanguage.sinhala) {
      return HandwritingModelType.sinhala;
    }
    return widget.character == widget.character.toUpperCase()
        ? HandwritingModelType.englishUppercase
        : HandwritingModelType.englishLowercase;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final definition = _definition;

    return Scaffold(
      appBar: AppBar(title: const Text('Letter Time!')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Text(
              'Let’s learn ${widget.character}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.exampleWord != null) ...[
              const SizedBox(height: 4),
              Text(
                '${widget.emoji ?? ''}  ${widget.exampleWord}',
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 18),
            AspectRatio(
              aspectRatio: 0.95,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: definition == null
                    ? _UnsupportedCharacter(character: widget.character)
                    : AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) => StrokeDemonstrationCanvas(
                          definition: definition,
                          currentStrokeIndex: _currentStrokeIndex,
                          progress: Curves.easeInOut.transform(
                            _controller.value,
                          ),
                          showReferenceGlyph: definition.language ==
                                  HandwritingLanguage.sinhala &&
                              showSinhalaReferenceGlyph,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            if (definition != null) ...[
              _StepInformation(
                step: _currentStrokeIndex + 1,
                totalSteps: definition.strokes.length,
                instruction:
                    definition.strokes[_currentStrokeIndex].instruction,
              ),
              const SizedBox(height: 16),
              DemonstrationControls(
                onReplay: _replay,
                onPrevious: _previousStep,
                onNext: _nextStep,
                onPractice: _openPractice,
                canGoPrevious: _currentStrokeIndex > 0,
                canGoNext: _currentStrokeIndex < definition.strokes.length - 1,
              ),
            ] else
              FilledButton.icon(
                onPressed: _openPractice,
                icon: const Icon(Icons.edit_rounded),
                label: const Text('My Turn!'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(60),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StepInformation extends StatelessWidget {
  const _StepInformation({
    required this.step,
    required this.totalSteps,
    required this.instruction,
  });

  final int step;
  final int totalSteps;
  final String instruction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Text(
            'Step $step of $totalSteps',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            instruction,
            style: theme.textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _UnsupportedCharacter extends StatelessWidget {
  const _UnsupportedCharacter({required this.character});

  final String character;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              character,
              style: theme.textTheme.displayLarge?.copyWith(
                fontSize: 96,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Demonstration is not available for this character yet.',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
