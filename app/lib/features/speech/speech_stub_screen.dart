import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_drawer.dart';
import 'data/speech_words.dart';
import 'screens/speech_word_screen.dart';

/// Entry point of the Speech & Pronunciation tab. The file/class name is kept as-is because the
/// home shell references it (docs/CONTRIBUTING.md). It first asks which language to practise
/// (Sinhala or English), then shows that language's words.
class SpeechStubScreen extends ConsumerWidget {
  const SpeechStubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final language = ref.watch(speechLanguageProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: Text(l10n.speechTitle),
        actions: [
          if (language != null)
            IconButton(
              tooltip: l10n.speechChangeLanguage,
              icon: const Icon(Icons.translate),
              onPressed: () =>
                  ref.read(speechLanguageProvider.notifier).state = null,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: language == null
            ? const _LanguageChoice()
            : _WordList(words: speechWordsFor(language)),
      ),
    );
  }
}

/// "Which language do you want to practise?" with two big cards, each named in its own script.
class _LanguageChoice extends ConsumerWidget {
  const _LanguageChoice();

  static const _languages = [
    ('si', 'සිංහල', 'අ'),
    ('en', 'English', 'A'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Text(l10n.speechChooseLanguage,
            style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 24),
        for (final (code, name, letter) in _languages) ...[
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () =>
                    ref.read(speechLanguageProvider.notifier).state = code,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(letter,
                          style: theme.textTheme.displayLarge!
                              .copyWith(color: theme.colorScheme.primary)),
                      const SizedBox(height: 8),
                      Text(name, style: theme.textTheme.headlineMedium),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _WordList extends StatelessWidget {
  const _WordList({required this.words});

  final List<SpeechWord> words;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.speechChooseWord, style: theme.textTheme.titleMedium),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              for (final (i, word) in words.indexed)
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            SpeechWordScreen(words: words, initialIndex: i),
                      ),
                    ),
                    child: Center(
                      child: Text(word.text,
                          style: theme.textTheme.headlineMedium),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
