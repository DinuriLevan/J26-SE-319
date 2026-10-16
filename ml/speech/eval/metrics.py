"""Evaluation metrics shared by the eval scripts."""

from __future__ import annotations

import numpy as np


def balanced_accuracy(accepted: np.ndarray, label_ok: np.ndarray) -> dict:
    """accepted / label_ok: boolean arrays per trial. Balanced accuracy = mean(TPR, TNR), where
    TPR = correct attempts accepted and TNR = wrong attempts sent to remediation."""
    accepted, label_ok = np.asarray(accepted, bool), np.asarray(label_ok, bool)
    tpr = float(accepted[label_ok].mean()) if label_ok.any() else float("nan")
    tnr = float((~accepted[~label_ok]).mean()) if (~label_ok).any() else float("nan")
    return {
        "balanced_accuracy": (tpr + tnr) / 2,
        "accept_correct": tpr,
        "reject_wrong": tnr,
        "n_correct": int(label_ok.sum()),
        "n_wrong": int((~label_ok).sum()),
    }


def best_global_threshold(scores: np.ndarray, label_ok: np.ndarray) -> float:
    """Threshold (accept if score <= t) maximising balanced accuracy on the given trials."""
    scores, label_ok = np.asarray(scores, float), np.asarray(label_ok, bool)
    candidates = np.unique(scores)
    best_t, best_ba = float(candidates[0]), -1.0
    for t in candidates:
        ba = balanced_accuracy(scores <= t, label_ok)["balanced_accuracy"]
        if ba > best_ba:
            best_t, best_ba = float(t), ba
    return best_t


def levenshtein(a: str, b: str) -> int:
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        cur = [i]
        for j, cb in enumerate(b, 1):
            cur.append(min(prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + (ca != cb)))
        prev = cur
    return prev[-1]


def normalised_edit_distance(a: str, b: str) -> float:
    return levenshtein(a, b) / max(len(a), len(b), 1)
