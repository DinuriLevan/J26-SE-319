import 'package:drift/drift.dart';

/// On-device progress blobs so features can adapt while offline. Mirrors the
/// backend's `learner_progress` (free-form JSON per component), but keyed by
/// [progressKey] so one component can keep several blobs — e.g. Math &
/// Memory keeps one per game.
@DataClassName('LocalLearnerProgressEntry')
class LocalLearnerProgress extends Table {
  TextColumn get childId => text()();
  TextColumn get progressKey => text()();
  // JSON-encoded object; each feature defines its own shape.
  TextColumn get progressData => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {childId, progressKey};
}
