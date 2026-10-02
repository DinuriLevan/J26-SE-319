// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ChildProfilesTable extends ChildProfiles
    with TableInfo<$ChildProfilesTable, ChildProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ChildProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _avatarIdMeta =
      const VerificationMeta('avatarId');
  @override
  late final GeneratedColumn<String> avatarId = GeneratedColumn<String>(
      'avatar_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _preferredLanguageMeta =
      const VerificationMeta('preferredLanguage');
  @override
  late final GeneratedColumn<String> preferredLanguage =
      GeneratedColumn<String>('preferred_language', aliasedName, false,
          type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _gradeMeta = const VerificationMeta('grade');
  @override
  late final GeneratedColumn<int> grade = GeneratedColumn<int>(
      'grade', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, avatarId, preferredLanguage, grade, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'child_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<ChildProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('avatar_id')) {
      context.handle(_avatarIdMeta,
          avatarId.isAcceptableOrUnknown(data['avatar_id']!, _avatarIdMeta));
    } else if (isInserting) {
      context.missing(_avatarIdMeta);
    }
    if (data.containsKey('preferred_language')) {
      context.handle(
          _preferredLanguageMeta,
          preferredLanguage.isAcceptableOrUnknown(
              data['preferred_language']!, _preferredLanguageMeta));
    } else if (isInserting) {
      context.missing(_preferredLanguageMeta);
    }
    if (data.containsKey('grade')) {
      context.handle(
          _gradeMeta, grade.isAcceptableOrUnknown(data['grade']!, _gradeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ChildProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ChildProfile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      avatarId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar_id'])!,
      preferredLanguage: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}preferred_language'])!,
      grade: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}grade']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $ChildProfilesTable createAlias(String alias) {
    return $ChildProfilesTable(attachedDatabase, alias);
  }
}

class ChildProfile extends DataClass implements Insertable<ChildProfile> {
  final String id;
  final String name;
  final String avatarId;
  final String preferredLanguage;
  final int? grade;
  final DateTime createdAt;
  const ChildProfile(
      {required this.id,
      required this.name,
      required this.avatarId,
      required this.preferredLanguage,
      this.grade,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['avatar_id'] = Variable<String>(avatarId);
    map['preferred_language'] = Variable<String>(preferredLanguage);
    if (!nullToAbsent || grade != null) {
      map['grade'] = Variable<int>(grade);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ChildProfilesCompanion toCompanion(bool nullToAbsent) {
    return ChildProfilesCompanion(
      id: Value(id),
      name: Value(name),
      avatarId: Value(avatarId),
      preferredLanguage: Value(preferredLanguage),
      grade:
          grade == null && nullToAbsent ? const Value.absent() : Value(grade),
      createdAt: Value(createdAt),
    );
  }

  factory ChildProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ChildProfile(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      avatarId: serializer.fromJson<String>(json['avatarId']),
      preferredLanguage: serializer.fromJson<String>(json['preferredLanguage']),
      grade: serializer.fromJson<int?>(json['grade']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'avatarId': serializer.toJson<String>(avatarId),
      'preferredLanguage': serializer.toJson<String>(preferredLanguage),
      'grade': serializer.toJson<int?>(grade),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  ChildProfile copyWith(
          {String? id,
          String? name,
          String? avatarId,
          String? preferredLanguage,
          Value<int?> grade = const Value.absent(),
          DateTime? createdAt}) =>
      ChildProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        avatarId: avatarId ?? this.avatarId,
        preferredLanguage: preferredLanguage ?? this.preferredLanguage,
        grade: grade.present ? grade.value : this.grade,
        createdAt: createdAt ?? this.createdAt,
      );
  ChildProfile copyWithCompanion(ChildProfilesCompanion data) {
    return ChildProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      avatarId: data.avatarId.present ? data.avatarId.value : this.avatarId,
      preferredLanguage: data.preferredLanguage.present
          ? data.preferredLanguage.value
          : this.preferredLanguage,
      grade: data.grade.present ? data.grade.value : this.grade,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ChildProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarId: $avatarId, ')
          ..write('preferredLanguage: $preferredLanguage, ')
          ..write('grade: $grade, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, avatarId, preferredLanguage, grade, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ChildProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.avatarId == this.avatarId &&
          other.preferredLanguage == this.preferredLanguage &&
          other.grade == this.grade &&
          other.createdAt == this.createdAt);
}

class ChildProfilesCompanion extends UpdateCompanion<ChildProfile> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> avatarId;
  final Value<String> preferredLanguage;
  final Value<int?> grade;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const ChildProfilesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.avatarId = const Value.absent(),
    this.preferredLanguage = const Value.absent(),
    this.grade = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ChildProfilesCompanion.insert({
    required String id,
    required String name,
    required String avatarId,
    required String preferredLanguage,
    this.grade = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        avatarId = Value(avatarId),
        preferredLanguage = Value(preferredLanguage);
  static Insertable<ChildProfile> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? avatarId,
    Expression<String>? preferredLanguage,
    Expression<int>? grade,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (avatarId != null) 'avatar_id': avatarId,
      if (preferredLanguage != null) 'preferred_language': preferredLanguage,
      if (grade != null) 'grade': grade,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ChildProfilesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? avatarId,
      Value<String>? preferredLanguage,
      Value<int?>? grade,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return ChildProfilesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      avatarId: avatarId ?? this.avatarId,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      grade: grade ?? this.grade,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (avatarId.present) {
      map['avatar_id'] = Variable<String>(avatarId.value);
    }
    if (preferredLanguage.present) {
      map['preferred_language'] = Variable<String>(preferredLanguage.value);
    }
    if (grade.present) {
      map['grade'] = Variable<int>(grade.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ChildProfilesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('avatarId: $avatarId, ')
          ..write('preferredLanguage: $preferredLanguage, ')
          ..write('grade: $grade, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PendingActivityResultsTable extends PendingActivityResults
    with TableInfo<$PendingActivityResultsTable, PendingActivityResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingActivityResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _childIdMeta =
      const VerificationMeta('childId');
  @override
  late final GeneratedColumn<String> childId = GeneratedColumn<String>(
      'child_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _componentNameMeta =
      const VerificationMeta('componentName');
  @override
  late final GeneratedColumn<String> componentName = GeneratedColumn<String>(
      'component_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _activityIdMeta =
      const VerificationMeta('activityId');
  @override
  late final GeneratedColumn<String> activityId = GeneratedColumn<String>(
      'activity_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _resultPayloadMeta =
      const VerificationMeta('resultPayload');
  @override
  late final GeneratedColumn<String> resultPayload = GeneratedColumn<String>(
      'result_payload', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _syncedAtMeta =
      const VerificationMeta('syncedAt');
  @override
  late final GeneratedColumn<DateTime> syncedAt = GeneratedColumn<DateTime>(
      'synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _syncStatusMeta =
      const VerificationMeta('syncStatus');
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
      'sync_status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        childId,
        componentName,
        activityId,
        resultPayload,
        createdAt,
        syncedAt,
        syncStatus
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_activity_results';
  @override
  VerificationContext validateIntegrity(
      Insertable<PendingActivityResult> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('child_id')) {
      context.handle(_childIdMeta,
          childId.isAcceptableOrUnknown(data['child_id']!, _childIdMeta));
    } else if (isInserting) {
      context.missing(_childIdMeta);
    }
    if (data.containsKey('component_name')) {
      context.handle(
          _componentNameMeta,
          componentName.isAcceptableOrUnknown(
              data['component_name']!, _componentNameMeta));
    } else if (isInserting) {
      context.missing(_componentNameMeta);
    }
    if (data.containsKey('activity_id')) {
      context.handle(
          _activityIdMeta,
          activityId.isAcceptableOrUnknown(
              data['activity_id']!, _activityIdMeta));
    } else if (isInserting) {
      context.missing(_activityIdMeta);
    }
    if (data.containsKey('result_payload')) {
      context.handle(
          _resultPayloadMeta,
          resultPayload.isAcceptableOrUnknown(
              data['result_payload']!, _resultPayloadMeta));
    } else if (isInserting) {
      context.missing(_resultPayloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('synced_at')) {
      context.handle(_syncedAtMeta,
          syncedAt.isAcceptableOrUnknown(data['synced_at']!, _syncedAtMeta));
    }
    if (data.containsKey('sync_status')) {
      context.handle(
          _syncStatusMeta,
          syncStatus.isAcceptableOrUnknown(
              data['sync_status']!, _syncStatusMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingActivityResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingActivityResult(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      childId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}child_id'])!,
      componentName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}component_name'])!,
      activityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}activity_id'])!,
      resultPayload: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}result_payload'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      syncedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}synced_at']),
      syncStatus: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sync_status'])!,
    );
  }

  @override
  $PendingActivityResultsTable createAlias(String alias) {
    return $PendingActivityResultsTable(attachedDatabase, alias);
  }
}

class PendingActivityResult extends DataClass
    implements Insertable<PendingActivityResult> {
  final int id;
  final String childId;
  final String componentName;
  final String activityId;
  final String resultPayload;
  final DateTime createdAt;
  final DateTime? syncedAt;
  final String syncStatus;
  const PendingActivityResult(
      {required this.id,
      required this.childId,
      required this.componentName,
      required this.activityId,
      required this.resultPayload,
      required this.createdAt,
      this.syncedAt,
      required this.syncStatus});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['child_id'] = Variable<String>(childId);
    map['component_name'] = Variable<String>(componentName);
    map['activity_id'] = Variable<String>(activityId);
    map['result_payload'] = Variable<String>(resultPayload);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || syncedAt != null) {
      map['synced_at'] = Variable<DateTime>(syncedAt);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  PendingActivityResultsCompanion toCompanion(bool nullToAbsent) {
    return PendingActivityResultsCompanion(
      id: Value(id),
      childId: Value(childId),
      componentName: Value(componentName),
      activityId: Value(activityId),
      resultPayload: Value(resultPayload),
      createdAt: Value(createdAt),
      syncedAt: syncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(syncedAt),
      syncStatus: Value(syncStatus),
    );
  }

  factory PendingActivityResult.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingActivityResult(
      id: serializer.fromJson<int>(json['id']),
      childId: serializer.fromJson<String>(json['childId']),
      componentName: serializer.fromJson<String>(json['componentName']),
      activityId: serializer.fromJson<String>(json['activityId']),
      resultPayload: serializer.fromJson<String>(json['resultPayload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      syncedAt: serializer.fromJson<DateTime?>(json['syncedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'childId': serializer.toJson<String>(childId),
      'componentName': serializer.toJson<String>(componentName),
      'activityId': serializer.toJson<String>(activityId),
      'resultPayload': serializer.toJson<String>(resultPayload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'syncedAt': serializer.toJson<DateTime?>(syncedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  PendingActivityResult copyWith(
          {int? id,
          String? childId,
          String? componentName,
          String? activityId,
          String? resultPayload,
          DateTime? createdAt,
          Value<DateTime?> syncedAt = const Value.absent(),
          String? syncStatus}) =>
      PendingActivityResult(
        id: id ?? this.id,
        childId: childId ?? this.childId,
        componentName: componentName ?? this.componentName,
        activityId: activityId ?? this.activityId,
        resultPayload: resultPayload ?? this.resultPayload,
        createdAt: createdAt ?? this.createdAt,
        syncedAt: syncedAt.present ? syncedAt.value : this.syncedAt,
        syncStatus: syncStatus ?? this.syncStatus,
      );
  PendingActivityResult copyWithCompanion(
      PendingActivityResultsCompanion data) {
    return PendingActivityResult(
      id: data.id.present ? data.id.value : this.id,
      childId: data.childId.present ? data.childId.value : this.childId,
      componentName: data.componentName.present
          ? data.componentName.value
          : this.componentName,
      activityId:
          data.activityId.present ? data.activityId.value : this.activityId,
      resultPayload: data.resultPayload.present
          ? data.resultPayload.value
          : this.resultPayload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      syncedAt: data.syncedAt.present ? data.syncedAt.value : this.syncedAt,
      syncStatus:
          data.syncStatus.present ? data.syncStatus.value : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingActivityResult(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('componentName: $componentName, ')
          ..write('activityId: $activityId, ')
          ..write('resultPayload: $resultPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, childId, componentName, activityId,
      resultPayload, createdAt, syncedAt, syncStatus);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingActivityResult &&
          other.id == this.id &&
          other.childId == this.childId &&
          other.componentName == this.componentName &&
          other.activityId == this.activityId &&
          other.resultPayload == this.resultPayload &&
          other.createdAt == this.createdAt &&
          other.syncedAt == this.syncedAt &&
          other.syncStatus == this.syncStatus);
}

class PendingActivityResultsCompanion
    extends UpdateCompanion<PendingActivityResult> {
  final Value<int> id;
  final Value<String> childId;
  final Value<String> componentName;
  final Value<String> activityId;
  final Value<String> resultPayload;
  final Value<DateTime> createdAt;
  final Value<DateTime?> syncedAt;
  final Value<String> syncStatus;
  const PendingActivityResultsCompanion({
    this.id = const Value.absent(),
    this.childId = const Value.absent(),
    this.componentName = const Value.absent(),
    this.activityId = const Value.absent(),
    this.resultPayload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  PendingActivityResultsCompanion.insert({
    this.id = const Value.absent(),
    required String childId,
    required String componentName,
    required String activityId,
    required String resultPayload,
    this.createdAt = const Value.absent(),
    this.syncedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
  })  : childId = Value(childId),
        componentName = Value(componentName),
        activityId = Value(activityId),
        resultPayload = Value(resultPayload);
  static Insertable<PendingActivityResult> custom({
    Expression<int>? id,
    Expression<String>? childId,
    Expression<String>? componentName,
    Expression<String>? activityId,
    Expression<String>? resultPayload,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? syncedAt,
    Expression<String>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (childId != null) 'child_id': childId,
      if (componentName != null) 'component_name': componentName,
      if (activityId != null) 'activity_id': activityId,
      if (resultPayload != null) 'result_payload': resultPayload,
      if (createdAt != null) 'created_at': createdAt,
      if (syncedAt != null) 'synced_at': syncedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  PendingActivityResultsCompanion copyWith(
      {Value<int>? id,
      Value<String>? childId,
      Value<String>? componentName,
      Value<String>? activityId,
      Value<String>? resultPayload,
      Value<DateTime>? createdAt,
      Value<DateTime?>? syncedAt,
      Value<String>? syncStatus}) {
    return PendingActivityResultsCompanion(
      id: id ?? this.id,
      childId: childId ?? this.childId,
      componentName: componentName ?? this.componentName,
      activityId: activityId ?? this.activityId,
      resultPayload: resultPayload ?? this.resultPayload,
      createdAt: createdAt ?? this.createdAt,
      syncedAt: syncedAt ?? this.syncedAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (childId.present) {
      map['child_id'] = Variable<String>(childId.value);
    }
    if (componentName.present) {
      map['component_name'] = Variable<String>(componentName.value);
    }
    if (activityId.present) {
      map['activity_id'] = Variable<String>(activityId.value);
    }
    if (resultPayload.present) {
      map['result_payload'] = Variable<String>(resultPayload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (syncedAt.present) {
      map['synced_at'] = Variable<DateTime>(syncedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingActivityResultsCompanion(')
          ..write('id: $id, ')
          ..write('childId: $childId, ')
          ..write('componentName: $componentName, ')
          ..write('activityId: $activityId, ')
          ..write('resultPayload: $resultPayload, ')
          ..write('createdAt: $createdAt, ')
          ..write('syncedAt: $syncedAt, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ChildProfilesTable childProfiles = $ChildProfilesTable(this);
  late final $PendingActivityResultsTable pendingActivityResults =
      $PendingActivityResultsTable(this);
  late final ChildProfileDao childProfileDao =
      ChildProfileDao(this as AppDatabase);
  late final PendingActivityResultDao pendingActivityResultDao =
      PendingActivityResultDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [childProfiles, pendingActivityResults];
}

typedef $$ChildProfilesTableCreateCompanionBuilder = ChildProfilesCompanion
    Function({
  required String id,
  required String name,
  required String avatarId,
  required String preferredLanguage,
  Value<int?> grade,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$ChildProfilesTableUpdateCompanionBuilder = ChildProfilesCompanion
    Function({
  Value<String> id,
  Value<String> name,
  Value<String> avatarId,
  Value<String> preferredLanguage,
  Value<int?> grade,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$ChildProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatarId => $composableBuilder(
      column: $table.avatarId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get preferredLanguage => $composableBuilder(
      column: $table.preferredLanguage,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get grade => $composableBuilder(
      column: $table.grade, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$ChildProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatarId => $composableBuilder(
      column: $table.avatarId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get preferredLanguage => $composableBuilder(
      column: $table.preferredLanguage,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get grade => $composableBuilder(
      column: $table.grade, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$ChildProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ChildProfilesTable> {
  $$ChildProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get avatarId =>
      $composableBuilder(column: $table.avatarId, builder: (column) => column);

  GeneratedColumn<String> get preferredLanguage => $composableBuilder(
      column: $table.preferredLanguage, builder: (column) => column);

  GeneratedColumn<int> get grade =>
      $composableBuilder(column: $table.grade, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ChildProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ChildProfilesTable,
    ChildProfile,
    $$ChildProfilesTableFilterComposer,
    $$ChildProfilesTableOrderingComposer,
    $$ChildProfilesTableAnnotationComposer,
    $$ChildProfilesTableCreateCompanionBuilder,
    $$ChildProfilesTableUpdateCompanionBuilder,
    (
      ChildProfile,
      BaseReferences<_$AppDatabase, $ChildProfilesTable, ChildProfile>
    ),
    ChildProfile,
    PrefetchHooks Function()> {
  $$ChildProfilesTableTableManager(_$AppDatabase db, $ChildProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ChildProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ChildProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ChildProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> avatarId = const Value.absent(),
            Value<String> preferredLanguage = const Value.absent(),
            Value<int?> grade = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChildProfilesCompanion(
            id: id,
            name: name,
            avatarId: avatarId,
            preferredLanguage: preferredLanguage,
            grade: grade,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String avatarId,
            required String preferredLanguage,
            Value<int?> grade = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ChildProfilesCompanion.insert(
            id: id,
            name: name,
            avatarId: avatarId,
            preferredLanguage: preferredLanguage,
            grade: grade,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ChildProfilesTable, ChildProfile>(table),
                    BaseReferences<_$AppDatabase, $ChildProfilesTable,
                        ChildProfile>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ChildProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ChildProfilesTable,
    ChildProfile,
    $$ChildProfilesTableFilterComposer,
    $$ChildProfilesTableOrderingComposer,
    $$ChildProfilesTableAnnotationComposer,
    $$ChildProfilesTableCreateCompanionBuilder,
    $$ChildProfilesTableUpdateCompanionBuilder,
    (
      ChildProfile,
      BaseReferences<_$AppDatabase, $ChildProfilesTable, ChildProfile>
    ),
    ChildProfile,
    PrefetchHooks Function()>;
typedef $$PendingActivityResultsTableCreateCompanionBuilder
    = PendingActivityResultsCompanion Function({
  Value<int> id,
  required String childId,
  required String componentName,
  required String activityId,
  required String resultPayload,
  Value<DateTime> createdAt,
  Value<DateTime?> syncedAt,
  Value<String> syncStatus,
});
typedef $$PendingActivityResultsTableUpdateCompanionBuilder
    = PendingActivityResultsCompanion Function({
  Value<int> id,
  Value<String> childId,
  Value<String> componentName,
  Value<String> activityId,
  Value<String> resultPayload,
  Value<DateTime> createdAt,
  Value<DateTime?> syncedAt,
  Value<String> syncStatus,
});

class $$PendingActivityResultsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingActivityResultsTable> {
  $$PendingActivityResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get childId => $composableBuilder(
      column: $table.childId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get componentName => $composableBuilder(
      column: $table.componentName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get activityId => $composableBuilder(
      column: $table.activityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get resultPayload => $composableBuilder(
      column: $table.resultPayload, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnFilters(column));
}

class $$PendingActivityResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingActivityResultsTable> {
  $$PendingActivityResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get childId => $composableBuilder(
      column: $table.childId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get componentName => $composableBuilder(
      column: $table.componentName,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get activityId => $composableBuilder(
      column: $table.activityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get resultPayload => $composableBuilder(
      column: $table.resultPayload,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get syncedAt => $composableBuilder(
      column: $table.syncedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => ColumnOrderings(column));
}

class $$PendingActivityResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingActivityResultsTable> {
  $$PendingActivityResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get childId =>
      $composableBuilder(column: $table.childId, builder: (column) => column);

  GeneratedColumn<String> get componentName => $composableBuilder(
      column: $table.componentName, builder: (column) => column);

  GeneratedColumn<String> get activityId => $composableBuilder(
      column: $table.activityId, builder: (column) => column);

  GeneratedColumn<String> get resultPayload => $composableBuilder(
      column: $table.resultPayload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get syncedAt =>
      $composableBuilder(column: $table.syncedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
      column: $table.syncStatus, builder: (column) => column);
}

class $$PendingActivityResultsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PendingActivityResultsTable,
    PendingActivityResult,
    $$PendingActivityResultsTableFilterComposer,
    $$PendingActivityResultsTableOrderingComposer,
    $$PendingActivityResultsTableAnnotationComposer,
    $$PendingActivityResultsTableCreateCompanionBuilder,
    $$PendingActivityResultsTableUpdateCompanionBuilder,
    (
      PendingActivityResult,
      BaseReferences<_$AppDatabase, $PendingActivityResultsTable,
          PendingActivityResult>
    ),
    PendingActivityResult,
    PrefetchHooks Function()> {
  $$PendingActivityResultsTableTableManager(
      _$AppDatabase db, $PendingActivityResultsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingActivityResultsTableFilterComposer(
                  $db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingActivityResultsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingActivityResultsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> childId = const Value.absent(),
            Value<String> componentName = const Value.absent(),
            Value<String> activityId = const Value.absent(),
            Value<String> resultPayload = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
          }) =>
              PendingActivityResultsCompanion(
            id: id,
            childId: childId,
            componentName: componentName,
            activityId: activityId,
            resultPayload: resultPayload,
            createdAt: createdAt,
            syncedAt: syncedAt,
            syncStatus: syncStatus,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String childId,
            required String componentName,
            required String activityId,
            required String resultPayload,
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> syncedAt = const Value.absent(),
            Value<String> syncStatus = const Value.absent(),
          }) =>
              PendingActivityResultsCompanion.insert(
            id: id,
            childId: childId,
            componentName: componentName,
            activityId: activityId,
            resultPayload: resultPayload,
            createdAt: createdAt,
            syncedAt: syncedAt,
            syncStatus: syncStatus,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PendingActivityResultsTable,
                        PendingActivityResult>(table),
                    BaseReferences<_$AppDatabase, $PendingActivityResultsTable,
                        PendingActivityResult>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PendingActivityResultsTableProcessedTableManager
    = ProcessedTableManager<
        _$AppDatabase,
        $PendingActivityResultsTable,
        PendingActivityResult,
        $$PendingActivityResultsTableFilterComposer,
        $$PendingActivityResultsTableOrderingComposer,
        $$PendingActivityResultsTableAnnotationComposer,
        $$PendingActivityResultsTableCreateCompanionBuilder,
        $$PendingActivityResultsTableUpdateCompanionBuilder,
        (
          PendingActivityResult,
          BaseReferences<_$AppDatabase, $PendingActivityResultsTable,
              PendingActivityResult>
        ),
        PendingActivityResult,
        PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ChildProfilesTableTableManager get childProfiles =>
      $$ChildProfilesTableTableManager(_db, _db.childProfiles);
  $$PendingActivityResultsTableTableManager get pendingActivityResults =>
      $$PendingActivityResultsTableTableManager(
          _db, _db.pendingActivityResults);
}
