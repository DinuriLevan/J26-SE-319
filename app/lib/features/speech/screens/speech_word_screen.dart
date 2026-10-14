import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../profile/providers/profile_providers.dart';
import '../data/speech_api.dart';
import '../data/speech_recorder.dart';
import '../data/speech_words.dart';
import 'speech_result_screen.dart';

enum _Phase { idle, recording, checking }

/// Shows one word; the child taps the mic, says it, taps again (or it auto-stops), and gets feedback.
class SpeechWordScreen extends ConsumerStatefulWidget {
  const SpeechWordScreen({super.key, required this.initialIndex});

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

  SpeechWord get _word => speechDemoWords[_index];

  @override
  void dispose() {
    _autoStop?.cancel();
    super.dispose();
  }

  Future<void> _onMicTap() async {
    final l10n = AppLocalizations.of(context);
    final recorder = ref.read(speechRecorderProvider);

    if (_phase == _Phase.recording) return _stopAndAssess();
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

    try {
      await recorder.start();
    } catch (_) {
      if (mounted) setState(() => _message = l10n.speechSomethingWrong);
      return;
    }
    if (!mounted) return;
    _autoStop = Timer(SpeechRecorder.maxDuration, _stopAndAssess);
    setState(() {
      _phase = _Phase.recording;
      _message = null;
      _offerSettings = false;
    });
  }

  Future<void> _stopAndAssess() async {
    if (_phase != _Phase.recording) return;
    _autoStop?.cancel();
    final l10n = AppLocalizations.of(context);
    setState(() => _phase = _Phase.checking);

    final path = await ref.read(speechRecorderProvider).stop();
    final childId = ref.read(activeChildIdProvider);
    if (path == null || childId == null) {
      setState(() {
        _phase = _Phase.idle;
        _message = l10n.speechSomethingWrong;
      });
      return;
    }

    try {
      final result = await ref.read(speechApiProvider).assess(
            audioPath: path,
            word: _word,
            childId: childId,
          );
      await _recordActivity(childId, result);
      if (!mounted) return;
      setState(() => _phase = _Phase.idle);
      final next = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
            builder: (_) => SpeechResultScreen(word: _word, result: result)),
      );
      if (next == true && mounted) {
        setState(() => _index = (_index + 1) % speechDemoWords.length);
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
    }
  }

  /// One shared ActivityResult per scored word, via the offline queue (docs/CONTRIBUTING.md).
  Future<void> _recordActivity(String childId, AssessResult result) async {
    await ref.read(appDatabaseProvider).pendingActivityResultDao.enqueue(
          childId: childId,
          componentName: 'speech',
          activityId: 'speech_word:${result.wordId}',
          resultPayload: jsonEncode(result.toActivityPayload()),
        );
    unawaited(ref.read(syncServiceProvider).flushPendingResults());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Watching keeps the autoDispose recorder alive for as long as this screen is mounted;
    // with only ref.read it would be disposed straight after creation.
    ref.watch(speechRecorderProvider);
    final recording = _phase == _Phase.recording;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.speechTitle)),
      body: SafeArea(
        child: Container(
          width: double.infinity, // centre content across the full screen width
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Text(_word.text,
                  style: theme.textTheme.displayMedium,
                  textAlign: TextAlign.center),
              const Spacer(),
              if (_phase == _Phase.checking)
                const SizedBox(
                    width: 96, height: 96, child: CircularProgressIndicator())
              else
                SizedBox(
                  width: 120,
                  height: 120,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      backgroundColor:
                          recording ? theme.colorScheme.error : null,
                    ),
                    onPressed: _onMicTap,
                    child: Icon(recording ? Icons.stop : Icons.mic, size: 56),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                switch (_phase) {
                  _Phase.idle => l10n.speechTapToRecord,
                  _Phase.recording => l10n.speechRecording,
                  _Phase.checking => l10n.speechChecking,
                },
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(_message!,
                    style: theme.textTheme.bodyLarge,
                    textAlign: TextAlign.center),
                if (_offerSettings)
                  TextButton(
                      onPressed: openAppSettings,
                      child: Text(l10n.speechOpenSettings)),
              ],
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}
