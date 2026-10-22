"""Shared paths, column names and helpers for the spelling difficulty pipeline.

Everything here mirrors the Flutter app (app/lib/features/spelling/...), so
simulated data, training and the in-app classifier use the same definitions.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import pandas as pd

# Windows consoles default to cp1252; results contain ±, −, →.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")

HERE = Path(__file__).resolve().parent
DATA = HERE / "data"
RESULTS = HERE / "results"
REPO = HERE.parent.parent
APP = REPO / "app"
WORD_BANK = APP / "assets" / "spelling" / "english_wordbank.csv"

# Where spell_export.py writes the model for the app.
APP_MODEL_DART = APP / "lib" / "features" / "spelling" / "model" / "difficulty_model_m2cgen.dart"
APP_MODEL_ASSETS = APP / "assets" / "spelling" / "model"
APP_PARITY_FIXTURE = APP / "test" / "features" / "spelling" / "fixtures" / "difficulty_parity.json"

SIM_BANNER = "SIMULATED DATA — pipeline validation only. Final results will come from pilot data."
PILOT_BANNER = "PILOT DATA — results from real children."

CLASSES = ["easy", "medium", "hard"]

# Same order as FeatureRow.columns in feature_extractor.dart (the app's
# features CSV export). The app may add extra columns at the end.
FEATURE_COLUMNS = [
    "childId", "sessionId", "roundNo", "wordIndex", "word_id", "word", "phonics_skill",
    "skill_stage", "difficulty", "timestamp", "mode", "use_behaviour",
    "first_input_ms", "total_ms", "mean_gap_ms", "max_gap_ms", "paused_ms", "replays", "motor_slips",
    "corrections", "n_insertions", "n_deletions", "n_replacements", "n_reorders", "distractor_picks",
    "answer_length_diff", "attempts", "correct_first_try", "final_correct", "hesitation_ratio",
    "pause_ratio", "first_wrong_answer", "edit_distance",
    "reversal", "vowel_sub", "other_sub", "omission", "insertion", "transposition",
    "target_grapheme_error", "evidence_weight", "p_before", "p_after",
]
ERROR_TYPES = ["reversal", "vowel_sub", "other_sub", "omission", "insertion", "transposition"]
BOOL_COLUMNS = ["use_behaviour", "correct_first_try", "final_correct", "target_grapheme_error"]


def banner_for(dataset_path: str | Path) -> str:
    """Simulated files are named sim_*.csv; anything else is pilot data."""
    return SIM_BANNER if Path(dataset_path).name.startswith("sim_") else PILOT_BANNER


def load_word_bank() -> pd.DataFrame:
    wb = pd.read_csv(WORD_BANK, encoding="utf-8-sig", keep_default_na=False)
    wb["spelling"] = wb["word"].str.lower()
    wb["skill_stage"] = wb["skill_stage"].astype(int)
    wb["difficulty"] = pd.to_numeric(wb["difficulty"], errors="coerce").fillna(1).astype(int)
    return wb


def skill_order(wb: pd.DataFrame) -> list[str]:
    """Skills in the app's teaching order: stage 0 (sight words), 1 … 8; CSV
    order within a stage (WordBank.skillOrder in word_bank.dart)."""
    first_seen = {}
    for i, s in enumerate(wb["phonics_skill"]):
        first_seen.setdefault(s, i)
    stage = dict(zip(wb["phonics_skill"], wb["skill_stage"]))
    return sorted(first_seen, key=lambda s: (stage[s], first_seen[s]))


def read_features_csv(path: str | Path) -> pd.DataFrame:
    """Reads the app's (or the simulator's) features CSV."""
    df = pd.read_csv(path, comment="#", keep_default_na=True)
    for c in BOOL_COLUMNS:
        if c in df.columns:
            df[c] = df[c].map(lambda v: str(v).strip().lower() == "true").astype(bool)
    return df


def write_csv_with_banner(df: pd.DataFrame, path: Path, banner: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="") as f:
        f.write(f"# {banner}\n")
        df.to_csv(f, index=False)


def write_json(obj, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, indent=2, ensure_ascii=False), encoding="utf-8")


# --------------------------------------------------------------- BKT (port)
# Mirrors spelling_config.dart / learner_model.dart.
P_LEARN = 0.05
P_SLIP = 0.10
P_GUESS_SCALE = 1.2
FLUENT_HESITATION = 1.2
W_FLUENT, W_HESITANT, W_SECOND, W_THIRD = 1.0, 0.6, 0.25, 0.1
W_OFF_TARGET_SOLVED, W_OFF_TARGET_FAILED = 0.6, 0.3
DEFAULT_MEDIAN_MS = 3000.0
MIN_WORDS_FOR_MEDIAN = 5


def p_guess(letters: int) -> float:
    base = 0.35 if letters <= 3 else (0.25 if letters == 4 else 0.15)
    return min(0.9, max(0.01, base * P_GUESS_SCALE))


def bayes(p: float, correct: bool, guess: float, slip: float = P_SLIP) -> float:
    if correct:
        return p * (1 - slip) / (p * (1 - slip) + (1 - p) * guess)
    return p * slip / (p * slip + (1 - p) * (1 - guess))


def bkt_update(p: float, w: float, letters: int) -> float:
    g = p_guess(letters)
    post = w * bayes(p, True, g) + (1 - w) * bayes(p, False, g)
    return post + (1 - post) * P_LEARN


def evidence_weight(row: dict) -> float:
    """LearnerModel.evidenceWeight with "use behaviour" on."""
    if row["correct_first_try"]:
        fluent = row["hesitation_ratio"] < FLUENT_HESITATION and row["corrections"] <= 1
        return W_FLUENT if fluent else W_HESITANT
    if row["first_wrong_answer"] and not row["target_grapheme_error"]:
        return W_OFF_TARGET_SOLVED if row["final_correct"] else W_OFF_TARGET_FAILED
    if not row["final_correct"]:
        return 0.0
    return W_SECOND if row["attempts"] <= 2 else W_THIRD


def median_or_default(values: list[float]) -> float:
    if len(values) < MIN_WORDS_FOR_MEDIAN:
        return DEFAULT_MEDIAN_MS
    m = float(np.median(values))
    return m if m > 0 else DEFAULT_MEDIAN_MS


# ------------------------------------------------------------ Sinhala (--lang si)
# Mirrors app/lib/features/spelling/sinhala/ (word bank, sinhala_features.dart,
# sinhala_learner.dart). English keeps everything above unchanged.
SI_WORD_BANK = APP / "assets" / "spelling" / "sinhala" / "sinhala_wordbank.json"
SI_SKILLS = APP / "assets" / "spelling" / "sinhala" / "sinhala_skills.json"
SI_ERROR_TYPES = ["pilla_missing", "pilla_wrong", "pilla_length", "hal", "lookalike", "other_letter",
                  "missing", "extra", "order"]
SI_FEATURE_COLUMNS = [
    "childId", "sessionId", "roundNo", "wordIndex", "word_id", "word", "phonics_skill",
    "skill_stage", "difficulty", "timestamp", "mode",
    "first_input_ms", "total_ms", "mean_gap_ms", "max_gap_ms", "paused_ms", "replays", "motor_slips",
    "corrections", "n_insertions", "n_deletions", "n_replacements", "n_reorders", "distractor_picks",
    "answer_length_diff", "attempts", "correct_first_try", "final_correct", "hesitation_ratio",
    "pause_ratio", "first_wrong_answer", "edit_distance", *SI_ERROR_TYPES,
    "n_aksharas", "n_marks", "evidence_weight", "p_before", "p_after",
]
ZWJ = "‍"
HAL = "්"
# Short <-> long pillas, and letters children confuse (same lists as sinhala_errors.dart).
SI_LENGTH_PAIRS = {"ි": "ී", "ී": "ි", "ු": "ූ", "ූ": "ු",
                   "ැ": "ෑ", "ෑ": "ැ", "ෙ": "ේ", "ේ": "ෙ",
                   "ො": "ෝ", "ෝ": "ො"}
SI_CONFUSABLE_GROUPS = ["කඛ", "ගඝඟ", "චඡ", "ජඣ", "ටඨ", "ඩඪඬ", "තථ", "දධඳ", "පඵ", "බභඹ", "මඹ",
                        "නණ", "ලළ", "සශෂ", "අආ", "ඇඈ", "ඉඊ", "උඌ", "එඒ", "ඔඕ"]

LANGS = {
    "en": {
        "model_dart": APP_MODEL_DART, "assets": APP_MODEL_ASSETS, "fixture": APP_PARITY_FIXTURE,
        "score_fn": "difficultyModelScore", "best": "best_model.json", "prefix": "",
        "parity_test": "test/features/spelling/difficulty_parity_test.dart",
    },
    "si": {
        "model_dart": APP / "lib" / "features" / "spelling" / "sinhala" / "model" / "difficulty_model_si_m2cgen.dart",
        "assets": APP / "assets" / "spelling" / "model_si",
        "fixture": APP / "test" / "features" / "spelling" / "fixtures" / "difficulty_parity_si.json",
        "score_fn": "difficultyModelScoreSi", "best": "si_best_model.json", "prefix": "si_",
        "parity_test": "test/features/spelling/difficulty_parity_si_test.dart",
    },
}


def split_akshara(ak: str) -> tuple[str, list[str]]:
    """Base letter + pilla marks; ්‍ය and ්‍ර are one mark (Akshara.parse in the app)."""
    ak = ak.strip()
    marks, i = [], 1
    while i < len(ak):
        if ak[i] == HAL and i + 2 < len(ak) and ak[i + 1] == ZWJ:
            marks.append(ak[i:i + 3])
            i += 3
        else:
            marks.append(ak[i])
            i += 1
    return ak[0], marks


def mark_order(m: str) -> int:
    if len(m) == 3:
        return 0
    return 2 if m in ("ං", "ඃ") else 1


def compose(base: str, marks: list[str]) -> str:
    return base + "".join(sorted(marks, key=mark_order))


def load_si_word_bank() -> pd.DataFrame:
    rows = json.loads(SI_WORD_BANK.read_text(encoding="utf-8"))
    df = pd.DataFrame(rows)
    df["phonics_skill"] = df["primary_skill"]
    df["skill_stage"] = df["skill_stage"].astype(int)
    df["difficulty"] = pd.to_numeric(df["difficulty"], errors="coerce").fillna(1).astype(int)
    df["akshara_list"] = df["aksharas"].map(lambda s: [split_akshara(a) for a in s.split("|") if a.strip()])
    return df


def si_skill_order() -> list[str]:
    stages = json.loads(SI_SKILLS.read_text(encoding="utf-8"))["stages"]
    return [s["skill"] for s in sorted(stages, key=lambda s: s["stage"])]


def si_p_guess(aksharas: int) -> float:
    """Guess chance by number of aksharas (SinhalaLearner.pGuess in the app)."""
    base = 0.35 if aksharas <= 2 else (0.25 if aksharas == 3 else 0.15)
    return min(0.9, max(0.01, base * P_GUESS_SCALE))


def si_bkt_update(p: float, w: float, aksharas: int) -> float:
    g = si_p_guess(aksharas)
    post = w * bayes(p, True, g) + (1 - w) * bayes(p, False, g)
    return post + (1 - post) * P_LEARN


def si_evidence_weight(row: dict) -> float:
    """SinhalaLearner.evidenceWeight: how much a word counts as 'knows it'."""
    if row["correct_first_try"]:
        fluent = row["hesitation_ratio"] < FLUENT_HESITATION and row["corrections"] <= 1
        return W_FLUENT if fluent else W_HESITANT
    if not row["final_correct"]:
        return 0.0
    return W_SECOND if row["attempts"] <= 2 else W_THIRD
