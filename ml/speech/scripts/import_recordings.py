"""Import a folder of single-word recordings (one speaker) into the reference bank.

Each file is named after the word it contains (e.g. "අම්මා.WAV", "ගස .WAV", "වතුර (1).WAV"). Names
are matched to config/words.csv after NFC normalisation, dropping spaces, a "(n)" suffix and the
extension; a stray digit typed after the word ("boy9") is dropped if that leaves a known word, and
ALIASES maps known spelling variants to the app word. An unmatched file stops the run.

Files are converted to 16 kHz mono (untrimmed, like scripts/build_demo_bank.py) and written as
data/reference/<word_id>/<speaker>_r<NN>.wav plus metadata with "source": "field_recording".
Re-running replaces only this speaker's field recordings (plus those of any --replace-speaker id,
for a renamed speaker). Test speakers are refused.
Run scripts/build_embeddings.py and scripts/align_units.py next.

Usage (from ml/speech):
    python scripts/import_recordings.py --src "data/new voice/adult sinhala" --speaker si_a1 \
        --age-group adult --language si
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import unicodedata
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd
import soundfile as sf

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from src.audio import AudioValidationError, load_audio  # noqa: E402
from src.settings import load_settings  # noqa: E402

SOURCE = "field_recording"
AUDIO_EXTS = {".wav"}
# File-name spelling -> app word (owner-confirmed 2026-10-20: same words, file-name typos).
ALIASES = {"පුසා": "පූසා", "පාසල": "පාසල්", "මල්ලී": "මල්ලි", "hart": "hat"}
SPEAKER_RE = re.compile(r"^[a-z0-9_]{1,32}$")


def word_key(filename: str) -> str:
    """'වතුර  (1).WAV' -> 'වතුර' (NFC, no spaces, no '(n)' suffix, no extension)."""
    stem = unicodedata.normalize("NFC", Path(filename).stem)
    stem = re.sub(r"\(\d+\)", "", stem)
    stem = re.sub(r"\s+", "", stem)
    return ALIASES.get(stem.lower(), ALIASES.get(stem, stem))


def match_files(files: list[Path], words: pd.DataFrame, language: str) -> tuple[dict, list[str]]:
    """{word_id: [files in name order]} and the names that match no word of the language."""
    col = "text_si" if language == "si" else "text_en"
    lookup = {
        unicodedata.normalize("NFC", str(t)).strip().lower(): wid
        for wid, t, lang in zip(words.word_id, words[col], words.language)
        if lang == language and str(t).strip()
    }
    matched: dict[str, list[Path]] = {}
    unmatched = []
    for f in sorted(files, key=lambda p: p.name):
        key = word_key(f.name).lower()
        wid = lookup.get(key)
        if wid is None and re.search(r"\D\d+$", key):  # "boy9": a stray digit after the word
            stripped = re.sub(r"\d+$", "", key)
            wid = lookup.get(ALIASES.get(stripped, stripped))
        if wid is None:
            unmatched.append(f.name)
        else:
            matched.setdefault(wid, []).append(f)
    return matched, unmatched


def remove_previous(ref_root: Path, speaker: str, word_ids: set[str]) -> int:
    """Delete this speaker's earlier field recordings of these words (only those) so re-runs are
    idempotent. Limited to one language's words: the same person may have recorded both."""
    n = 0
    for meta_path in ref_root.glob(f"*/{speaker}_r*.json"):
        if meta_path.parent.name not in word_ids:
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("source") == SOURCE and meta.get("speaker_id") == speaker:
            meta_path.unlink()
            meta_path.with_suffix(".wav").unlink(missing_ok=True)
            n += 1
    return n


def import_folder(
    src: Path,
    speaker: str,
    age_group: str,
    language: str,
    settings: dict,
    words: pd.DataFrame,
    replace_speakers: tuple[str, ...] = (),
) -> dict[str, int]:
    if not SPEAKER_RE.match(speaker):
        raise SystemExit(f"Speaker id {speaker!r} must match {SPEAKER_RE.pattern}.")
    if speaker in set(settings["corpus"]["test_speakers"]):
        raise SystemExit(f"{speaker} is a test speaker: test voices never go into the bank.")
    files = [p for p in src.iterdir() if p.is_file() and p.suffix.lower() in AUDIO_EXTS]
    matched, unmatched = match_files(files, words, language)
    if unmatched:
        raise SystemExit(f"No practice word matches: {unmatched}. Add an alias or rename the file.")

    ref_root = Path(settings["paths"]["reference_dir"])
    sr = settings["audio"]["sample_rate"]
    clips = {}
    for wid, wfiles in matched.items():  # load everything first: nothing is written on a bad file
        for f in wfiles:
            try:
                clips[f] = load_audio(f, target_sr=sr, max_duration_s=10, trim=False)
            except AudioValidationError as exc:
                raise SystemExit(f"{f.name}: {exc}") from exc

    lang_words = set(words.word_id[words.language == language])
    removed = sum(remove_previous(ref_root, s, lang_words) for s in (speaker, *replace_speakers))
    now = datetime.now(timezone.utc).isoformat(timespec="seconds")
    written = 0
    for wid, wfiles in matched.items():
        out = ref_root / wid
        out.mkdir(parents=True, exist_ok=True)
        for i, f in enumerate(wfiles, start=1):
            ref_id = f"{speaker}_r{i:02d}"
            sf.write(out / f"{ref_id}.wav", clips[f], sr, subtype="PCM_16")
            meta = {
                "speaker_id": speaker,
                "age_group": age_group,
                "accent": "unknown",
                "source": SOURCE,
                "recorded_from": f.name,
                "imported_at": now,
                "units": [],
            }
            (out / f"{ref_id}.json").write_text(
                json.dumps(meta, ensure_ascii=False, indent=2), encoding="utf-8"
            )
            written += 1
    return {
        "written": written,
        "removed": removed,
        "words": len(matched),
        "missing": sorted(lang_words - set(matched)),
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--src", type=Path, required=True)
    parser.add_argument("--speaker", required=True)
    parser.add_argument("--age-group", choices=["adult", "child"], required=True)
    parser.add_argument("--language", choices=["si", "en"], required=True)
    parser.add_argument(
        "--replace-speaker",
        action="append",
        default=[],
        help="also delete this earlier id's field recordings (when a speaker is renamed)",
    )
    args = parser.parse_args()
    settings = load_settings()
    words = pd.read_csv(settings["paths"]["words_csv"], dtype=str).fillna("")
    r = import_folder(
        args.src,
        args.speaker,
        args.age_group,
        args.language,
        settings,
        words,
        tuple(args.replace_speaker),
    )
    print(
        f"{args.speaker}: wrote {r['written']} references for {r['words']} words "
        f"(replaced {r['removed']}); words without a file: {r['missing'] or 'none'}"
    )


if __name__ == "__main__":
    main()
