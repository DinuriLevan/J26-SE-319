import 'package:akurin/features/speech/data/speech_words.dart';
import 'package:akurin/features/speech/parent/speech_parent_stats.dart';
import 'package:flutter_test/flutter_test.dart';

final _w = {for (final w in speechDemoWords) w.text: w};

// Wednesday 2026-10-21, noon. Weeks start on Monday 2026-10-19.
final now = DateTime(2026, 10, 21, 12);

SpeechWordResult r(String word, int daysAgo,
        {bool mastered = true, int tries = 1, List<String> later = const []}) =>
    SpeechWordResult(
      at: now.subtract(Duration(days: daysAgo)),
      word: _w[word]!,
      mastered: mastered,
      fullWordTries: tries,
      practiseLater: later,
    );

void main() {
  test('fromPayload reads finished words and skips rows it cannot use', () {
    final at = DateTime(2026, 10, 20);
    final ok = SpeechWordResult.fromPayload(at, {
      'word_id': 'w_005',
      'outcome': 'fallback',
      'full_word_attempts': 3,
      'practise_later': ['c', 't'],
    })!;
    expect((ok.word.text, ok.mastered, ok.fullWordTries), ('cat', false, 3));
    expect(ok.practiseLater, ['c', 't']);
    expect(SpeechWordResult.fromPayload(at, {'word_id': 'w_005'}),
        isNull); // early row
    expect(
        SpeechWordResult.fromPayload(
            at, {'word_id': 'w_999', 'outcome': 'mastered'}),
        isNull);
  });

  test('mastered vs still practising', () {
    final s = SpeechParentStats.from([
      r('cat', 3, mastered: false, tries: 3),
      r('cat', 1),
      r('hat', 1, mastered: false, tries: 3),
    ], now: now);
    expect(s.mastered.map((p) => p.word.text), ['cat']);
    expect(s.mastered.single.sessions, 2);
    expect(s.practising.map((p) => p.word.text), ['hat']);
  });

  test('sounds to practise: ranked, and dropped after a first-try success', () {
    final s = SpeechParentStats.from([
      r('cat', 5, mastered: false, tries: 3, later: ['c', 't']),
      r('cat', 4, mastered: false, tries: 3, later: ['t']),
      r('hat', 3, mastered: false, tries: 3, later: ['h']),
      r('hat', 1), // said right on the first try: "h" is no longer needed
      r('මම', 40,
          mastered: false, tries: 3, later: ['ම']), // older than 30 days
    ], now: now);
    expect([for (final x in s.sounds) '${x.label}:${x.count}'], ['t:2', 'c:1']);
    expect(s.sounds.first.word.text, 'cat');
  });

  test('a mastery that needed several tries keeps the sound on the list', () {
    final s = SpeechParentStats.from([
      r('cat', 3, mastered: false, tries: 3, later: ['c']),
      r('cat', 1, tries: 2),
    ], now: now);
    expect(s.sounds.single.label, 'c');
  });

  test('daily activity covers 14 days, today last', () {
    final s = SpeechParentStats.from(
        [r('cat', 0), r('hat', 0), r('rat', 1), r('cat', 13), r('cat', 14)],
        now: now);
    expect(s.daily.length, 14);
    expect(s.daily.last, 2);
    expect(s.daily[12], 1);
    expect(s.daily.first, 1); // 13 days ago; 14 days ago is outside
  });

  test('weekly improvement with gaps for weeks without practice', () {
    final s = SpeechParentStats.from([
      // 3 weeks ago: 1 of 2 on the first try.
      r('cat', 22, tries: 1), r('hat', 22, mastered: false, tries: 3),
      // this week: 3 of 4 on the first try; mastered words took 1, 1, 1, 3 tries.
      r('cat', 1), r('hat', 1), r('rat', 0), r('ran', 0, tries: 3),
    ], now: now);
    expect(s.weeks.length, 8);
    expect(s.weeks.last.start, DateTime(2026, 10, 19));
    expect(s.weeks.last.firstTryRate, 0.75);
    expect(s.weeks.last.avgTries, 1.5);
    expect(s.weeks[4].firstTryRate, 0.5);
    expect(s.weeks[5].firstTryRate, isNull); // no practice: a gap, not 0%
    final (from, to, weeks) = s.trend!;
    expect((from.firstTryRate, to.firstTryRate, weeks), (0.5, 0.75, 3));
  });

  test('summary: words this week and the practice streak', () {
    final s = SpeechParentStats.from(
        [r('cat', 1), r('hat', 2), r('cat', 2), r('rat', 3), r('cat', 9)],
        now: now);
    expect(s.wordsThisWeek, 3);
    expect(s.streakDays, 3); // yesterday, 2 and 3 days ago (not yet today)
  });

  test('language filter', () {
    final all = [r('cat', 1), r('මම', 1, mastered: false, tries: 3)];
    expect(SpeechParentStats.from(all, now: now, language: 'si').mastered,
        isEmpty);
    expect(SpeechParentStats.from(all, now: now, language: 'en').practising,
        isEmpty);
    expect(SpeechParentStats.from([], now: now).isEmpty, isTrue);
  });
}
