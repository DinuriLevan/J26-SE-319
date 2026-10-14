"""Reference tests for src/scoring.py, using synthetic phoneme prototypes.

Same data, seed and assertions as the original script. They are only wrapped in pytest functions
so that pytest collects them. Do not weaken these assertions; add new tests instead.
"""

import numpy as np
import pytest

from src.scoring import cosine_cost_matrix, localise, score_against_references

rng = np.random.default_rng(0)
D = 32
proto = {p: rng.normal(size=D) for p in "abcdef"}  # fake phoneme embeddings


def utt(phonemes, durs, noise=0.15):
    frames = []
    for p, d in zip(phonemes, durs):
        frames += [proto[p] + rng.normal(scale=noise, size=D) for _ in range(d)]
    return np.array(frames)


# Reference word = phonemes a,b,c  (segments in reference frames)
ref_adult = utt("abc", [10, 12, 10])
ref_segments = [("a", 0, 10), ("b", 10, 22), ("c", 22, 32)]
# Accent variant: legitimately uses 'd' where adult uses 'b'
ref_variant = utt("adc", [11, 11, 10])

child_ok = utt("abc", [14, 18, 13])  # slower, correct
child_variant = utt("adc", [13, 15, 12])  # accepted regional/accent variant
child_wrong = utt("aec", [14, 18, 13])  # genuine error on 2nd sound

refs_single = [{"emb": ref_adult, "age_group": "adult", "variant_id": "A"}]
refs_multi = refs_single + [{"emb": ref_variant, "age_group": "adult", "variant_id": "B"}]


@pytest.fixture(scope="module")
def multi_ref_threshold():
    # Thresholds from the synthetic numbers (in real use: calibrate on labelled data).
    s_ok, _ = score_against_references(child_ok, refs_multi, k=1)
    s_var, _ = score_against_references(child_variant, refs_multi, k=1)
    s_wrong, _ = score_against_references(child_wrong, refs_multi, k=1)
    thr = (max(s_ok, s_var) + s_wrong) / 2
    return thr, s_ok, s_var, s_wrong


def test_multi_reference_accepts_ok_and_variant_rejects_wrong(multi_ref_threshold):
    thr, s_ok, s_var, s_wrong = multi_ref_threshold
    assert (
        s_ok < thr and s_var < thr and s_wrong > thr
    ), "multi-ref should accept ok+variant, reject wrong"


def test_single_reference_penalises_legitimate_variant(multi_ref_threshold):
    thr = multi_ref_threshold[0]
    s1_var, _ = score_against_references(child_variant, refs_single, k=1)
    assert s1_var > thr, "single reference wrongly penalises the legitimate variant"


def test_localisation_flags_second_sound():
    agg, results = score_against_references(child_wrong, refs_multi, k=1)
    best = results[0]
    ref_emb = next(r["emb"] for r in refs_multi if r["variant_id"] == best["variant_id"])
    best["frame_cost"] = cosine_cost_matrix(child_wrong, ref_emb)
    segs = (
        ref_segments if best["variant_id"] == "A" else [("a", 0, 11), ("d", 11, 22), ("c", 22, 32)]
    )
    loc = localise(len(child_wrong), best, segs)
    costs = {s["label"]: s["cost"] for s in loc}
    worst = max(costs, key=costs.get)
    assert worst in ("b", "d"), "should flag the 2nd sound"
