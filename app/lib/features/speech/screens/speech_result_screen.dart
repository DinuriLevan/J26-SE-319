import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/speech_api.dart';
import '../data/speech_words.dart';

/// Encouraging, non-punitive feedback. Pops `true` for "next word", `false` for "try again".
/// Numbers are never shown to the child; debug builds show them small for the demo/devs.
class SpeechResultScreen extends StatelessWidget {
  const SpeechResultScreen(
      {super.key, required this.word, required this.result});

  final SpeechWord word;
  final AssessResult result;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final ok = result.accepted;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.speechTitle)),
      body: SafeArea(
        child: Container(
          width: double.infinity, // centre content across the full screen width
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                ok ? Icons.star_rounded : Icons.emoji_emotions_outlined,
                size: 120,
                color: ok ? Colors.amber : theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(ok ? l10n.speechGreatJob : l10n.speechNiceTry,
                  style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(word.text, style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(
                ok ? l10n.speechAcceptedBody : l10n.speechPractiseBody,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (kDebugMode)
                Text(
                  'score ${result.score.toStringAsFixed(3)} / threshold '
                  '${result.threshold.toStringAsFixed(3)} (${result.thresholdSource}) · '
                  'ref ${result.nearestVariant} · ${result.totalLatencyMs.round()} ms',
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.replay),
                      label: Text(l10n.speechTryAgain),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(true),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(l10n.speechNextWord),
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
