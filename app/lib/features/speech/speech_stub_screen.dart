import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../shared/widgets/app_drawer.dart';
import '../home_shell/providers/nav_providers.dart';
import 'audio/speech_voice.dart';
import 'data/speech_api.dart';
import 'data/speech_words.dart';
import 'screens/speech_word_screen.dart';
import 'ui/speech_theme.dart';
import 'ui/talking_parrot.dart';
import 'ui/word_tile.dart';

/// Position of this tab in HomeShellScreen's page list (Home, Math, Spelling, Writing, Speech).
/// The shell keeps every tab mounted, so the parrot only speaks while this tab is selected.
const _speechTabIndex = 4;

final _speechTabActiveProvider =
    Provider<bool>((ref) => ref.watch(selectedTabProvider) == _speechTabIndex);

/// Entry point of the Speech & Pronunciation tab. The file/class name is kept as-is because the
/// home shell references it (docs/CONTRIBUTING.md). It first asks which language to practise
/// (Sinhala or English), then shows that language's words.
class SpeechStubScreen extends ConsumerWidget {
  const SpeechStubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SpeechThemed(child: Builder(builder: (context) {
      final l10n = AppLocalizations.of(context);
      final language = ref.watch(speechLanguageProvider);
      return Scaffold(
        appBar: AppBar(
          leading: const DrawerMenuButton(),
          title: Text(l10n.speechTitle),
          actions: [
            const VoiceToggleButton(),
            if (language != null)
              IconButton(
                tooltip: l10n.speechChangeLanguage,
                icon: const Icon(Icons.translate_rounded),
                onPressed: () =>
                    ref.read(speechLanguageProvider.notifier).state = null,
              ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: language == null
                ? const _LanguageChoice()
                : _WordList(words: speechWordsFor(language)),
          ),
        ),
      );
    }));
  }
}

/// The parrot asks "Which language do you want to practise?"; two big cards, each named in its
/// own script with its first letter in a circle.
class _LanguageChoice extends ConsumerWidget {
  const _LanguageChoice();

  static const _languages = [
    ('si', 'සිංහල', 'අ', SpeechColors.peach),
    ('en', 'English', 'A', SpeechColors.sky),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TalkingParrot(
          text: l10n.speechChooseLanguage,
          lines: [VoiceLine('speechChooseLanguage', l10n.speechChooseLanguage)],
          speakKey: 'choose-language',
          active: ref.watch(_speechTabActiveProvider),
          parrotSize: 110,
        ),
        const SizedBox(height: 20),
        for (final (code, name, letter, colour) in _languages) ...[
          Expanded(
            child: Semantics(
              button: true,
              label: name,
              excludeSemantics: true,
              child: Material(
                color: colour,
                borderRadius: BorderRadius.circular(SpeechTheme.radius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(SpeechTheme.radius),
                  onTap: () =>
                      ref.read(speechLanguageProvider.notifier).state = code,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 104,
                          height: 104,
                          decoration: const BoxDecoration(
                            color: SpeechColors.paper,
                            shape: BoxShape.circle,
                            boxShadow: speechShadow,
                          ),
                          child: Center(
                            child: Text(letter,
                                style: theme.textTheme.displayMedium!.copyWith(
                                    color: SpeechColors.coralDeep,
                                    height: 1.2)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(name, style: theme.textTheme.headlineMedium),
                      ],
                    ),
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

/// The chosen language's words grouped by level, easiest first: Level 1 ★, Level 2 ★★, Level 3 ★★★.
/// Children see only words that are ready (enough reference recordings); debug builds also show
/// the others, greyed, so a developer can record adult references for them.
class _WordList extends ConsumerWidget {
  const _WordList({required this.words});

  /// All words of the chosen language, ordered easiest first.
  final List<SpeechWord> words;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(speechWordsProvider);
    if (info.isLoading) return const Center(child: CircularProgressIndicator());
    final map = info.valueOrNull; // null on error: fall back to the static list
    final shown = practiceWords(words, map,
        showUnready: ref.watch(speechShowUnreadyWordsProvider));
    // "Next word" in the practice screen only moves through words a child can practise.
    final playable = practiceWords(words, map, showUnready: false);
    return _LevelGrid(
        words: shown,
        playable: playable,
        info: map,
        active: ref.watch(_speechTabActiveProvider));
  }
}

class _LevelGrid extends StatelessWidget {
  const _LevelGrid(
      {required this.words,
      required this.playable,
      this.info,
      this.active = true});

  final List<SpeechWord> words;
  final List<SpeechWord> playable;
  final Map<String, WordInfo>? info;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final levels = {for (final w in words) w.level}.toList()..sort();

    return ListView(
      children: [
        TalkingParrot(
          text: l10n.speechChooseWord,
          lines: [VoiceLine('speechChooseWord', l10n.speechChooseWord)],
          speakKey: 'choose-word:${words.isEmpty ? '' : words.first.language}',
          active: active,
          parrotSize: 84,
        ),
        for (final level in levels) ...[
          const SizedBox(height: 20),
          _LevelRibbon(level: level, label: l10n.speechLevel(level)),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              for (final word in words)
                if (word.level == level) _tile(context, word),
            ],
          ),
        ],
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _tile(BuildContext context, SpeechWord word) {
    final ready = info == null || isWordReady(info![word.id]);
    final index = playable.indexOf(word);
    return WordTile(
      text: word.text,
      level: word.level,
      ready: ready,
      // Developer-only badge (unready words are never shown to children).
      badge: ready
          ? null
          : 'needs recordings ${info![word.id]?.nRefs ?? 0}/$speechMinRefs',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SpeechWordScreen(
            // Unready words (developers only) open on their own so references can be recorded.
            words: ready && index >= 0 ? playable : [word],
            initialIndex: ready && index >= 0 ? index : 0,
          ),
        ),
      ),
    );
  }
}

class _LevelRibbon extends StatelessWidget {
  const _LevelRibbon({required this.level, required this.label});

  final int level;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: SpeechColors.levelDeep(level),
          borderRadius: BorderRadius.circular(40),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: theme.textTheme.titleLarge),
            const SizedBox(width: 8),
            for (var i = 0; i < level; i++)
              const Icon(Icons.star_rounded, color: SpeechColors.sun, size: 24),
          ],
        ),
      ),
    );
  }
}
