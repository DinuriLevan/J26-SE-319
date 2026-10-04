// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pending_activity_result_dao.dart';

// ignore_for_file: type=lint
mixin _$PendingActivityResultDaoMixin on DatabaseAccessor<AppDatabase> {
  $PendingActivityResultsTable get pendingActivityResults =>
      attachedDatabase.pendingActivityResults;
  PendingActivityResultDaoManager get managers =>
      PendingActivityResultDaoManager(this);
}

class PendingActivityResultDaoManager {
  final _$PendingActivityResultDaoMixin _db;
  PendingActivityResultDaoManager(this._db);
  $$PendingActivityResultsTableTableManager get pendingActivityResults =>
      $$PendingActivityResultsTableTableManager(
          _db.attachedDatabase, _db.pendingActivityResults);
}
