"""Spoken instructions for the app: a recording script and clean prompt assets.

1. Recording script: lists every prompt key with its exact text (English and Sinhala), taken from
   the app's ARB files so the voice always matches the bubble text:
       python scripts/prepare_prompts.py --script
   -> data/prompts/RECORDING_SCRIPT.md (gitignored)

2. Convert recordings: an ADULT reads each line (with their consent). Save the raw files as
   <in>/<en|si>/<key>.<wav|ogg|flac>, then:
       python scripts/prepare_prompts.py --in data/prompts/raw
   -> app/assets/speech/prompts/<en|si>/<key>.wav: mono, 22.05 kHz, 16-bit, silence trimmed,
      loudness normalised, 15 ms fades. Missing and unexpected keys are reported.

Prompts without a recording fall back to the phone's text-to-speech in the app.
Never put children's voices here: these files ship inside the app.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from src.audio import AudioValidationError, load_audio  # noqa: E402

REPO = ROOT.parents[1]
ARB_DIR = REPO / "app" / "lib" / "l10n"
ASSET_DIR = REPO / "app" / "assets" / "speech" / "prompts"
LANGS = ("en", "si")
SAMPLE_RATE = 22050
TARGET_RMS_DB = -20.0
PEAK_LIMIT = 0.89  # about -1 dBFS
FADE_S = 0.015

# Keys the parrot speaks (app/lib/features/speech/...); must exist in the ARB files.
PROMPT_KEYS = [
    "speechChooseLanguage",
    "speechChooseWord",
    "speechTapToRecord",
    "speechWholeWordAgain",
    "speechListen",
    "speechSaySound",
    "speechBlend",
    "speechStepWellDone",
    "speechStepOnceMore",
    "speechGoodPractice",
    "speechCouldNotHear",
    "speechMicNeeded",
    "speechSomethingWrong",
    "speechGreatJob",
    "speechAcceptedBody",
    "speechFallbackTitle",
    "speechPractiseBody",
    "speechCardUnlocked",
]


def load_texts(arb_dir: Path = ARB_DIR) -> dict[str, dict[str, str]]:
    texts = {}
    for lang in LANGS:
        arb = json.loads((arb_dir / f"app_{lang}.arb").read_text(encoding="utf-8"))
        missing = [k for k in PROMPT_KEYS if k not in arb]
        if missing:
            raise SystemExit(f"app_{lang}.arb is missing prompt keys: {missing}")
        texts[lang] = {k: arb[k] for k in PROMPT_KEYS}
    return texts


def write_script(texts: dict[str, dict[str, str]], out: Path) -> None:
    lines = [
        "# Parrot voice: recording script",
        "",
        "An adult reads each line warmly and slowly, as if to a 7-year-old. Save each as",
        "`<en|si>/<key>.wav` (or .ogg/.flac) in one folder, then run",
        "`python scripts/prepare_prompts.py --in <folder>`.",
        "",
        "| key | English | සිංහල |",
        "|---|---|---|",
    ]
    for k in PROMPT_KEYS:
        lines.append(f"| `{k}` | {texts['en'][k]} | {texts['si'][k]} |")
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text("\n".join(lines) + "\n", encoding="utf-8")


def clean_prompt(wav: np.ndarray, sr: int = SAMPLE_RATE) -> np.ndarray:
    """Loudness-normalise to TARGET_RMS_DB (peak-limited) and add short fades."""
    rms = float(np.sqrt(np.mean(wav**2)) + 1e-12)
    out = wav * (10 ** (TARGET_RMS_DB / 20) / rms)
    peak = float(np.max(np.abs(out)))
    if peak > PEAK_LIMIT:
        out *= PEAK_LIMIT / peak
    n = min(int(FADE_S * sr), out.size // 2)
    if n:
        ramp = np.linspace(0.0, 1.0, n, dtype=np.float32)
        out[:n] *= ramp
        out[-n:] *= ramp[::-1]
    return out.astype(np.float32)


def convert(in_dir: Path, out_dir: Path = ASSET_DIR) -> dict[str, list[str]]:
    """Returns a report: converted, missing and unexpected files per language."""
    report: dict[str, list[str]] = {"converted": [], "missing": [], "unexpected": [], "failed": []}
    for lang in LANGS:
        src = in_dir / lang
        files = {f.stem: f for f in src.glob("*") if f.suffix.lower() in {".wav", ".ogg", ".flac"}}
        for key in PROMPT_KEYS:
            if key not in files:
                report["missing"].append(f"{lang}/{key}")
                continue
            try:
                wav = load_audio(
                    files[key], target_sr=SAMPLE_RATE, max_duration_s=15, trim_top_db=35
                )
            except AudioValidationError as exc:
                report["failed"].append(f"{lang}/{key}: {exc}")
                continue
            dest = out_dir / lang / f"{key}.wav"
            dest.parent.mkdir(parents=True, exist_ok=True)
            sf.write(dest, clean_prompt(wav), SAMPLE_RATE, subtype="PCM_16")
            report["converted"].append(f"{lang}/{key}")
        report["unexpected"] += [f"{lang}/{s}" for s in files if s not in PROMPT_KEYS]
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--script", action="store_true", help="write the recording script")
    parser.add_argument("--in", dest="in_dir", type=Path, help="folder with en/ and si/ recordings")
    parser.add_argument("--out", type=Path, default=ASSET_DIR)
    args = parser.parse_args()

    texts = load_texts()
    if args.script or not args.in_dir:
        out = ROOT / "data" / "prompts" / "RECORDING_SCRIPT.md"
        write_script(texts, out)
        print(f"Recording script: {out}")
    if args.in_dir:
        report = convert(args.in_dir, args.out)
        for k, v in report.items():
            print(f"{k}: {len(v)}" + (f"  {', '.join(v)}" if v and k != "converted" else ""))


if __name__ == "__main__":
    main()
