"""Index the children's sentence recordings into data/corpus/utterances.csv.

Expected layout (as collected; ethics approval confirmed 2026-10-15):
    data/grade <G> (<N>) full/grade <G> (<N>) full/<English|Sinhala>/<Level 1|Level 2>/<sentence>[ - incorrect].<wav|ogg>

The file name is the transcript. "- incorrect" marks a reading the collector judged incorrect
(label_ok = 0). Speakers get anonymous ids (g3_s1, ...) and a dev/test split by speaker from
config/settings.yaml (corpus.test_speakers). Audio is not copied or modified.

Usage (from ml/speech):
    python scripts/build_child_corpus.py
"""

from __future__ import annotations

import csv
import re
import sys
import unicodedata
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.settings import load_settings  # noqa: E402

SPEAKER_DIR = re.compile(r"grade (\d+) \((\d+)\) full", re.I)
INCORRECT = re.compile(r"\s*-\s*incorrect\s*$", re.I)
ZWJ = "‍"


def normalise_text(stem: str) -> str:
    # File systems dropped the zero-width joiner in Sinhala conjuncts (ප්‍ර); "_" marks where it was.
    text = stem.replace("_", ZWJ)
    text = re.sub(r"\s+", " ", unicodedata.normalize("NFC", text)).strip()
    return text.rstrip(".").strip()


def index_corpus(data_dir: Path, test_speakers: set[str]) -> list[dict]:
    rows = []
    for f in sorted(data_dir.glob("grade*/**/*")):
        if f.suffix.lower() not in {".wav", ".ogg"}:
            continue
        rel = f.relative_to(data_dir).parts
        m = SPEAKER_DIR.fullmatch(rel[0])
        if not m or len(rel) != 5:
            raise SystemExit(f"Unexpected path layout: {f}")
        grade, num = m.groups()
        speaker_id = f"g{grade}_s{num}"
        language = "si" if rel[2].lower().startswith("sinh") else "en"
        level = int(re.search(r"\d+", rel[3]).group())
        label_ok = 0 if INCORRECT.search(f.stem) else 1
        text = normalise_text(INCORRECT.sub("", f.stem))
        rows.append(
            {
                "utt_id": f"{speaker_id}_{language}_l{level}_{len(rows):04d}",
                "path": f.relative_to(data_dir).as_posix(),
                "speaker_id": speaker_id,
                "grade": int(grade),
                "age_group": "child",
                "language": language,
                "level": level,
                "text": text,
                "label_ok": label_ok,
                "split": "test" if speaker_id in test_speakers else "dev",
            }
        )
    return rows


def main() -> None:
    settings = load_settings()
    data_dir = settings["paths"]["data_dir"]
    rows = index_corpus(data_dir, set(settings["corpus"]["test_speakers"]))
    out = data_dir / "corpus" / "utterances.csv"
    out.parent.mkdir(parents=True, exist_ok=True)
    with open(out, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    speakers = sorted({(r["speaker_id"], r["split"]) for r in rows})
    print(f"{len(rows)} utterances, speakers: {speakers}")
    print(f"label_ok=0: {sum(r['label_ok'] == 0 for r in rows)}")


if __name__ == "__main__":
    main()
