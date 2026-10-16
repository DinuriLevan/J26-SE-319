"""Learned acceptance range (src/threshold.py) on synthetic phoneme prototypes."""

import numpy as np
import pytest

from src.dtw_fast import dtw as fast_dtw
from src.scoring import score_against_references
from src.threshold import acceptance_range, leave_one_out_scores

D = 32


def _bank(seed, n_std, n_var):
    rng = np.random.default_rng(seed)
    proto = {p: rng.normal(size=D) for p in "abcdef"}

    def utt(ph, durs, noise=0.15):
        return np.array(
            [proto[p] + rng.normal(scale=noise, size=D) for p, d in zip(ph, durs) for _ in range(d)]
        )

    refs = [
        {"emb": utt("abc", rng.integers(9, 14, 3)), "age_group": "adult", "variant_id": f"std{i}"}
        for i in range(n_std)
    ] + [
        {"emb": utt("adc", rng.integers(9, 14, 3)), "age_group": "child", "variant_id": f"var{i}"}
        for i in range(n_var)
    ]
    children = {
        "ok": utt("abc", [14, 18, 13]),  # slower, correct
        "variant": utt("adc", [13, 15, 12]),  # legitimate accent variant (in the bank)
        "wrong": utt("aec", [14, 18, 13]),  # genuine error on the 2nd sound
    }
    return refs, children


def test_fallback_below_min_refs():
    refs, _ = _bank(0, 2, 1)
    r = acceptance_range(refs, k=3, n_std=2.0, min_refs=4, fallback=0.3)
    assert (r.source, r.threshold, r.n_refs) == ("fallback", 0.3, 3)
    assert r.loo_scores == ()


def test_loo_scores_match_manual_and_cap_k():
    refs, _ = _bank(1, 3, 1)
    loo = leave_one_out_scores(refs, k=10)  # k capped at n - 1 = 3
    for i, s in enumerate(loo):
        others = refs[:i] + refs[i + 1 :]
        assert s == pytest.approx(score_against_references(refs[i]["emb"], others, k=3)[0])
    r = acceptance_range(refs, k=10, n_std=2.0, min_refs=4)
    assert r.source == "bank"
    assert r.threshold == pytest.approx(np.mean(loo) + 2.0 * np.std(loo))


def test_fast_dtw_gives_same_range():
    refs, _ = _bank(2, 3, 2)
    a = acceptance_range(refs, k=3)
    b = acceptance_range(refs, k=3, dtw_fn=fast_dtw)
    assert a.threshold == pytest.approx(b.threshold, rel=1e-12)


@pytest.mark.parametrize("n_std,n_var", [(3, 3), (3, 2)])
def test_learned_range_accepts_variant_rejects_wrong(n_std, n_var):
    """The core claim: a range learned from a multi-reference bank (no hand-tuned threshold)
    accepts the correct word and the accent variant and rejects the wrong sound."""
    refs, kids = _bank(0, n_std, n_var)
    r = acceptance_range(refs, k=3, n_std=2.0, min_refs=4, dtw_fn=fast_dtw)
    assert r.source == "bank"
    s = {
        name: score_against_references(emb, refs, k=3, dtw_fn=fast_dtw)[0]
        for name, emb in kids.items()
    }
    assert s["ok"] <= r.threshold, s
    assert s["variant"] <= r.threshold, s
    assert s["wrong"] > r.threshold, s


def test_single_reference_cannot_learn_a_range():
    refs, _ = _bank(0, 1, 0)
    assert acceptance_range(refs, min_refs=4, fallback=0.3).source == "fallback"


def test_speaker_loo_ignores_same_speaker_takes():
    refs, _ = _bank(3, 3, 2)
    # Duplicate takes per speaker: speaker-level LOO must not compare a take with its twin.
    takes = [dict(r, speaker=r["variant_id"]) for r in refs] + [
        dict(r, speaker=r["variant_id"], variant_id=r["variant_id"] + "_take2") for r in refs
    ]
    token = leave_one_out_scores(takes, k=1, unit="token")
    speaker = leave_one_out_scores(takes, k=1, unit="speaker")
    assert max(token) == pytest.approx(0.0, abs=1e-6)  # each take's nearest is its own twin
    assert min(speaker) > 1e-3
    # With one reference per speaker the two units agree.
    assert leave_one_out_scores(refs, k=3, unit="speaker") == pytest.approx(
        leave_one_out_scores(refs, k=3, unit="token")
    )
