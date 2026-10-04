import 'package:drift/drift.dart';

/// Local-only child profile — a single row per install (see decision-log.md
/// for why multi-profile support was dropped). `id` is a client-generated
/// UUID that's also synced to the backend's `child_profiles` table (see
/// docs/api-contract.md).
class ChildProfiles extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get avatarId => text()();
  TextColumn get preferredLanguage => text()();
  IntColumn get grade => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
