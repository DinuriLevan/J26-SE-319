/// Retry / remediation loop: Detect -> Localise -> Isolate -> Drill -> Reconnect (pure logic).
///
/// Dart port of ml/speech/src/retry.py. Both are tested against the shared scenarios in
/// ml/speech/tests/retry_cases.json, so keep them in step: change the Python, the Dart and the
/// JSON together.
///
///   FULL_WORD --accepted--> REWARD
///       | not accepted: worst 1-2 flagged units, then for each unit:
///       v
///   LISTEN (adult model audio; skipped if none) -> SAY_UNIT -> BLEND (unit + neighbour)
///       | after the last unit
///       v
///   FULL_WORD (try again)
///
/// Up to [maxTries] attempts per step. A unit step that runs out of tries takes a gentle fallback
/// (the unit is scheduled for later practice and the loop moves on). A full word that runs out of
/// tries ends in FALLBACK. Nothing is punitive.
///
/// Practice mode ([onPractised]): a SAY_UNIT or BLEND step can be marked as practised without a
/// score; the loop moves on as if it passed and schedules the flagged unit for later practice.
library;

enum StepKind { fullWord, listen, sayUnit, blend, reward, fallback }

const _kindNames = {
  StepKind.fullWord: 'full_word',
  StepKind.listen: 'listen',
  StepKind.sayUnit: 'say_unit',
  StepKind.blend: 'blend',
  StepKind.reward: 'reward',
  StepKind.fallback: 'fallback',
};

String stepKindName(StepKind k) => _kindNames[k]!;

class RetryStep {
  const RetryStep(this.kind,
      {this.unit, this.spanStart, this.spanEnd, this.tryNo = 1});

  final StepKind kind;
  final int? unit;
  final int? spanStart;
  final int? spanEnd;
  final int tryNo;

  Map<String, Object?> toJson() => {
        'kind': stepKindName(kind),
        'unit': unit,
        'span': spanStart == null ? null : [spanStart, spanEnd],
        'try': tryNo,
      };
}

class RetryEvent {
  const RetryEvent(this.type, this.step, this.unit, {this.passed, this.units});

  /// attempt_scored | unit_flagged | step_passed | word_mastered | fallback_taken
  final String type;
  final StepKind step;
  final int? unit;
  final bool? passed;
  final List<int>? units;

  @override
  String toString() => '$type:${stepKindName(step)}:${unit ?? 'null'}';
}

class RetryStateError extends StateError {
  RetryStateError(super.message);
}

class RetryLoop {
  RetryLoop(this.nUnits,
      {this.maxTries = 3, this.maxFlagged = 2, Set<int>? listenUnits})
      : listenUnits = listenUnits ?? {for (var i = 0; i < nUnits; i++) i} {
    if (nUnits < 1) throw ArgumentError('A word needs at least one unit.');
  }

  final int nUnits;
  final int maxTries;
  final int maxFlagged;

  /// Units that have adult model audio; the others skip LISTEN.
  final Set<int> listenUnits;

  final List<RetryEvent> events = [];
  final List<int> scheduledUnits = [];
  final List<int> _queue = [];
  int _fullTries = 0;
  int _stepTries = 0;
  RetryStep step = const RetryStep(StepKind.fullWord);

  bool get done =>
      step.kind == StepKind.reward || step.kind == StepKind.fallback;

  RetryStep onFullWord({required bool accepted, required List<int> flagged}) {
    _expect(StepKind.fullWord);
    _fullTries++;
    _emit('attempt_scored', StepKind.fullWord, null, passed: accepted);
    if (accepted) {
      _emit('word_mastered', StepKind.fullWord, null);
      return _go(const RetryStep(StepKind.reward));
    }
    final units =
        flagged.where((u) => u >= 0 && u < nUnits).take(maxFlagged).toList();
    if (_fullTries >= maxTries) {
      units.forEach(_schedule);
      _emit('fallback_taken', StepKind.fullWord, null, units: units);
      return _go(const RetryStep(StepKind.fallback));
    }
    if (units.isEmpty) {
      return _go(RetryStep(StepKind.fullWord, tryNo: _fullTries + 1));
    }
    for (final u in units) {
      _emit('unit_flagged', StepKind.fullWord, u);
    }
    _queue
      ..clear()
      ..addAll(units);
    return _startUnit(_queue.removeAt(0));
  }

  RetryStep onListened() {
    _expect(StepKind.listen);
    final u = step.unit!;
    return _go(RetryStep(StepKind.sayUnit,
        unit: u, spanStart: u, spanEnd: u, tryNo: _stepTries + 1));
  }

  RetryStep onUnit({required bool passed}) {
    _expect(StepKind.sayUnit);
    final u = step.unit!;
    _stepTries++;
    _emit('attempt_scored', StepKind.sayUnit, u, passed: passed);
    if (passed) {
      _emit('step_passed', StepKind.sayUnit, u);
      if (nUnits == 1) return _nextUnit();
      _stepTries = 0;
      final (a, b) = _blendSpan(u);
      return _go(RetryStep(StepKind.blend, unit: u, spanStart: a, spanEnd: b));
    }
    if (_stepTries >= maxTries) return _unitFallback(u, StepKind.sayUnit);
    final kind = listenUnits.contains(u) ? StepKind.listen : StepKind.sayUnit;
    return _go(RetryStep(kind,
        unit: u, spanStart: u, spanEnd: u, tryNo: _stepTries + 1));
  }

  RetryStep onBlend({required bool passed}) {
    _expect(StepKind.blend);
    final u = step.unit!;
    _stepTries++;
    _emit('attempt_scored', StepKind.blend, u, passed: passed);
    if (passed) {
      _emit('step_passed', StepKind.blend, u);
      return _nextUnit();
    }
    if (_stepTries >= maxTries) return _unitFallback(u, StepKind.blend);
    return _go(RetryStep(StepKind.blend,
        unit: u,
        spanStart: step.spanStart,
        spanEnd: step.spanEnd,
        tryNo: _stepTries + 1));
  }

  /// The child said the sound (SAY_UNIT) or blend (BLEND): practised, not scored.
  RetryStep onPractised() {
    final kind = step.kind;
    if (kind != StepKind.sayUnit && kind != StepKind.blend) {
      throw RetryStateError(
          "Expected input for '${stepKindName(kind)}', got 'practised'.");
    }
    final u = step.unit!;
    _emit('unit_practised', kind, u);
    _schedule(u);
    if (kind == StepKind.sayUnit && nUnits > 1) {
      _stepTries = 0;
      final (a, b) = _blendSpan(u);
      return _go(RetryStep(StepKind.blend, unit: u, spanStart: a, spanEnd: b));
    }
    return _nextUnit();
  }

  (int, int) _blendSpan(int u) => u + 1 < nUnits ? (u, u + 1) : (u - 1, u);

  RetryStep _startUnit(int u) {
    _stepTries = 0;
    final kind = listenUnits.contains(u) ? StepKind.listen : StepKind.sayUnit;
    return _go(RetryStep(kind, unit: u, spanStart: u, spanEnd: u));
  }

  RetryStep _nextUnit() {
    if (_queue.isNotEmpty) return _startUnit(_queue.removeAt(0));
    return _go(RetryStep(StepKind.fullWord, tryNo: _fullTries + 1));
  }

  RetryStep _unitFallback(int u, StepKind kind) {
    _schedule(u);
    _emit('fallback_taken', kind, u, units: [u]);
    return _nextUnit();
  }

  void _schedule(int u) {
    if (!scheduledUnits.contains(u)) scheduledUnits.add(u);
  }

  void _expect(StepKind kind) {
    if (step.kind != kind) {
      throw RetryStateError(
          'Expected input for ${stepKindName(step.kind)}, got ${stepKindName(kind)}.');
    }
  }

  void _emit(String type, StepKind kind, int? unit,
          {bool? passed, List<int>? units}) =>
      events.add(RetryEvent(type, kind, unit, passed: passed, units: units));

  RetryStep _go(RetryStep s) => step = s;
}
