import numpy as np
import pytest

from src import scoring
from src.dtw_fast import dtw, dtw_cost


@pytest.mark.parametrize("shape", [(1, 1), (1, 7), (7, 1), (5, 5), (13, 29), (40, 17)])
def test_matches_reference_on_random_costs(shape):
    rng = np.random.default_rng(sum(shape))
    for _ in range(5):
        cost = rng.random(shape)
        ref_cost, ref_path = scoring.dtw(cost)
        fast_cost, fast_path = dtw(cost)
        assert fast_cost == pytest.approx(ref_cost, rel=1e-12, abs=1e-12)
        assert fast_path == ref_path
        assert dtw_cost(cost) == pytest.approx(ref_cost, rel=1e-12, abs=1e-12)


def test_matches_reference_with_ties():
    # Integer costs create many equal accumulated values, exercising the tie-breaking order.
    rng = np.random.default_rng(1)
    for _ in range(20):
        cost = rng.integers(0, 2, size=(9, 12)).astype(float)
        assert dtw(cost) == scoring.dtw(cost)


def test_matches_reference_on_cosine_costs():
    rng = np.random.default_rng(2)
    a, b = rng.normal(size=(30, 64)), rng.normal(size=(22, 64))
    cost = scoring.cosine_cost_matrix(a, b)
    assert dtw(cost)[1] == scoring.dtw(cost)[1]
    assert dtw(cost)[0] == pytest.approx(scoring.dtw(cost)[0], rel=1e-12)
