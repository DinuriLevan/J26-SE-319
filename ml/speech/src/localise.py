"""Unit-level localisation (spec step 6), used only when an attempt is not accepted.

Take the best-matching reference that has unit boundaries, project its units through the DTW path
onto the child's frames (src.scoring.localise), score each unit by its mean frame cost, flag the
worst unit, and also flag the second worst when its cost is close to the worst. Flagged units get
an error type from src.errors.
"""

from __future__ import annotations

from src.errors import classify
from src.scoring import cosine_cost_matrix, localise

FRAME_S = 0.02  # wav2vec2/XLS-R frame hop


def unit_frames(
    units: list[dict], n_frames: int, min_frames: int = 1
) -> list[tuple[str, int, int]]:
    """Reference units in seconds -> contiguous (label, start_frame, end_frame) covering 0..n_frames.

    Boundaries are rounded to frames, kept strictly increasing with at least `min_frames` per unit
    where the reference is long enough, and the outer edges are stretched to cover every frame.
    """
    k = len(units)
    if k == 0 or n_frames < k:
        return []
    min_frames = max(1, min(min_frames, n_frames // k))
    cuts = [round(u["start_s"] / FRAME_S) for u in units[1:]]
    bounds = [0]
    for i, c in enumerate(cuts, start=1):
        lo = bounds[-1] + min_frames
        hi = n_frames - (k - i) * min_frames
        bounds.append(min(max(c, lo), hi))
    bounds.append(n_frames)
    return [(u["label"], bounds[i], bounds[i + 1]) for i, u in enumerate(units)]


def localise_attempt(
    child_emb,
    ref: dict,
    path: list[tuple[int, int]],
    settings: dict,
) -> list[dict]:
    """Segments in the API shape: label, start_s, end_s (child timeline), status, cost, error_type.

    ref: {"emb", "units"} of the best-matching reference; path: its DTW path against the child.
    """
    loc_cfg, err_cfg = settings["localisation"], settings["errors"]
    segs = unit_frames(ref["units"], len(ref["emb"]), loc_cfg.get("min_unit_frames", 2))
    if not segs:
        return []
    frame_cost = cosine_cost_matrix(child_emb, ref["emb"])
    loc = localise(len(child_emb), {"path": path, "frame_cost": frame_cost}, segs)
    tempo = len(child_emb) / len(ref["emb"])

    order = sorted(range(len(loc)), key=lambda i: loc[i]["cost"], reverse=True)
    flagged = {order[0]}
    if loc_cfg["max_flagged_units"] >= 2 and len(order) > 1:
        if loc[order[1]]["cost"] >= loc_cfg["second_flag_ratio"] * loc[order[0]]["cost"]:
            flagged.add(order[1])

    out = []
    for i, ((label, rs, re_), seg) in enumerate(zip(segs, loc)):
        c0, c1 = seg["child_span"]
        child_frames = c1 - c0 + 1
        is_flagged = i in flagged
        out.append(
            {
                "label": label,
                "start_s": round(c0 * FRAME_S, 3),
                "end_s": round((c1 + 1) * FRAME_S, 3),
                "status": "flagged" if is_flagged else "ok",
                "cost": round(seg["cost"], 4),
                "error_type": (
                    classify(label, seg["cost"], child_frames, re_ - rs, tempo, err_cfg)
                    if is_flagged
                    else None
                ),
            }
        )
    return out
