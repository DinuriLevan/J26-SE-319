import '../data/speech_words.dart';

/// One finished practice word, read back from the local record of speech results
/// (SpeechProgressStore.wordResults). Built from completedWordPayload (logic/speech_rewards.dart).
class SpeechWordResult {
  const SpeechWordResult({
    required this.at,
    required this.word,
    required this.mastered,
    required this.fullWordTries,
    this.practiseLater = const [],
  });

  final DateTime at;
  final SpeechWord word;
  final bool mastered;
  final int fullWordTries;

  /// Sounds (unit labels) scheduled for later practice in this session.
  final List<String> practiseLater;

  bool get firstTry => mastered && fullWordTries == 1;

  /// Null for rows this view cannot use: unknown words, or early rows written before the payload
  /// had an outcome.
  static SpeechWordResult? fromPayload(
      DateTime at, Map<String, dynamic> payload) {
    final outcome = payload['outcome'];
    final word = _wordsById[payload['word_id']];
    if (word == null || (outcome != 'mastered' && outcome != 'fallback')) {
      return null;
    }
    return SpeechWordResult(
      at: at,
      word: word,
      mastered: outcome == 'mastered',
      fullWordTries: (payload['full_word_attempts'] as num?)?.toInt() ?? 1,
      practiseLater: [
        for (final u in (payload['practise_later'] as List? ?? const []))
          u.toString()
      ],
    );
  }
}

final _wordsById = {for (final w in speechDemoWords) w.id: w};

class WordProgress {
  const WordProgress(this.word, this.sessions, this.mastered);
  final SpeechWord word;
  final int sessions;
  final bool mastered;
}

/// A sound the child was asked to practise later, with the word it came from (to play it).
class SoundToPractise {
  const SoundToPractise(this.label, this.word, this.count, this.lastSeen);
  final String label;
  final SpeechWord word;
  final int count;
  final DateTime lastSeen;
}

/// One week of practice. [words] == 0 means no practice that week (a gap, not a zero).
class WeekPoint {
  const WeekPoint(this.start, this.words, this.firstTry, this.avgTries);
  final DateTime start;
  final int words;
  final int firstTry;

  /// Average whole-word tries for the words mastered that week; null if none were mastered.
  final double? avgTries;

  double? get firstTryRate => words == 0 ? null : firstTry / words;
}

/// What the parent dashboard shows for speech. Pure: [now] is passed in so it can be tested.
class SpeechParentStats {
  SpeechParentStats._({
    required this.mastered,
    required this.practising,
    required this.sounds,
    required this.daily,
    required this.weeks,
    required this.wordsThisWeek,
    required this.streakDays,
  });

  static const dailyDays = 14;
  static const weekCount = 8;
  static const soundWindow = Duration(days: 30);

  final List<WordProgress> mastered;
  final List<WordProgress> practising;

  /// Most-needed first.
  final List<SoundToPractise> sounds;

  /// Words practised per day, oldest first; the last entry is today.
  final List<int> daily;

  /// Oldest first; the last entry is the current week (weeks start on Monday).
  final List<WeekPoint> weeks;

  /// Different words practised in the last 7 days.
  final int wordsThisWeek;

  /// Days in a row with practice, ending today (or yesterday, if not yet today).
  final int streakDays;

  bool get isEmpty => mastered.isEmpty && practising.isEmpty;

  factory SpeechParentStats.from(List<SpeechWordResult> all,
      {required DateTime now, String? language}) {
    final results = [
      for (final r in all)
        if (language == null || r.word.language == language) r
    ]..sort((a, b) => a.at.compareTo(b.at));
    final today = _day(now);

    // Words: mastered once = mastered.
    final byWord = <String, List<SpeechWordResult>>{};
    for (final r in results) {
      byWord.putIfAbsent(r.word.id, () => []).add(r);
    }
    final progress = [
      for (final rs in byWord.values)
        WordProgress(rs.first.word, rs.length, rs.any((r) => r.mastered))
    ]..sort((a, b) => b.sessions.compareTo(a.sessions));

    // Sounds: practise-later labels from the last 30 days, unless the word was later said right
    // on the first try.
    final sounds = <String, SoundToPractise>{};
    for (final r in results) {
      if (now.difference(r.at) > soundWindow) continue;
      for (final label in r.practiseLater) {
        final key = '${r.word.id}|$label';
        final old = sounds[key];
        sounds[key] =
            SoundToPractise(label, r.word, (old?.count ?? 0) + 1, r.at);
      }
    }
    sounds.removeWhere((_, s) => results.any((r) =>
        r.word.id == s.word.id && r.firstTry && r.at.isAfter(s.lastSeen)));
    final rankedSounds = sounds.values.toList()
      ..sort((a, b) => b.count != a.count
          ? b.count.compareTo(a.count)
          : b.lastSeen.compareTo(a.lastSeen));

    // Daily activity, last 14 days.
    final daily = List.filled(dailyDays, 0);
    for (final r in results) {
      final ago = today.difference(_day(r.at)).inDays;
      if (ago >= 0 && ago < dailyDays) daily[dailyDays - 1 - ago]++;
    }

    // Weekly improvement, last 8 weeks.
    final thisWeek = today.subtract(Duration(days: today.weekday - 1));
    final weeks = [
      for (var i = weekCount - 1; i >= 0; i--)
        _week(results, thisWeek.subtract(Duration(days: 7 * i))),
    ];

    final weekAgo = now.subtract(const Duration(days: 7));
    final practisedDays = {for (final r in results) _day(r.at)};
    var streak = 0;
    var d = practisedDays.contains(today)
        ? today
        : today.subtract(const Duration(days: 1));
    while (practisedDays.contains(d)) {
      streak++;
      d = d.subtract(const Duration(days: 1));
    }

    return SpeechParentStats._(
      mastered: [
        for (final p in progress)
          if (p.mastered) p
      ],
      practising: [
        for (final p in progress)
          if (!p.mastered) p
      ],
      sounds: rankedSounds,
      daily: daily,
      weeks: weeks,
      wordsThisWeek: {
        for (final r in results)
          if (r.at.isAfter(weekAgo)) r.word.id
      }.length,
      streakDays: streak,
    );
  }

  /// First and last weeks with practice, for the "improvement" summary; null below two weeks.
  (WeekPoint, WeekPoint, int)? get trend {
    final active = [
      for (final w in weeks)
        if (w.words > 0) w
    ];
    if (active.length < 2) return null;
    final span = active.last.start.difference(active.first.start).inDays ~/ 7;
    return (active.first, active.last, span);
  }

  static WeekPoint _week(List<SpeechWordResult> results, DateTime start) {
    final end = start.add(const Duration(days: 7));
    final rs = [
      for (final r in results)
        if (!_day(r.at).isBefore(start) && _day(r.at).isBefore(end)) r
    ];
    final mastered = [
      for (final r in rs)
        if (r.mastered) r
    ];
    return WeekPoint(
      start,
      rs.length,
      rs.where((r) => r.firstTry).length,
      mastered.isEmpty
          ? null
          : mastered.map((r) => r.fullWordTries).reduce((a, b) => a + b) /
              mastered.length,
    );
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
