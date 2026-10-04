// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'child_profile_dao.dart';

// ignore_for_file: type=lint
mixin _$ChildProfileDaoMixin on DatabaseAccessor<AppDatabase> {
  $ChildProfilesTable get childProfiles => attachedDatabase.childProfiles;
  ChildProfileDaoManager get managers => ChildProfileDaoManager(this);
}

class ChildProfileDaoManager {
  final _$ChildProfileDaoMixin _db;
  ChildProfileDaoManager(this._db);
  $$ChildProfilesTableTableManager get childProfiles =>
      $$ChildProfilesTableTableManager(_db.attachedDatabase, _db.childProfiles);
}
