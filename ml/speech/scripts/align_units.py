"""Fill unit (akshara/syllable) boundaries into every reference json via MMS forced alignment.

For each data/reference/<word_id>/<ref_id>.json, the word's units from config/words.csv
(e.g. අ|ම්මා, c|a|t) are romanised one by one (uroman) and aligned as separate "words" on the
SAME trimmed audio that scripts/build_embeddings.py embedded, so times map to embedding frames
(frame = time / 0.02 s). Neighbouring units share a boundary at the midpoint of the gap between
them, so the units tile the word. Written with "units_source": "mms_fa".

References whose units_source is "manual" (hand-marked in Audacity/Praat) are never overwritten
unless --force is given. Use --spotcheck N to export N random unit clips for listening.

Usage (from ml/speech):
    python scripts/align_units.py [--force] [--spotcheck 30]
"""

from __future__ import annotations

import argparse
import json
import random
import shutil
import sys
from pathlib import Path

import numpy as np
import pandas as pd
import soundfile as sf
import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.audio import load_audio  # noqa: E402
from src.settings import load_settings  # noqa: E402


def tile_units(labels: list[str], spans: list[tuple[float, float, float]]) -> list[dict]:
    """spans: (start_s, end_s, score) per unit, possibly with gaps. Returns contiguous units."""
    units = []
    for i, (label, (start, end, score)) in enumerate(zip(labels, spans)):
        if i > 0:
            start = (spans[i - 1][1] + start) / 2
        if i < len(spans) - 1:
            end = (end + spans[i + 1][0]) / 2
        units.append(
            {"label": label, "start_s": round(start, 3), "end_s": round(end, 3), "score": score}
        )
    return units


def main() -> None:
    import torchaudio
    import uroman as ur

    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="also overwrite manual boundaries")
    parser.add_argument("--spotcheck", type=int, default=0)
    args = parser.parse_args()

    settings = load_settings()
    audio_cfg = settings["audio"]
    words = pd.read_csv(settings["paths"]["words_csv"], dtype=str).set_index("word_id")
    ref_root = Path(settings["paths"]["reference_dir"])

    bundle = torchaudio.pipelines.MMS_FA
    model = bundle.get_model(with_star=False).eval()
    tokenizer, aligner = bundle.get_tokenizer(), bundle.get_aligner()
    vocab = set(bundle.get_dict()) - {"-", "*"}
    uroman = ur.Uroman()

    done, skipped, failed, clips = 0, 0, [], []
    for meta_path in sorted(ref_root.glob("*/*.json")):
        word_id = meta_path.parent.name
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("units_source") == "manual" and not args.force:
            skipped += 1
            continue
        labels = words.loc[word_id, "units"].split("|")
        romans = [
            "".join(c for c in uroman.romanize_string(u).lower() if c in vocab) for u in labels
        ]
        wav = load_audio(
            meta_path.with_suffix(".wav"),
            target_sr=audio_cfg["sample_rate"],
            max_duration_s=60,
            trim_top_db=audio_cfg["trim_top_db"],
        )  # same trimming as build_embeddings, so times match embedding frames
        try:
            with torch.inference_mode():
                emission, _ = model(torch.from_numpy(wav)[None])
            aligned = aligner(emission[0], tokenizer(romans))
        except Exception as exc:  # e.g. clip too short for the number of letters
            failed.append(f"{word_id}/{meta_path.stem}: {exc}")
            continue
        sec = wav.size / emission.size(1) / bundle.sample_rate
        spans = [
            (s[0].start * sec, s[-1].end * sec, round(float(np.mean([t.score for t in s])), 3))
            for s in aligned
        ]
        meta["units"] = tile_units(labels, spans)
        meta["units_source"] = "mms_fa"
        meta_path.write_text(json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8")
        done += 1
        clips += [(word_id, meta_path.stem, wav, u) for u in meta["units"]]

    print(f"aligned {done}, kept manual {skipped}, failed {len(failed)}")
    for f in failed:
        print("  FAILED", f)

    if args.spotcheck and clips:
        out = settings["paths"]["data_dir"] / "corpus" / "unit_spotcheck"
        shutil.rmtree(out, ignore_errors=True)
        out.mkdir(parents=True)
        for i, (word_id, ref_id, wav, u) in enumerate(
            random.Random(0).sample(clips, min(args.spotcheck, len(clips)))
        ):
            a, b = int(u["start_s"] * 16000), int(u["end_s"] * 16000)
            sf.write(out / f"{i:02d}_{word_id}_{ref_id}_{u['label']}.wav", wav[a:b], 16000)
        print(f"{min(args.spotcheck, len(clips))} unit clips for listening in {out}")


if __name__ == "__main__":
    main()
