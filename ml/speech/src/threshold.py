"""Acceptance range learned from the reference bank itself (no hand-tuned global threshold).

Leave-one-out: each reference is scored against the OTHER references exactly as a child would be
(mean of the k nearest DTW costs). Those scores describe how far a legitimate rendition of the word
sits from the rest of the bank. A child is accepted if their aggregate <= mean + n_std * std.

With fewer than `min_refs` references the spread cannot be estimated, so the conservative global
fallback from config is used and the result is marked threshold_source = "fallback".
"""

from __future__ import annotations

from dataclasses import dataclass, field

import numpy as np

from src.scoring import score_against_references


@dataclass(frozen=True)
class AcceptanceRange:
    threshold: float
    source: str  # "bank" | "fallback"
    n_refs: int
    loo_scores: tuple[float, ...] = field(default=())
    mean: float | None = None
    std: float | None = None


def leave_one_out_scores(refs: list[dict], k: int, dtw_fn=None, unit: str = "token") -> list[float]:
    """Aggregate score of each reference against the others (k capped at the number of others).

    unit = "token" (spec): leave out just that reference.
    unit = "speaker": also leave out every other reference by the same speaker (ref["speaker"],
    falling back to ref["variant_id"]), so a bank with several takes per child is not judged
    against that child's own voice. Identical to "token" when each speaker has one reference.
    """
    scores = []
    for i, ref in enumerate(refs):
        if unit == "speaker":
            spk = ref.get("speaker", ref["variant_id"])
            others = [o for o in refs if o.get("speaker", o["variant_id"]) != spk]
        else:
            others = refs[:i] + refs[i + 1 :]
        if not others:
            continue
        k_eff = max(1, min(k, len(others)))
        agg, _ = score_against_references(ref["emb"], others, k=k_eff, dtw_fn=dtw_fn)
        scores.append(agg)
    return scores


def acceptance_range(
    refs: list[dict],
    k: int = 3,
    n_std: float = 2.0,
    min_refs: int = 4,
    fallback: float = 0.30,
    dtw_fn=None,
    loo_unit: str = "token",
) -> AcceptanceRange:
    loo = leave_one_out_scores(refs, k, dtw_fn, loo_unit) if len(refs) >= min_refs else []
    if len(loo) < min_refs:
        return AcceptanceRange(threshold=float(fallback), source="fallback", n_refs=len(refs))
    mean, std = float(np.mean(loo)), float(np.std(loo))
    return AcceptanceRange(
        threshold=mean + n_std * std,
        source="bank",
        n_refs=len(refs),
        loo_scores=tuple(loo),
        mean=mean,
        std=std,
    )
