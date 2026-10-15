"""numba-JIT DTW with the same recurrence, tie-breaking and path normalisation as src/scoring.dtw.

tests/test_dtw_fast.py checks the results are identical to the pure-Python reference.
"""

from __future__ import annotations

import numpy as np
from numba import njit


@njit(cache=True)
def _dtw(cost):
    n, m = cost.shape
    acc = np.full((n + 1, m + 1), np.inf)
    acc[0, 0] = 0.0
    for i in range(1, n + 1):
        for j in range(1, m + 1):
            acc[i, j] = cost[i - 1, j - 1] + min(acc[i - 1, j], acc[i, j - 1], acc[i - 1, j - 1])
    # Backtrack with the reference's preference order on ties: diagonal, up, left.
    path = np.empty((n + m, 2), dtype=np.int64)
    i, j, k = n, m, 0
    while i > 0 and j > 0:
        path[k, 0] = i - 1
        path[k, 1] = j - 1
        k += 1
        d, u, l = acc[i - 1, j - 1], acc[i - 1, j], acc[i, j - 1]
        if d <= u and d <= l:
            i -= 1
            j -= 1
        elif u <= l:
            i -= 1
        else:
            j -= 1
    return acc[n, m] / k, path[:k][::-1]


def dtw(cost: np.ndarray):
    """Drop-in for src.scoring.dtw: (normalised_cost, path[list of (i, j)])."""
    c, path = _dtw(np.ascontiguousarray(cost, dtype=np.float64))
    return float(c), [(int(i), int(j)) for i, j in path]


def dtw_cost(cost: np.ndarray) -> float:
    """Normalised cost only (skips building the Python path list)."""
    return float(_dtw(np.ascontiguousarray(cost, dtype=np.float64))[0])
