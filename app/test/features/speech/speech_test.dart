import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:akurin/features/speech/data/speech_api.dart';
import 'package:akurin/features/speech/data/speech_words.dart';
import 'package:akurin/features/speech/screens/speech_result_screen.dart';
import 'package:akurin/l10n/app_localizations.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

const _okJson = {
  'word_id': 'w_004',
  'decision': 'accepted',
  'score': 0.12,
  'threshold': 0.3,
  'threshold_source': 'fallback',
  'nearest_variant': 'spk_adult_01',
  'segments': [],
  'latency_ms': {'load': 1, 'embed': 2, 'dtw': 3, 'total': 6},
};

/// Answers every request with a fixed status/body, or throws a connection error if status is null.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, [this.body]);

  final int? status;
  final Map<String, dynamic>? body;
  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? _, Future<void>? __) async {
    lastRequest = options;
    if (status == null) {
      throw DioException.connectionError(
          requestOptions: options, reason: 'refused');
    }
    return ResponseBody.fromString(jsonEncode(body ?? {}), status!, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const word = SpeechWord(id: 'w_004', text: 'cat', language: 'en');
  late String wavPath;

  setUpAll(() async {
    final dir = await Directory.systemTemp.createTemp('speech_test');
    wavPath = '${dir.path}/a.wav';
    await File(wavPath).writeAsBytes([0, 1, 2, 3]);
  });

  SpeechApi apiWith(_FakeAdapter adapter) => SpeechApi(
      Dio(BaseOptions(baseUrl: 'http://x'))..httpClientAdapter = adapter);

  group('SpeechApi.assess', () {
    test('parses the contract and posts word/language/child_id', () async {
      final adapter = _FakeAdapter(200, _okJson);
      final r = await apiWith(adapter)
          .assess(audioPath: wavPath, word: word, childId: 'c1');
      expect(r.accepted, isTrue);
      expect(r.score, 0.12);
      expect(r.thresholdSource, 'fallback');
      expect(r.totalLatencyMs, 6);
      expect(adapter.lastRequest!.path, '/speech/assess');
      final fields =
          Map.fromEntries((adapter.lastRequest!.data as FormData).fields);
      expect(fields, {'word_id': 'w_004', 'language': 'en', 'child_id': 'c1'});
      expect(r.toActivityPayload()['decision'], 'accepted');
    });

    Future<AssessFailure> failureFor(int? status) async {
      try {
        await apiWith(_FakeAdapter(status, {'detail': 'x'}))
            .assess(audioPath: wavPath, word: word, childId: 'c1');
      } on AssessException catch (e) {
        return e.failure;
      }
      fail('expected AssessException');
    }

    test('maps errors to gentle failure kinds', () async {
      expect(await failureFor(400), AssessFailure.couldNotHear);
      expect(await failureFor(503), AssessFailure.unreachable);
      expect(await failureFor(null), AssessFailure.unreachable);
      expect(await failureFor(502), AssessFailure.other);
    });
  });

  test('addReference sends adult-only dev fields and no child id', () async {
    final adapter = _FakeAdapter(200, {'ref_id': 'adult_01_p01', 'n_refs': 9});
    final r = await apiWith(adapter)
        .addReference(audioPath: wavPath, word: word, speakerId: 'adult_01');
    expect(r['ref_id'], 'adult_01_p01');
    expect(adapter.lastRequest!.path, '/speech/references');
    final fields =
        Map.fromEntries((adapter.lastRequest!.data as FormData).fields);
    expect(fields['age_group'], 'adult');
    expect(fields['speaker_id'], 'adult_01');
    expect(fields.containsKey('child_id'), isFalse);
  });

  group('SpeechResultScreen', () {
    Future<void> pump(WidgetTester tester,
        {required bool accepted, required String lang}) {
      final result = AssessResult.fromJson({
        ..._okJson,
        'decision': accepted ? 'accepted' : 'needs_remediation',
      });
      return tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SpeechResultScreen(word: word, result: result),
      ));
    }

    testWidgets('accepted shows praise (en)', (tester) async {
      await pump(tester, accepted: true, lang: 'en');
      await tester.pumpAndSettle();
      expect(find.text('Great job!'), findsOneWidget);
    });

    testWidgets('not accepted is encouraging, never "wrong" (en)',
        (tester) async {
      await pump(tester, accepted: false, lang: 'en');
      await tester.pumpAndSettle();
      expect(find.text('Nice try!'), findsOneWidget);
      expect(
          find.textContaining(
              RegExp('wrong|incorrect|fail', caseSensitive: false)),
          findsNothing);
    });

    testWidgets('Sinhala locale uses Sinhala strings', (tester) async {
      await pump(tester, accepted: true, lang: 'si');
      await tester.pumpAndSettle();
      expect(find.text('නියමයි!'), findsOneWidget);
    });
  });
}
