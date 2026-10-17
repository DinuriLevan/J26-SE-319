import 'retry_loop.dart';

/// Milestone cards (owner decision 2026-10-16): one card for every 5 different words mastered,
/// card_id "speech_words_5", "speech_words_10", ... in the shared card album.
const speechMilestoneEvery = 5;

String? milestoneCard(int masteredWordCount) =>
    masteredWordCount > 0 && masteredWordCount % speechMilestoneEvery == 0
        ? 'speech_words_$masteredWordCount'
        : null;

/// The one shared ActivityResult payload written when a word is finished (mastered or fallback).
Map<String, Object?> completedWordPayload({
  required String wordId,
  required RetryLoop loop,
  required List<String> units,
  double? lastScore,
}) {
  final flagged = <int>[
    for (final e in loop.events)
      if (e.type == 'unit_flagged' && e.unit != null) e.unit!,
  ];
  int attempts(StepKind k) => loop.events
      .where((e) => e.type == 'attempt_scored' && e.step == k)
      .length;
  return {
    'word_id': wordId,
    'outcome': loop.step.kind == StepKind.reward ? 'mastered' : 'fallback',
    'full_word_attempts': attempts(StepKind.fullWord),
    'unit_attempts': attempts(StepKind.sayUnit),
    'blend_attempts': attempts(StepKind.blend),
    'flagged_units': [for (final u in flagged.toSet()) units[u]],
    'practise_later': [for (final u in loop.scheduledUnits) units[u]],
    'last_score': lastScore,
    'events': [for (final e in loop.events) e.toString()],
  };
}
