"""Download a Twemoji picture for every practice word into the app.

The picture for each word is the emoji in the `picture` column of config/words.csv. Its Twemoji SVG
(CC-BY 4.0) is downloaded from a version-pinned CDN URL into a staging folder, checked, and copied
to app/assets/speech/pictures/<word_id>.svg, together with ATTRIBUTION.md. Re-running only fetches
what is missing (use --force to refresh everything).

Usage (from ml/speech):
    python scripts/fetch_word_pictures.py [--force]
"""

from __future__ import annotations

import argparse
import csv
import shutil
import sys
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parents[1]
sys.path.insert(0, str(ROOT))
from src.settings import load_settings  # noqa: E402

TWEMOJI_VERSION = "15.1.0"
BASE_URL = f"https://cdn.jsdelivr.net/gh/jdecked/twemoji@{TWEMOJI_VERSION}/assets/svg"
OUT_DIR = REPO / "app" / "assets" / "speech" / "pictures"
STAGING = ROOT / "data" / "pictures_staging"
MAX_BYTES = 50_000
ZWJ, VS16 = "‍", "️"

ATTRIBUTION = f"""# Word pictures

The pictures in this folder are **Twemoji** graphics, version {TWEMOJI_VERSION}
(https://github.com/jdecked/twemoji), copyright 2020 Twitter, Inc and other contributors,
licensed under **CC-BY 4.0** (https://creativecommons.org/licenses/by/4.0/).

Files are named by practice word id (see ml/speech/config/words.csv, column `picture`) and were
fetched by ml/speech/scripts/fetch_word_pictures.py. They are unmodified.
"""


def twemoji_code(emoji: str) -> str:
    """Twemoji's file name for an emoji: lower-case hex code points joined by '-'. The emoji
    variation selector U+FE0F is dropped unless the sequence contains a zero-width joiner."""
    chars = emoji if ZWJ in emoji else emoji.replace(VS16, "")
    return "-".join(f"{ord(c):x}" for c in chars)


def is_svg(data: bytes) -> bool:
    head = data[:200].lstrip().lower()
    return len(data) <= MAX_BYTES and (head.startswith(b"<svg") or head.startswith(b"<?xml"))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="re-download every picture")
    args = parser.parse_args()

    words = list(csv.DictReader(open(load_settings()["paths"]["words_csv"], encoding="utf-8")))
    STAGING.mkdir(parents=True, exist_ok=True)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    fetched, kept, failed = 0, 0, []
    for w in words:
        dest = OUT_DIR / f"{w['word_id']}.svg"
        if dest.exists() and not args.force:
            kept += 1
            continue
        if not w.get("picture"):
            failed.append(f"{w['word_id']}: no picture in words.csv")
            continue
        code = twemoji_code(w["picture"])
        staged = STAGING / f"{code}.svg"
        try:
            with urllib.request.urlopen(f"{BASE_URL}/{code}.svg", timeout=20) as resp:
                data = resp.read(MAX_BYTES + 1)
        except Exception as exc:  # network or 404
            failed.append(f"{w['word_id']} ({w['picture']} {code}): {exc}")
            continue
        if not is_svg(data):
            failed.append(f"{w['word_id']} ({code}): not a small SVG")
            continue
        staged.write_bytes(data)
        shutil.copyfile(staged, dest)
        fetched += 1
    (OUT_DIR / "ATTRIBUTION.md").write_text(ATTRIBUTION, encoding="utf-8")
    print(f"fetched {fetched}, already present {kept}, failed {len(failed)}")
    for f in failed:
        print("  FAILED", f)
    if failed:
        raise SystemExit(1)


if __name__ == "__main__":
    main()
