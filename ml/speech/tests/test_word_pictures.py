import csv
import sys
from pathlib import Path

import pytest

from src.settings import load_settings

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
from fetch_word_pictures import OUT_DIR, is_svg, twemoji_code  # noqa: E402

WORDS = list(csv.DictReader(open(load_settings()["paths"]["words_csv"], encoding="utf-8")))


@pytest.mark.parametrize(
    "emoji,code",
    [
        ("🐱", "1f431"),
        ("☀️", "2600"),  # emoji variation selector dropped
        ("✏️", "270f"),
        ("👁️", "1f441"),
        ("🏃‍♀️", "1f3c3-200d-2640-fe0f"),  # kept inside a ZWJ sequence
        ("👨‍👩‍👧", "1f468-200d-1f469-200d-1f467"),
    ],
)
def test_twemoji_file_names(emoji, code):
    assert twemoji_code(emoji) == code


def test_every_word_has_a_picture_file():
    missing = [w["word_id"] for w in WORDS if not w.get("picture")]
    assert not missing, f"words without a picture: {missing}"
    for w in WORDS:
        svg = OUT_DIR / f"{w['word_id']}.svg"
        assert svg.exists(), f"{w['word_id']} ({w['picture']}): run scripts/fetch_word_pictures.py"
        assert is_svg(svg.read_bytes())
    assert (OUT_DIR / "ATTRIBUTION.md").exists()


def test_is_svg_rejects_non_svg():
    assert is_svg(b'<svg xmlns="http://www.w3.org/2000/svg"></svg>')
    assert not is_svg(b"<html>404 Not Found</html>")
    assert not is_svg(b"<svg>" + b" " * 60_000)
