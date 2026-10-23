"""Mispronunciation study (dev only): how often does the service accept a deliberate mispronunciation?

Other practice words (eval/threshold_study_dev.py) are easy to reject; the errors that matter are
close to the target ("cut" for cat, "අමා" for අම්මා). A DEV speaker records the mispronunciations
listed in eval/mispronunciations.csv (one per word; categories TO VALIDATE WITH A SPEECH-LANGUAGE
EXPERT, Sinhala forms TO REVIEW BY A NATIVE SPEAKER), named "<word>__<what was said>.WAV", e.g.
"cat__cut.WAV", "අම්මා__අමා.WAV", in one folder per speaker.

Each clip is processed like a live attempt (same audio loading and embedder as the service) and
scored against the word's bank WITHOUT the recorder's own references, so their voice does not help.
The decision uses the configured pass mark (scoring.threshold_mode). For comparison, the
recorder's CORRECT clip of each word is scored the same way.

Usage (from ml/speech):
    python eval/mispronunciation_study_dev.py --src "data/new voice/mispronounced/adult" --speaker fr_a1
Writes eval/results/mispronunciation_study_dev_<speaker>.{csv,md}.
"""

from __future__ import annotations

import argparse
import re
import sys
import unicodedata
from pathlib import Path

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "scripts"))
from import_recordings import word_key  # noqa: E402

from src.audio import load_audio  # noqa: E402
from src.bank import ReferenceBank  # noqa: E402
from src.dtw_fast import dtw as fast_dtw  # noqa: E402
from src.embed import make_embedder  # noqa: E402
from src.scoring import score_against_references  # noqa: E402
from src.settings import load_settings  # noqa: E402
from src.splits import assert_dev_only  # noqa: E402
from src.threshold import acceptance_range  # noqa: E402

SHEET = ROOT / "eval" / "mispronunciations.csv"
OUT = ROOT / "eval" / "results"


def parse_name(filename: str) -> tuple[str, str]:
    """'cat__cut.WAV' -> ('cat', 'cut'); spaces, '(1)' and NFC handled like the import script."""
    stem = unicodedata.normalize("NFC", Path(filename).stem)
    if "__" not in stem:
        raise ValueError(f"{filename}: expected '<word>__<what was said>.WAV'")
    word, said = stem.split("__", 1)
    # The import's spelling aliases apply to the target word only: "said" is a mispronunciation
    # on purpose (පුසා for පූසා), so it is only cleaned of spaces and a "(n)" suffix.
    said = re.sub(r"\s+", "", re.sub(r"\(\d+\)", "", said))
    return word_key(word + ".wav"), said


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--src", type=Path, required=True)
    parser.add_argument("--speaker", required=True, help="recorder's speaker id (left out of banks)")
    parser.add_argument("--embedder", default="xlsr", choices=["xlsr", "spectral"])
    args = parser.parse_args()

    settings = load_settings()
    sc, audio = settings["scoring"], settings["audio"]
    assert_dev_only(
        ["test" if args.speaker in settings["corpus"]["test_speakers"] else "dev"], "Mispronunciation study"
    )
    bank = ReferenceBank.from_settings(settings)
    embedder = make_embedder(args.embedder, settings)
    bank.check_embedder(embedder.name)
    sheet = pd.read_csv(SHEET, dtype=str)
    by_text = {unicodedata.normalize("NFC", t).lower(): wid for wid, t in zip(sheet.word_id, sheet.word)}
    category = {(r.word_id, unicodedata.normalize("NFC", r.said)): r.category for r in sheet.itertuples()}

    def pass_mark(word_id: str, refs: list[dict]) -> float:
        if sc.get("threshold_mode") == "shared":
            return float(sc["shared_threshold"][bank.words[word_id]["language"]])
        return acceptance_range(
            refs, sc["k_nearest"], sc["n_std"], sc["min_refs_for_bank_threshold"],
            sc["fallback_threshold"], fast_dtw, sc.get("loo_unit", "token"),
        ).threshold

    rows, unknown = [], []
    for f in sorted(p for p in args.src.iterdir() if p.suffix.lower() == ".wav"):
        word, said = parse_name(f.name)
        word_id = by_text.get(word.lower())
        if word_id is None:
            unknown.append(f.name)
            continue
        refs = [r for r in bank.reference_set(word_id) if r["speaker"] != args.speaker]
        thr = pass_mark(word_id, refs)
        wav = load_audio(f, audio["sample_rate"], audio["max_duration_s"], audio["trim_top_db"])
        score, _ = score_against_references(embedder.embed(wav), refs, k=sc["k_nearest"], dtw_fn=fast_dtw)
        own = [r for r in bank.reference_set(word_id) if r["speaker"] == args.speaker]
        correct = (
            score_against_references(own[0]["emb"], refs, k=sc["k_nearest"], dtw_fn=fast_dtw)[0]
            if own else np.nan
        )
        rows.append({
            "word_id": word_id,
            "language": bank.words[word_id]["language"],
            "word": word,
            "said": said,
            "category": category.get((word_id, said), "other"),
            "score": round(float(score), 4),
            "correct_score": round(float(correct), 4),
            "threshold": round(thr, 4),
            "mispronunciation_accepted": bool(score <= thr),
            "correct_accepted": bool(correct <= thr) if own else None,
        })
    if unknown:
        raise SystemExit(f"Not a practice word: {unknown}")
    if not rows:
        raise SystemExit(f"No '<word>__<said>.WAV' files in {args.src}")

    df = pd.DataFrame(rows)
    OUT.mkdir(parents=True, exist_ok=True)
    stem = OUT / f"mispronunciation_study_dev_{args.speaker}"
    df.to_csv(stem.with_suffix(".csv"), index=False, encoding="utf-8")
    lines = [
        f"# Mispronunciation study (dev only): {args.speaker}",
        "",
        f"`eval/mispronunciation_study_dev.py`, pass mark mode `{sc.get('threshold_mode', 'per_word')}`. "
        "Lower 'accepted' is better for mispronunciations; higher is better for correct words.",
        "",
        "| Language | Category | Clips | Mispronunciations accepted | Same speaker's correct word accepted |",
        "|---|---|---|---|---|",
    ]
    for (lang, cat), g in df.groupby(["language", "category"]):
        ok = g.correct_accepted.dropna()
        lines.append(
            f"| {lang} | {cat} | {len(g)} | {g.mispronunciation_accepted.mean():.0%} "
            f"| {ok.mean():.0%} |" if len(ok) else f"| {lang} | {cat} | {len(g)} | "
            f"{g.mispronunciation_accepted.mean():.0%} | - |"
        )
    for lang, g in df.groupby("language"):
        lines.append(
            f"| **{lang}** | **all** | {len(g)} | **{g.mispronunciation_accepted.mean():.0%}** "
            f"| {g.correct_accepted.dropna().mean():.0%} |"
        )
    stem.with_suffix(".md").write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))


if __name__ == "__main__":
    main()
