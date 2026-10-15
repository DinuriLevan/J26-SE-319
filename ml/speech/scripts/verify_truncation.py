"""Verify the truncated XLS-R encoder reproduces hidden_states[layer] of the full model.

For each layer, a copy of the model cut to layer+1 transformer layers must give np.allclose output
to the full model's hidden_states[layer] on real clips. As a control, it also reports the naive cut
to `layer` layers, which should NOT match (the final layer_norm lands on the wrong output).

Usage (from ml/speech):
    python scripts/verify_truncation.py [--layers 6 12 18 23] [--n-clips 5]
Writes eval/results/truncation_check.json (numbers only, no audio).
"""

from __future__ import annotations

import argparse
import copy
import json
import sys
import time
from pathlib import Path

import numpy as np
import pandas as pd
import torch

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.audio import load_audio  # noqa: E402
from src.embed import truncate_encoder  # noqa: E402
from src.settings import SPEECH_ROOT, load_settings  # noqa: E402


def hidden(model, inputs, layer):
    with torch.inference_mode():
        return model(inputs, output_hidden_states=True).hidden_states[layer][0].numpy()


def main() -> None:
    from transformers import AutoFeatureExtractor, Wav2Vec2Model

    parser = argparse.ArgumentParser()
    parser.add_argument("--layers", type=int, nargs="+", default=[1, 6, 12, 18, 23])
    parser.add_argument("--n-clips", type=int, default=5)
    args = parser.parse_args()

    settings = load_settings()
    name = settings["embedding"]["model_name"]
    data_dir = settings["paths"]["data_dir"]
    utts = pd.read_csv(data_dir / "corpus" / "utterances.csv")
    clips = utts[utts.split == "dev"].sample(args.n_clips, random_state=0)  # dev only

    extractor = AutoFeatureExtractor.from_pretrained(name)
    full = Wav2Vec2Model.from_pretrained(name).eval()
    inputs = [
        extractor(
            load_audio(data_dir / p, max_duration_s=60), sampling_rate=16000, return_tensors="pt"
        ).input_values
        for p in clips.path
    ]

    results = []
    for layer in args.layers:
        ok_model = truncate_encoder(copy.deepcopy(full), layer)
        naive = copy.deepcopy(full)
        naive.encoder.layers = naive.encoder.layers[:layer]
        max_diff, naive_diff, t_full, t_trunc = 0.0, 0.0, 0.0, 0.0
        all_close = True
        for x in inputs:
            t = time.perf_counter()
            ref = hidden(full, x, layer)
            t_full += time.perf_counter() - t
            t = time.perf_counter()
            out = hidden(ok_model, x, layer)
            t_trunc += time.perf_counter() - t
            all_close &= bool(np.allclose(ref, out, rtol=1e-5, atol=1e-5))
            max_diff = max(max_diff, float(np.abs(ref - out).max()))
            naive_diff = max(naive_diff, float(np.abs(ref - hidden(naive, x, layer)).max()))
        row = {
            "layer": layer,
            "kept_layers": len(ok_model.encoder.layers),
            "allclose": all_close,
            "max_abs_diff": max_diff,
            "naive_cut_max_abs_diff": naive_diff,
            "speedup": round(t_full / t_trunc, 2),
        }
        results.append(row)
        print(row)

    out = SPEECH_ROOT / "eval" / "results" / "truncation_check.json"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(
        json.dumps({"model": name, "n_clips": len(inputs), "results": results}, indent=2)
    )
    if not all(r["allclose"] for r in results):
        raise SystemExit(
            "Truncated encoder does NOT match the full model. Keep truncate_encoder: false."
        )
    print(f"All layers match. Written {out}")


if __name__ == "__main__":
    main()
