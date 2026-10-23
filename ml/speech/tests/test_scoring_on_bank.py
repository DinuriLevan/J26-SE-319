"""Check that the on-disk bank format (from make_synthetic_bank.py) works with src/scoring.py."""

import json
import sys
from pathlib import Path

import numpy as np
import pytest

from src.scoring import cosine_cost_matrix, localise, score_against_references

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from make_synthetic_bank import FRAME_S, build_bank  # noqa: E402


def _load_refs(bank: Path, word_id: str, exclude: str | None = None):
    refs = []
    for meta_path in sorted((bank / "reference" / word_id).glob("*.json")):
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta["speaker_id"] == exclude:
            continue
        refs.append(
            {
                "emb": np.load(bank / "embeddings" / word_id / f"{meta['speaker_id']}.npy"),
                "age_group": meta["age_group"],
                "variant_id": meta["speaker_id"],
                "units": meta["units"],
            }
        )
    return refs


@pytest.fixture(scope="module")
def bank(tmp_path_factory):
    path = tmp_path_factory.mktemp("bank")
    build_bank(path, seed=0, dim=64)
    return path


def test_same_word_scores_lower_than_other_word(bank):
    probe = np.load(bank / "embeddings" / "w_001" / "spk_child_01.npy")
    same, _ = score_against_references(probe, _load_refs(bank, "w_001", exclude="spk_child_01"))
    other, _ = score_against_references(probe, _load_refs(bank, "w_003"))
    assert same < other


def test_localise_with_bank_unit_boundaries(bank):
    # Swap the middle unit of w_001 (ක|ම|ල) for ස, taken from w_003 (පා|ස|ල).
    word = np.load(bank / "embeddings" / "w_001" / "spk_child_01.npy")
    meta = json.loads(
        (bank / "reference" / "w_001" / "spk_child_01.json").read_text(encoding="utf-8")
    )
    other = np.load(bank / "embeddings" / "w_003" / "spk_child_01.npy")
    other_meta = json.loads(
        (bank / "reference" / "w_003" / "spk_child_01.json").read_text(encoding="utf-8")
    )
    f = lambda s: round(s / FRAME_S)  # noqa: E731
    u, o = meta["units"], other_meta["units"][1]
    probe = np.concatenate(
        [
            word[: f(u[1]["start_s"])],
            other[f(o["start_s"]) : f(o["end_s"])],
            word[f(u[2]["start_s"]) :],
        ]
    )

    refs = _load_refs(bank, "w_001", exclude="spk_child_01")
    _, results = score_against_references(probe, refs)
    best = results[0]
    ref = next(r for r in refs if r["variant_id"] == best["variant_id"])
    best["frame_cost"] = cosine_cost_matrix(probe, ref["emb"])
    segs = [(x["label"], f(x["start_s"]), f(x["end_s"])) for x in ref["units"]]
    loc = localise(len(probe), best, segs)
    worst = max(loc, key=lambda s: s["cost"])
    assert worst["label"] == "ම"
