import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/sync/sync_service.dart';
import '../../profile/providers/profile_providers.dart';
import '../engine/attempt.dart';
import '../memory_match/engine/memory_match_models.dart';
import '../number_quest/engine/number_quest_models.dart';

/// Local progress and result queueing for the Math & Memory games.
///
/// - Progress lives in `local_learner_progress` (one row per child per game),
///   so both games adapt fully offline and survive app restarts.
/// - Every finished (or abandoned) attempt is queued in
///   `pending_activity_results` as `component_name: math_memory`; the shared
///   [SyncService] sends it to `POST /activity-results` when online.
class MathProgressRepository {
  MathProgressRepository(this._db, this._activeChildId, {this.onResultQueued});

  final AppDatabase _db;
  final String? Function() _activeChildId;

  /// Called after a result is queued (best-effort sync trigger).
  final void Function()? onResultQueued;

  Future<String> _childId() async {
    final active = _activeChildId();
    if (active != null) return active;
    final profile = await _db.childProfileDao.getSingleOnce();
    if (profile == null) throw StateError('No local child profile yet');
    return profile.id;
  }

  Future<Map<String, dynamic>?> _load(MathGameId game) async {
    final raw = await _db.localLearnerProgressDao.getProgressData(await _childId(), game.key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as Map).cast<String, dynamic>();
    } on FormatException {
      return null;
    }
  }

  Future<void> _save(MathGameId game, Map<String, dynamic> json) async {
    await _db.localLearnerProgressDao.upsert(
      childId: await _childId(),
      progressKey: game.key,
      progressData: jsonEncode(json),
    );
  }

  Future<NumberQuestProgress> loadNumberQuest() async {
    final json = await _load(MathGameId.numberQuest);
    return json == null ? NumberQuestProgress.initial() : NumberQuestProgress.fromJson(json);
  }

  Future<MemoryMatchProgress> loadMemoryMatch() async {
    final json = await _load(MathGameId.memoryMatch);
    return json == null ? MemoryMatchProgress.initial() : MemoryMatchProgress.fromJson(json);
  }

  Future<void> markTutorialSeen(MathGameId game) async {
    switch (game) {
      case MathGameId.numberQuest:
        final p = await loadNumberQuest();
        if (!p.tutorialSeen) await _save(game, p.copyWith(tutorialSeen: true).toJson());
      case MathGameId.memoryMatch:
        final p = await loadMemoryMatch();
        if (!p.tutorialSeen) await _save(game, p.copyWith(tutorialSeen: true).toJson());
    }
  }

  /// Saves a completed attempt's new progress and queues its result, in one
  /// transaction so the attempt count and the queued result never disagree.
  Future<void> completeAttempt({
    required MathGameId game,
    required Map<String, dynamic> progressAfter,
    required Map<String, dynamic> payload,
  }) async {
    final childId = await _childId();
    await _db.transaction(() async {
      await _db.localLearnerProgressDao.upsert(
        childId: childId,
        progressKey: game.key,
        progressData: jsonEncode(progressAfter),
      );
      await _enqueue(childId, game, payload);
    });
    onResultQueued?.call();
  }

  /// Queues an abandoned attempt's partial data. Progress is not touched, so
  /// an abandoned first attempt never counts as the baseline.
  Future<void> recordAbandonedAttempt({
    required MathGameId game,
    required Map<String, dynamic> payload,
  }) async {
    await _enqueue(await _childId(), game, payload);
    onResultQueued?.call();
  }

  Future<void> _enqueue(String childId, MathGameId game, Map<String, dynamic> payload) {
    return _db.pendingActivityResultDao.enqueue(
      childId: childId,
      componentName: mathMemoryComponentName,
      activityId: game.key,
      resultPayload: jsonEncode(payload),
    );
  }
}

final mathProgressRepositoryProvider = Provider<MathProgressRepository>((ref) {
  return MathProgressRepository(
    ref.watch(appDatabaseProvider),
    () => ref.read(activeChildIdProvider),
    onResultQueued: () {
      // Best-effort; never blocks or fails gameplay.
      ref.read(syncServiceProvider).flushPendingResults().catchError((_) {});
    },
  );
});

/// Seed for each new attempt's question/board generator. Overridden in tests
/// for reproducible games.
final mathGameSeedProvider = Provider<int Function()>(
  (ref) => () => DateTime.now().microsecondsSinceEpoch,
);

/// Clock for response times. Overridden in tests.
final mathGameClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
