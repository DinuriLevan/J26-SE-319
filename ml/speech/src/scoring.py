"""Core scoring logic for the reference-voice pronunciation component (numpy only).

Embeddings are (T, D) arrays: one vector per ~20 ms frame from a wav2vec2/XLS-R layer.
"""

import numpy as np


def cosine_cost_matrix(a: np.ndarray, b: np.ndarray) -> np.ndarray:
    """Pairwise cosine DISTANCE between frames of a (Ta, D) and b (Tb, D)."""
    a_n = a / (np.linalg.norm(a, axis=1, keepdims=True) + 1e-8)
    b_n = b / (np.linalg.norm(b, axis=1, keepdims=True) + 1e-8)
    return 1.0 - a_n @ b_n.T


def dtw(cost: np.ndarray):
    """Classic DTW on a cost matrix. Returns (normalised_cost, path[list of (i, j)])."""
    n, m = cost.shape
    acc = np.full((n + 1, m + 1), np.inf)
    acc[0, 0] = 0.0
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            acc[i, j] = cost[i - 1, j - 1] + min(acc[i - 1, j], acc[i, j - 1], acc[i - 1, j - 1])
    # backtrack
    i, j, path = n, m, []
    while i > 0 and j > 0:
        path.append((i - 1, j - 1))
        step = int(np.argmin([acc[i - 1, j - 1], acc[i - 1, j], acc[i, j - 1]]))
        if step == 0:
            i, j = i - 1, j - 1
        elif step == 1:
            i -= 1
        else:
            j -= 1
    path.reverse()
    return acc[n, m] / len(path), path


def score_against_references(child_emb, refs, k=3):
    """refs: list of dicts {emb, age_group, variant_id}. Returns per-reference results and
    an aggregate = mean of the k smallest DTW costs (robust to one odd reference)."""
    results = []
    for r in refs:
        c, path = dtw(cosine_cost_matrix(child_emb, r["emb"]))
        results.append(
            {"variant_id": r["variant_id"], "age_group": r["age_group"], "cost": c, "path": path}
        )
    results.sort(key=lambda x: x["cost"])
    agg = float(np.mean([x["cost"] for x in results[:k]]))
    return agg, results


def localise(child_len, best, ref_segments):
    """Project reference segment boundaries (in reference frames) onto the child's frames via the
    DTW path, then score each segment by the mean frame cost along that part of the path.
    ref_segments: list of (label, ref_start_frame, ref_end_frame). `best` is one entry of
    score_against_references' results plus the cost matrix under key 'frame_cost'."""
    path = best["path"]
    frame_cost = best["frame_cost"]  # (Tchild, Tref)
    out = []
    for label, rs, re_ in ref_segments:
        pts = [(i, j) for i, j in path if rs <= j < re_]
        if not pts:
            out.append({"label": label, "cost": float("nan"), "child_span": None})
            continue
        cost = float(np.mean([frame_cost[i, j] for i, j in pts]))
        ci = [i for i, _ in pts]
        out.append({"label": label, "cost": cost, "child_span": (min(ci), max(ci))})
    return out
