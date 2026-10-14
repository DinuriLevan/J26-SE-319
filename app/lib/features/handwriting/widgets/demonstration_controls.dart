import 'package:flutter/material.dart';

class DemonstrationControls extends StatelessWidget {
  const DemonstrationControls({
    super.key,
    required this.onReplay,
    required this.onPrevious,
    required this.onNext,
    required this.onPractice,
    required this.canGoPrevious,
    required this.canGoNext,
  });

  final VoidCallback onReplay;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onPractice;
  final bool canGoPrevious;
  final bool canGoNext;

  @override
  Widget build(BuildContext context) {
    const buttonHeight = 56.0;

    return Column(
      children: [
        OutlinedButton.icon(
          onPressed: onReplay,
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Replay'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, buttonHeight),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canGoPrevious ? onPrevious : null,
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Previous Step'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(buttonHeight),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: canGoNext ? onNext : null,
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Next Step'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(buttonHeight),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onPractice,
          icon: const Icon(Icons.edit_rounded),
          label: const Text('My Turn!'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 60),
          ),
        ),
      ],
    );
  }
}
