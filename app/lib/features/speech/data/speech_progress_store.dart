import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/db/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../../core/sync/sync_service.dart';
import '../logic/speech_rewards.dart';

/// Speech's use of the shared on-device queue and card album. Reads the shared
/// pending_activity_results table (rows stay after syncing) but never changes its schema.
class SpeechProgressStore {
  SpeechProgressStore(this._db, this._dio, this._sync);

  final AppDatabase _db;
  final Dio _dio;
  final SyncService _sync;

  /// Writes the one ActivityResult for a finished word (docs/CONTRIBUTING.md) and syncs.
  Future<void> recordCompletedWord(
      String childId, Map<String, Object?> payload) async {
    await _db.pendingActivityResultDao.enqueue(
      childId: childId,
      componentName: 'speech',
      activityId: 'speech_word:${payload['word_id']}',
      resultPayload: jsonEncode(payload),
    );
    unawaited(_sync.flushPendingResults());
  }

  /// Number of different words this child has mastered, from the local record of finished words.
  Future<int> masteredWordCount(String childId) async {
    final rows = await (_db.select(_db.pendingActivityResults)
          ..where((t) =>
              t.childId.equals(childId) & t.componentName.equals('speech')))
        .get();
    final words = <String>{};
    for (final r in rows) {
      final payload = jsonDecode(r.resultPayload) as Map<String, dynamic>;
      if (payload['outcome'] == 'mastered') {
        words.add(payload['word_id'] as String);
      }
    }
    return words.length;
  }

  /// After a word is mastered: unlock the milestone card if this word reached one. Best effort:
  /// returns the card id if the unlock call succeeded, else null (offline handling is Stage 6).
  Future<String?> unlockMilestoneIfReached(String childId) async {
    final card = milestoneCard(await masteredWordCount(childId));
    if (card == null) return null;
    try {
      await _dio.post('/rewards/$childId/unlock', data: {'card_id': card});
      return card;
    } on DioException {
      return null;
    }
  }
}

final speechProgressStoreProvider = Provider<SpeechProgressStore>((ref) {
  return SpeechProgressStore(
    ref.watch(appDatabaseProvider),
    ref.watch(apiClientProvider),
    ref.watch(syncServiceProvider),
  );
});
