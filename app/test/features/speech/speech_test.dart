import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:akurin/features/speech/data/speech_api.dart';
import 'package:akurin/features/speech/data/speech_words.dart';
import 'package:akurin/features/speech/logic/retry_loop.dart';
import 'package:akurin/features/speech/logic/speech_rewards.dart';
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

/// Answers every request with a fixed JSON list.
class _ListAdapter implements HttpClientAdapter {
  _ListAdapter(this.body);

  final List<Object?> body;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? _, Future<void>? __) async {
    return ResponseBody.fromString(jsonEncode(body), 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const word = SpeechWord(id: 'w_005', text: 'cat', language: 'en', level: 1);
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
      expect(fields, {'word_id': 'w_005', 'language': 'en', 'child_id': 'c1'});
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

  test('parses segments and orders flagged units worst first', () {
    final r = AssessResult.fromJson({
      ..._okJson,
      'decision': 'needs_remediation',
      'segments': [
        {
          'label': 'අ',
          'start_s': 0.0,
          'end_s': 0.1,
          'status': 'flagged',
          'cost': 0.3,
          'error_type': 'distortion'
        },
        {
          'label': 'ම්මා',
          'start_s': 0.1,
          'end_s': 0.5,
          'status': 'flagged',
          'cost': 0.6,
          'error_type': 'omission'
        },
        {
          'label': 'x',
          'start_s': 0.5,
          'end_s': 0.6,
          'status': 'ok',
          'cost': 0.1,
          'error_type': null
        },
      ],
    });
    expect(r.segments, hasLength(3));
    expect(r.flaggedUnits.map((u) => u.label), ['ම්මා', 'අ']);
    expect(r.flaggedUnits.first.errorType, 'omission');
    expect((r.toActivityPayload()['flagged_units'] as List).length, 2);
    expect(AssessResult.fromJson(_okJson).segments, isEmpty);
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

  group('remediation API', () {
    test('words parses units and adult audio availability', () async {
      final adapter = _FakeAdapter(200, null);
      final api = SpeechApi(Dio(BaseOptions(baseUrl: 'http://x'))
        ..httpClientAdapter = _ListAdapter([
          {
            'word_id': 'w_001',
            'text': 'අම්මා',
            'language': 'si',
            'units': ['අ', 'ම්මා'],
            'listen_units': [0, 1],
            'has_word_audio': true,
          }
        ]));
      final words = await api.words();
      expect(words.single.units, ['අ', 'ම්මා']);
      expect(words.single.listenUnits, {0, 1});
      expect(words.single.spanLabel(0, 1), 'අම්මා');
      expect(adapter.lastRequest, isNull);
    });

    test('assessUnit sends the span and child id', () async {
      final adapter = _FakeAdapter(
          200, {'decision': 'accepted', 'score': 0.1, 'label': 'a'});
      final r = await apiWith(adapter).assessUnit(
          audioPath: wavPath, word: word, start: 1, end: 2, childId: 'c1');
      expect(r.accepted, isTrue);
      expect(adapter.lastRequest!.path, '/speech/assess-unit');
      final fields =
          Map.fromEntries((adapter.lastRequest!.data as FormData).fields);
      expect(fields['start_unit'], '1');
      expect(fields['end_unit'], '2');
      expect(fields['child_id'], 'c1');
    });

    test('listen returns null when there is no adult model audio', () async {
      final api = apiWith(_FakeAdapter(404, {'detail': 'none'}));
      expect(await api.listen(word, start: 0, end: 0), isNull);
    });
  });

  group('SpeechResultScreen', () {
    Future<void> pump(WidgetTester tester,
        {required bool mastered,
        required String lang,
        List<String> later = const [],
        bool card = false}) {
      return tester.pumpWidget(MaterialApp(
        locale: Locale(lang),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        // Reduce motion (as a child's device might): every speech animation must settle.
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!),
        home: SpeechResultScreen(
            word: word,
            mastered: mastered,
            practiseLater: later,
            cardUnlocked: card),
      ));
    }

    testWidgets('mastered shows praise and the card (en)', (tester) async {
      await pump(tester, mastered: true, lang: 'en', card: true);
      await tester.pumpAndSettle();
      expect(find.text('Great job!'), findsOneWidget);
      expect(find.text('You unlocked a new card!'), findsOneWidget);
    });

    testWidgets('fallback is encouraging, names the unit, never "wrong"',
        (tester) async {
      await pump(tester, mastered: false, lang: 'en', later: ['c']);
      await tester.pumpAndSettle();
      expect(find.text('Great effort!'), findsOneWidget);
      expect(find.text("We'll practise c again later."), findsOneWidget);
      expect(
          find.textContaining(
              RegExp('wrong|incorrect|fail', caseSensitive: false)),
          findsNothing);
    });

    testWidgets('Sinhala locale uses Sinhala strings', (tester) async {
      await pump(tester, mastered: false, lang: 'si', later: ['ම']);
      await tester.pumpAndSettle();
      expect(find.text('හොඳ උත්සාහයක්!'), findsOneWidget);
      expect(find.text('අපි ම ආයෙත් පස්සේ පුහුණු වෙමු.'), findsOneWidget);
    });
  });

  group('rewards and completed-word payload', () {
    test('milestone card every 5 mastered words', () {
      expect(
          [for (var n = 0; n <= 11; n++) milestoneCard(n)].whereType<String>(),
          ['speech_words_5', 'speech_words_10']);
    });

    test('payload summarises the loop', () {
      final loop = RetryLoop(3, listenUnits: {});
      loop.onFullWord(accepted: false, flagged: [1]);
      loop.onUnit(passed: true);
      loop.onBlend(passed: true);
      loop.onFullWord(accepted: true, flagged: []);
      final p = completedWordPayload(
          wordId: 'w_005', loop: loop, units: ['c', 'a', 't'], lastScore: 0.2);
      expect(p['outcome'], 'mastered');
      expect(p['full_word_attempts'], 2);
      expect(p['unit_attempts'], 1);
      expect(p['blend_attempts'], 1);
      expect(p['flagged_units'], ['a']);
      expect(p['practise_later'], isEmpty);
    });
  });
}
