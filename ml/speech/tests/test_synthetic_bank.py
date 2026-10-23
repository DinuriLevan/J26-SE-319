import csv
import json
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from make_synthetic_bank import FRAME_S, SPEAKERS, WORDS, build_bank  # noqa: E402


def test_bank_layout_and_shapes(tmp_path):
    build_bank(tmp_path, seed=0, dim=16)

    with open(tmp_path / "words.csv", encoding="utf-8") as f:
        rows = list(csv.DictReader(f))
    assert [r["word_id"] for r in rows] == [w[0] for w in WORDS]

    for row in rows:
        units = row["units"].split("|")
        for speaker_id, age_group, _ in SPEAKERS:
            emb = np.load(tmp_path / "embeddings" / row["word_id"] / f"{speaker_id}.npy")
            meta = json.loads(
                (tmp_path / "reference" / row["word_id"] / f"{speaker_id}.json").read_text(
                    encoding="utf-8"
                )
            )
            assert emb.dtype == np.float32 and emb.shape[1] == 16
            assert meta["age_group"] == age_group
            assert [u["label"] for u in meta["units"]] == units
            # Unit boundaries are contiguous and cover every frame.
            assert meta["units"][0]["start_s"] == 0.0
            for a, b in zip(meta["units"], meta["units"][1:]):
                assert a["end_s"] == b["start_s"]
            assert round(meta["units"][-1]["end_s"] / FRAME_S) == emb.shape[0]


def test_bank_is_deterministic(tmp_path):
    build_bank(tmp_path / "a", seed=7, dim=8)
    build_bank(tmp_path / "b", seed=7, dim=8)
    rel = Path("embeddings") / "w_001" / "spk_child_01.npy"
    np.testing.assert_array_equal(np.load(tmp_path / "a" / rel), np.load(tmp_path / "b" / rel))


def test_same_unit_frames_are_closer_than_different_units(tmp_path):
    """Sanity check that the synthetic data carries unit identity (what DTW scoring relies on)."""
    build_bank(tmp_path, seed=0, dim=64)
    emb = np.load(tmp_path / "embeddings" / "w_001" / "spk_adult_01.npy")
    meta = json.loads(
        (tmp_path / "reference" / "w_001" / "spk_adult_01.json").read_text(encoding="utf-8")
    )
    means = [
        emb[round(u["start_s"] / FRAME_S) : round(u["end_s"] / FRAME_S)].mean(axis=0)
        for u in meta["units"]
    ]
    other = np.load(tmp_path / "embeddings" / "w_001" / "spk_adult_02.npy")
    other_meta = json.loads(
        (tmp_path / "reference" / "w_001" / "spk_adult_02.json").read_text(encoding="utf-8")
    )
    first = other_meta["units"][0]
    probe = other[round(first["start_s"] / FRAME_S) : round(first["end_s"] / FRAME_S)].mean(axis=0)
    dists = [np.linalg.norm(probe - m) for m in means]
    assert int(np.argmin(dists)) == 0
