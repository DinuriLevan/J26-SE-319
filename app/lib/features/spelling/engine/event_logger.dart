/// Raw interaction events for one word, timestamped in ms on a monotonic clock.
enum SpellingEventType {
  audioStart('AUDIO_START'),
  audioEnd('AUDIO_END'),
  replay('REPLAY'),
  tilePlace('TILE_PLACE'),
  tileRemove('TILE_REMOVE'),
  tileMove('TILE_MOVE'),
  check('CHECK'),
  autoReturn('AUTO_RETURN'), // system: wrong tiles bounced back after a check
  pause('PAUSE'), // app went to the background or the game screen was left
  resume('RESUME'),
  wordEnd('WORD_END');

  const SpellingEventType(this.code);
  final String code;

  static SpellingEventType fromCode(String code) => values.firstWhere((v) => v.code == code);
}

class SpellingEvent {
  const SpellingEvent(this.type, this.t, [this.data = const {}]);

  final SpellingEventType type;

  /// Milliseconds since the logger started (like performance.now()).
  final double t;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {'type': type.code, 't': double.parse(t.toStringAsFixed(1)), ...data};

  factory SpellingEvent.fromJson(Map<String, Object?> json) {
    final data = Map<String, Object?>.from(json)..remove('type')..remove('t');
    return SpellingEvent(
      SpellingEventType.fromCode(json['type']! as String),
      (json['t']! as num).toDouble(),
      data,
    );
  }
}

/// Collects the events of the current word. Nothing is saved here — the
/// engine stores the list when the word ends.
///
/// The clock stops while the game is paused (app in the background, screen
/// left), so every timestamp — and every timing feature — is active time
/// only. PAUSE / RESUME are still logged, with the paused wall time.
class EventLogger {
  EventLogger({Stopwatch? clock, DateTime Function()? wallClock})
      : _clock = clock ?? (Stopwatch()..start()),
        _wall = wallClock ?? DateTime.now;

  final Stopwatch _clock;
  final DateTime Function() _wall;
  List<SpellingEvent> _events = [];
  DateTime? _pausedAt;

  double get now => _clock.elapsedMicroseconds / 1000.0;

  bool get paused => _pausedAt != null;

  /// Stops the clock. Calling it again while paused does nothing.
  void pause() {
    if (paused) return;
    _clock.stop();
    _pausedAt = _wall();
    log(SpellingEventType.pause);
  }

  /// Restarts the clock and logs how long the pause lasted.
  void resume() {
    final at = _pausedAt;
    if (at == null) return;
    _pausedAt = null;
    log(SpellingEventType.resume, {'pausedMs': _wall().difference(at).inMilliseconds});
    _clock.start();
  }

  List<SpellingEvent> get events => List.unmodifiable(_events);

  SpellingEvent log(SpellingEventType type, [Map<String, Object?> data = const {}]) {
    final event = SpellingEvent(type, now, data);
    _events.add(event);
    return event;
  }

  /// Returns this word's events and starts a fresh list for the next word.
  List<SpellingEvent> takeWord() {
    final done = _events;
    _events = [];
    return done;
  }
}
