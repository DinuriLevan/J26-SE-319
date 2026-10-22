import '../../engine/event_logger.dart';
import '../../engine/spelling_config.dart';
import '../data/sinhala_progress.dart';
import '../data/sinhala_word_bank.dart';
import 'sinhala_errors.dart';
import 'sinhala_learner.dart';

/// Columns of the Sinhala features CSV, in order. The Python pipeline uses
/// the same names (ml/spelling/spell_common.py, SI_FEATURE_COLUMNS).
const sinhalaFeatureColumns = [
  'childId', 'sessionId', 'roundNo', 'wordIndex', 'word_id', 'word', 'phonics_skill',
  'skill_stage', 'difficulty', 'timestamp', 'mode',
  'first_input_ms', 'total_ms', 'mean_gap_ms', 'max_gap_ms', 'paused_ms', 'replays', 'motor_slips',
  'corrections', 'n_insertions', 'n_deletions', 'n_replacements', 'n_reorders', 'distractor_picks',
  'answer_length_diff', 'attempts', 'correct_first_try', 'final_correct', 'hesitation_ratio',
  'pause_ratio', 'first_wrong_answer', 'edit_distance', ...SinhalaError.all,
  'n_aksharas', 'n_marks', 'evidence_weight', 'p_before', 'p_after',
  // The difficulty classifier's prediction for this word.
  'clf_label', 'clf_p_hard', 'clf_source',
];

/// Turns one word's events into its feature row (FR2).
///
/// Events (logged by the Sinhala game controller):
///   TILE_PLACE {tile, mark, index | onAkshara, replaced}  a letter onto the line or a pilla onto a letter
///   TILE_MOVE  {tile, msSincePlaced}                       a letter moved along the line / a pilla to another letter
///   TILE_REMOVE {tile, msSincePlaced}                      back to the tray
///   CHECK {answer, correct, attemptNo, aksharas}           ✓ pressed
/// plus AUDIO_START / AUDIO_END / REPLAY / PAUSE / RESUME / WORD_END.
///
/// Timing is active time only (the logger's clock stops while paused). The
/// child's speed is compared with their own earlier words.
Map<String, Object?> featurizeSinhala({
  required List<SpellingEvent> events,
  required SinhalaWord word,
  required SinhalaProgress progress,
  required String sessionId,
  required int roundNo,
  required int wordIndex,
  required String mode,
  required Map<String, int> errors,
  String? firstWrongAnswer,
  DateTime? now,
}) {
  List<SpellingEvent> of(SpellingEventType t) => [for (final e in events) if (e.type == t) e];
  final audioStarts = of(SpellingEventType.audioStart);
  final audioEnds = of(SpellingEventType.audioEnd);
  final places = of(SpellingEventType.tilePlace);
  final removes = of(SpellingEventType.tileRemove);
  final moves = of(SpellingEventType.tileMove);
  final checks = of(SpellingEventType.check);
  final first = events.isEmpty ? 0.0 : events.first.t;

  final firstAudioEnd = audioEnds.isNotEmpty ? audioEnds.first.t : (audioStarts.isNotEmpty ? audioStarts.first.t : first);
  final firstInput = places.isEmpty ? 0.0 : (places.first.t - firstAudioEnd).clamp(0.0, double.infinity);
  final start = audioStarts.isNotEmpty ? audioStarts.first.t : first;
  final end = checks.isNotEmpty ? checks.last.t : (events.isEmpty ? start : events.last.t);
  final gaps = [for (var i = 1; i < places.length; i++) places[i].t - places[i - 1].t];
  final meanGap = gaps.isEmpty ? 0.0 : gaps.reduce((a, b) => a + b) / gaps.length;
  final maxGap = gaps.isEmpty ? 0.0 : gaps.reduce((a, b) => a > b ? a : b);
  final pausedMs = of(SpellingEventType.resume)
      .fold<double>(0, (sum, e) => sum + ((e.data['pausedMs'] as num?)?.toDouble() ?? 0));

  double since(SpellingEvent e) => (e.data['msSincePlaced'] as num?)?.toDouble() ?? double.infinity;
  final slips = removes.where((e) => since(e) < SpellingConfig.slipMs).toList();
  final deletions = removes.length - slips.length;
  final reorders = moves.where((e) => since(e) >= SpellingConfig.slipMs).length;
  final replacements = [...places, ...moves].fold<int>(0, (n, e) => n + ((e.data['replaced'] as num?)?.toInt() ?? 0));
  // A slip's tile put straight back is not a new insertion.
  final slipTiles = [for (final e in slips) e.data['tile']];
  var insertions = 0;
  for (final e in places) {
    if (slipTiles.remove(e.data['tile'])) continue;
    insertions++;
  }
  final wordTiles = {...word.letters, ...word.marks};
  final distractorPicks = places.where((e) => !wordTiles.contains(e.data['tile'])).length;

  final attempts = checks.length.clamp(0, SpellingConfig.maxAttempts);
  final correctFirstTry = checks.isNotEmpty && checks.first.data['correct'] == true;
  final finalCorrect = checks.any((c) => c.data['correct'] == true);
  final firstAksharas = checks.isEmpty ? null : (checks.first.data['aksharas'] as num?)?.toInt();

  return {
    'childId': 'si-child',
    'sessionId': sessionId,
    'roundNo': roundNo,
    'wordIndex': wordIndex,
    'word_id': word.id,
    'word': word.word,
    'phonics_skill': word.skill,
    'skill_stage': word.stage,
    'difficulty': word.difficulty,
    'timestamp': (now ?? DateTime.now()).toIso8601String(),
    'mode': mode,
    'first_input_ms': firstInput,
    'total_ms': (end - start).clamp(0.0, double.infinity),
    'mean_gap_ms': meanGap,
    'max_gap_ms': maxGap,
    'paused_ms': pausedMs,
    'replays': of(SpellingEventType.replay).length,
    'motor_slips': slips.length,
    'corrections': deletions + reorders + replacements,
    'n_insertions': insertions,
    'n_deletions': deletions,
    'n_replacements': replacements,
    'n_reorders': reorders,
    'distractor_picks': distractorPicks,
    'answer_length_diff': firstAksharas == null ? 0 : firstAksharas - word.aksharas.length,
    'attempts': attempts,
    'correct_first_try': correctFirstTry,
    'final_correct': finalCorrect,
    'hesitation_ratio': firstInput / SinhalaLearner.medianFirstInput(progress),
    'pause_ratio': maxGap / SinhalaLearner.medianMaxGap(progress),
    'first_wrong_answer': firstWrongAnswer,
    'edit_distance': errors.values.fold<int>(0, (a, b) => a + b),
    for (final t in SinhalaError.all) t: errors[t] ?? 0,
    'n_aksharas': word.aksharas.length,
    'n_marks': word.marks.length,
  };
}

/// One CSV line per word, in [sinhalaFeatureColumns] order.
String sinhalaFeaturesCsv(Iterable<Map<String, Object?>> rows) {
  String cell(Object? v) {
    if (v == null) return '';
    final s = v is double ? v.toStringAsFixed(3) : v.toString();
    return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }

  return [
    sinhalaFeatureColumns.join(','),
    for (final r in rows) [for (final c in sinhalaFeatureColumns) cell(r[c])].join(','),
  ].join('\n');
}
