"""Checks the Sinhala game's recorded audio and lists what to record.

All Sinhala audio is recorded by a person (no text-to-speech). The game plays these files,
saved as .wav (or .m4a / .mp3) with these names:
  words    app/assets/spelling/sinhala/audio/<word_id>.wav        e.g. SI0001.wav  (පූසා)
  prompts  app/assets/spelling/sinhala/audio/prompts/<key>.wav    e.g. listen.wav  (අහන්න!)
  tiles    app/assets/spelling/sinhala/audio/tiles/<code>.wav     each letter (ප) and each akshara
           (පූ), read when a tile is tapped or the word is read akshara by akshara. Pillas have
           no sound of their own.

The prompt texts are read from the app (lib/features/spelling/sinhala/services/sinhala_voice.dart,
SinhalaPrompts.lines), so that file is the only list of prompts.

  python spell_si_audio.py               # reports missing recordings (and files no longer used)
  python spell_si_audio.py --checklist   # writes data/si_recording_list.csv to record from
"""
from __future__ import annotations

import argparse
import csv
import json
import re
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

ROOT = Path(__file__).resolve().parents[2]
SINHALA = ROOT / "app" / "assets" / "spelling" / "sinhala"
WORD_BANK = SINHALA / "sinhala_wordbank.json"
AUDIO = SINHALA / "audio"
RECORDING_TYPES = (".wav", ".m4a", ".mp3")
PROMPTS_DART = ROOT / "app" / "lib" / "features" / "spelling" / "sinhala" / "services" / "sinhala_voice.dart"
ZWJ = "‍"


def tile_key(text: str) -> str:
    """Same file name as SinhalaClip.tileKey in the app: code points, e.g. 0DCA-200D-0DBA."""
    return "-".join(f"{ord(c):04X}" for c in text)


def split_akshara(ak: str) -> tuple[str, list[str]]:
    """Base letter + pilla marks; ්‍ය and ්‍ර count as one mark (as in the app's Akshara.parse)."""
    ak = ak.strip()
    marks, i = [], 1
    while i < len(ak):
        if ak[i] == "්" and i + 2 < len(ak) and ak[i + 1] == ZWJ:
            marks.append(ak[i:i + 3])
            i += 3
        else:
            marks.append(ak[i])
            i += 1
    return ak[0], marks


def read_prompts() -> dict[str, str]:
    source = PROMPTS_DART.read_text(encoding="utf-8")
    block = source.split("static const lines", 1)[1].split("};", 1)[0]
    return dict(re.findall(r"'(\w+)':\s*'([^']*)'", block))


def is_mark(text: str) -> bool:
    """A pilla (vowel sign, hal, bindu, ්‍ය, ්‍ර): same rule as Akshara.isMark in the app."""
    c = ord(text[0])
    return c in (0x0D82, 0x0D83, 0x0DF2, 0x0DF3) or 0x0DCA <= c <= 0x0DDF


def recorded(path: Path) -> Path | None:
    """The recording for this clip (.wav, .m4a or .mp3 with the same name), if there is one."""
    for ext in RECORDING_TYPES:
        if path.with_suffix(ext).exists():
            return path.with_suffix(ext)
    return None


def jobs(only: str | None) -> list[tuple[Path, str]]:
    """(file to record, text to say) for everything the game can play."""
    words = json.loads(WORD_BANK.read_text(encoding="utf-8"))
    out: list[tuple[Path, str]] = []
    if only in (None, "words"):
        out += [(AUDIO / f"{w['word_id']}.wav", w["word"].strip()) for w in words]
    if only in (None, "prompts"):
        out += [(AUDIO / "prompts" / f"{k}.wav", t) for k, t in read_prompts().items()]
    if only in (None, "tiles"):
        tiles: dict[str, str] = {}
        for w in words:
            for ak in w["aksharas"].split("|"):
                if not ak.strip():
                    continue
                base, _ = split_akshara(ak)
                tiles.setdefault(base, base)                          # the letter's sound
                tiles.setdefault(ak.strip(), ak.strip())               # the akshara's sound
            for d in w.get("confusable_distractors", "").split():      # look-alike tray letters
                if not is_mark(d):
                    tiles.setdefault(d, d)
        out += [(AUDIO / "tiles" / f"{tile_key(t)}.wav", say) for t, say in tiles.items()]
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--only", choices=["words", "prompts", "tiles"])
    ap.add_argument("--checklist", action="store_true",
                    help="write data/si_recording_list.csv: every file name and what to say")
    args = ap.parse_args()

    items = jobs(args.only)
    if args.checklist:
        write_checklist(items)
        return

    missing = [(path, text) for path, text in items if recorded(path) is None]
    needed = {path.with_suffix("") for path, _ in items}
    unused = [f for f in AUDIO.rglob("*") if f.suffix in RECORDING_TYPES and f.with_suffix("") not in needed]
    print(f"{len(items) - len(missing)} of {len(items)} recordings found.")
    for path, text in missing:
        print(f"  missing  {path.relative_to(SINHALA).as_posix()}  ({text})")
    if args.only is None:
        for f in unused:
            print(f"  not used {f.relative_to(SINHALA).as_posix()}")
    if not missing:
        print("All recordings are there. Rebuild the app (flutter run) to include new ones.")


def write_checklist(items: list[tuple[Path, str]]) -> None:
    """A list to record from: folder, file name, the Sinhala to say, and what exists already."""
    out = Path(__file__).resolve().parent / "data" / "si_recording_list.csv"
    with open(out, "w", encoding="utf-8-sig", newline="") as f:   # utf-8-sig: Excel shows Sinhala
        writer = csv.writer(f)
        writer.writerow(["folder", "file_name", "say_this", "now"])
        for path, text in items:
            folder = path.parent.relative_to(SINHALA).as_posix()
            have = recorded(path)
            now = "missing" if have is None else "recorded"
            writer.writerow([folder, path.stem, text, now])
    print(f"Wrote {out} ({len(items)} lines). Open it in Excel and record from it.")


if __name__ == "__main__":
    main()
