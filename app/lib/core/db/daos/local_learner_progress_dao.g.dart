// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_learner_progress_dao.dart';

// ignore_for_file: type=lint
mixin _$LocalLearnerProgressDaoMixin on DatabaseAccessor<AppDatabase> {
  $LocalLearnerProgressTable get localLearnerProgress =>
      attachedDatabase.localLearnerProgress;
  LocalLearnerProgressDaoManager get managers =>
      LocalLearnerProgressDaoManager(this);
}

class LocalLearnerProgressDaoManager {
  final _$LocalLearnerProgressDaoMixin _db;
  LocalLearnerProgressDaoManager(this._db);
  $$LocalLearnerProgressTableTableManager get localLearnerProgress =>
      $$LocalLearnerProgressTableTableManager(
          _db.attachedDatabase, _db.localLearnerProgress);
}
