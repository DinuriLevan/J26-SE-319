import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../services/handwriting_feedback_speech_service.dart';

enum EnglishHandwritingResultAction { tryAgain, nextLetter, backToLetters }

class EnglishHandwritingResultScreen extends StatefulWidget {
  const EnglishHandwritingResultScreen({
    super.key,
    required this.isCorrect,
    this.feedbackSpeechService,
  });

  final bool isCorrect;
  final HandwritingFeedbackSpeechClient? feedbackSpeechService;

  @override
  State<EnglishHandwritingResultScreen> createState() =>
      _EnglishHandwritingResultScreenState();
}

class _EnglishHandwritingResultScreenState
    extends State<EnglishHandwritingResultScreen>
    with SingleTickerProviderStateMixin {
  late final HandwritingFeedbackSpeechClient _speechService;
  late final bool _ownsSpeechService;
  late final AnimationController _animationController;
  late final Animation<double> _entranceAnimation;
  var _hasSpoken = false;
  var _isLeaving = false;

  @override
  void initState() {
    super.initState();
    _ownsSpeechService = widget.feedbackSpeechService == null;
    _speechService =
        widget.feedbackSpeechService ?? HandwritingFeedbackSpeechService();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _entranceAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakOnce());
  }

  void _speakOnce() {
    if (!mounted || _hasSpoken) return;
    _hasSpoken = true;
    unawaited(_speakFeedbackSafely());
  }

  Future<void> _speakFeedbackSafely() async {
    try {
      if (widget.isCorrect) {
        await _speechService.speakSuccess();
      } else {
        await _speechService.speakRetry();
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Handwriting speech] Result feedback failed: $error');
      }
    }
  }

  Future<void> _stopSpeechSafely() async {
    try {
      await _speechService.stop();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Handwriting speech] Could not stop feedback: $error');
      }
    }
  }

  Future<void> _leave(EnglishHandwritingResultAction action) async {
    if (_isLeaving) return;
    _isLeaving = true;
    await _stopSpeechSafely();
    if (!mounted) return;
    Navigator.of(context).pop(action);
  }

  @override
  void dispose() {
    _animationController.dispose();
    unawaited(_disposeSpeechSafely());
    super.dispose();
  }

  Future<void> _disposeSpeechSafely() async {
    try {
      if (_ownsSpeechService) {
        await _speechService.dispose();
      } else {
        await _speechService.stop();
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('[Handwriting speech] Cleanup failed: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final message = widget.isCorrect
        ? HandwritingFeedbackSpeechService.successMessage
        : HandwritingFeedbackSpeechService.retryMessage;

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) unawaited(_stopSpeechSafely());
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  height: 180,
                  child: Center(
                    child: widget.isCorrect
                        ? _SuccessAnimation(animation: _entranceAnimation)
                        : _RetryAnimation(
                            controller: _animationController,
                            animation: _entranceAnimation,
                          ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  message,
                  key: const ValueKey('english-result-message'),
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: widget.isCorrect
                        ? Colors.green.shade700
                        : colors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const Spacer(),
                if (widget.isCorrect) ...[
                  FilledButton.icon(
                    key: const ValueKey('next-letter'),
                    onPressed: _isLeaving
                        ? null
                        : () => _leave(
                              EnglishHandwritingResultAction.nextLetter,
                            ),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Next Letter'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 64),
                      textStyle: theme.textTheme.titleLarge,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    key: const ValueKey('back-to-letters'),
                    onPressed: _isLeaving
                        ? null
                        : () => _leave(
                              EnglishHandwritingResultAction.backToLetters,
                            ),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Back to Letters'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 60),
                      textStyle: theme.textTheme.titleMedium,
                    ),
                  ),
                ] else
                  FilledButton.icon(
                    key: const ValueKey('try-again'),
                    onPressed: _isLeaving
                        ? null
                        : () => _leave(
                              EnglishHandwritingResultAction.tryAgain,
                            ),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Try Again'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 64),
                      textStyle: theme.textTheme.titleLarge,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessAnimation extends StatelessWidget {
  const _SuccessAnimation({required this.animation});

  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: animation,
        child: SizedBox.square(
          key: const ValueKey('success-animation'),
          dimension: 170,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 118, color: color),
              Positioned(
                top: 10,
                right: 12,
                child: Icon(
                  Icons.star_rounded,
                  size: 38,
                  color: Colors.amber.shade600,
                ),
              ),
              Positioned(
                bottom: 14,
                left: 14,
                child: Icon(
                  Icons.star_rounded,
                  size: 30,
                  color: Colors.amber.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetryAnimation extends StatelessWidget {
  const _RetryAnimation({required this.controller, required this.animation});

  final AnimationController controller;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final turns = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: -0.025, end: 0.025), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 0.025, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: controller, curve: Curves.easeInOut));
    return FadeTransition(
      opacity: animation,
      child: RotationTransition(
        turns: turns,
        child: Icon(
          Icons.edit_note_rounded,
          key: const ValueKey('retry-animation'),
          size: 132,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
