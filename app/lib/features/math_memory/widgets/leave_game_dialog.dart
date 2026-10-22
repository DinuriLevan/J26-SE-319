import 'package:flutter/material.dart';

import 'feedback_panel.dart';
import 'math_palette.dart';

/// Asks before leaving a game in progress. Returns true to leave.
///
/// Leaving ends the attempt without counting it: it is not the baseline and
/// doesn't change difficulty (see `MathProgressRepository`).
Future<bool> confirmLeaveGame(BuildContext context, MathGameColors colors) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Stop playing?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: MathPalette.ink,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'You can start again any time.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: mathPrimaryButtonStyle(context, colors, height: 52),
                child: const Text('Keep Playing'),
              ),
              const SizedBox(height: 10),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: mathSecondaryButtonStyle(context, colors, height: 52),
                child: const Text('Stop'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return leave ?? false;
}
