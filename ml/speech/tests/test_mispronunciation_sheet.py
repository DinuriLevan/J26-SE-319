"""eval/mispronunciations.csv and the study's file-name parsing (no audio)."""

import csv
import sys
import unicodedata
from pathlib import Path

import pytest

from src.settings import load_settings

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "eval"))
from mispronunciation_study_dev import SHEET, parse_name  # noqa: E402

WORDS = {r["word_id"]: r for r in csv.DictReader(open(load_settings()["paths"]["words_csv"], encoding="utf-8"))}
ROWS = list(csv.DictReader(open(SHEET, encoding="utf-8")))


def test_sheet_has_one_mispronunciation_per_practice_word():
    assert sorted(r["word_id"] for r in ROWS) == sorted(WORDS)
    for r in ROWS:
        w = WORDS[r["word_id"]]
        assert unicodedata.normalize("NFC", r["word"]) == (w["text_si"] or w["text_en"]).lower()
        assert r["said"] and r["said"] != r["word"] and r["category"]


@pytest.mark.parametrize(
    "name,parsed",
    [
        ("cat__cut.WAV", ("cat", "cut")),
        ("අම්මා__අමා.WAV", ("අම්මා", "අමා")),
        ("ගස __කස (1).WAV", ("ගස", "කස")),
        ("පුසා__පුසා.WAV", ("පූසා", "පුසා")),  # aliases fix the word, never what was said
    ],
)
def test_parse_name(name, parsed):
    assert parse_name(name) == parsed


def test_parse_name_needs_the_separator():
    with pytest.raises(ValueError):
        parse_name("cat.WAV")
