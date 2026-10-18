import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../audio/speech_voice.dart';
import '../data/speech_words.dart';
import '../ui/celebration.dart';
import '../ui/parrot.dart';
import '../ui/speech_theme.dart';
import '../ui/speech_widgets.dart';
import '../ui/talking_parrot.dart';

/// End of a word's practice loop. Always encouraging and non-punitive: either the word was
/// mastered (confetti, stars, maybe a new card) or we gently move on and practise the hard units
/// later. Pops `true` for "next word", `false` for "try again". Numbers are never shown to the
/// child; debug builds may pass [debugLine] for the demo/developers.
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
    return SpeechThemed(child: Builder(builder: (context) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);

      final title = mastered ? l10n.speechGreatJob : l10n.speechFallbackTitle;
      final body = mastered
          ? l10n.speechAcceptedBody
          : practiseLater.isEmpty
              ? l10n.speechPractiseBody
              : l10n.speechFallbackBody(practiseLater.join(', '));

      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.speechTitle),
          actions: const [VoiceToggleButton()],
        ),
        body: Stack(
          children: [
            SafeArea(
              child: FillOrScroll(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Column(
                  children: [
                    const Spacer(),
                    SpokenLines(
                      lines: [
                        VoiceLine(
                            mastered ? 'speechGreatJob' : 'speechFallbackTitle',
                            title),
                        if (mastered)
                          VoiceLine('speechAcceptedBody', body)
                        else if (practiseLater.isEmpty)
                          VoiceLine('speechPractiseBody', body)
                        else
                          // Recorded voice: the general "let's practise" line; TTS reads it all.
                          VoiceLine('speechFallbackBody', body,
                              recordedAlternative: const [
                                'speechPractiseBody'
                              ]),
                        if (cardUnlocked)
                          VoiceLine(
                              'speechCardUnlocked', l10n.speechCardUnlocked),
                      ],
                      speakKey: 'result:${word.id}:$mastered',
                      builder: (context, talking, replay) => Column(
                        children: [
                          ParrotBuddy(
                            mood: mastered
                                ? ParrotMood.happy
                                : ParrotMood.encourage,
                            size: 170,
                            talking: talking,
                          ),
                          if (replay != null)
                            IconButton.filledTonal(
                              tooltip: l10n.speechHearAgain,
                              onPressed: replay,
                              iconSize: 30,
                              icon: const Icon(Icons.volume_up_rounded),
                            ),
                        ],
                      ),
                    ),
                    if (mastered) ...[
                      const SizedBox(height: 4),
                      const StarRow(),
                    ],
                    const SizedBox(height: 12),
                    Text(title,
                        style: theme.textTheme.headlineLarge,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 6),
                      decoration: BoxDecoration(
                        color: mastered ? SpeechColors.mint : SpeechColors.sky,
                        borderRadius: BorderRadius.circular(SpeechTheme.radius),
                      ),
                      child: Text(word.text,
                          style: theme.textTheme.displaySmall!
                              .copyWith(height: 1.3)),
                    ),
                    const SizedBox(height: 16),
                    Text(body,
                        style: theme.textTheme.titleMedium,
                        textAlign: TextAlign.center),
                    if (!mastered && practiseLater.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final u in practiseLater)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: SpeechColors.peach,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: ExcludeSemantics(
                                child: Text(u,
                                    style: theme.textTheme.headlineSmall),
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (cardUnlocked) ...[
                      const SizedBox(height: 24),
                      CardReveal(label: l10n.speechCardUnlocked),
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
                            icon: const Icon(Icons.replay_rounded),
                            label: Text(l10n.speechTryAgain),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => Navigator.of(context).pop(true),
                            icon: const Icon(Icons.arrow_forward_rounded),
                            label: Text(l10n.speechNextWord),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (mastered) const Positioned.fill(child: ConfettiBurst()),
          ],
        ),
      );
    }));
  }
}
