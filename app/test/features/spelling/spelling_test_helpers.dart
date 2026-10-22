import 'dart:io';

import 'package:akurin/features/spelling/data/word_bank.dart';
import 'package:akurin/features/spelling/engine/event_logger.dart';
import 'package:akurin/features/spelling/engine/feature_extractor.dart';

/// Loads the real word bank CSV (tests run from the app/ folder).
WordBank loadTestBank() => WordBank.parse(File(WordBank.assetPath).readAsStringSync());

/// A feature row with just the fields the model and selector read.
FeatureRow fakeRow(
  WordEntry w, {
  bool correctFirstTry = true,
  bool finalCorrect = true,
  int attempts = 1,
  int corrections = 0,
  double hesitationRatio = 1.0,
  Map<String, int> errors = const {},
  int roundNo = 2,
  String? wrongAnswer,
  bool targetGraphemeError = true,
}) =>
    FeatureRow({
      'childId': 'c1',
      'roundNo': roundNo,
      'word_id': w.id,
      'word': w.word,
      'first_wrong_answer': wrongAnswer ?? (correctFirstTry ? null : '?'),
      'target_grapheme_error': !correctFirstTry && targetGraphemeError,
      'phonics_skill': w.phonicsSkill,
      'skill_stage': w.stage,
      'mode': 'adaptive',
      'correct_first_try': correctFirstTry,
      'final_correct': finalCorrect,
      'attempts': attempts,
      'corrections': corrections,
      'motor_slips': 0,
      'hesitation_ratio': hesitationRatio,
      'first_input_ms': 1000.0,
      'max_gap_ms': 800.0,
      ...errors,
    });

/// Events for a word answered on the first try, with even pacing.
List<SpellingEvent> quickCorrectEvents(WordEntry w) {
  var t = 0.0;
  final events = <SpellingEvent>[
    SpellingEvent(SpellingEventType.audioStart, t),
    SpellingEvent(SpellingEventType.audioEnd, t += 1000),
  ];
  t += 800;
  for (var i = 0; i < w.letters.length; i++) {
    events.add(SpellingEvent(SpellingEventType.tilePlace, t, {'letter': w.letters[i], 'slot': i}));
    t += 600;
  }
  events.add(SpellingEvent(SpellingEventType.check, t, {'answer': w.spelling, 'correct': true, 'attemptNo': 1}));
  return events;
}
