import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../engine/feature_extractor.dart';
import '../engine/learner_model.dart';
import '../engine/spelling_config.dart';

/// Where the spelling component keeps its data. Swap the implementation for
/// a REST backend later without touching the engine or UI.
abstract class SpellingStorage {
  Future<List<ChildModel>> loadChildren();
  Future<ChildModel?> loadChild(String childId);
  Future<void> saveChild(ChildModel child);

  Future<void> saveRow(FeatureRow row);
  Future<List<FeatureRow>> loadRows({String? childId});

  /// One word's raw events: {childId, sessionId, roundNo, wordIndex, word_id, events: [...]}.
  Future<void> saveEvents(Map<String, Object?> wordEvents);
  Future<List<Map<String, Object?>>> loadEvents({String? childId});

  Future<SpellingSettings> loadSettings();
  Future<void> saveSettings(SpellingSettings settings);

  /// Deletes all saved spelling data (children, rows, events, settings).
  Future<void> clearAll();
}

/// JSON files in the app's private documents folder (works offline,
/// survives app restarts). Rows and events are append-only JSON lines.
class FileSpellingStorage implements SpellingStorage {
  FileSpellingStorage({Future<Directory>? root}) : _root = root ?? _defaultRoot();

  final Future<Directory> _root;

  static Future<Directory> _defaultRoot() async {
    final docs = await getApplicationDocumentsDirectory();
    return Directory('${docs.path}/spelling').create(recursive: true);
  }

  Future<Directory> get _childrenDir async =>
      Directory('${(await _root).path}/children').create(recursive: true);
  Future<File> get _rowsFile async => File('${(await _root).path}/feature_rows.jsonl');
  Future<File> get _eventsFile async => File('${(await _root).path}/events.jsonl');
  Future<File> get _settingsFile async => File('${(await _root).path}/settings.json');

  @override
  Future<List<ChildModel>> loadChildren() async {
    final dir = await _childrenDir;
    final children = <ChildModel>[];
    await for (final f in dir.list()) {
      if (f is File && f.path.endsWith('.json')) {
        try {
          children.add(ChildModel.fromJson(jsonDecode(await f.readAsString()) as Map<String, Object?>));
        } catch (_) {
          // Skip a damaged file rather than lose every child.
        }
      }
    }
    return children..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<ChildModel?> loadChild(String childId) async {
    final f = File('${(await _childrenDir).path}/$childId.json');
    if (!await f.exists()) return null;
    return ChildModel.fromJson(jsonDecode(await f.readAsString()) as Map<String, Object?>);
  }

  @override
  Future<void> saveChild(ChildModel child) async {
    final f = File('${(await _childrenDir).path}/${child.childId}.json');
    final tmp = File('${f.path}.tmp');
    await tmp.writeAsString(jsonEncode(child.toJson()), flush: true);
    await tmp.rename(f.path); // atomic replace
  }

  @override
  Future<void> saveRow(FeatureRow row) async =>
      (await _rowsFile).writeAsString('${jsonEncode(row.toJson())}\n', mode: FileMode.append, flush: true);

  @override
  Future<List<FeatureRow>> loadRows({String? childId}) async {
    final rows = (await _readLines(await _rowsFile)).map(FeatureRow.fromJson);
    return [for (final r in rows) if (childId == null || r.childId == childId) r];
  }

  @override
  Future<void> saveEvents(Map<String, Object?> wordEvents) async =>
      (await _eventsFile).writeAsString('${jsonEncode(wordEvents)}\n', mode: FileMode.append, flush: true);

  @override
  Future<List<Map<String, Object?>>> loadEvents({String? childId}) async => [
        for (final e in await _readLines(await _eventsFile))
          if (childId == null || e['childId'] == childId) e,
      ];

  @override
  Future<SpellingSettings> loadSettings() async {
    final f = await _settingsFile;
    if (!await f.exists()) return SpellingSettings();
    return SpellingSettings.fromJson(jsonDecode(await f.readAsString()) as Map<String, Object?>);
  }

  @override
  Future<void> saveSettings(SpellingSettings settings) async =>
      (await _settingsFile).writeAsString(jsonEncode(settings.toJson()), flush: true);

  @override
  Future<void> clearAll() async {
    final root = await _root;
    if (await root.exists()) {
      await for (final entry in root.list()) {
        await entry.delete(recursive: true);
      }
    }
  }

  Future<List<Map<String, Object?>>> _readLines(File f) async {
    if (!await f.exists()) return [];
    final out = <Map<String, Object?>>[];
    for (final line in await f.readAsLines()) {
      if (line.trim().isEmpty) continue;
      try {
        out.add((jsonDecode(line) as Map).cast<String, Object?>());
      } catch (_) {}
    }
    return out;
  }
}

/// In-memory storage for tests and the child simulator.
class InMemorySpellingStorage implements SpellingStorage {
  final Map<String, Map<String, Object?>> _children = {};
  final List<FeatureRow> rows = [];
  final List<Map<String, Object?>> events = [];
  SpellingSettings settings = SpellingSettings();

  @override
  Future<List<ChildModel>> loadChildren() async =>
      _children.values.map(ChildModel.fromJson).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  @override
  Future<ChildModel?> loadChild(String childId) async {
    final j = _children[childId];
    return j == null ? null : ChildModel.fromJson(j);
  }

  @override
  Future<void> saveChild(ChildModel child) async =>
      _children[child.childId] = jsonDecode(jsonEncode(child.toJson())) as Map<String, Object?>;

  @override
  Future<void> saveRow(FeatureRow row) async => rows.add(FeatureRow.fromJson(row.toJson()));

  @override
  Future<List<FeatureRow>> loadRows({String? childId}) async =>
      [for (final r in rows) if (childId == null || r.childId == childId) r];

  @override
  Future<void> saveEvents(Map<String, Object?> wordEvents) async => events.add(wordEvents);

  @override
  Future<List<Map<String, Object?>>> loadEvents({String? childId}) async =>
      [for (final e in events) if (childId == null || e['childId'] == childId) e];

  @override
  Future<SpellingSettings> loadSettings() async => settings;

  @override
  Future<void> saveSettings(SpellingSettings s) async => settings = s;

  @override
  Future<void> clearAll() async {
    _children.clear();
    rows.clear();
    events.clear();
    settings = SpellingSettings();
  }
}
