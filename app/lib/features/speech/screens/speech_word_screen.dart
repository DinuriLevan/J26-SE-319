import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../l10n/app_localizations.dart';
import '../../profile/providers/profile_providers.dart';
import '../audio/speech_voice.dart';
import '../data/speech_api.dart';
import '../data/speech_progress_store.dart';
import '../data/speech_recorder.dart';
import '../data/speech_words.dart';
import '../logic/retry_loop.dart';
import '../logic/speech_rewards.dart';
import '../ui/parrot.dart';
import '../ui/speech_theme.dart';
import '../ui/speech_widgets.dart';
import '../ui/talking_parrot.dart';
import '../ui/word_picture.dart';
import 'speech_result_screen.dart';

enum _Phase { idle, recording, checking }

/// Practises one word with the remediation loop (logic/retry_loop.dart):
/// say the word -> if not accepted, for the worst 1-2 units: Listen -> Say the sound -> Blend ->
/// say the whole word again. Feedback is always encouraging; numbers are never shown to the child.
class SpeechWordScreen extends ConsumerStatefulWidget {
  const SpeechWordScreen(
      {super.key, required this.words, required this.initialIndex});

  /// The words of the chosen practice language; "next word" cycles through these.
  final List<SpeechWord> words;
  final int initialIndex;

  @override
  ConsumerState<SpeechWordScreen> createState() => _SpeechWordScreenState();
}

class _SpeechWordScreenState extends ConsumerState<SpeechWordScreen> {
  late int _index = widget.initialIndex;
  _Phase _phase = _Phase.idle;
  String? _message;
  bool _offerSettings = false;
  Timer? _autoStop;

  RetryLoop? _loop;
  WordInfo? _info;
  double? _lastScore;
  final AudioPlayer _player = AudioPlayer();
  final Map<String, String?> _listenCache = {};

  /// Debug builds only: when set, recordings are saved as adult references for this speaker
  /// instead of being scored (see _toggleReferenceMode). Always null in release builds.
  String? _refSpeaker;

  SpeechWord get _word => widget.words[_index];
  RetryStep? get _step => _loop?.step;

  @override
  void dispose() {
    _autoStop?.cancel();
    _player.dispose();
    super.dispose();
  }

  // ---- loop setup -------------------------------------------------------------------------

  void _startLoop(WordInfo info) {
    _info = info;
    _loop = RetryLoop(info.units.length, listenUnits: info.listenUnits);
    _lastScore = null;
  }

  void _ensureLoop(Map<String, WordInfo> words) {
    final info = words[_word.id];
    if (info != null && (_loop == null || _info?.wordId != _word.id)) {
      _startLoop(info);
    }
  }

  // ---- recording ----------------------------------------------------------------------------

  Future<void> _onMicTap() async {
    final l10n = AppLocalizations.of(context);
    final recorder = ref.read(speechRecorderProvider);

    if (_phase == _Phase.recording) return _stopAndScore();
    if (_phase != _Phase.idle) return;

    final permission = await recorder.ensurePermission();
    if (!mounted) return;
    if (permission != MicPermission.granted) {
      setState(() {
        _message = l10n.speechMicNeeded;
        _offerSettings = permission == MicPermission.permanentlyDenied;
      });
      return;
    }
    await _player.stop();
    await ref.read(speechVoiceProvider).stop(); // never talk over the child
    try {
      await recorder.start();
    } catch (_) {
      if (mounted) setState(() => _message = l10n.speechSomethingWrong);
      return;
    }
    if (!mounted) return;
    _autoStop = Timer(SpeechRecorder.maxDuration, _stopAndScore);
    setState(() {
      _phase = _Phase.recording;
      _message = null;
      _offerSettings = false;
    });
  }

  Future<void> _stopAndScore() async {
    if (_phase != _Phase.recording) return;
    _autoStop?.cancel();
    final l10n = AppLocalizations.of(context);
    setState(() => _phase = _Phase.checking);

    final path = await ref.read(speechRecorderProvider).stop();
    final childId = ref.read(activeChildIdProvider);
    final loop = _loop;
    if (path == null || childId == null || loop == null) {
      setState(() {
        _phase = _Phase.idle;
        _message = l10n.speechSomethingWrong;
      });
      return;
    }

    try {
      if (_refSpeaker != null) {
        await _saveReference(path, _refSpeaker!);
        return;
      }
      final api = ref.read(speechApiProvider);
      final step = loop.step;
      bool passed;
      switch (step.kind) {
        case StepKind.fullWord:
          final r =
              await api.assess(audioPath: path, word: _word, childId: childId);
          _lastScore = r.score;
          final flagged = [
            for (final u in r.flaggedUnits) r.segments.indexOf(u),
          ];
          loop.onFullWord(accepted: r.accepted, flagged: flagged);
          passed = r.accepted;
        case StepKind.sayUnit:
        case StepKind.blend:
          final r = await api.assessUnit(
            audioPath: path,
            word: _word,
            start: step.spanStart!,
            end: step.spanEnd!,
            childId: childId,
          );
          step.kind == StepKind.sayUnit
              ? loop.onUnit(passed: r.accepted)
              : loop.onBlend(passed: r.accepted);
          passed = r.accepted;
        default:
          throw StateError('No recording expected in ${step.kind}');
      }
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _message = passed ? l10n.speechStepWellDone : l10n.speechStepOnceMore;
      });
      if (loop.done) {
        await _finishWord(childId, loop);
      }
      // The Listen step's model audio starts after the parrot has said "Listen carefully"
      // (TalkingParrot.onSpoken in _stepBody).
    } on AssessException catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _message = switch (e.failure) {
          AssessFailure.couldNotHear => l10n.speechCouldNotHear,
          _ => l10n.speechSomethingWrong,
        };
      });
    } finally {
      // Never keep the child's recording on the device longer than needed.
      final file = File(path);
      if (await file.exists()) await file.delete();
      if (mounted && _phase == _Phase.checking) {
        setState(() => _phase = _Phase.idle);
      }
    }
  }

  // ---- listen step ------------------------------------------------------------------------

  Future<void> _playListen() async {
    final step = _step;
    if (step == null || step.kind != StepKind.listen) return;
    final key = '${_word.id}:${step.spanStart}-${step.spanEnd}';
    try {
      final path = _listenCache.containsKey(key)
          ? _listenCache[key]
          : _listenCache[key] = await ref
              .read(speechApiProvider)
              .listen(_word, start: step.spanStart, end: step.spanEnd);
      if (path == null) {
        // No adult model audio after all: go straight to saying the sound.
        if (mounted) setState(() => _loop!.onListened());
        return;
      }
      await _player.setFilePath(path);
      await _player.play();
    } catch (_) {
      if (mounted) {
        setState(
            () => _message = AppLocalizations.of(context).speechSomethingWrong);
      }
    }
  }

  /// "Hear before saying": plays the whole word, or units [start]..[end], when the child taps.
  /// The adult recording is used when one exists; otherwise text-to-speech in the word's language,
  /// except for English units: TTS reads a lone letter by its name ("c" -> "see"), which would
  /// teach the wrong sound, so those need a recording.
  Future<void> _hear({int? start, int? end}) async {
    final info = _info;
    if (info == null || _phase != _Phase.idle) return;
    final word = _word;
    final unit = start != null;
    final hasRecording = unit
        ? [for (var i = start; i <= end!; i++) i]
            .every(info.listenUnits.contains)
        : info.hasWordAudio;
    final key = '${word.id}:$start-$end';
    await _player.stop();
    await ref.read(speechVoiceProvider).playModel(
          fetchRecording: () async {
            if (!hasRecording) return null;
            if (!_listenCache.containsKey(key)) {
              _listenCache[key] = await ref
                  .read(speechApiProvider)
                  .listen(word, start: start, end: end);
            }
            return _listenCache[key];
          },
          ttsText: unit ? info.spanLabel(start, end!) : word.text,
          lang: word.language,
          allowTts: !unit || word.language == 'si',
        );
  }

  /// Tiles the child can tap to hear (see [_hear] for the English-letter rule).
  bool _canHearUnit(int i) =>
      _info!.listenUnits.contains(i) || _word.language == 'si';

  void _onListened() {
    _player.stop();
    setState(() {
      _loop!.onListened();
      _message = null;
    });
  }

  // ---- end of word ------------------------------------------------------------------------

  Future<void> _finishWord(String childId, RetryLoop loop) async {
    final store = ref.read(speechProgressStoreProvider);
    final info = _info!;
    final mastered = loop.step.kind == StepKind.reward;
    await store.recordCompletedWord(
      childId,
      completedWordPayload(
          wordId: _word.id,
          loop: loop,
          units: info.units,
          lastScore: _lastScore),
    );
    final card =
        mastered ? await store.unlockMilestoneIfReached(childId) : null;
    if (!mounted) return;
    final next = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SpeechResultScreen(
          word: _word,
          mastered: mastered,
          cardUnlocked: card != null,
          practiseLater: [for (final u in loop.scheduledUnits) info.units[u]],
          debugLine: kDebugMode
              ? 'last score ${_lastScore?.toStringAsFixed(3)} · '
                  '${loop.events.length} events · card $card'
              : null,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      if (next == true) _index = (_index + 1) % widget.words.length;
      _loop = null; // a fresh loop for the next (or same) word
      _message = null;
    });
  }

  // ---- developer tool: adult references -----------------------------------------------------

  /// DEVELOPER TOOL: upload the recording as an adult reference instead of scoring it.
  Future<void> _saveReference(String path, String speakerId) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final r = await ref.read(speechApiProvider).addReference(
            audioPath: path,
            word: _word,
            speakerId: speakerId,
          );
      ref.invalidate(speechWordsProvider); // listen audio may now exist
      _listenCache.clear();
      messenger.showSnackBar(SnackBar(
        content: Text('Saved ${r['ref_id']} · ${r['n_refs']} refs from '
            '${r['n_speakers']} speakers · threshold ${r['threshold']} '
            '(${r['threshold_source']})'),
      ));
    } on AssessException catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text('Reference not saved: ${e.detail ?? e.failure.name}'),
      ));
    } finally {
      if (mounted) setState(() => _phase = _Phase.idle);
    }
  }

  /// DEVELOPER TOOL: switch reference-recording mode on (asks for the adult speaker id) or off.
  Future<void> _toggleReferenceMode() async {
    if (_refSpeaker != null) {
      setState(() => _refSpeaker = null);
      return;
    }
    final controller = TextEditingController(text: 'adult_01');
    final speaker = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record adult references (dev)'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Speaker id (a-z, 0-9, _)',
            helperText: 'Adults only. Use a different id for each person.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Start')),
        ],
      ),
    );
    controller.dispose();
    if (speaker == null || !RegExp(r'^[a-z0-9_]{1,32}$').hasMatch(speaker)) {
      return;
    }
    if (mounted) setState(() => _refSpeaker = speaker);
  }

  // ---- UI -------------------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Watching keeps the autoDispose recorder alive for as long as this screen is mounted.
    ref.watch(speechRecorderProvider);
    final words = ref.watch(speechWordsProvider);

    return SpeechThemed(child: Builder(builder: (context) {
      final l10n = AppLocalizations.of(context);
      final theme = Theme.of(context);
      return Scaffold(
        appBar: AppBar(
          title: Text(l10n.speechTitle),
          actions: [
            const VoiceToggleButton(),
            if (kDebugMode)
              IconButton(
                tooltip: 'Record adult references (dev)',
                icon: Icon(_refSpeaker == null
                    ? Icons.library_add_outlined
                    : Icons.library_add_check),
                onPressed: _phase == _Phase.idle ? _toggleReferenceMode : null,
              ),
          ],
        ),
        body: SafeArea(
          child: words.when(
            loading: () =>
                _centered(theme, l10n.speechLoading, mood: ParrotMood.thinking),
            error: (_, __) => _centered(theme, l10n.speechSomethingWrong,
                mood: ParrotMood.encourage,
                action: OutlinedButton(
                  onPressed: () => ref.invalidate(speechWordsProvider),
                  child: Text(l10n.speechTryAgain),
                )),
            data: (map) {
              _ensureLoop(map);
              if (_loop == null) {
                return _centered(theme, l10n.speechSomethingWrong,
                    mood: ParrotMood.encourage);
              }
              return _stepBody(context, l10n, theme);
            },
          ),
        ),
      );
    }));
  }

  Widget _centered(ThemeData theme, String text,
      {ParrotMood mood = ParrotMood.idle, Widget? action}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ParrotBuddy(mood: mood, size: 140),
            const SizedBox(height: 16),
            Text(text,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action],
          ],
        ),
      ),
    );
  }

  /// The parrot's mood follows what is happening: listening while recording, thinking while
  /// checking, happy after a pass, encouraging after "once more".
  ParrotMood _mood(AppLocalizations l10n) {
    if (_phase == _Phase.recording) return ParrotMood.listening;
    if (_phase == _Phase.checking) return ParrotMood.thinking;
    if (_message == l10n.speechStepWellDone) return ParrotMood.happy;
    if (_message != null) return ParrotMood.encourage;
    return ParrotMood.idle;
  }

  /// What the parrot says aloud: feedback first, then the instruction. Silent while recording
  /// or checking, and once the word is finished (the result screen speaks then).
  List<VoiceLine> _voiceLines(
      AppLocalizations l10n, RetryStep step, String instruction) {
    if (_phase != _Phase.idle || _loop!.done) return const [];
    final messageKey = {
      l10n.speechStepWellDone: 'speechStepWellDone',
      l10n.speechStepOnceMore: 'speechStepOnceMore',
      l10n.speechCouldNotHear: 'speechCouldNotHear',
      l10n.speechMicNeeded: 'speechMicNeeded',
      l10n.speechSomethingWrong: 'speechSomethingWrong',
    }[_message];
    final instructionKey = switch (step.kind) {
      StepKind.fullWord when step.tryNo > 1 => 'speechWholeWordAgain',
      StepKind.fullWord => 'speechTapToRecord',
      StepKind.listen => 'speechListen',
      StepKind.sayUnit => 'speechSaySound',
      StepKind.blend => 'speechBlend',
      _ => null,
    };
    return [
      if (messageKey != null) VoiceLine(messageKey, _message!),
      if (instructionKey != null) VoiceLine(instructionKey, instruction),
    ];
  }

  Widget _stepBody(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    final step = _step!;
    final recording = _phase == _Phase.recording;
    final isListen = step.kind == StepKind.listen;
    final remediating = step.kind != StepKind.fullWord || step.tryNo > 1;

    final instruction = switch (step.kind) {
      StepKind.fullWord when step.tryNo > 1 => l10n.speechWholeWordAgain,
      StepKind.fullWord => l10n.speechTapToRecord,
      StepKind.listen => l10n.speechListen,
      StepKind.sayUnit => l10n.speechSaySound,
      StepKind.blend => l10n.speechBlend,
      _ => '',
    };
    final bubble = recording
        ? l10n.speechRecording
        : _phase == _Phase.checking
            ? l10n.speechChecking
            : _message == null
                ? instruction
                : '$_message\n$instruction';

    return FillOrScroll(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        children: [
          if (_refSpeaker != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: SpeechColors.butter,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'DEV: recordings are saved as adult references for '
                '"$_refSpeaker", not scored.',
                textAlign: TextAlign.center,
              ),
            ),
          TalkingParrot(
            text: bubble,
            mood: _mood(l10n),
            lines: _voiceLines(l10n, step, instruction),
            speakKey: '${_word.id}|${stepKindName(step.kind)}|${step.unit}|'
                '${step.tryNo}|${_phase.name}|$_message',
            onSpoken: isListen ? _playListen : null,
          ),
          if (_offerSettings)
            TextButton(
                onPressed: openAppSettings,
                child: Text(l10n.speechOpenSettings)),
          const Spacer(),
          if (remediating) ...[
            StepTrail(kind: step.kind),
            const SizedBox(height: 20),
          ],
          // The word's picture: big for the whole word, smaller while practising a sound so the
          // highlighted tiles stay the focus.
          WordPicture(
              wordId: _word.id, size: step.spanStart == null ? 120 : 72),
          const SizedBox(height: 16),
          SyllableTiles(
            onTapUnit: _phase == _Phase.idle && !isListen
                ? (i) => _hear(start: i, end: i)
                : null,
            canTapUnit: _canHearUnit,
            hearLabel: l10n.speechHearSound,
            units: _info!.units,
            targetStart: step.spanStart,
            targetEnd: step.spanEnd,
            fontSize: step.spanStart == null ? 64 : 48,
          ),
          if (step.spanStart != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              decoration: BoxDecoration(
                color: SpeechColors.peach,
                borderRadius: BorderRadius.circular(SpeechTheme.radius),
                boxShadow: speechShadow,
              ),
              child: Text(
                _info!.spanLabel(step.spanStart!, step.spanEnd!),
                style: theme.textTheme.displayLarge!
                    .copyWith(color: SpeechColors.navy, height: 1.25),
              ),
            ),
          ],
          if (!isListen) ...[
            const SizedBox(height: 20),
            // "Hear before saying": the whole word, or the sound being practised. Tap only, so
            // the first try stays a real reading attempt.
            FilledButton.tonalIcon(
              key: const ValueKey('hear_it'),
              style: FilledButton.styleFrom(
                backgroundColor: SpeechColors.sky,
                foregroundColor: SpeechColors.navy,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              ),
              onPressed: _phase == _Phase.idle
                  ? () => _hear(start: step.spanStart, end: step.spanEnd)
                  : null,
              icon: const Icon(Icons.hearing_rounded, size: 30),
              label: Text(l10n.speechHearWord),
            ),
          ],
          const Spacer(),
          if (isListen)
            Column(
              children: [
                StreamBuilder<PlayerState>(
                  stream: _player.playerStateStream,
                  builder: (context, snap) {
                    final st = snap.data;
                    final playing = st != null &&
                        st.playing &&
                        st.processingState != ProcessingState.completed;
                    return ListenButton(
                      playing: playing,
                      onPressed: _playListen,
                      label: l10n.speechPlayAgain,
                    );
                  },
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _onListened,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: Text(l10n.speechNext),
                ),
              ],
            )
          else
            MicButton(
              recording: recording,
              label: recording ? l10n.speechRecording : instruction,
              onPressed: _phase == _Phase.checking ? null : _onMicTap,
            ),
        ],
      ),
    );
  }
}
