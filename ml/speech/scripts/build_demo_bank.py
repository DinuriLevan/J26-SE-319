"""Build the reference bank for the words in config/words.csv from the child sentence corpus.

For each word, every aligned token said by a DEV child (same filters as the layer sweep) is cut out
and written as data/reference/<word_id>/<speaker>_t<NN>.wav plus a metadata json. Test children
are never used, so they stay unseen for the final evaluation. Run scripts/build_embeddings.py next.

Usage (from ml/speech):
    python scripts/build_demo_bank.py [--min-refs 4]
"""

from __future__ import annotations

import argparse
import json
import shutil
import sys
from pathlib import Path

import pandas as pd
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))
from layer_sweep import PAD_S, select_tokens  # noqa: E402

from src.audio import load_audio  # noqa: E402
from src.settings import load_settings  # noqa: E402
from src.splits import assert_dev_only  # noqa: E402


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--min-refs", type=int, default=4)
    args = parser.parse_args()

    settings = load_settings()
    data_dir = settings["paths"]["data_dir"]
    ref_root = settings["paths"]["reference_dir"]
    words = pd.read_csv(settings["paths"]["words_csv"], dtype=str).fillna("")
    tokens = select_tokens(pd.read_csv(data_dir / "corpus" / "words.csv"), 0.12, 0.3)
    assert_dev_only(tokens.split, "Reference bank")
    paths = pd.read_csv(data_dir / "corpus" / "utterances.csv").set_index("utt_id").path

    for w in words.itertuples():
        key = w.text_si if w.language == "si" else w.text_en.lower()
        toks = tokens[(tokens.language == w.language) & (tokens.key == key)]
        toks = toks.sort_values(["speaker_id", "utt_id", "word_index"])
        out = ref_root / w.word_id
        shutil.rmtree(out, ignore_errors=True)
        out.mkdir(parents=True)
        take = {}
        for t in toks.itertuples():
            take[t.speaker_id] = take.get(t.speaker_id, 0) + 1
            ref_id = f"{t.speaker_id}_t{take[t.speaker_id]:02d}"
            wav = load_audio(data_dir / paths[t.utt_id], max_duration_s=60, trim=False)
            a, b = max(0, int((t.start_s - PAD_S) * 16000)), int((t.end_s + PAD_S) * 16000)
            sf.write(out / f"{ref_id}.wav", wav[a:b], 16000)
            meta = {
                "speaker_id": t.speaker_id,
                "age_group": "child",
                "accent": "unknown",
                "source": "child_corpus",
                "utt_id": t.utt_id,
                "units": [],  # akshara boundaries come with Stage 4
            }
            (out / f"{ref_id}.json").write_text(
                json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
            )
        flag = "" if len(toks) >= args.min_refs else f"  (< {args.min_refs}: fallback threshold)"
        print(
            f"{w.word_id} {key}: {len(toks)} refs from {toks.speaker_id.nunique()} children{flag}"
        )


if __name__ == "__main__":
    main()
