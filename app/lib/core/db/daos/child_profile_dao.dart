import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/child_profiles_table.dart';

part 'child_profile_dao.g.dart';

@DriftAccessor(tables: [ChildProfiles])
class ChildProfileDao extends DatabaseAccessor<AppDatabase> with _$ChildProfileDaoMixin {
  ChildProfileDao(super.db);

  /// There is at most one profile per install (see decision-log.md), so this
  /// is the main way features should read it.
  Stream<ChildProfile?> watchSingle() =>
      select(childProfiles).watchSingleOrNull();

  Future<ChildProfile?> getSingleOnce() =>
      select(childProfiles).getSingleOrNull();

  Future<ChildProfile?> getById(String id) =>
      (select(childProfiles)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<void> upsert(ChildProfilesCompanion profile) =>
      into(childProfiles).insertOnConflictUpdate(profile);
}
