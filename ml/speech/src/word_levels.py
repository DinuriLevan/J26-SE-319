"""Rule-based difficulty levels (1 = easiest .. 3) for Grade 2-3 practice words.

TO VALIDATE WITH A TEACHER / SPEECH-LANGUAGE EXPERT: these are transparent starting rules, not a
validated reading-difficulty scale.

Sinhala (units = aksharas):
  * a double consonant or conjunct (hal kirima ් followed by another consonant inside the word,
    e.g. අම්මා, අක්කා) -> level 3
  * otherwise points = (aksharas - 2) + long vowel present + final hal (e.g. බත්):
    0 -> level 1, 1 -> level 2, >= 2 -> level 3
English (units = letter chunks, e.g. sh|e, s|ch|oo|l):
  * 2+ syllables -> level 3
  * otherwise points = letter teams (multi-letter chunks: sh, oo, ay, ...) + consonant letters at the
    start before the first vowel beyond one (sk, pl, sch):
    0 -> level 1, 1-2 -> level 2, >= 3 -> level 3
"""

from __future__ import annotations

import re

HAL = "්"
LONG_VOWELS = set("ආඈඊඌඒඕ") | set("ාෑීූේෝ")  # ආ ඈ ... ා ෑ ී ූ ේ ෝ
CONSONANT = re.compile(r"[ක-ෆ]")


def sinhala_level(word: str, units: list[str]) -> int:
    if re.search(HAL + "‍?" + CONSONANT.pattern, word):
        return 3  # double consonant / conjunct
    points = max(0, len(units) - 2)
    points += any(c in LONG_VOWELS for c in word)
    points += word.endswith(HAL)
    return 1 if points == 0 else 2 if points == 1 else 3


def english_syllables(word: str) -> int:
    w = word.lower()
    groups = len(re.findall(r"[aeiouy]+", w))
    if w.endswith("e") and not w.endswith("le") and groups > 1:
        groups -= 1  # silent final e (rice, cake)
    return max(1, groups)


def english_level(word: str, units: list[str]) -> int:
    if english_syllables(word) >= 2:
        return 3
    teams = sum(len(u) > 1 for u in units)
    onset = re.match(r"[^aeiouy]*", word.lower()).group()
    points = teams + max(0, len(onset) - 1)
    return 1 if points == 0 else 2 if points <= 2 else 3


def word_level(word: str, units: list[str], language: str) -> int:
    return sinhala_level(word, units) if language == "si" else english_level(word, units)
