import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../data/speech_words.dart';

/// End of a word's practice loop. Always encouraging and non-punitive: either the word was
/// mastered (stars, maybe a new card) or we gently move on and practise the hard units later.
/// Pops `true` for "next word", `false` for "try again". Numbers are never shown to the child;
/// debug builds may pass [debugLine] for the demo/developers.
class SpeechResultScreen extends StatelessWidget {
  const SpeechResultScreen({
    super.key,
    required this.word,
    required this.mastered,
    this.cardUnlocked = false,
    this.practiseLater = const [],
    this.debugLine,
  });

  final SpeechWord word;
  final bool mastered;
  final bool cardUnlocked;

  /// Unit labels scheduled for later practice (fallback only).
  final List<String> practiseLater;
  final String? debugLine;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    final title = mastered ? l10n.speechGreatJob : l10n.speechFallbackTitle;
    final body = mastered
        ? l10n.speechAcceptedBody
        : practiseLater.isEmpty
            ? l10n.speechPractiseBody
            : l10n.speechFallbackBody(practiseLater.join(', '));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.speechTitle)),
      body: SafeArea(
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Icon(
                mastered ? Icons.star_rounded : Icons.emoji_emotions_outlined,
                size: 120,
                color: mastered ? Colors.amber : theme.colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(title, style: theme.textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(word.text, style: theme.textTheme.displaySmall),
              const SizedBox(height: 8),
              Text(body,
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center),
              if (cardUnlocked) ...[
                const SizedBox(height: 24),
                Card(
                  color: Colors.amber.shade100,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.style, size: 32),
                        const SizedBox(width: 12),
                        Text(l10n.speechCardUnlocked,
                            style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
              ],
              const Spacer(),
              if (debugLine != null)
                Text(debugLine!,
                    style: theme.textTheme.bodySmall,
                    textAlign: TextAlign.center),
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
