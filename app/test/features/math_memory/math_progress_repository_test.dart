import 'dart:convert';

import 'package:akurin/core/db/app_database.dart';
import 'package:akurin/features/math_memory/data/math_progress_repository.dart';
import 'package:akurin/features/math_memory/engine/activity_phase.dart';
import 'package:akurin/features/math_memory/engine/attempt.dart';
import 'package:akurin/features/math_memory/memory_match/engine/memory_match_models.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_quest_models.dart';
import 'package:akurin/features/math_memory/number_quest/engine/number_quest_session.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  late AppDatabase db;
  late MathProgressRepository repo;
  late int queued;

  setUp(() {
    db = createTestDatabase();
    queued = 0;
    repo = MathProgressRepository(db, () => testChildId, onResultQueued: () => queued++);
  });

  tearDown(() => db.close());

  NumberQuestAttemptResult finishNumberQuest(NumberQuestProgress progress) {
    final s = NumberQuestSession(progress: progress, seed: 1);
    while (s.phase != ActivityPhase.finished) {
      s.select(s.current.answer);
      s.next();
    }
    return s.result!;
  }

  test('fresh progress for both games', () async {
    expect((await repo.loadNumberQuest()).completedAttempts, 0);
    expect((await repo.loadMemoryMatch()).completedAttempts, 0);
  });

  test('a completed attempt is saved locally and queued for sync', () async {
    final result = finishNumberQuest(await repo.loadNumberQuest());
    await repo.completeAttempt(
      game: MathGameId.numberQuest,
      progressAfter: result.progressAfter.toJson(),
      payload: result.payload,
    );

    final progress = await repo.loadNumberQuest();
    expect(progress.completedAttempts, 1);
    expect(progress.nextAttemptType, AttemptType.scored);

    final pending = await db.pendingActivityResultDao.getUnsynced();
    expect(pending, hasLength(1));
    expect(pending.single.componentName, 'math_memory');
    expect(pending.single.activityId, 'number_quest');
    expect(pending.single.childId, testChildId);
    final payload = jsonDecode(pending.single.resultPayload) as Map<String, dynamic>;
    expect(payload['attempt_type'], 'baseline');
    expect(payload['completion_status'], 'completed');
    expect(payload['schema_version'], 1);
    expect(payload['activities'], hasLength(10));
    expect(queued, 1);
  });

  test('games keep separate progress: Number Quest baseline does not skip Memory Match baseline', () async {
    final result = finishNumberQuest(await repo.loadNumberQuest());
    await repo.completeAttempt(
      game: MathGameId.numberQuest,
      progressAfter: result.progressAfter.toJson(),
      payload: result.payload,
    );
    await repo.markTutorialSeen(MathGameId.numberQuest);

    final memory = await repo.loadMemoryMatch();
    expect(memory.completedAttempts, 0);
    expect(memory.nextAttemptType, AttemptType.baseline);
    expect(memory.tutorialSeen, isFalse);

    final quest = await repo.loadNumberQuest();
    expect(quest.tutorialSeen, isTrue);
    expect(quest.completedAttempts, 1, reason: 'marking the tutorial keeps attempts');
  });

  test('an abandoned attempt is queued but never counts as the baseline', () async {
    final s = NumberQuestSession(progress: await repo.loadNumberQuest(), seed: 1);
    s.select(s.current.answer);
    await repo.recordAbandonedAttempt(game: MathGameId.numberQuest, payload: s.abandonedPayload());

    final progress = await repo.loadNumberQuest();
    expect(progress.completedAttempts, 0);
    expect(progress.nextAttemptType, AttemptType.baseline);

    final pending = await db.pendingActivityResultDao.getUnsynced();
    expect(jsonDecode(pending.single.resultPayload)['completion_status'], 'abandoned');
  });

  test('progress survives a round trip through JSON', () async {
    final custom = MemoryMatchProgress.initial().copyWith(
      completedAttempts: 3,
      adaptive: const MemoryAdaptiveState(
        config: MemoryConfig(positions: 6, memorizeSeconds: 4),
        successStreak: 1,
        nextHarder: MemoryFactor.time,
        recent: [1, 0.5],
      ),
    );
    await repo.completeAttempt(
      game: MathGameId.memoryMatch,
      progressAfter: custom.toJson(),
      payload: const {'test': true},
    );
    final loaded = await repo.loadMemoryMatch();
    expect(loaded.completedAttempts, 3);
    expect(loaded.adaptive.config, const MemoryConfig(positions: 6, memorizeSeconds: 4));
    expect(loaded.adaptive.nextHarder, MemoryFactor.time);
    expect(loaded.adaptive.recent, [1.0, 0.5]);
  });

  test('falls back to the stored profile when no child is active', () async {
    final noChild = MathProgressRepository(db, () => null);
    await expectLater(noChild.loadNumberQuest(), throwsStateError);

    await db.childProfileDao.upsert(ChildProfilesCompanion.insert(
      id: 'stored-child',
      name: 'Learner',
      avatarId: 'avatar_1',
      preferredLanguage: 'en',
    ));
    await noChild.markTutorialSeen(MathGameId.memoryMatch);
    expect(await db.localLearnerProgressDao.getProgressData('stored-child', 'memory_match'), isNotNull);
  });
}
