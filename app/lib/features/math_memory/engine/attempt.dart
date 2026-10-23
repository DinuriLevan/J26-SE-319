/// Shared attempt vocabulary for the Math & Memory games.
library;

/// `component_name` for every result this feature queues — see
/// docs/api-contract.md.
const mathMemoryComponentName = 'math_memory';

/// Version of the JSON stored in `local_learner_progress` and sent in each
/// activity result's payload. Bump when either shape changes.
const mathMemorySchemaVersion = 1;

enum MathGameId {
  numberQuest('number_quest'),
  memoryMatch('memory_match');

  const MathGameId(this.key);

  /// Stable id used as `activity_id` and as the local progress key.
  final String key;
}

/// A child's first completed attempt at each game is an ungraded baseline;
/// every later attempt is scored and adaptive.
enum AttemptType {
  baseline,
  scored;

  static AttemptType forCompletedAttempts(int completedAttempts) =>
      completedAttempts == 0 ? AttemptType.baseline : AttemptType.scored;
}

/// Only `completed` attempts change progress. `abandoned` ones are queued for
/// research data but never count as the baseline or advance difficulty.
enum CompletionStatus { completed, abandoned }

/// Both games allow one retry after a hint, then reveal the answer.
const maxTriesPerActivity = 2;

/// How a child answered one activity.
class AnswerOutcome {
  const AnswerOutcome({
    required this.correct,
    required this.tries,
    required this.firstResponseMs,
  });

  /// Whether the child eventually found the right answer.
  final bool correct;

  /// Answers given, 1..[maxTriesPerActivity].
  final int tries;

  /// Time from the activity appearing to the child's first answer.
  final int firstResponseMs;

  bool get correctFirstTry => correct && tries == 1;

  /// A hint is shown after every wrong answer.
  bool get neededHint => tries > 1;

  /// The signal the adaptive engines learn from: 1 for first-try correct,
  /// 0.5 for correct after a hint, 0 otherwise.
  double get mastery => correctFirstTry ? 1.0 : (correct ? 0.5 : 0.0);

  Map<String, dynamic> toJson() => {
        'correct': correct,
        'correct_first_try': correctFirstTry,
        'tries': tries,
        'hint_shown': neededHint,
        'first_response_ms': firstResponseMs,
      };
}

/// Mean of [values], or null when empty.
double? meanOf(Iterable<double> values) {
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a + b) / values.length;
}

/// The last [window] items of [values] after appending [value].
List<double> pushRecent(List<double> values, double value, int window) {
  final next = [...values, value];
  return next.length <= window ? next : next.sublist(next.length - window);
}
