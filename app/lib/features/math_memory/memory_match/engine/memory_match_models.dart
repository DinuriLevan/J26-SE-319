import '../../engine/attempt.dart';
import '../../engine/math_picture.dart';

/// The board is always 3×3; [MemoryConfig.positions] of its cells hold a
/// picture in each round.
const memoryBoardColumns = 3;
const memoryBoardCells = memoryBoardColumns * memoryBoardColumns;

/// The two difficulty factors. Only one changes at a time.
enum MemoryFactor { positions, time }

/// Difficulty of one recall round.
class MemoryConfig {
  const MemoryConfig({required this.positions, required this.memorizeSeconds});

  /// Pictures on the board (3..9).
  final int positions;

  /// How long the pictures stay face-up (3..10 s).
  final int memorizeSeconds;

  MemoryConfig copyWith({int? positions, int? memorizeSeconds}) => MemoryConfig(
        positions: positions ?? this.positions,
        memorizeSeconds: memorizeSeconds ?? this.memorizeSeconds,
      );

  @override
  bool operator ==(Object other) =>
      other is MemoryConfig &&
      other.positions == positions &&
      other.memorizeSeconds == memorizeSeconds;

  @override
  int get hashCode => Object.hash(positions, memorizeSeconds);

  @override
  String toString() => 'MemoryConfig($positions pictures, ${memorizeSeconds}s)';

  Map<String, dynamic> toJson() => {
        'positions': positions,
        'memorize_seconds': memorizeSeconds,
      };

  factory MemoryConfig.fromJson(Map<String, dynamic> json) => MemoryConfig(
        positions: (json['positions'] as num?)?.toInt() ?? 3,
        memorizeSeconds: (json['memorize_seconds'] as num?)?.toInt() ?? 6,
      );
}

/// One recall activity: a board of distinct pictures and one target.
class MemoryRound {
  MemoryRound({required this.config, required this.board, required this.targetCell})
      : assert(board.containsKey(targetCell)),
        assert(board.values.toSet().length == board.length, 'pictures must be unique');

  final MemoryConfig config;

  /// Cell index (0..8, row by row) → picture. Pictures are unique, so every
  /// target has exactly one correct cell.
  final Map<int, MathPicture> board;

  final int targetCell;

  MathPicture get target => board[targetCell]!;

  /// Cells with a picture, in reading order. Card numbers follow this order.
  List<int> get activeCells => board.keys.toList()..sort();

  /// The number printed on a face-down card (1-based), or null for an empty cell.
  int? numberFor(int cell) {
    final i = activeCells.indexOf(cell);
    return i == -1 ? null : i + 1;
  }

  int get targetNumber => numberFor(targetCell)!;

  Map<String, dynamic> toJson() => {
        ...config.toJson(),
        'board': {for (final e in board.entries) '${e.key}': e.value.name},
        'target_picture': target.name,
        'target_cell': targetCell,
        'target_number': targetNumber,
      };
}

/// What the Memory Match engine knows. Persisted between attempts.
class MemoryAdaptiveState {
  const MemoryAdaptiveState({
    required this.config,
    this.successStreak = 0,
    this.errorStreak = 0,
    this.cooldown = 0,
    this.nextHarder = MemoryFactor.positions,
    this.nextEasier = MemoryFactor.time,
    this.recent = const [],
  });

  final MemoryConfig config;

  /// First-try correct recalls in a row.
  final int successStreak;

  /// Recalls in a row that were not first-try correct.
  final int errorStreak;

  /// Rounds left before the configuration may change again.
  final int cooldown;

  /// Which factor the next "harder" / "easier" step changes. They alternate
  /// so the game never changes both at once.
  final MemoryFactor nextHarder;
  final MemoryFactor nextEasier;

  /// Recent [AnswerOutcome.mastery] values, oldest first.
  final List<double> recent;

  double? get recentAccuracy => meanOf(recent);

  MemoryAdaptiveState copyWith({
    MemoryConfig? config,
    int? successStreak,
    int? errorStreak,
    int? cooldown,
    MemoryFactor? nextHarder,
    MemoryFactor? nextEasier,
    List<double>? recent,
  }) {
    return MemoryAdaptiveState(
      config: config ?? this.config,
      successStreak: successStreak ?? this.successStreak,
      errorStreak: errorStreak ?? this.errorStreak,
      cooldown: cooldown ?? this.cooldown,
      nextHarder: nextHarder ?? this.nextHarder,
      nextEasier: nextEasier ?? this.nextEasier,
      recent: recent ?? this.recent,
    );
  }

  Map<String, dynamic> toJson() => {
        'config': config.toJson(),
        'success_streak': successStreak,
        'error_streak': errorStreak,
        'cooldown': cooldown,
        'next_harder': nextHarder.name,
        'next_easier': nextEasier.name,
        'recent': recent,
      };

  factory MemoryAdaptiveState.fromJson(Map<String, dynamic> json) {
    MemoryFactor factor(Object? name, MemoryFactor fallback) =>
        MemoryFactor.values.firstWhere((f) => f.name == name, orElse: () => fallback);
    return MemoryAdaptiveState(
      config: json['config'] is Map
          ? MemoryConfig.fromJson((json['config'] as Map).cast<String, dynamic>())
          : const MemoryConfig(positions: 3, memorizeSeconds: 6),
      successStreak: (json['success_streak'] as num?)?.toInt() ?? 0,
      errorStreak: (json['error_streak'] as num?)?.toInt() ?? 0,
      cooldown: (json['cooldown'] as num?)?.toInt() ?? 0,
      nextHarder: factor(json['next_harder'], MemoryFactor.positions),
      nextEasier: factor(json['next_easier'], MemoryFactor.time),
      recent: [for (final v in (json['recent'] as List?) ?? const []) (v as num).toDouble()],
    );
  }
}

/// Everything Memory Match remembers about a child, stored locally under
/// [MathGameId.memoryMatch]. Independent of Number Quest.
class MemoryMatchProgress {
  const MemoryMatchProgress({
    required this.tutorialSeen,
    required this.completedAttempts,
    required this.adaptive,
  });

  factory MemoryMatchProgress.initial() => const MemoryMatchProgress(
        tutorialSeen: false,
        completedAttempts: 0,
        adaptive: MemoryAdaptiveState(config: MemoryConfig(positions: 3, memorizeSeconds: 6)),
      );

  final bool tutorialSeen;
  final int completedAttempts;
  final MemoryAdaptiveState adaptive;

  AttemptType get nextAttemptType => AttemptType.forCompletedAttempts(completedAttempts);

  int get nextAttemptNumber => completedAttempts + 1;

  MemoryMatchProgress copyWith({
    bool? tutorialSeen,
    int? completedAttempts,
    MemoryAdaptiveState? adaptive,
  }) {
    return MemoryMatchProgress(
      tutorialSeen: tutorialSeen ?? this.tutorialSeen,
      completedAttempts: completedAttempts ?? this.completedAttempts,
      adaptive: adaptive ?? this.adaptive,
    );
  }

  Map<String, dynamic> toJson() => {
        'schema_version': mathMemorySchemaVersion,
        'tutorial_seen': tutorialSeen,
        'completed_attempts': completedAttempts,
        'adaptive': adaptive.toJson(),
      };

  factory MemoryMatchProgress.fromJson(Map<String, dynamic> json) => MemoryMatchProgress(
        tutorialSeen: json['tutorial_seen'] as bool? ?? false,
        completedAttempts: (json['completed_attempts'] as num?)?.toInt() ?? 0,
        adaptive: json['adaptive'] is Map
            ? MemoryAdaptiveState.fromJson((json['adaptive'] as Map).cast<String, dynamic>())
            : MemoryMatchProgress.initial().adaptive,
      );
}
