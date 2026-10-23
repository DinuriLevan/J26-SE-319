import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/local_learner_progress_table.dart';

part 'local_learner_progress_dao.g.dart';

@DriftAccessor(tables: [LocalLearnerProgress])
class LocalLearnerProgressDao extends DatabaseAccessor<AppDatabase>
    with _$LocalLearnerProgressDaoMixin {
  LocalLearnerProgressDao(super.db);

  /// The stored JSON for [progressKey], or null if nothing is saved yet.
  Future<String?> getProgressData(String childId, String progressKey) async {
    final row = await (select(localLearnerProgress)
          ..where((t) => t.childId.equals(childId) & t.progressKey.equals(progressKey)))
        .getSingleOrNull();
    return row?.progressData;
  }

  Future<void> upsert({
    required String childId,
    required String progressKey,
    required String progressData,
  }) {
    return into(localLearnerProgress).insertOnConflictUpdate(
      LocalLearnerProgressCompanion.insert(
        childId: childId,
        progressKey: progressKey,
        progressData: progressData,
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
