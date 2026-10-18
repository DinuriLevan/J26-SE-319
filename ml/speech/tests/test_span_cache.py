"""SpanBank disk cache: a second start-up reuses span embeddings instead of re-running the embedder."""

import json
import sys
from pathlib import Path

import numpy as np
import pytest
import soundfile as sf

from src.bank import ReferenceBank
from src.embed import SpectralEmbedder
from src.settings import load_settings
from src.units import SpanBank

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from build_embeddings import build  # noqa: E402


class CountingEmbedder(SpectralEmbedder):
    def __init__(self):
        super().__init__()
        self.calls = 0

    def embed(self, wav):
        self.calls += 1
        return super().embed(wav)


@pytest.fixture
def bank_settings(tmp_path):
    from tests.conftest import tone_word

    settings = load_settings()
    settings["paths"] = {
        "words_csv": tmp_path / "words.csv",
        "reference_dir": tmp_path / "reference",
        "embeddings_dir": tmp_path / "embeddings",
    }
    (tmp_path / "words.csv").write_text(
        "word_id,text_si,text_en,language,grade,units\nw_001,,cat,en,2,c|a|t\n", encoding="utf-8"
    )
    d = tmp_path / "reference" / "w_001"
    d.mkdir(parents=True)
    for i in range(4):
        durs = [0.3, 0.35 + 0.02 * i, 0.3]
        sf.write(d / f"spk{i}.wav", tone_word([440, 880, 660], durs, seed=i), 16000)
        t, units = 0.0, []
        for label, du in zip("cat", durs):
            units.append({"label": label, "start_s": round(t, 3), "end_s": round(t + du, 3)})
            t += du
        (d / f"spk{i}.json").write_text(
            json.dumps({"speaker_id": f"spk{i}", "age_group": "child", "units": units}),
            encoding="utf-8",
        )
    build(settings, SpectralEmbedder())
    return settings


def test_second_spanbank_loads_from_disk(bank_settings):
    first = CountingEmbedder()
    sb1 = SpanBank(ReferenceBank.from_settings(bank_settings), first, bank_settings)
    refs1 = sb1.span_refs("w_001", 1, 2)
    assert first.calls == 4 and len(refs1) == 4

    second = CountingEmbedder()
    sb2 = SpanBank(ReferenceBank.from_settings(bank_settings), second, bank_settings)
    refs2 = sb2.span_refs("w_001", 1, 2)
    assert second.calls == 0  # everything came from data/embeddings/_spans
    for a, b in zip(refs1, refs2):
        np.testing.assert_array_equal(a["emb"], b["emb"])
    assert sb2.span_range("w_001", 1, 2).threshold == pytest.approx(
        sb1.span_range("w_001", 1, 2).threshold
    )


def test_changed_unit_boundaries_miss_the_cache(bank_settings):
    SpanBank(
        ReferenceBank.from_settings(bank_settings), CountingEmbedder(), bank_settings
    ).span_refs("w_001", 1, 1)
    meta_path = bank_settings["paths"]["reference_dir"] / "w_001" / "spk0.json"
    meta = json.loads(meta_path.read_text(encoding="utf-8"))
    meta["units"][1]["start_s"] += 0.05  # re-aligned boundary
    meta_path.write_text(json.dumps(meta), encoding="utf-8")

    counting = CountingEmbedder()
    SpanBank(ReferenceBank.from_settings(bank_settings), counting, bank_settings).span_refs(
        "w_001", 1, 1
    )
    assert counting.calls == 1  # only the re-aligned reference is embedded again
