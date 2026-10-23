"""Dev/test split guard. Anything that chooses layer, k, n or thresholds must use dev rows only.

The split is by speaker (child), so no test child's voice is ever seen while tuning.
"""

from __future__ import annotations

from typing import Iterable


class SplitLeakError(RuntimeError):
    """Raised when tuning code is handed test-split data."""


def assert_dev_only(splits: Iterable[str], purpose: str) -> None:
    bad = {s for s in splits if s != "dev"}
    if bad:
        raise SplitLeakError(
            f"{purpose} must use dev data only, but got split(s) {sorted(bad)}. "
            "Test speakers are reserved for the final evaluation."
        )
