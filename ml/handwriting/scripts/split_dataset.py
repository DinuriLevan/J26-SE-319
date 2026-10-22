#!/usr/bin/env python3
"""Create reproducible train/validation/test splits for handwriting datasets.

Images are copied from datasets/processed; the source tree is never changed.
Byte-identical images within a class are grouped by SHA-256 so they cannot be
assigned to different splits.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import random
import shutil
import sys
import uuid
from collections import defaultdict
from pathlib import Path
from typing import Iterable, Sequence


HANDWRITING_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_INPUT = HANDWRITING_ROOT / "datasets" / "processed"
DEFAULT_OUTPUT = HANDWRITING_ROOT / "datasets" / "split"
DEFAULT_REPORT = HANDWRITING_ROOT / "results" / "dataset_split_report.json"
SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".webp"}
SPLIT_NAMES = ("train", "val", "test")
SMALL_CLASS_THRESHOLD = 10
MARKER_NAME = ".akurin_split_dataset.json"


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Split processed handwriting images by class."
    )
    parser.add_argument("--train", type=float, default=0.70)
    parser.add_argument("--val", type=float, default=0.15)
    parser.add_argument("--test", type=float, default=0.15)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT)
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT)
    parser.add_argument(
        "--force",
        action="store_true",
        help="Replace a non-empty output directory not created by this script.",
    )
    return parser.parse_args(argv)


def validate_ratios(ratios: Sequence[float]) -> None:
    if any(value <= 0 or value >= 1 for value in ratios):
        raise ValueError("--train, --val and --test must each be between 0 and 1.")
    if not math.isclose(sum(ratios), 1.0, rel_tol=0.0, abs_tol=1e-9):
        raise ValueError(
            "--train + --val + --test must equal 1.0 "
            f"(received {sum(ratios):.10g})."
        )


def _is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def validate_paths(input_dir: Path, output_dir: Path) -> tuple[Path, Path]:
    input_dir = input_dir.resolve()
    output_dir = output_dir.resolve()
    if not input_dir.is_dir():
        raise ValueError(f"Processed dataset directory does not exist: {input_dir}")
    if input_dir == output_dir:
        raise ValueError("Input and output directories must be different.")
    if _is_relative_to(output_dir, input_dir) or _is_relative_to(input_dir, output_dir):
        raise ValueError("Input and output directories must not contain one another.")
    if output_dir == output_dir.anchor or output_dir.parent == output_dir:
        raise ValueError("Refusing to use a filesystem root as the output directory.")
    return input_dir, output_dir


def discover_datasets(input_dir: Path) -> list[tuple[Path, list[Path]]]:
    datasets: list[tuple[Path, list[Path]]] = []
    for dataset_dir in sorted((p for p in input_dir.iterdir() if p.is_dir()), key=lambda p: p.name):
        classes = sorted((p for p in dataset_dir.iterdir() if p.is_dir()), key=lambda p: p.name)
        if classes:
            datasets.append((dataset_dir, classes))
    if not datasets:
        raise ValueError(f"No dataset/class folders were found below: {input_dir}")
    return datasets


def image_files(class_dir: Path) -> list[Path]:
    return sorted(
        (
            path
            for path in class_dir.iterdir()
            if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS
        ),
        key=lambda path: path.name,
    )


def file_sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def target_counts(total: int, ratios: Sequence[float]) -> list[int]:
    """Use largest-remainder rounding while keeping all counts additive."""
    exact = [total * ratio for ratio in ratios]
    counts = [math.floor(value) for value in exact]
    remaining = total - sum(counts)
    order = sorted(
        range(len(ratios)),
        key=lambda index: (-(exact[index] - counts[index]), index),
    )
    for index in order[:remaining]:
        counts[index] += 1

    # When possible, ensure even a very small class has an example in every set.
    if total >= len(ratios):
        for empty_index in [i for i, count in enumerate(counts) if count == 0]:
            donor = max(range(len(counts)), key=lambda i: counts[i])
            if counts[donor] > 1:
                counts[donor] -= 1
                counts[empty_index] += 1
    return counts


def stable_class_seed(seed: int, dataset: str, class_name: str) -> int:
    value = f"{seed}\0{dataset}\0{class_name}".encode("utf-8")
    return int.from_bytes(hashlib.sha256(value).digest()[:8], "big")


def assign_groups(
    files: Sequence[Path], ratios: Sequence[float], seed: int
) -> tuple[dict[str, list[Path]], int, int]:
    by_hash: dict[str, list[Path]] = defaultdict(list)
    for path in files:
        by_hash[file_sha256(path)].append(path)

    groups = list(by_hash.values())
    rng = random.Random(seed)
    rng.shuffle(groups)
    # Place large duplicate families first; stable sort retains the shuffled order
    # between equally sized groups.
    groups.sort(key=len, reverse=True)

    targets = target_counts(len(files), ratios)
    counts = [0, 0, 0]
    assigned = {name: [] for name in SPLIT_NAMES}
    for group in groups:
        size = len(group)

        def placement_key(index: int) -> tuple[float, float, int]:
            projected = counts.copy()
            projected[index] += size
            total_error = sum(abs(projected[i] - targets[i]) for i in range(3))
            remaining_capacity = targets[index] - counts[index]
            return (total_error, -remaining_capacity, index)

        chosen = min(range(3), key=placement_key)
        assigned[SPLIT_NAMES[chosen]].extend(group)
        counts[chosen] += size

    duplicate_groups = sum(1 for group in groups if len(group) > 1)
    largest_group = max((len(group) for group in groups), default=0)
    return assigned, duplicate_groups, largest_group


def class_warnings(dataset: str, class_name: str, counts: dict[str, int]) -> list[str]:
    warnings: list[str] = []
    total = counts["total"]
    label = f"{dataset}/{class_name}"
    if total < SMALL_CLASS_THRESHOLD:
        warnings.append(
            f"Class {label} only contains {total} image(s); estimates may be unreliable."
        )
    empty_splits = [name for name in SPLIT_NAMES if counts[name] == 0]
    if total and empty_splits:
        warnings.append(
            f"Class {label} has no image in: {', '.join(empty_splits)}."
        )
    if total == 0:
        warnings.append(f"Class {label} contains no supported images.")
    return warnings


def verify_assignment(files: Sequence[Path], assigned: dict[str, list[Path]]) -> None:
    source_paths = {path.resolve() for path in files}
    split_sets = {
        name: {path.resolve() for path in assigned[name]} for name in SPLIT_NAMES
    }
    if any(split_sets[a] & split_sets[b] for a, b in (("train", "val"), ("train", "test"), ("val", "test"))):
        raise RuntimeError("Validation failed: a source file was assigned to multiple splits.")
    if set().union(*split_sets.values()) != source_paths:
        raise RuntimeError("Validation failed: assigned files do not match source files.")


def verify_copied_class(
    staging_dir: Path,
    dataset_name: str,
    class_name: str,
    assigned: dict[str, list[Path]],
) -> None:
    """Check the files actually written to disk, not only the assignment lists."""
    actual_names: dict[str, set[str]] = {}
    for split_name in SPLIT_NAMES:
        destination = staging_dir / dataset_name / split_name / class_name
        actual_names[split_name] = {
            path.name
            for path in destination.iterdir()
            if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS
        }
        expected_names = {path.name for path in assigned[split_name]}
        if actual_names[split_name] != expected_names:
            raise RuntimeError(
                f"Copy validation failed for {dataset_name}/{class_name}/{split_name}."
            )
    if any(
        actual_names[a] & actual_names[b]
        for a, b in (("train", "val"), ("train", "test"), ("val", "test"))
    ):
        raise RuntimeError(
            f"Output validation failed: duplicate filename across splits for "
            f"{dataset_name}/{class_name}."
        )


def build_split(
    input_dir: Path,
    staging_dir: Path,
    ratios: Sequence[float],
    seed: int,
) -> dict:
    report: dict = {
        "seed": seed,
        "ratios": dict(zip(SPLIT_NAMES, ratios)),
        "source_directory": str(input_dir),
        "total_images": 0,
        "total_train": 0,
        "total_validation": 0,
        "total_test": 0,
        "datasets": {},
        "warnings": [],
        "leakage_prevention": {
            "method": "SHA-256 exact-content grouping within each class",
            "exact_duplicate_groups": 0,
            "limitation": (
                "Processed filenames are sequential and do not retain original/augmentation "
                "family identifiers. Byte-identical files are kept together, but visually "
                "related augmented variants cannot be linked reliably from these filenames."
            ),
        },
        "validation": {
            "counts_match_source": True,
            "no_source_file_overlap": True,
        },
    }

    for dataset_dir, class_dirs in discover_datasets(input_dir):
        dataset_name = dataset_dir.name
        dataset_report = {
            "total": 0,
            "train": 0,
            "val": 0,
            "test": 0,
            "classes": {},
        }
        for class_dir in class_dirs:
            files = image_files(class_dir)
            assigned, duplicate_groups, largest_group = assign_groups(
                files,
                ratios,
                stable_class_seed(seed, dataset_name, class_dir.name),
            )
            verify_assignment(files, assigned)

            counts = {
                "total": len(files),
                **{name: len(assigned[name]) for name in SPLIT_NAMES},
            }
            if counts["train"] + counts["val"] + counts["test"] != counts["total"]:
                raise RuntimeError(f"Count validation failed for {dataset_name}/{class_dir.name}")

            for split_name in SPLIT_NAMES:
                destination = staging_dir / dataset_name / split_name / class_dir.name
                destination.mkdir(parents=True, exist_ok=True)
                for source in assigned[split_name]:
                    shutil.copy2(source, destination / source.name)
            verify_copied_class(
                staging_dir, dataset_name, class_dir.name, assigned
            )

            warnings = class_warnings(dataset_name, class_dir.name, counts)
            report["warnings"].extend(warnings)
            dataset_report["classes"][class_dir.name] = {
                **counts,
                "exact_duplicate_groups": duplicate_groups,
                "largest_exact_duplicate_group": largest_group,
            }
            for key in ("total", "train", "val", "test"):
                dataset_report[key] += counts[key]
            report["leakage_prevention"]["exact_duplicate_groups"] += duplicate_groups

        report["datasets"][dataset_name] = dataset_report
        report["total_images"] += dataset_report["total"]
        report["total_train"] += dataset_report["train"]
        report["total_validation"] += dataset_report["val"]
        report["total_test"] += dataset_report["test"]

    copied_total = report["total_train"] + report["total_validation"] + report["total_test"]
    if copied_total != report["total_images"]:
        raise RuntimeError("Global validation failed: split counts do not match source total.")
    return report


def directory_is_empty(path: Path) -> bool:
    return not path.exists() or not any(path.iterdir())


def publish_split(staging_dir: Path, output_dir: Path, force: bool) -> None:
    if output_dir.exists() and not directory_is_empty(output_dir):
        marker = output_dir / MARKER_NAME
        if not marker.is_file() and not force:
            raise ValueError(
                f"Output directory is non-empty and was not created by this script: {output_dir}. "
                "Choose another --output or pass --force to replace it."
            )

    backup_dir = output_dir.with_name(f".{output_dir.name}.backup")
    if backup_dir.exists():
        raise ValueError(f"Cannot publish while stale backup exists: {backup_dir}")

    output_dir.parent.mkdir(parents=True, exist_ok=True)
    had_output = output_dir.exists()
    try:
        if had_output:
            output_dir.replace(backup_dir)
        staging_dir.replace(output_dir)
    except Exception:
        if had_output and backup_dir.exists() and not output_dir.exists():
            backup_dir.replace(output_dir)
        raise
    else:
        if backup_dir.exists():
            shutil.rmtree(backup_dir)


def write_json(path: Path, payload: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def run(args: argparse.Namespace) -> dict:
    ratios = (args.train, args.val, args.test)
    validate_ratios(ratios)
    input_dir, output_dir = validate_paths(args.input, args.output)
    report_path = args.report.resolve()

    output_dir.parent.mkdir(parents=True, exist_ok=True)
    # Create this with mkdir rather than tempfile.mkdtemp. On Windows,
    # mkdtemp can apply a private ACL which remains attached after the folder is
    # renamed, preventing another local account from rerunning the splitter.
    for _ in range(100):
        staging_dir = output_dir.parent / (
            f".{output_dir.name}.staging-{uuid.uuid4().hex}"
        )
        try:
            staging_dir.mkdir()
            break
        except FileExistsError:
            continue
    else:
        raise RuntimeError("Could not create a unique staging directory.")
    try:
        report = build_split(input_dir, staging_dir, ratios, args.seed)
        marker = {
            "generator": "ml/handwriting/scripts/split_dataset.py",
            "seed": args.seed,
        }
        write_json(staging_dir / MARKER_NAME, marker)
        publish_split(staging_dir, output_dir, args.force)
    finally:
        if staging_dir.exists():
            shutil.rmtree(staging_dir)

    report["output_directory"] = str(output_dir)
    write_json(report_path, report)
    return report


def print_summary(report: dict, report_path: Path) -> None:
    print("Dataset split completed successfully.")
    print(f"Total images: {report['total_images']}")
    print(f"Train: {report['total_train']}")
    print(f"Validation: {report['total_validation']}")
    print(f"Test: {report['total_test']}")
    for dataset_name, counts in report["datasets"].items():
        print(
            f"  {dataset_name}: total={counts['total']}, train={counts['train']}, "
            f"val={counts['val']}, test={counts['test']}"
        )
    if report["warnings"]:
        print(f"Warnings ({len(report['warnings'])}):", file=sys.stderr)
        for warning in report["warnings"]:
            print(f"  WARNING: {warning}", file=sys.stderr)
    else:
        print("Warnings: none")
    print(f"Report: {report_path.resolve()}")


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        report = run(args)
    except (OSError, ValueError, RuntimeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1
    print_summary(report, args.report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
