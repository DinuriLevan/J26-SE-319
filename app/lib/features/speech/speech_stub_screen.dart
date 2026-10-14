import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_drawer.dart';
import 'data/speech_words.dart';
import 'screens/speech_word_screen.dart';

/// Entry point of the Speech & Pronunciation tab. The file/class name is kept as-is because the
/// home shell references it (docs/CONTRIBUTING.md); it now shows the word list.
class SpeechStubScreen extends StatelessWidget {
  const SpeechStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
          leading: const DrawerMenuButton(), title: Text(l10n.speechTitle)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
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
                  for (final (i, word) in speechDemoWords.indexed)
                    Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  SpeechWordScreen(initialIndex: i)),
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
        ),
      ),
    );
  }
}
