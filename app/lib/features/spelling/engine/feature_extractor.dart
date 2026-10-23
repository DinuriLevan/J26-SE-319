import '../data/word_bank.dart';
import 'error_analyzer.dart';
import 'event_logger.dart';
import 'learner_model.dart';
import 'spelling_config.dart';

/// Identifiers attached to every feature row.
class WordContext {
  const WordContext({
    required this.childId,
    required this.sessionId,
    required this.roundNo,
    required this.wordIndex,
    required this.mode,
  });

  final String childId;
  final String sessionId;
  final int roundNo;
  final int wordIndex;

  /// "adaptive", "fixed" or "placement".
  final String mode;
}

/// One row per word — the research dataset (exported as CSV).
class FeatureRow {
  FeatureRow(this.values);

  final Map<String, Object?> values;

  static const columns = [
    'childId', 'sessionId', 'roundNo', 'wordIndex', 'word_id', 'word', 'phonics_skill',
    'skill_stage', 'difficulty', 'timestamp', 'mode', 'use_behaviour',
    'first_input_ms', 'total_ms', 'mean_gap_ms', 'max_gap_ms', 'paused_ms', 'replays', 'motor_slips',
    'corrections', 'n_insertions', 'n_deletions', 'n_replacements', 'n_reorders', 'distractor_picks',
    'answer_length_diff', 'attempts', 'correct_first_try', 'final_correct', 'hesitation_ratio',
    'pause_ratio', 'first_wrong_answer', 'edit_distance', ...ErrorType.all,
    'target_grapheme_error', 'evidence_weight', 'p_before', 'p_after',
    // Difficulty classifier output for this word (after the model update).
    'clf_label', 'clf_p_hard', 'clf_source',
  ];

  String get childId => values['childId']! as String;
  String get wordId => values['word_id']! as String;
  String get skill => values['phonics_skill']! as String;
  int get stage => values['skill_stage']! as int;
  String get mode => values['mode']! as String;
  int get roundNo => values['roundNo'] as int? ?? 0;
  String get word => values['word'] as String? ?? '';

  /// Letters in the word (sets the BKT guess chance).
  int get wordLength => word.isEmpty ? 4 : word.length;
  String? get firstWrongAnswer => values['first_wrong_answer'] as String?;
  bool get targetGraphemeError => values['target_grapheme_error'] as bool? ?? false;
  bool get correctFirstTry => values['correct_first_try']! as bool;
  bool get finalCorrect => values['final_correct']! as bool;
  int get attempts => values['attempts']! as int;
  int get corrections => values['corrections']! as int;
  int get motorSlips => values['motor_slips']! as int;
  int count(String column) => values[column] as int? ?? 0;
  double get hesitationRatio => (values['hesitation_ratio']! as num).toDouble();
  double get firstInputMs => (values['first_input_ms']! as num).toDouble();
  double get maxGapMs => (values['max_gap_ms']! as num).toDouble();
  int errorCount(String type) => values[type] as int? ?? 0;

  Map<String, Object?> toJson() => values;

  factory FeatureRow.fromJson(Map<String, Object?> json) => FeatureRow(Map.of(json));

  List<String> toCsvCells() => [
        for (final c in columns) _csv(values[c]),
      ];

  static String _csv(Object? v) {
    if (v == null) return '';
    final s = v is double ? v.toStringAsFixed(3) : v.toString();
    return s.contains(RegExp(r'[",\n]')) ? '"${s.replaceAll('"', '""')}"' : s;
  }
}

/// Turns one word's raw events into a feature row. Reads the child's running
/// medians (it does not update them — the engine does that afterwards, so
/// hesitation_ratio compares against the child's *earlier* words only).
FeatureRow featurize(
  List<SpellingEvent> events,
  WordEntry word,
  ChildModel child,
  WordContext ctx, {
  bool useBehaviour = true,
  double slipMs = SpellingConfig.slipMs,
  DateTime? now,
}) {
  // The app's clock already stops while paused. If a log still contains a
  // paused stretch (e.g. data from another source), take it out of every
  // timestamp so no timing feature includes paused time.
  final pauses = <(double, double)>[];
  double? pausedFrom;
  for (final e in events) {
    if (e.type == SpellingEventType.pause) pausedFrom ??= e.t;
    if (e.type == SpellingEventType.resume && pausedFrom != null) {
      pauses.add((pausedFrom, e.t));
      pausedFrom = null;
    }
  }
  if (pauses.isNotEmpty) {
    double active(double t) {
      var out = t;
      for (final (from, to) in pauses) {
        if (t >= to) {
          out -= to - from;
        } else if (t > from) {
          out -= t - from;
        }
      }
      return out;
    }

    events = [for (final e in events) SpellingEvent(e.type, active(e.t), e.data)];
  }
  final pausedMs = events
      .where((e) => e.type == SpellingEventType.resume)
      .fold<double>(0, (sum, e) => sum + ((e.data['pausedMs'] as num?)?.toDouble() ?? 0));

  List<SpellingEvent> of(SpellingEventType type) => events.where((e) => e.type == type).toList();

  final audioStarts = of(SpellingEventType.audioStart);
  final audioEnds = of(SpellingEventType.audioEnd);
  final places = of(SpellingEventType.tilePlace);
  final removes = of(SpellingEventType.tileRemove);
  final moves = of(SpellingEventType.tileMove);
  final checks = of(SpellingEventType.check);

  final firstAudioEnd = audioEnds.isNotEmpty
      ? audioEnds.first.t
      : (audioStarts.isNotEmpty ? audioStarts.first.t : (events.isNotEmpty ? events.first.t : 0.0));
  final firstInput = places.isEmpty ? 0.0 : (places.first.t - firstAudioEnd).clamp(0.0, double.infinity);

  final start = audioStarts.isNotEmpty ? audioStarts.first.t : (events.isNotEmpty ? events.first.t : 0.0);
  final end = checks.isNotEmpty ? checks.last.t : (events.isNotEmpty ? events.last.t : start);
  final totalMs = (end - start).clamp(0.0, double.infinity);

  final gaps = <double>[
    for (var i = 1; i < places.length; i++) places[i].t - places[i - 1].t,
  ];
  final meanGap = gaps.isEmpty ? 0.0 : gaps.reduce((a, b) => a + b) / gaps.length;
  final maxGap = gaps.isEmpty ? 0.0 : gaps.reduce((a, b) => a > b ? a : b);

  double sinceOf(SpellingEvent e) => (e.data['msSincePlaced'] as num?)?.toDouble() ?? double.infinity;
  final motorSlips = removes.where((e) => sinceOf(e) < slipMs).length;
  final corrections = [...removes, ...moves].where((e) => sinceOf(e) >= slipMs).length;

  final attempts = checks.length.clamp(0, SpellingConfig.maxAttempts);
  final correctFirstTry = checks.isNotEmpty && checks.first.data['correct'] == true;
  final finalCorrect = checks.any((c) => c.data['correct'] == true);

  final firstWrong = checks.where((c) => c.data['correct'] != true).firstOrNull;
  final firstWrongAnswer = firstWrong?.data['answer'] as String?;
  final errors = firstWrongAnswer == null
      ? ErrorAnalysis.none()
      : analyzeErrors(word.spelling, firstWrongAnswer, word.targetGrapheme);

  final edits = classifyEdits(events, word.letters.toSet(), slipMs: slipMs);
  final firstAnswer = checks.isEmpty ? null : checks.first.data['answer'] as String?;

  final hesitationRatio = firstInput / child.medianFirstInput;
  final pauseRatio = maxGap / child.medianMaxGap;

  return FeatureRow({
    'childId': ctx.childId,
    'sessionId': ctx.sessionId,
    'roundNo': ctx.roundNo,
    'wordIndex': ctx.wordIndex,
    'word_id': word.id,
    'word': word.word,
    'phonics_skill': word.phonicsSkill,
    'skill_stage': word.stage,
    'difficulty': word.difficulty,
    'timestamp': (now ?? DateTime.now()).toIso8601String(),
    'mode': ctx.mode,
    'use_behaviour': useBehaviour,
    'first_input_ms': firstInput,
    'total_ms': totalMs,
    'mean_gap_ms': meanGap,
    'max_gap_ms': maxGap,
    'paused_ms': pausedMs,
    'replays': of(SpellingEventType.replay).length,
    'motor_slips': motorSlips,
    'corrections': corrections,
    'n_insertions': edits.insertions,
    'n_deletions': edits.deletions,
    'n_replacements': edits.replacements,
    'n_reorders': edits.reorders,
    'distractor_picks': edits.distractorPicks,
    'answer_length_diff': firstAnswer == null ? 0 : firstAnswer.length - word.spelling.length,
    'attempts': attempts,
    'correct_first_try': correctFirstTry,
    'final_correct': finalCorrect,
    'hesitation_ratio': hesitationRatio,
    'pause_ratio': pauseRatio,
    'first_wrong_answer': firstWrongAnswer,
    'edit_distance': errors.editDistance,
    for (final t in ErrorType.all) t: errors.count(t),
    'target_grapheme_error': errors.targetGraphemeError,
  });
}

/// Counts of the child's edits on the answer line (FR2).
class EditCounts {
  int insertions = 0, deletions = 0, replacements = 0, reorders = 0, distractorPicks = 0;
}

/// Classifies every edit the child made:
/// - insertion: a letter put on the line;
/// - deletion: a letter taken off the line;
/// - replacement: a letter taken off and, as the very next edit, a different
///   letter put in the same place (counted once, not as delete + insert);
/// - reorder: a letter moved along the line.
/// Motor slips (a letter picked up again within [slipMs]) and the matching
/// re-placement of that same letter are not counted. A distractor pick is any
/// placement of a letter that is not in the word.
EditCounts classifyEdits(List<SpellingEvent> events, Set<String> wordLetters, {double slipMs = SpellingConfig.slipMs}) {
  const editTypes = {SpellingEventType.tilePlace, SpellingEventType.tileRemove, SpellingEventType.tileMove};
  final edits = events.where((e) => editTypes.contains(e.type)).toList();
  final out = EditCounts();
  int? position(SpellingEvent e) => (e.data['index'] ?? e.data['slot']) as int?;
  bool isSlip(SpellingEvent e) => ((e.data['msSincePlaced'] as num?)?.toDouble() ?? double.infinity) < slipMs;

  String? slipLetter; // letter of the last slip, whose re-placement is skipped
  for (var i = 0; i < edits.length; i++) {
    final e = edits[i];
    final letter = e.data['letter'] as String?;
    switch (e.type) {
      case SpellingEventType.tilePlace:
        if (slipLetter != null && slipLetter == letter) {
          slipLetter = null;
          continue;
        }
        out.insertions++;
        if (letter != null && !wordLetters.contains(letter)) out.distractorPicks++;
      case SpellingEventType.tileRemove:
        if (isSlip(e)) {
          slipLetter = letter;
          continue;
        }
        final next = i + 1 < edits.length ? edits[i + 1] : null;
        if (next != null &&
            next.type == SpellingEventType.tilePlace &&
            position(next) != null &&
            position(next) == position(e) &&
            next.data['letter'] != letter) {
          out.replacements++;
          if (!wordLetters.contains(next.data['letter'])) out.distractorPicks++;
          i++; // the placement is part of this replacement
        } else {
          out.deletions++;
        }
      case SpellingEventType.tileMove:
        out.reorders++;
      default:
        break;
    }
  }
  return out;
}
