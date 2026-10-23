import '../../engine/attempt.dart';
import 'memory_match_models.dart';

/// Tunable limits and thresholds for Memory Match. Documented in
/// docs/math-memory-adaptive-engine.md.
class MemoryMatchAdaptiveConfig {
  const MemoryMatchAdaptiveConfig({
    this.roundsPerScoredAttempt = 6,
    this.minPositions = 3,
    this.maxPositions = 9,
    this.minSeconds = 3,
    this.maxSeconds = 10,
    this.harderAfter = 2,
    this.easierAfter = 2,
    this.cooldownRounds = 2,
    this.recentWindow = 6,
    this.baselineGoodMastery = 0.75,
    this.baselinePlan = defaultBaselinePlan,
  });

  final int roundsPerScoredAttempt;
  final int minPositions;
  final int maxPositions;
  final int minSeconds;
  final int maxSeconds;

  /// First-try correct recalls in a row before one factor gets harder.
  final int harderAfter;

  /// Missed recalls in a row before one factor gets easier.
  final int easierAfter;

  /// Rounds at a new configuration before it may change again.
  final int cooldownRounds;

  final int recentWindow;

  /// Baseline mastery at a board size needed to start at that size.
  final double baselineGoodMastery;

  /// Fixed, non-adaptive baseline rounds.
  final List<MemoryConfig> baselinePlan;

  static const defaultBaselinePlan = [
    MemoryConfig(positions: 3, memorizeSeconds: 6),
    MemoryConfig(positions: 3, memorizeSeconds: 6),
    MemoryConfig(positions: 4, memorizeSeconds: 6),
    MemoryConfig(positions: 4, memorizeSeconds: 6),
    MemoryConfig(positions: 5, memorizeSeconds: 6),
    MemoryConfig(positions: 5, memorizeSeconds: 6),
  ];

  Map<String, dynamic> toJson() => {
        'rounds_per_scored_attempt': roundsPerScoredAttempt,
        'positions_range': [minPositions, maxPositions],
        'memorize_seconds_range': [minSeconds, maxSeconds],
        'harder_after': harderAfter,
        'easier_after': easierAfter,
        'cooldown_rounds': cooldownRounds,
        'recent_window': recentWindow,
      };
}

enum MemoryChange { none, morePositions, lessTime, fewerPositions, moreTime }

class MemoryUpdate {
  const MemoryUpdate(this.state, this.change);

  final MemoryAdaptiveState state;
  final MemoryChange change;
}

/// Rules-based configuration adaptation for Memory Match. Pure and
/// deterministic.
class MemoryMatchAdaptiveEngine {
  const MemoryMatchAdaptiveEngine([this.config = const MemoryMatchAdaptiveConfig()]);

  final MemoryMatchAdaptiveConfig config;

  /// Starting configuration from the baseline:
  /// - positions: the largest board size the child recalled well at
  ///   (mean mastery ≥ [MemoryMatchAdaptiveConfig.baselineGoodMastery]),
  ///   counting up from the smallest and stopping at the first one they
  ///   didn't; never below the minimum.
  /// - memorize time: 5 s if overall mastery ≥ 0.8, 6 s if ≥ 0.5, else 7 s.
  MemoryAdaptiveState estimateFromBaseline(List<(MemoryConfig, AnswerOutcome)> results) {
    final sizes = {for (final (c, _) in results) c.positions}.toList()..sort();
    var positions = config.minPositions;
    for (final size in sizes) {
      final mean = meanOf([
        for (final (c, o) in results)
          if (c.positions == size) o.mastery,
      ])!;
      if (mean < config.baselineGoodMastery) break;
      positions = size;
    }

    final overall = meanOf([for (final (_, o) in results) o.mastery]) ?? 0;
    final seconds = overall >= 0.8 ? 5 : (overall >= 0.5 ? 6 : 7);

    final masteries = [for (final (_, o) in results) o.mastery];
    return MemoryAdaptiveState(
      config: MemoryConfig(
        positions: positions.clamp(config.minPositions, config.maxPositions),
        memorizeSeconds: seconds.clamp(config.minSeconds, config.maxSeconds),
      ),
      recent: masteries.length <= config.recentWindow
          ? masteries
          : masteries.sublist(masteries.length - config.recentWindow),
    );
  }

  /// Updates the configuration after one scored recall round.
  MemoryUpdate recordRound(MemoryAdaptiveState state, AnswerOutcome outcome) {
    final recent = pushRecent(state.recent, outcome.mastery, config.recentWindow);
    final cooldown = state.cooldown > 0 ? state.cooldown - 1 : 0;

    var success = state.successStreak;
    var errors = state.errorStreak;
    if (outcome.correctFirstTry) {
      success++;
      errors = 0;
    } else {
      success = 0;
      errors++;
    }

    var next = state.copyWith(
      successStreak: success,
      errorStreak: errors,
      cooldown: cooldown,
      recent: recent,
    );
    var change = MemoryChange.none;

    if (cooldown == 0 && errors >= config.easierAfter) {
      (next, change) = _easier(next);
    } else if (cooldown == 0 && success >= config.harderAfter) {
      (next, change) = _harder(next);
    }

    if (change != MemoryChange.none) {
      next = next.copyWith(successStreak: 0, errorStreak: 0, cooldown: config.cooldownRounds);
    }
    return MemoryUpdate(next, change);
  }

  (MemoryAdaptiveState, MemoryChange) _harder(MemoryAdaptiveState s) {
    final canAdd = s.config.positions < config.maxPositions;
    final canShorten = s.config.memorizeSeconds > config.minSeconds;
    if (canAdd && (s.nextHarder == MemoryFactor.positions || !canShorten)) {
      return (
        s.copyWith(
          config: s.config.copyWith(positions: s.config.positions + 1),
          nextHarder: MemoryFactor.time,
        ),
        MemoryChange.morePositions,
      );
    }
    if (canShorten) {
      return (
        s.copyWith(
          config: s.config.copyWith(memorizeSeconds: s.config.memorizeSeconds - 1),
          nextHarder: MemoryFactor.positions,
        ),
        MemoryChange.lessTime,
      );
    }
    return (s, MemoryChange.none);
  }

  (MemoryAdaptiveState, MemoryChange) _easier(MemoryAdaptiveState s) {
    final canLengthen = s.config.memorizeSeconds < config.maxSeconds;
    final canRemove = s.config.positions > config.minPositions;
    if (canLengthen && (s.nextEasier == MemoryFactor.time || !canRemove)) {
      return (
        s.copyWith(
          config: s.config.copyWith(memorizeSeconds: s.config.memorizeSeconds + 1),
          nextEasier: MemoryFactor.positions,
        ),
        MemoryChange.moreTime,
      );
    }
    if (canRemove) {
      return (
        s.copyWith(
          config: s.config.copyWith(positions: s.config.positions - 1),
          nextEasier: MemoryFactor.time,
        ),
        MemoryChange.fewerPositions,
      );
    }
    return (s, MemoryChange.none);
  }
}
