import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/db/app_database.dart';
import '../../../core/network/api_client.dart';

/// Id of the single local profile, or null until the splash screen's
/// bootstrap (`ProfileController.ensureProfileExists`) has run.
final activeChildIdProvider = StateProvider<String?>((ref) => null);

/// The single local profile, if one has been created yet.
final currentProfileProvider = StreamProvider<ChildProfile?>((ref) {
  return ref.watch(appDatabaseProvider).childProfileDao.watchSingle();
});

class ProfileController {
  ProfileController(this._db, this._dio);

  final AppDatabase _db;
  final Dio _dio;

  /// Called once from the splash screen. If a profile already exists
  /// locally, returns its id; otherwise creates a default one (no user
  /// input needed — see decision-log.md) and returns the new id.
  Future<String> ensureProfileExists() async {
    final existing = await _db.childProfileDao.getSingleOnce();
    if (existing != null) return existing.id;

    final id = const Uuid().v4();
    const name = 'Learner';
    const avatarId = 'avatar_1';
    const preferredLanguage = 'en';

    await _db.childProfileDao.upsert(
      ChildProfilesCompanion.insert(
        id: id,
        name: name,
        avatarId: avatarId,
        preferredLanguage: preferredLanguage,
      ),
    );

    await _syncToBackend(id: id, name: name, preferredLanguage: preferredLanguage, grade: null);
    return id;
  }

  /// Used by the Settings screen to edit name/avatar/language.
  Future<void> updateProfile({
    required String id,
    required String name,
    required String avatarId,
    required String preferredLanguage,
    int? grade,
  }) async {
    await _db.childProfileDao.upsert(
      ChildProfilesCompanion(
        id: Value(id),
        name: Value(name),
        avatarId: Value(avatarId),
        preferredLanguage: Value(preferredLanguage),
        grade: Value(grade),
      ),
    );

    await _syncToBackend(id: id, name: name, preferredLanguage: preferredLanguage, grade: grade);
  }

  // Best-effort sync to the backend; failure is fine, the profile stays
  // local until connectivity allows a retry (future improvement, see
  // decision-log.md). The backend upserts by id, so this is safe to call
  // for both creation and edits.
  Future<void> _syncToBackend({
    required String id,
    required String name,
    required String preferredLanguage,
    required int? grade,
  }) async {
    try {
      await _dio.post('/child-profiles', data: {
        'id': id,
        'name': name,
        'preferred_language': preferredLanguage,
        'grade': grade,
      });
    } catch (_) {
      // Ignored: profile is already usable locally.
    }
  }
}

final profileControllerProvider = Provider<ProfileController>((ref) {
  return ProfileController(ref.watch(appDatabaseProvider), ref.watch(apiClientProvider));
});
