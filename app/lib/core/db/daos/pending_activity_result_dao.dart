import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/pending_activity_results_table.dart';

part 'pending_activity_result_dao.g.dart';

@DriftAccessor(tables: [PendingActivityResults])
class PendingActivityResultDao extends DatabaseAccessor<AppDatabase>
    with _$PendingActivityResultDaoMixin {
  PendingActivityResultDao(super.db);

  /// Used by each feature component to queue a result for sync — see
  /// docs/CONTRIBUTING.md for the expected shape.
  Future<int> enqueue({
    required String childId,
    required String componentName,
    required String activityId,
    required String resultPayload,
  }) {
    return into(pendingActivityResults).insert(
      PendingActivityResultsCompanion.insert(
        childId: childId,
        componentName: componentName,
        activityId: activityId,
        resultPayload: resultPayload,
      ),
    );
  }

  Future<List<PendingActivityResult>> getUnsynced() {
    return (select(pendingActivityResults)
          ..where((t) => t.syncStatus.isIn(['pending', 'failed'])))
        .get();
  }

  Stream<int> watchPendingCount() {
    final query = selectOnly(pendingActivityResults)
      ..addColumns([pendingActivityResults.id.count()])
      ..where(pendingActivityResults.syncStatus.isIn(['pending', 'failed']));
    return query.map((row) => row.read(pendingActivityResults.id.count()) ?? 0).watchSingle();
  }

  Future<void> markSynced(int id) {
    return (update(pendingActivityResults)..where((t) => t.id.equals(id))).write(
      PendingActivityResultsCompanion(
        syncStatus: const Value('synced'),
        syncedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> markFailed(int id) {
    return (update(pendingActivityResults)..where((t) => t.id.equals(id))).write(
      const PendingActivityResultsCompanion(syncStatus: Value('failed')),
    );
  }
}
