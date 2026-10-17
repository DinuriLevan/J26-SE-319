"""Retry / remediation loop: Detect -> Localise -> Isolate -> Drill -> Reconnect (pure logic, no UI).

    FULL_WORD --accepted--> REWARD
        |  not accepted: take the worst 1-2 flagged units, then for each unit in turn:
        v
    LISTEN (adult model audio of the unit; skipped if none) -> SAY_UNIT -> BLEND (unit + neighbour)
        |  after the last unit
        v
    FULL_WORD (try again)

Each step allows up to max_tries attempts. When a unit step runs out of tries, the loop takes a gentle
fallback: the unit is scheduled for later practice and the loop moves on. When the full word runs out
of tries, the word ends in FALLBACK (move on to the next word, units scheduled). Nothing is punitive.

Events (dicts, in order): attempt_scored, unit_flagged, step_passed, word_mastered, fallback_taken.

The Flutter app has a Dart port (app/lib/features/speech/logic/retry_loop.dart). Both run the shared
scenarios in ml/speech/tests/retry_cases.json, so they cannot drift apart.
"""

from __future__ import annotations

from dataclasses import dataclass

FULL_WORD, LISTEN, SAY_UNIT, BLEND, REWARD, FALLBACK = (
    "full_word",
    "listen",
    "say_unit",
    "blend",
    "reward",
    "fallback",
)


class RetryStateError(RuntimeError):
    """An input arrived that does not belong to the current step."""


@dataclass(frozen=True)
class Step:
    kind: str
    unit: int | None = None  # unit index being practised
    span: tuple[int, int] | None = None  # inclusive unit span to say (SAY_UNIT / BLEND)
    try_no: int = 1  # 1-based attempt number within this step

    def as_dict(self) -> dict:
        return {
            "kind": self.kind,
            "unit": self.unit,
            "span": list(self.span) if self.span else None,
            "try": self.try_no,
        }


class RetryLoop:
    def __init__(
        self,
        n_units: int,
        max_tries: int = 3,
        max_flagged: int = 2,
        listen_units: set[int] | None = None,
    ):
        """listen_units: units that have adult model audio (None = all). Others skip LISTEN."""
        if n_units < 1:
            raise ValueError("A word needs at least one unit.")
        self.n_units = n_units
        self.max_tries = max_tries
        self.max_flagged = max_flagged
        self.listen_units = set(range(n_units)) if listen_units is None else set(listen_units)
        self.events: list[dict] = []
        self.scheduled_units: list[int] = []
        self._queue: list[int] = []
        self._full_tries = 0
        self._step_tries = 0
        self.step = Step(FULL_WORD, try_no=1)

    # ---- public inputs ----------------------------------------------------------------------

    @property
    def done(self) -> bool:
        return self.step.kind in (REWARD, FALLBACK)

    def on_full_word(self, accepted: bool, flagged: list[int]) -> Step:
        self._expect(FULL_WORD)
        self._full_tries += 1
        self._emit("attempt_scored", FULL_WORD, None, passed=accepted)
        if accepted:
            self._emit("word_mastered", FULL_WORD, None)
            return self._go(Step(REWARD))
        units = [u for u in flagged if 0 <= u < self.n_units][: self.max_flagged]
        if self._full_tries >= self.max_tries:
            for u in units:
                self._schedule(u)
            self._emit("fallback_taken", FULL_WORD, None, units=units)
            return self._go(Step(FALLBACK))
        if not units:
            return self._go(Step(FULL_WORD, try_no=self._full_tries + 1))
        for u in units:
            self._emit("unit_flagged", FULL_WORD, u)
        self._queue = units
        return self._start_unit(self._queue.pop(0))

    def on_listened(self) -> Step:
        self._expect(LISTEN)
        u = self.step.unit
        return self._go(Step(SAY_UNIT, u, (u, u), self._step_tries + 1))

    def on_unit(self, passed: bool) -> Step:
        self._expect(SAY_UNIT)
        u = self.step.unit
        self._step_tries += 1
        self._emit("attempt_scored", SAY_UNIT, u, passed=passed)
        if passed:
            self._emit("step_passed", SAY_UNIT, u)
            if self.n_units == 1:
                return self._next_unit()
            self._step_tries = 0
            return self._go(Step(BLEND, u, self._blend_span(u), 1))
        if self._step_tries >= self.max_tries:
            return self._unit_fallback(u, SAY_UNIT)
        if u in self.listen_units:
            return self._go(Step(LISTEN, u, (u, u), self._step_tries + 1))
        return self._go(Step(SAY_UNIT, u, (u, u), self._step_tries + 1))

    def on_blend(self, passed: bool) -> Step:
        self._expect(BLEND)
        u = self.step.unit
        self._step_tries += 1
        self._emit("attempt_scored", BLEND, u, passed=passed)
        if passed:
            self._emit("step_passed", BLEND, u)
            return self._next_unit()
        if self._step_tries >= self.max_tries:
            return self._unit_fallback(u, BLEND)
        return self._go(Step(BLEND, u, self.step.span, self._step_tries + 1))

    # ---- internals -----------------------------------------------------------------------------

    def _blend_span(self, u: int) -> tuple[int, int]:
        return (u, u + 1) if u + 1 < self.n_units else (u - 1, u)

    def _start_unit(self, u: int) -> Step:
        self._step_tries = 0
        if u in self.listen_units:
            return self._go(Step(LISTEN, u, (u, u), 1))
        return self._go(Step(SAY_UNIT, u, (u, u), 1))

    def _next_unit(self) -> Step:
        if self._queue:
            return self._start_unit(self._queue.pop(0))
        return self._go(Step(FULL_WORD, try_no=self._full_tries + 1))

    def _unit_fallback(self, u: int, step: str) -> Step:
        self._schedule(u)
        self._emit("fallback_taken", step, u, units=[u])
        return self._next_unit()

    def _schedule(self, u: int) -> None:
        if u not in self.scheduled_units:
            self.scheduled_units.append(u)

    def _expect(self, kind: str) -> None:
        if self.step.kind != kind:
            raise RetryStateError(f"Expected input for {self.step.kind!r}, got {kind!r}.")

    def _emit(self, type_: str, step: str, unit: int | None, **extra) -> None:
        self.events.append({"type": type_, "step": step, "unit": unit, **extra})

    def _go(self, step: Step) -> Step:
        self.step = step
        return step
