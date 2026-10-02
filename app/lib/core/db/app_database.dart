import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/child_profile_dao.dart';
import 'daos/pending_activity_result_dao.dart';
import 'tables/child_profiles_table.dart';
import 'tables/pending_activity_results_table.dart';

part 'app_database.g.dart';

/// Shared drift database instance. All four components should read/write
/// through this provider rather than opening their own database connection.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

@DriftDatabase(
  tables: [ChildProfiles, PendingActivityResults],
  daos: [ChildProfileDao, PendingActivityResultDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // Dropped the PIN column when multi-profile switching was
            // removed (see decision-log.md). This is a local SQLite cache,
            // not the backend's source of truth, so a destructive recreate
            // of just this table is acceptable — the app auto-creates a
            // fresh profile on next splash if this one is gone.
            await m.deleteTable('child_profiles');
            await m.createTable(childProfiles);
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'akurin.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
