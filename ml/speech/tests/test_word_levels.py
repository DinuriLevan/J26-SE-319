import csv
import unicodedata

import pytest

from src.settings import load_settings
from src.word_levels import english_syllables, word_level

WORDS = list(csv.DictReader(open(load_settings()["paths"]["words_csv"], encoding="utf-8")))


@pytest.mark.parametrize("row", WORDS, ids=[r["word_id"] for r in WORDS])
def test_word_list_entry_is_consistent(row):
    text = row["text_si"] or row["text_en"]
    units = row["units"].split("|")
    # Units tile the written word exactly.
    assert unicodedata.normalize("NFC", "".join(units)) == unicodedata.normalize("NFC", text)
    # The stored level is the rule-based level (src/word_levels.py), not a hand-picked one.
    assert int(row["level"]) == word_level(text, units, row["language"])


def test_each_language_has_every_level_in_order():
    for lang in ("si", "en"):
        levels = [int(r["level"]) for r in WORDS if r["language"] == lang]
        assert set(levels) == {1, 2, 3}
        assert levels == sorted(levels), f"{lang} words must be listed easiest first"


def test_word_ids_are_unique():
    ids = [r["word_id"] for r in WORDS]
    assert len(ids) == len(set(ids))


@pytest.mark.parametrize(
    "word,units,lang,level",
    [
        ("මම", ["ම", "ම"], "si", 1),
        ("බත්", ["බ", "ත්"], "si", 2),  # final hal
        ("පාට", ["පා", "ට"], "si", 2),  # long vowel
        ("ගෙදර", ["ගෙ", "ද", "ර"], "si", 2),  # three aksharas
        ("අම්මා", ["අ", "ම්මා"], "si", 3),  # double consonant
        ("පාසල්", ["පා", "ස", "ල්"], "si", 3),  # 3 aksharas + long vowel + final hal
        ("cat", ["c", "a", "t"], "en", 1),
        ("she", ["sh", "e"], "en", 2),  # letter team
        ("play", ["p", "l", "ay"], "en", 2),  # cluster + team
        ("school", ["s", "ch", "oo", "l"], "en", 3),  # sch cluster + 2 teams
        ("apple", ["a", "pp", "le"], "en", 3),  # two syllables
    ],
)
def test_level_rules(word, units, lang, level):
    assert word_level(word, units, lang) == level


def test_english_syllable_counter():
    assert [english_syllables(w) for w in ["cat", "rice", "apple", "garden", "tasty", "sky"]] == [
        1,
        1,
        2,
        2,
        2,
        1,
    ]
