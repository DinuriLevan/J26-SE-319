import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'speech_words.dart';

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
      );

  final String wordId;
  final bool accepted;
  final double score;
  final double threshold;
  final String thresholdSource;
  final String nearestVariant;
  final double totalLatencyMs;

  Map<String, dynamic> toActivityPayload() => {
        'word_id': wordId,
        'decision': accepted ? 'accepted' : 'needs_remediation',
        'score': score,
        'threshold': threshold,
        'threshold_source': thresholdSource,
        'nearest_variant': nearestVariant,
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
      final status = e.response?.statusCode;
      final detail = e.response?.data is Map
          ? (e.response!.data as Map)['detail']?.toString()
          : null;
      if (status == 400) {
        throw AssessException(AssessFailure.couldNotHear, detail);
      }
      if (status == null || status == 503) {
        throw AssessException(AssessFailure.unreachable, detail);
      }
      throw AssessException(AssessFailure.other, detail ?? 'HTTP $status');
    }
  }
}

final speechApiProvider =
    Provider<SpeechApi>((ref) => SpeechApi(ref.watch(apiClientProvider)));
