#!/usr/bin/env python3
"""Audit the processed English-lowercase dataset without modifying images."""

from __future__ import annotations

import hashlib
import json
from collections import defaultdict
from pathlib import Path

import cv2
import matplotlib.pyplot as plt
import numpy as np


ROOT = Path(__file__).resolve().parents[1]
DATASET_DIR = ROOT / "datasets" / "processed" / "english_lowercase"
RESULTS_DIR = ROOT / "results"
REPORT_PATH = RESULTS_DIR / "lowercase_dataset_audit.json"
PREVIEW_PATH = RESULTS_DIR / "lowercase_problem_classes_preview.png"
PROBLEM_CLASSES = ("b", "d", "p", "q", "s", "c", "e")
SUPPORTED = {".png", ".jpg", ".jpeg", ".bmp", ".webp"}


def perceptual_hash(gray: np.ndarray) -> int:
    small = cv2.resize(gray, (16, 16), interpolation=cv2.INTER_AREA)
    threshold = float(np.mean(small))
    bits = (small < threshold).reshape(-1)
    value = 0
    for bit in bits:
        value = (value << 1) | int(bit)
    return value


def inspect_image(path: Path) -> dict[str, object]:
    gray = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if gray is None:
        return {"readable": False, "reason": "unreadable"}
    ink = gray < 245
    ink_fraction = float(np.mean(ink))
    points = cv2.findNonZero(ink.astype(np.uint8))
    if points is None:
        bounds = None
        edge_touch = False
    else:
        x, y, width, height = cv2.boundingRect(points)
        bounds = [int(x), int(y), int(width), int(height)]
        edge_touch = x == 0 or y == 0 or x + width >= gray.shape[1] or y + height >= gray.shape[0]
    return {
        "readable": True,
        "shape": [int(gray.shape[0]), int(gray.shape[1])],
        "ink_fraction": ink_fraction,
        "bounds": bounds,
        "edge_touch": edge_touch,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
        "phash": perceptual_hash(gray),
    }


def create_preview(files_by_class: dict[str, list[Path]]) -> None:
    rows = len(PROBLEM_CLASSES)
    columns = 10
    figure, axes = plt.subplots(rows, columns, figsize=(15, rows * 1.65))
    for row, class_name in enumerate(PROBLEM_CLASSES):
        files = files_by_class[class_name]
        indices = np.linspace(0, len(files) - 1, columns, dtype=int)
        for column, index in enumerate(indices):
            axis = axes[row, column]
            axis.imshow(cv2.imread(str(files[index]), cv2.IMREAD_GRAYSCALE), cmap="gray", vmin=0, vmax=255)
            axis.axis("off")
            if column == 0:
                axis.set_title(f"{class_name} ({len(files)})", loc="left")
    figure.tight_layout()
    figure.savefig(PREVIEW_PATH, dpi=160, bbox_inches="tight")
    plt.close(figure)


def main() -> int:
    if not DATASET_DIR.is_dir():
        raise SystemExit(f"Missing dataset: {DATASET_DIR}")
    RESULTS_DIR.mkdir(parents=True, exist_ok=True)

    files_by_class: dict[str, list[Path]] = {}
    records: list[tuple[str, Path, dict[str, object]]] = []
    for class_dir in sorted(path for path in DATASET_DIR.iterdir() if path.is_dir()):
        files = sorted(path for path in class_dir.iterdir() if path.suffix.lower() in SUPPORTED)
        files_by_class[class_dir.name] = files
        records.extend((class_dir.name, path, inspect_image(path)) for path in files)

    exact_groups: dict[str, list[tuple[str, str]]] = defaultdict(list)
    quality_issues: list[dict[str, object]] = []
    for class_name, path, record in records:
        if not record["readable"]:
            quality_issues.append({"class": class_name, "file": str(path), "reason": record["reason"]})
            continue
        exact_groups[str(record["sha256"])].append((class_name, str(path)))
        reasons: list[str] = []
        if record["shape"] != [224, 224]:
            reasons.append("unexpected_size")
        if float(record["ink_fraction"]) < 0.002:
            reasons.append("almost_blank")
        if float(record["ink_fraction"]) > 0.55:
            reasons.append("excessive_ink")
        if record["edge_touch"]:
            reasons.append("ink_touches_edge")
        if reasons:
            quality_issues.append({"class": class_name, "file": str(path), "reasons": reasons})

    duplicate_groups = [
        {"sha256": digest, "files": files, "cross_class": len({item[0] for item in files}) > 1}
        for digest, files in exact_groups.items()
        if len(files) > 1
    ]

    problem_records = [record for record in records if record[0] in PROBLEM_CLASSES and record[2]["readable"]]
    near_cross_class: list[dict[str, object]] = []
    for left_index, (left_class, left_path, left) in enumerate(problem_records):
        for right_class, right_path, right in problem_records[left_index + 1 :]:
            if left_class == right_class:
                continue
            distance = int(int(left["phash"]) ^ int(right["phash"])).bit_count()
            if distance <= 10:
                near_cross_class.append(
                    {
                        "distance": distance,
                        "left_class": left_class,
                        "left": str(left_path),
                        "right_class": right_class,
                        "right": str(right_path),
                    }
                )
    near_cross_class.sort(key=lambda item: int(item["distance"]))

    counts = {class_name: len(files) for class_name, files in files_by_class.items()}
    report = {
        "dataset": str(DATASET_DIR),
        "total": sum(counts.values()),
        "class_counts": counts,
        "minimum_class_count": min(counts.values()),
        "maximum_class_count": max(counts.values()),
        "imbalance_ratio_max_to_min": max(counts.values()) / min(counts.values()),
        "problem_class_counts": {name: counts[name] for name in PROBLEM_CLASSES},
        "quality_issues": quality_issues,
        "exact_duplicate_groups": duplicate_groups,
        "cross_class_exact_duplicate_groups": [group for group in duplicate_groups if group["cross_class"]],
        "near_cross_class_problem_pairs_hamming_le_10": near_cross_class[:200],
        "notes": [
            "Perceptual-hash matches are review candidates, not automatic relabel decisions.",
            "The audit never changes or deletes source images.",
        ],
    }
    REPORT_PATH.write_text(json.dumps(report, indent=2), encoding="utf-8")
    create_preview(files_by_class)
    print(json.dumps({
        "total": report["total"],
        "class_counts": counts,
        "quality_issues": len(quality_issues),
        "duplicate_groups": len(duplicate_groups),
        "cross_class_duplicates": len(report["cross_class_exact_duplicate_groups"]),
        "near_problem_pairs": len(near_cross_class),
        "report": str(REPORT_PATH),
        "preview": str(PREVIEW_PATH),
    }, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
