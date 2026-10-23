"""Rule-based mapping from a flagged unit to an error type: substitution | omission | insertion |
distortion. TO VALIDATE WITH SPEECH-LANGUAGE EXPERT (rules and ratios are starting hypotheses).

Inputs are what localisation already knows: the unit label, its mean frame cost, how many child
frames it was mapped onto, and how many frames it has in the reference. Durations are compared after
correcting for the child's overall speaking rate (tempo = child frames / reference frames).
"""

from __future__ import annotations

import re
from functools import lru_cache
from pathlib import Path

import yaml

from src.settings import SPEECH_ROOT

DEFAULT_CONFUSIONS = SPEECH_ROOT / "config" / "confusions.yaml"
GEMINATE = re.compile(r"(.)්‍?\1")  # consonant + hal kirima (්) + same consonant


@lru_cache(maxsize=4)
def load_confusions(path: Path | str = DEFAULT_CONFUSIONS) -> dict:
    with open(path, encoding="utf-8") as f:
        return yaml.safe_load(f)


def confusion_categories(label: str, confusions: dict) -> set[str]:
    cats = set()
    if any(m in label for m in confusions.get("vowel_length", {}).get("long_marks", [])):
        cats.add("vowel_length")
    if GEMINATE.search(label):
        cats.add("geminates")
    for cat in ("aspiration", "prenasalised_stops"):
        letters = {c for pair in confusions.get(cat, {}).get("pairs", []) for c in pair}
        if any(c in label for c in letters):
            cats.add(cat)
    return cats


def classify(
    label: str,
    unit_cost: float,
    child_frames: int,
    ref_frames: int,
    tempo: float,
    cfg: dict,
    confusions: dict | None = None,
) -> str:
    """cfg: settings["errors"] (omission_ratio, insertion_ratio, short_ratio, substitution_cost)."""
    confusions = load_confusions() if confusions is None else confusions
    expected = max(ref_frames * tempo, 1e-6)
    ratio = child_frames / expected
    if ratio < cfg["omission_ratio"]:
        return "omission"
    if ratio > cfg["insertion_ratio"]:
        return "insertion"
    cats = confusion_categories(label, confusions)
    if ratio < cfg["short_ratio"]:
        if "geminates" in cats:
            return "omission"
        if "vowel_length" in cats:
            return "distortion"
    if cats & {"aspiration", "prenasalised_stops"}:
        return "substitution"
    return "substitution" if unit_cost >= cfg["substitution_cost"] else "distortion"
