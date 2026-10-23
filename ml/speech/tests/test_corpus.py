import sys
from pathlib import Path

import numpy as np
import pytest
import soundfile as sf

from src.splits import SplitLeakError, assert_dev_only

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from build_child_corpus import ZWJ, index_corpus, normalise_text  # noqa: E402
from layer_sweep import build_pairs, select_tokens  # noqa: E402


def test_assert_dev_only():
    assert_dev_only(["dev", "dev"], "x")
    with pytest.raises(SplitLeakError, match="dev data only"):
        assert_dev_only(["dev", "test"], "Threshold tuning")


def test_normalise_text_restores_zwj_and_strips_punctuation():
    assert normalise_text("ප්_රහේලිකාව  විසඳා.") == f"ප්{ZWJ}රහේලිකාව විසඳා"


def _touch(root: Path, rel: str):
    p = root / rel
    p.parent.mkdir(parents=True, exist_ok=True)
    sf.write(p, np.zeros(1600, dtype=np.float32), 16000)


def test_index_corpus_ids_labels_and_split(tmp_path):
    _touch(tmp_path, "grade 3 (1) full/grade 3 (1) full/English/Level 1/I eat rice.wav")
    _touch(
        tmp_path, "grade 3 (1) full/grade 3 (1) full/English/Level 1/The sun shines - incorrect.wav"
    )
    _touch(tmp_path, "grade 4 (2) full/grade 4 (2) full/sinhla/level 2/මම ගමට යමි.wav")
    rows = index_corpus(tmp_path, test_speakers={"g4_s2"})
    by_text = {r["text"]: r for r in rows}
    assert by_text["I eat rice"]["speaker_id"] == "g3_s1"
    assert by_text["I eat rice"]["split"] == "dev" and by_text["I eat rice"]["label_ok"] == 1
    assert by_text["The sun shines"]["label_ok"] == 0
    si = by_text["මම ගමට යමි"]
    assert (si["language"], si["level"], si["split"], si["grade"]) == ("si", 2, "test", 4)


def test_layer_sweep_refuses_test_rows_and_pairs_cross_speaker():
    import pandas as pd

    words = pd.DataFrame(
        {
            "word": ["sun", "Sun", "cat", "cat", "sun"],
            "language": ["en"] * 5,
            "speaker_id": ["a", "b", "a", "b", "c"],
            "split": ["dev", "dev", "dev", "dev", "test"],
            "label_ok": [1] * 5,
            "start_s": [0.0] * 5,
            "end_s": [0.3] * 5,
            "align_score": [0.9] * 5,
        }
    )
    w = select_tokens(words, min_dur=0.1, min_align=0.3)
    assert set(w.split) == {"dev"} and len(w) == 4  # test speaker c dropped, "Sun" == "sun"
    pairs = build_pairs(w, n_neg=5, seed=0)
    for q, c, pos in pairs:
        assert w.speaker_id[q] != w.speaker_id[c]
        assert pos == (w.key[q] == w.key[c])
