import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../l10n/app_localizations.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/speech_api.dart';
import '../data/speech_progress_store.dart';
import '../data/speech_recorder.dart';
import '../data/speech_words.dart';
import '../logic/retry_loop.dart';
import '../logic/speech_rewards.dart';
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
      } else if (loop.step.kind == StepKind.listen) {
        unawaited(_playListen());
      }
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
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Watching keeps the autoDispose recorder alive for as long as this screen is mounted.
    ref.watch(speechRecorderProvider);
    final words = ref.watch(speechWordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.speechTitle),
        actions: [
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
          loading: () => _centered(theme, l10n.speechLoading, spinner: true),
          error: (_, __) => _centered(theme, l10n.speechSomethingWrong,
              action: TextButton(
                onPressed: () => ref.invalidate(speechWordsProvider),
                child: Text(l10n.speechTryAgain),
              )),
          data: (map) {
            _ensureLoop(map);
            if (_loop == null) {
              return _centered(theme, l10n.speechSomethingWrong);
            }
            return _stepBody(context, l10n, theme);
          },
        ),
      ),
    );
  }

  Widget _centered(ThemeData theme, String text,
      {bool spinner = false, Widget? action}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (spinner) const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(text,
              style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _stepBody(
      BuildContext context, AppLocalizations l10n, ThemeData theme) {
    final step = _step!;
    final recording = _phase == _Phase.recording;
    final isListen = step.kind == StepKind.listen;

    final instruction = switch (step.kind) {
      StepKind.fullWord when step.tryNo > 1 => l10n.speechWholeWordAgain,
      StepKind.fullWord => l10n.speechTapToRecord,
      StepKind.listen => l10n.speechListen,
      StepKind.sayUnit => l10n.speechSaySound,
      StepKind.blend => l10n.speechBlend,
      _ => '',
    };

    return Container(
      width: double.infinity, // centre content across the full screen width
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          if (_refSpeaker != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: Colors.orange.shade100,
              child: Text(
                'DEV: recordings are saved as adult references for '
                '"$_refSpeaker", not scored.',
                textAlign: TextAlign.center,
              ),
            ),
          const Spacer(),
          _WordWithHighlight(
            units: _info!.units,
            highlightStart: step.spanStart,
            highlightEnd: step.spanEnd,
            style: theme.textTheme.displayMedium!,
            highlightColor: theme.colorScheme.primary,
          ),
          if (step.spanStart != null) ...[
            const SizedBox(height: 12),
            Text(
              _info!.spanLabel(step.spanStart!, step.spanEnd!),
              style: theme.textTheme.displayLarge!
                  .copyWith(color: theme.colorScheme.primary),
            ),
          ],
          const Spacer(),
          if (isListen)
            Column(
              children: [
                SizedBox(
                  width: 120,
                  height: 120,
                  child: FilledButton(
                    style: FilledButton.styleFrom(shape: const CircleBorder()),
                    onPressed: _playListen,
                    child: const Icon(Icons.volume_up, size: 56),
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  onPressed: _onListened,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(l10n.speechNext),
                ),
              ],
            )
          else if (_phase == _Phase.checking)
            const SizedBox(
                width: 96, height: 96, child: CircularProgressIndicator())
          else
            SizedBox(
              width: 120,
              height: 120,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  backgroundColor: recording ? theme.colorScheme.error : null,
                ),
                onPressed: _onMicTap,
                child: Icon(recording ? Icons.stop : Icons.mic, size: 56),
              ),
            ),
          const SizedBox(height: 16),
          Text(
            recording
                ? l10n.speechRecording
                : _phase == _Phase.checking
                    ? l10n.speechChecking
                    : instruction,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          if (_message != null) ...[
            const SizedBox(height: 16),
            Text(_message!,
                style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            if (_offerSettings)
              TextButton(
                  onPressed: openAppSettings,
                  child: Text(l10n.speechOpenSettings)),
          ],
          const Spacer(),
        ],
      ),
    );
  }
}

/// The word with the units being practised highlighted (e.g. අ[ම්මා]).
class _WordWithHighlight extends StatelessWidget {
  const _WordWithHighlight({
    required this.units,
    required this.highlightStart,
    required this.highlightEnd,
    required this.style,
    required this.highlightColor,
  });

  final List<String> units;
  final int? highlightStart;
  final int? highlightEnd;
  final TextStyle style;
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    final a = highlightStart, b = highlightEnd;
    return Text.rich(
      TextSpan(children: [
        for (var i = 0; i < units.length; i++)
          TextSpan(
            text: units[i],
            style: a != null && i >= a && i <= b!
                ? style.copyWith(
                    color: highlightColor, decoration: TextDecoration.underline)
                : style,
          ),
      ]),
      textAlign: TextAlign.center,
    );
  }
}
