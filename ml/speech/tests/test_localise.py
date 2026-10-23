import numpy as np
import pytest

from src.dtw_fast import dtw
from src.errors import classify, confusion_categories, load_confusions
from src.localise import FRAME_S, localise_attempt, unit_frames
from src.settings import load_settings

SETTINGS = load_settings()
ERR = SETTINGS["errors"]


def _units(labels, durs_frames):
    t, out = 0, []
    for label, d in zip(labels, durs_frames):
        out.append({"label": label, "start_s": t * FRAME_S, "end_s": (t + d) * FRAME_S})
        t += d
    return out


# ---- unit_frames -------------------------------------------------------------------------


def test_unit_frames_tile_the_reference():
    segs = unit_frames(_units("abc", [10, 12, 10]), 32)
    assert segs == [("a", 0, 10), ("b", 10, 22), ("c", 22, 32)]


def test_unit_frames_enforces_min_frames_and_order():
    # Unit b aligned to a zero-length sliver: it still gets min_frames, order is kept.
    units = [
        {"label": "a", "start_s": 0.0, "end_s": 0.2},
        {"label": "b", "start_s": 0.2, "end_s": 0.2},
        {"label": "c", "start_s": 0.2, "end_s": 0.4},
    ]
    segs = unit_frames(units, 20, min_frames=2)
    assert [s[0] for s in segs] == ["a", "b", "c"]
    assert all(e - s >= 2 for _, s, e in segs)
    assert segs[0][1] == 0 and segs[-1][2] == 20


def test_unit_frames_empty_when_reference_too_short():
    assert unit_frames(_units("abc", [1, 1, 1]), 2) == []
    assert unit_frames([], 10) == []


# ---- errors.classify -----------------------------------------------------------------------


def test_classify_duration_rules():
    # expected = ref_frames * tempo = 10
    assert classify("ම", 0.6, 2, 10, 1.0, ERR) == "omission"
    assert classify("ම", 0.6, 30, 10, 1.0, ERR) == "insertion"
    assert classify("ම", 0.6, 10, 10, 1.0, ERR) == "substitution"  # high cost
    assert classify("ම", 0.2, 10, 10, 1.0, ERR) == "distortion"  # moderate cost
    # tempo correction: a slow child (tempo 2) with 20 frames is normal length.
    assert classify("ම", 0.2, 20, 10, 2.0, ERR) == "distortion"


def test_classify_sinhala_confusion_rules():
    c = load_confusions()
    assert {"geminates", "vowel_length"} <= confusion_categories("ම්මා", c)
    assert classify("ම්මා", 0.3, 5, 10, 1.0, ERR, c) == "omission"  # geminate said short
    assert "vowel_length" in confusion_categories("ආ", c)
    assert classify("ආ", 0.3, 5, 10, 1.0, ERR, c) == "distortion"  # long vowel said short
    assert classify("ඛ", 0.2, 10, 10, 1.0, ERR, c) == "substitution"  # aspirated stop
    assert confusion_categories("cat", c) == set()


# ---- localise_attempt on synthetic phoneme prototypes ---------------------------------------


@pytest.fixture(scope="module")
def protos():
    rng = np.random.default_rng(0)
    proto = {p: rng.normal(size=32) for p in "abcdef"}

    def utt(ph, durs, noise=0.15):
        return np.array(
            [
                proto[p] + rng.normal(scale=noise, size=32)
                for p, d in zip(ph, durs)
                for _ in range(d)
            ]
        )

    return utt


def _attempt(utt, child_ph, child_durs):
    ref = {"emb": utt("abc", [10, 12, 10]), "units": _units("abc", [10, 12, 10])}
    child = utt(child_ph, child_durs)
    _, path = dtw(1.0 - _cos(child, ref["emb"]))
    return localise_attempt(child, ref, path, SETTINGS), child


def _cos(a, b):
    a = a / np.linalg.norm(a, axis=1, keepdims=True)
    b = b / np.linalg.norm(b, axis=1, keepdims=True)
    return a @ b.T


def test_flags_the_wrong_middle_unit(protos):
    segs, child = _attempt(protos, "aec", [14, 18, 13])
    assert [s["label"] for s in segs] == ["a", "b", "c"]
    flagged = [s for s in segs if s["status"] == "flagged"]
    assert [s["label"] for s in flagged] == ["b"]
    assert flagged[0]["error_type"] in {"substitution", "distortion"}
    assert all(s["error_type"] is None for s in segs if s["status"] == "ok")
    # Segments are in order on the child's timeline and cover it.
    assert segs[0]["start_s"] == 0.0
    assert segs[-1]["end_s"] == pytest.approx(len(child) * FRAME_S)
    assert all(a["end_s"] <= b["start_s"] + 1e-9 for a, b in zip(segs, segs[1:]))


def test_flags_the_wrong_first_unit(protos):
    segs, _ = _attempt(protos, "fbc", [12, 14, 11])
    assert [s["label"] for s in segs if s["status"] == "flagged"][0] == "a"


def test_omitted_unit_is_flagged_as_omission(protos):
    # Child skips "b" entirely: DTW maps b onto very few child frames.
    segs, _ = _attempt(protos, "ac", [12, 12])
    b = next(s for s in segs if s["label"] == "b")
    assert b["status"] == "flagged"
    assert b["error_type"] == "omission"
