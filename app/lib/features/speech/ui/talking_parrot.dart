import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/app_localizations.dart';
import '../audio/speech_voice.dart';
import 'parrot.dart';
import 'speech_widgets.dart';

/// Speaks [lines] once whenever [speakKey] changes (in the app language), and stops when it leaves
/// the screen. [builder] gets whether the voice is talking and a replay callback (null when
/// there is nothing to say). [onSpoken] runs after the automatic speech finishes (or straight away
/// when muted), e.g. to play the model audio after "Listen carefully".
class SpokenLines extends ConsumerStatefulWidget {
  const SpokenLines({
    super.key,
    required this.lines,
    required this.speakKey,
    required this.builder,
    this.active = true,
    this.onSpoken,
  });

  /// What to say; empty = stay quiet (e.g. while the child is recording).
  final List<VoiceLine> lines;

  /// Identity of what is being said; speech happens again only when this changes.
  final String speakKey;

  /// Only speak while visible (tabs in the home shell stay mounted in the background).
  final bool active;
  final VoidCallback? onSpoken;
  final Widget Function(
      BuildContext context, bool talking, VoidCallback? replay) builder;

  @override
  ConsumerState<SpokenLines> createState() => _SpokenLinesState();
}

class _SpokenLinesState extends ConsumerState<SpokenLines> {
  String? _spokenKey;
  late final SpeechVoice _voice = ref.read(speechVoiceProvider);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _schedule(); // also runs when the app language changes
  }

  @override
  void didUpdateWidget(SpokenLines old) {
    super.didUpdateWidget(old);
    if (old.active && !widget.active) {
      _voice.stop();
      _spokenKey = null; // speak again when the tab comes back
    }
    _schedule();
  }

  void _schedule() {
    // The language is part of the key: switching the app language says it again in the new one.
    final key = '${_lang()}|${widget.speakKey}';
    if (!widget.active || key == _spokenKey) return;
    _spokenKey = key;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || _spokenKey != key) return;
      if (widget.lines.isNotEmpty) {
        await _voice.say(widget.lines, _lang());
      }
      if (mounted && _spokenKey == key) widget.onSpoken?.call();
    });
  }

  String _lang() => Localizations.localeOf(context).languageCode;

  @override
  void dispose() {
    _voice.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: _voice.speaking,
      builder: (context, speaking, _) => widget.builder(
        context,
        speaking && widget.active,
        widget.lines.isEmpty
            ? null
            : () => _voice.say(widget.lines, _lang(), auto: false),
      ),
    );
  }
}

/// [ParrotSays] that speaks its lines (see [SpokenLines]), moves its beak while talking and shows
/// a replay button on the bubble.
class TalkingParrot extends StatelessWidget {
  const TalkingParrot({
    super.key,
    required this.text,
    required this.lines,
    required this.speakKey,
    this.mood = ParrotMood.idle,
    this.parrotSize = 104,
    this.active = true,
    this.onSpoken,
  });

  final String text;
  final List<VoiceLine> lines;
  final String speakKey;
  final ParrotMood mood;
  final double parrotSize;
  final bool active;
  final VoidCallback? onSpoken;

  @override
  Widget build(BuildContext context) {
    return SpokenLines(
      lines: lines,
      speakKey: speakKey,
      active: active,
      onSpoken: onSpoken,
      builder: (context, talking, replay) => ParrotSays(
        text: text,
        mood: mood,
        parrotSize: parrotSize,
        talking: talking,
        onReplay: replay,
        replayLabel: AppLocalizations.of(context).speechHearAgain,
      ),
    );
  }
}

/// App-bar toggle for the parrot's automatic speech.
class VoiceToggleButton extends ConsumerWidget {
  const VoiceToggleButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final on = ref.watch(speechAutoSpeakProvider);
    return IconButton(
      tooltip: on ? l10n.speechVoiceOff : l10n.speechVoiceOn,
      icon: Icon(on ? Icons.volume_up_rounded : Icons.volume_off_rounded),
      onPressed: () => ref.read(speechAutoSpeakProvider.notifier).state = !on,
    );
  }
}
