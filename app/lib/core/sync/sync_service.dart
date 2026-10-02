import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../db/app_database.dart';
import '../network/api_client.dart';
import 'connectivity_service.dart';

/// Minimal, best-effort sync of the offline activity-result queue.
///
/// This deliberately does NOT implement a robust background sync engine
/// (no WorkManager/isolate integration) — see docs/decision-log.md. It is
/// triggered from app start, on connectivity regain, and optionally right
/// after a new result is queued.
class SyncService {
  SyncService(this._db, this._dio);

  final AppDatabase _db;
  final Dio _dio;

  Future<void> flushPendingResults() async {
    final pending = await _db.pendingActivityResultDao.getUnsynced();

    for (final row in pending) {
      try {
        await _dio.post(
          '/activity-results',
          data: {
            'child_id': row.childId,
            'component_name': row.componentName,
            'activity_id': row.activityId,
            'result_payload': jsonDecode(row.resultPayload),
          },
        );
        await _db.pendingActivityResultDao.markSynced(row.id);
      } catch (_) {
        await _db.pendingActivityResultDao.markFailed(row.id);
      }
    }
  }
}

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(ref.watch(appDatabaseProvider), ref.watch(apiClientProvider));
});

/// Listens for connectivity regain and triggers a flush. Call
/// `ref.watch(syncTriggerProvider)` once near app start (e.g. in the home
/// shell's build method) to wire this up.
final syncTriggerProvider = Provider<void>((ref) {
  ref.listen(connectivityProvider, (previous, next) {
    final wasOffline = previous?.maybeWhen(
          data: (results) => results.every((r) => r == ConnectivityResult.none),
          orElse: () => true,
        ) ??
        true;
    final isOnlineNow = next.maybeWhen(
      data: (results) => results.any((r) => r != ConnectivityResult.none),
      orElse: () => false,
    );

    if (wasOffline && isOnlineNow) {
      ref.read(syncServiceProvider).flushPendingResults();
    }
  });
});
