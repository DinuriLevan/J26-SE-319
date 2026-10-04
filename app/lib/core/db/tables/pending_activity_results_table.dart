import 'package:drift/drift.dart';

/// Generic offline queue of activity results. ALL four feature components
/// write into this one table (tagged by [componentName]) and the shared
/// sync service flushes it to the backend's POST /activity-results.
class PendingActivityResults extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get childId => text()();
  TextColumn get componentName => text()();
  TextColumn get activityId => text()();
  // JSON-encoded string; encode/decode with dart:convert at the call site.
  TextColumn get resultPayload => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get syncedAt => dateTime().nullable()();
  // One of: 'pending' / 'syncing' / 'synced' / 'failed'.
  TextColumn get syncStatus => text().withDefault(const Constant('pending'))();
}
