"""Retry loop (src/retry.py) against the shared scenarios in retry_cases.json.

The same file drives the Dart port's tests (app/test/features/speech/retry_loop_test.dart).
"""

import json
from pathlib import Path

import pytest

from src.retry import RetryLoop, RetryStateError

CASES = json.loads((Path(__file__).parent / "retry_cases.json").read_text(encoding="utf-8"))[
    "cases"
]


def _apply(loop: RetryLoop, action: dict):
    match action["input"]:
        case "full_word":
            return loop.on_full_word(action["accepted"], action["flagged"])
        case "listened":
            return loop.on_listened()
        case "unit":
            return loop.on_unit(action["passed"])
        case "blend":
            return loop.on_blend(action["passed"])
        case "practised":
            return loop.on_practised()
    raise ValueError(action)


@pytest.mark.parametrize("case", CASES, ids=[c["name"] for c in CASES])
def test_shared_scenarios(case):
    loop = RetryLoop(
        case["n_units"],
        max_tries=3,
        max_flagged=2,
        listen_units=None if case["listen_units"] is None else set(case["listen_units"]),
    )
    steps = [_apply(loop, a).as_dict() for a in case["actions"]]
    assert steps == case["steps"]
    events = [
        f"{e['type']}:{e['step']}:{'null' if e['unit'] is None else e['unit']}" for e in loop.events
    ]
    assert events == case["events"]
    assert loop.scheduled_units == case["scheduled"]
    assert loop.step.kind == case["final"] and loop.done


def test_spec_required_scenarios_are_covered():
    names = {c["name"] for c in CASES}
    assert {"happy_path", "one_retry", "exhaustion", "two_flagged_units"} <= names


def test_rejects_input_for_the_wrong_step():
    loop = RetryLoop(3)
    with pytest.raises(RetryStateError):
        loop.on_unit(True)
    loop.on_full_word(True, [])
    with pytest.raises(RetryStateError):
        loop.on_full_word(True, [])  # word already finished


def test_flagged_units_outside_the_word_are_ignored():
    loop = RetryLoop(2, listen_units=set())
    step = loop.on_full_word(False, [7, 1])
    assert (step.kind, step.unit) == ("say_unit", 1)


def test_fallback_events_carry_the_scheduled_units():
    loop = RetryLoop(2, max_tries=1, listen_units=set())
    loop.on_full_word(False, [1, 0])
    assert loop.step.kind == "fallback"
    fb = [e for e in loop.events if e["type"] == "fallback_taken"]
    assert fb == [{"type": "fallback_taken", "step": "full_word", "unit": None, "units": [1, 0]}]
    assert loop.scheduled_units == [1, 0]


def test_practised_only_on_sound_steps():
    loop = RetryLoop(3)
    with pytest.raises(RetryStateError):
        loop.on_practised()  # the whole word is always scored
