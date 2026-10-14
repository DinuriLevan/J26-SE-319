"""Load config/settings.yaml. Relative paths are resolved against ml/speech/."""

from __future__ import annotations

from pathlib import Path
from typing import Any

import yaml

SPEECH_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_SETTINGS = SPEECH_ROOT / "config" / "settings.yaml"


def load_settings(path: Path | str = DEFAULT_SETTINGS) -> dict[str, Any]:
    with open(path, encoding="utf-8") as f:
        settings = yaml.safe_load(f)
    for key, value in settings.get("paths", {}).items():
        p = Path(value)
        settings["paths"][key] = p if p.is_absolute() else SPEECH_ROOT / p
    return settings
