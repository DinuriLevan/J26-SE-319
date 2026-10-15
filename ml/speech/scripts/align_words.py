"""Word boundaries for the child sentence corpus via MMS forced alignment (torchaudio MMS_FA).

Reads data/corpus/utterances.csv, romanises each transcript with uroman (Sinhala and English),
aligns it, and writes data/corpus/words.csv with one row per word:
    utt_id, word_index, word, roman, start_s, end_s, align_score, speaker_id, language, split, label_ok
Times are relative to the original (untrimmed) file. Boundaries are automatic ("source: mms_fa")
and must be spot-checked by ear before being trusted for unit-level work.

Usage (from ml/speech):
    python scripts/align_words.py
"""

from __future__ import annotations

import re
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd
import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.audio import load_audio  # noqa: E402
from src.settings import load_settings  # noqa: E402


def romanise_words(text: str, uroman, vocab: set[str]) -> list[tuple[str, str]]:
    """[(original word, romanised word restricted to the aligner's alphabet)], dropping empties."""
    out = []
    for word in re.findall(r"[^\s.,!?]+", text):
        roman = uroman.romanize_string(word).lower()
        roman = "".join(c for c in roman if c in vocab)
        if roman:
            out.append((word, roman))
    return out


def main() -> None:
    import torchaudio
    import uroman as ur

    settings = load_settings()
    data_dir = settings["paths"]["data_dir"]
    utts = pd.read_csv(data_dir / "corpus" / "utterances.csv")

    bundle = torchaudio.pipelines.MMS_FA
    model = bundle.get_model(with_star=False).eval()
    tokenizer, aligner = bundle.get_tokenizer(), bundle.get_aligner()
    vocab = set(bundle.get_dict()) - {"-", "*"}
    uroman = ur.Uroman()

    rows, t0 = [], time.perf_counter()
    for u in utts.itertuples():
        words = romanise_words(u.text, uroman, vocab)
        wav = load_audio(data_dir / u.path, max_duration_s=60, trim=False)
        with torch.inference_mode():
            emission, _ = model(torch.from_numpy(wav)[None])
        spans = aligner(emission[0], tokenizer([r for _, r in words]))
        sec_per_frame = wav.size / emission.size(1) / bundle.sample_rate
        for i, ((word, roman), span) in enumerate(zip(words, spans)):
            rows.append(
                {
                    "utt_id": u.utt_id,
                    "word_index": i,
                    "word": word,
                    "roman": roman,
                    "start_s": round(span[0].start * sec_per_frame, 3),
                    "end_s": round(span[-1].end * sec_per_frame, 3),
                    "align_score": round(float(np.mean([s.score for s in span])), 3),
                    "speaker_id": u.speaker_id,
                    "language": u.language,
                    "split": u.split,
                    "label_ok": u.label_ok,
                }
            )
    out = data_dir / "corpus" / "words.csv"
    pd.DataFrame(rows).to_csv(out, index=False, encoding="utf-8")
    print(
        f"{len(rows)} words from {len(utts)} utterances in {time.perf_counter() - t0:.0f}s -> {out}"
    )


if __name__ == "__main__":
    main()
