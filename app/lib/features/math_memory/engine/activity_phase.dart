/// Where one activity is in its answer → feedback cycle. Shared by both games.
enum ActivityPhase {
  /// Waiting for a first answer.
  answering,

  /// The first answer was wrong; a hint is showing and one more try is allowed.
  hint,

  /// Answered correctly. Waiting for Next.
  correct,

  /// Out of tries; the answer has been shown. Waiting for Next.
  revealed,

  /// The attempt is over.
  finished;

  bool get acceptsAnswer => this == answering || this == hint;

  bool get awaitingNext => this == correct || this == revealed;
}
