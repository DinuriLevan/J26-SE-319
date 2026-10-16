import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'speech_words.dart';

/// One unit (akshara / letter chunk) of the attempt, located on the child's timeline.
/// Only present when the attempt was not accepted (see docs/api-contract.md).
class SpeechSegment {
  const SpeechSegment({
    required this.label,
    required this.startS,
    required this.endS,
    required this.flagged,
    required this.cost,
    this.errorType,
  });

  factory SpeechSegment.fromJson(Map<String, dynamic> json) => SpeechSegment(
        label: json['label'] as String,
        startS: (json['start_s'] as num).toDouble(),
        endS: (json['end_s'] as num).toDouble(),
        flagged: json['status'] == 'flagged',
        cost: (json['cost'] as num).toDouble(),
        errorType: json['error_type'] as String?,
      );

  final String label;
  final double startS;
  final double endS;
  final bool flagged;
  final double cost;

  /// substitution | omission | insertion | distortion (only for flagged units).
  final String? errorType;

  Map<String, dynamic> toJson() => {
        'label': label,
        'flagged': flagged,
        'cost': cost,
        'error_type': errorType,
      };
}

/// Response of POST /speech/assess (see docs/api-contract.md).
class AssessResult {
  const AssessResult({
    required this.wordId,
    required this.accepted,
    required this.score,
    required this.threshold,
    required this.thresholdSource,
    required this.nearestVariant,
    required this.totalLatencyMs,
    this.segments = const [],
  });

  factory AssessResult.fromJson(Map<String, dynamic> json) => AssessResult(
        wordId: json['word_id'] as String,
        accepted: json['decision'] == 'accepted',
        score: (json['score'] as num).toDouble(),
        threshold: (json['threshold'] as num).toDouble(),
        thresholdSource: json['threshold_source'] as String,
        nearestVariant: json['nearest_variant'] as String,
        totalLatencyMs:
            ((json['latency_ms'] as Map)['total'] as num).toDouble(),
        segments: [
          for (final s in (json['segments'] as List? ?? const []))
            SpeechSegment.fromJson(s as Map<String, dynamic>),
        ],
      );

  final String wordId;
  final bool accepted;
  final double score;
  final double threshold;
  final String thresholdSource;
  final String nearestVariant;
  final double totalLatencyMs;
  final List<SpeechSegment> segments;

  /// Units to practise, worst first (empty when accepted).
  List<SpeechSegment> get flaggedUnits =>
      segments.where((s) => s.flagged).toList()
        ..sort((a, b) => b.cost.compareTo(a.cost));

  Map<String, dynamic> toActivityPayload() => {
        'word_id': wordId,
        'decision': accepted ? 'accepted' : 'needs_remediation',
        'score': score,
        'threshold': threshold,
        'threshold_source': thresholdSource,
        'nearest_variant': nearestVariant,
        'flagged_units': [for (final s in flaggedUnits) s.toJson()],
      };
}

/// Why an assessment could not produce a result, so the UI can pick a gentle message.
enum AssessFailure { couldNotHear, unreachable, other }

class AssessException implements Exception {
  const AssessException(this.failure, [this.detail]);

  final AssessFailure failure;
  final String? detail;

  @override
  String toString() => 'AssessException($failure, $detail)';
}

class SpeechApi {
  SpeechApi(this._dio);

  final Dio _dio;

  Future<AssessResult> assess({
    required String audioPath,
    required SpeechWord word,
    required String childId,
  }) async {
    final form = FormData.fromMap({
      'audio':
          await MultipartFile.fromFile(audioPath, filename: 'utterance.wav'),
      'word_id': word.id,
      'language': word.language,
      'child_id': childId,
    });
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/speech/assess',
        data: form,
        // The first call after the model service starts can be slower than the shared 10 s default.
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return AssessResult.fromJson(resp.data!);
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  /// DEVELOPER TOOL (debug builds only): add an ADULT reference recording of [word] to the
  /// bank. The service rejects it unless started with SPEECH_ALLOW_REFERENCE_UPLOAD=1, and it
  /// never accepts children's recordings. No child id is sent.
  Future<Map<String, dynamic>> addReference({
    required String audioPath,
    required SpeechWord word,
    required String speakerId,
    String accent = 'unknown',
  }) async {
    final form = FormData.fromMap({
      'audio':
          await MultipartFile.fromFile(audioPath, filename: 'reference.wav'),
      'word_id': word.id,
      'language': word.language,
      'speaker_id': speakerId,
      'age_group': 'adult',
      'accent': accent,
    });
    try {
      final resp = await _dio.post<Map<String, dynamic>>(
        '/speech/references',
        data: form,
        options: Options(receiveTimeout: const Duration(seconds: 20)),
      );
      return resp.data!;
    } on DioException catch (e) {
      throw _failure(e);
    }
  }

  AssessException _failure(DioException e) {
    final status = e.response?.statusCode;
    final detail = e.response?.data is Map
        ? (e.response!.data as Map)['detail']?.toString()
        : null;
    if (status == 400) {
      return AssessException(AssessFailure.couldNotHear, detail);
    }
    if (status == null || status == 503) {
      return AssessException(AssessFailure.unreachable, detail);
    }
    return AssessException(AssessFailure.other, detail ?? 'HTTP $status');
  }
}

final speechApiProvider =
    Provider<SpeechApi>((ref) => SpeechApi(ref.watch(apiClientProvider)));
