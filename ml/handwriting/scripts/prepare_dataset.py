#!/usr/bin/env python3
"""Prepare AkuRin handwriting images without modifying the raw dataset.

The script discovers dataset and class folders under datasets/raw, normalizes
supported images to black handwriting on a centered 224x224 white canvas, and
writes PNG files to the equivalent datasets/processed folders.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import sys
import tempfile
from collections.abc import Iterable
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import cv2
import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError


HANDWRITING_ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = HANDWRITING_ROOT.parents[1]
DEFAULT_RAW_DIR = HANDWRITING_ROOT / "datasets" / "raw"
DEFAULT_PROCESSED_DIR = HANDWRITING_ROOT / "datasets" / "processed"
DEFAULT_RESULTS_DIR = HANDWRITING_ROOT / "results"
SINHALA_PREVIEW_FONT = (
    PROJECT_ROOT / "app" / "assets" / "fonts" / "NotoSansSinhala-VariableFont_wdth,wght.ttf"
)
SUPPORTED_EXTENSIONS = {".png", ".jpg", ".jpeg", ".bmp", ".webp"}
OUTPUT_SIZE = 224
CONTENT_SIZE = 176


class SkippedImageError(ValueError):
    """Raised for a readable image that contains no usable handwriting."""


@dataclass(frozen=True)
class ImageRecord:
    dataset: str
    class_name: str
    source_path: Path


def _border_pixels(image: np.ndarray) -> np.ndarray:
    """Return a robust sample of pixels expected to represent the background."""
    height, width = image.shape[:2]
    band = max(1, min(height, width) // 20)
    return np.concatenate(
        (
            image[:band].reshape(-1, image.shape[2]),
            image[-band:].reshape(-1, image.shape[2]),
            image[:, :band].reshape(-1, image.shape[2]),
            image[:, -band:].reshape(-1, image.shape[2]),
        ),
        axis=0,
    )


def load_rgb_on_white(path: Path) -> np.ndarray:
    """Load an image with EXIF correction and composite transparency on white."""
    try:
        with Image.open(path) as source:
            source.load()
            corrected = ImageOps.exif_transpose(source)
            has_alpha = corrected.mode in {"RGBA", "LA"} or (
                corrected.mode == "P" and "transparency" in corrected.info
            )
            if has_alpha:
                foreground = corrected.convert("RGBA")
                background = Image.new("RGBA", foreground.size, (255, 255, 255, 255))
                rgb_image = Image.alpha_composite(background, foreground).convert("RGB")
            else:
                rgb_image = corrected.convert("RGB")
            rgb = np.asarray(rgb_image, dtype=np.uint8).copy()
    except (UnidentifiedImageError, OSError, ValueError) as error:
        raise RuntimeError(f"unreadable or corrupt image: {error}") from error

    if rgb.size == 0 or rgb.shape[0] < 2 or rgb.shape[1] < 2:
        raise SkippedImageError("image is empty or too small")
    return rgb


def normalize_background_polarity(rgb: np.ndarray) -> np.ndarray:
    """Return grayscale with a light background and dark handwriting."""
    gray = cv2.cvtColor(rgb, cv2.COLOR_RGB2GRAY)
    border_luminance = float(np.median(cv2.cvtColor(
        _border_pixels(rgb).reshape(-1, 1, 3), cv2.COLOR_RGB2GRAY
    )))

    # The border estimates the paper/background rather than assuming a fixed
    # polarity. This converts white-on-black writing to dark-on-light writing.
    if border_luminance < 127.5:
        gray = cv2.bitwise_not(gray)
    return gray


def _local_contrast_mask(gray: np.ndarray) -> np.ndarray:
    """Recover faint pencil/pen strokes under uneven illumination."""
    min_side = min(gray.shape)
    sigma = max(3.0, min_side / 28.0)
    estimated_background = cv2.GaussianBlur(gray, (0, 0), sigmaX=sigma, sigmaY=sigma)
    ink_response = cv2.subtract(estimated_background, gray)
    high_response = float(np.percentile(ink_response, 99.5))
    if high_response < 2.0:
        return np.zeros_like(gray, dtype=np.uint8)

    scaled = np.clip(ink_response.astype(np.float32) * (255.0 / high_response), 0, 255)
    scaled = scaled.astype(np.uint8)
    _, local_mask = cv2.threshold(
        scaled,
        0,
        255,
        cv2.THRESH_BINARY + cv2.THRESH_OTSU,
    )
    return local_mask


def create_ink_mask(gray: np.ndarray) -> np.ndarray:
    """Create a foreground mask using global and faint-stroke-safe thresholds."""
    if float(np.max(gray)) - float(np.min(gray)) < 3.0:
        raise SkippedImageError("image is completely blank or has no contrast")

    blurred = cv2.GaussianBlur(gray, (3, 3), 0)
    _, global_binary = cv2.threshold(
        blurred,
        0,
        255,
        cv2.THRESH_BINARY + cv2.THRESH_OTSU,
    )
    global_mask = np.where(global_binary == 0, 255, 0).astype(np.uint8)
    local_mask = _local_contrast_mask(blurred)

    # Local recovery is restricted to pixels darker than the estimated paper.
    # This helps faint pencil and coloured pen while avoiding bright paper noise.
    border_gray = np.concatenate(
        (gray[0], gray[-1], gray[:, 0], gray[:, -1]),
        axis=0,
    )
    paper_level = float(np.median(border_gray))
    plausibly_ink = gray.astype(np.float32) < paper_level - 2.0
    combined = np.where(
        (global_mask > 0) | ((local_mask > 0) & plausibly_ink),
        255,
        0,
    ).astype(np.uint8)
    return combined


def filter_components(mask: np.ndarray) -> np.ndarray:
    """Remove tiny noise while preserving detached dots and Sinhala marks."""
    height, width = mask.shape
    image_area = height * width
    component_count, labels, stats, _ = cv2.connectedComponentsWithStats(
        mask,
        connectivity=8,
    )
    if component_count <= 1:
        raise SkippedImageError("no handwriting was detected")

    candidate_labels: list[int] = []
    for index in range(1, component_count):
        x = int(stats[index, cv2.CC_STAT_LEFT])
        y = int(stats[index, cv2.CC_STAT_TOP])
        component_width = int(stats[index, cv2.CC_STAT_WIDTH])
        component_height = int(stats[index, cv2.CC_STAT_HEIGHT])
        touches_left = x == 0
        touches_top = y == 0
        touches_right = x + component_width >= width
        touches_bottom = y + component_height >= height
        touched_edges = sum(
            (touches_left, touches_top, touches_right, touches_bottom)
        )
        spans_most_width = component_width >= width * 0.75
        spans_most_height = component_height >= height * 0.75
        is_page_frame = touched_edges >= 2 and (
            spans_most_width or spans_most_height
        )
        is_long_border_line = touched_edges >= 1 and (
            (spans_most_width and component_width >= component_height * 8)
            or (spans_most_height and component_height >= component_width * 8)
        )
        if not is_page_frame and not is_long_border_line:
            candidate_labels.append(index)

    if not candidate_labels:
        raise SkippedImageError("only page borders or frame artifacts were detected")

    largest_area = max(int(stats[index, cv2.CC_STAT_AREA]) for index in candidate_labels)
    minimum_main_area = max(3, int(round(image_area * 0.00015)))
    if largest_area < minimum_main_area:
        raise SkippedImageError("detected marks are too small to be usable")

    # Significant components establish the character's core bounds. Smaller
    # components are retained only when close enough to be a dot or diacritic,
    # preventing remote dust/noise from expanding the crop.
    significant_area = max(2, int(round(largest_area * 0.03)))
    significant_labels = [
        index
        for index in candidate_labels
        if int(stats[index, cv2.CC_STAT_AREA]) >= significant_area
    ]
    anchor_left = min(int(stats[index, cv2.CC_STAT_LEFT]) for index in significant_labels)
    anchor_top = min(int(stats[index, cv2.CC_STAT_TOP]) for index in significant_labels)
    anchor_right = max(
        int(stats[index, cv2.CC_STAT_LEFT] + stats[index, cv2.CC_STAT_WIDTH])
        for index in significant_labels
    )
    anchor_bottom = max(
        int(stats[index, cv2.CC_STAT_TOP] + stats[index, cv2.CC_STAT_HEIGHT])
        for index in significant_labels
    )
    allowed_gap = max(anchor_right - anchor_left, anchor_bottom - anchor_top) * 0.6

    keep_area = max(2, int(round(largest_area * 0.008)))
    kept_labels: list[int] = []
    for index in candidate_labels:
        component_area = int(stats[index, cv2.CC_STAT_AREA])
        if component_area < keep_area:
            continue
        if component_area >= significant_area:
            kept_labels.append(index)
            continue

        x = int(stats[index, cv2.CC_STAT_LEFT])
        y = int(stats[index, cv2.CC_STAT_TOP])
        component_right = x + int(stats[index, cv2.CC_STAT_WIDTH])
        component_bottom = y + int(stats[index, cv2.CC_STAT_HEIGHT])
        horizontal_gap = max(anchor_left - component_right, x - anchor_right, 0)
        vertical_gap = max(anchor_top - component_bottom, y - anchor_bottom, 0)
        if (horizontal_gap**2 + vertical_gap**2) ** 0.5 <= allowed_gap:
            kept_labels.append(index)

    cleaned = np.isin(labels, kept_labels).astype(np.uint8) * 255
    foreground_fraction = float(np.count_nonzero(cleaned)) / image_area
    if foreground_fraction < 0.00015:
        raise SkippedImageError("too little handwriting was detected")
    if foreground_fraction > 0.65:
        raise SkippedImageError("foreground covers most of the image")
    return cleaned


def center_on_canvas(mask: np.ndarray) -> np.ndarray:
    """Crop safely, preserve aspect ratio, and center on a white square."""
    points = cv2.findNonZero(mask)
    if points is None:
        raise SkippedImageError("no handwriting remained after noise filtering")

    x, y, width, height = cv2.boundingRect(points)
    padding = max(2, int(round(max(width, height) * 0.04)))
    left = max(0, x - padding)
    top = max(0, y - padding)
    right = min(mask.shape[1], x + width + padding)
    bottom = min(mask.shape[0], y + height + padding)
    cropped = mask[top:bottom, left:right]

    crop_height, crop_width = cropped.shape
    scale = min(CONTENT_SIZE / crop_width, CONTENT_SIZE / crop_height)
    resized_width = max(1, int(round(crop_width * scale)))
    resized_height = max(1, int(round(crop_height * scale)))
    interpolation = cv2.INTER_AREA if scale < 1.0 else cv2.INTER_LINEAR
    resized_mask = cv2.resize(
        cropped,
        (resized_width, resized_height),
        interpolation=interpolation,
    )

    canvas = np.full((OUTPUT_SIZE, OUTPUT_SIZE), 255, dtype=np.uint8)
    offset_x = (OUTPUT_SIZE - resized_width) // 2
    offset_y = (OUTPUT_SIZE - resized_height) // 2
    ink = 255 - resized_mask
    canvas[
        offset_y : offset_y + resized_height,
        offset_x : offset_x + resized_width,
    ] = ink
    return canvas


def preprocess_image(path: Path) -> np.ndarray:
    """Convert one source image to the standard AkuRin model input format."""
    rgb = load_rgb_on_white(path)
    gray = normalize_background_polarity(rgb)
    mask = create_ink_mask(gray)
    cleaned_mask = filter_components(mask)
    return center_on_canvas(cleaned_mask)


def discover_images(raw_dir: Path) -> list[ImageRecord]:
    records: list[ImageRecord] = []
    for dataset_dir in sorted(
        (path for path in raw_dir.iterdir() if path.is_dir()),
        key=lambda path: path.name.casefold(),
    ):
        for class_dir in sorted(
            (path for path in dataset_dir.iterdir() if path.is_dir()),
            key=lambda path: path.name.casefold(),
        ):
            source_files = sorted(
                (
                    path
                    for path in class_dir.rglob("*")
                    if path.is_file() and path.suffix.lower() in SUPPORTED_EXTENSIONS
                ),
                key=lambda path: str(path.relative_to(class_dir)).casefold(),
            )
            records.extend(
                ImageRecord(dataset_dir.name, class_dir.name, path)
                for path in source_files
            )
    return records


def _empty_counts() -> dict[str, int]:
    return {"found": 0, "processed": 0, "skipped": 0, "failed": 0}


def _increment_counts(
    report: dict[str, Any],
    record: ImageRecord,
    field: str,
) -> None:
    dataset_counts = report["per_dataset"].setdefault(record.dataset, _empty_counts())
    class_key = f"{record.dataset}/{record.class_name}"
    class_counts = report["per_class"].setdefault(class_key, _empty_counts())
    dataset_counts[field] += 1
    class_counts[field] += 1


def save_png(image: np.ndarray, output_path: Path) -> None:
    """Atomically write a PNG, including paths containing Sinhala characters."""
    output_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = output_path.with_suffix(".tmp")
    Image.fromarray(image, mode="L").save(
        temporary_path,
        format="PNG",
        optimize=True,
    )
    temporary_path.replace(output_path)


def create_preview(
    processed_paths: list[Path],
    processed_dir: Path,
    preview_path: Path,
    sample_count: int,
    seed: int,
) -> bool:
    if not processed_paths or sample_count <= 0:
        return False

    matplotlib_cache = Path(tempfile.gettempdir()) / "akurin_matplotlib"
    matplotlib_cache.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("MPLCONFIGDIR", str(matplotlib_cache))
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.font_manager import FontProperties

    sample_size = min(sample_count, len(processed_paths))
    samples = random.Random(seed).sample(processed_paths, sample_size)
    columns = 5
    rows = (sample_size + columns - 1) // columns
    figure, axes = plt.subplots(rows, columns, figsize=(12, rows * 2.5))
    axes_array = np.atleast_1d(axes).reshape(-1)
    sinhala_font = (
        FontProperties(fname=str(SINHALA_PREVIEW_FONT), size=8)
        if SINHALA_PREVIEW_FONT.is_file()
        else None
    )

    for axis, path in zip(axes_array, samples, strict=False):
        with Image.open(path) as image:
            axis.imshow(image, cmap="gray", vmin=0, vmax=255)
        relative = path.relative_to(processed_dir)
        title_options: dict[str, Any] = {"fontsize": 8}
        if relative.parts[0] == "sinhala" and sinhala_font is not None:
            title_options["fontproperties"] = sinhala_font
        axis.set_title(
            f"{relative.parts[0]} / {relative.parts[1]}",
            **title_options,
        )
        axis.axis("off")
    for axis in axes_array[sample_size:]:
        axis.axis("off")

    figure.suptitle("AkuRin handwriting preprocessing preview", fontsize=14)
    figure.tight_layout()
    preview_path.parent.mkdir(parents=True, exist_ok=True)
    figure.savefig(preview_path, dpi=160, bbox_inches="tight")
    plt.close(figure)
    return True


def _is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.relative_to(parent)
        return True
    except ValueError:
        return False


def validate_paths(raw_dir: Path, processed_dir: Path) -> None:
    raw_resolved = raw_dir.resolve()
    processed_resolved = processed_dir.resolve()
    if not raw_resolved.is_dir():
        raise FileNotFoundError(f"Raw dataset directory does not exist: {raw_resolved}")
    if raw_resolved == processed_resolved:
        raise ValueError("Processed output directory cannot be the raw directory")
    if _is_relative_to(processed_resolved, raw_resolved):
        raise ValueError("Processed output directory cannot be inside the raw directory")


def prepare_dataset(
    raw_dir: Path,
    processed_dir: Path,
    results_dir: Path,
    preview_count: int = 25,
    seed: int = 319,
    limit_per_class: int | None = None,
) -> dict[str, Any]:
    validate_paths(raw_dir, processed_dir)
    records = discover_images(raw_dir)
    if limit_per_class is not None:
        limited: list[ImageRecord] = []
        class_counts: dict[tuple[str, str], int] = {}
        for record in records:
            key = (record.dataset, record.class_name)
            count = class_counts.get(key, 0)
            if count < limit_per_class:
                limited.append(record)
                class_counts[key] = count + 1
        records = limited

    report: dict[str, Any] = {
        "generated_at_utc": datetime.now(timezone.utc).isoformat(),
        "raw_directory": str(raw_dir.resolve()),
        "processed_directory": str(processed_dir.resolve()),
        "total_found": len(records),
        "processed": 0,
        "skipped": 0,
        "failed": 0,
        "output_size": f"{OUTPUT_SIZE}x{OUTPUT_SIZE}",
        "supported_extensions": sorted(SUPPORTED_EXTENSIONS),
        "per_dataset": {},
        "per_class": {},
        "skipped_files": [],
        "failures": [],
    }
    for record in records:
        _increment_counts(report, record, "found")

    successful_paths: list[Path] = []
    output_indices: dict[tuple[str, str], int] = {}
    for position, record in enumerate(records, start=1):
        relative_source = str(record.source_path.relative_to(raw_dir))
        key = (record.dataset, record.class_name)
        try:
            processed_image = preprocess_image(record.source_path)
            next_index = output_indices.get(key, 0) + 1
            output_indices[key] = next_index
            output_name = f"{record.class_name}_{next_index:05d}.png"
            output_path = (
                processed_dir / record.dataset / record.class_name / output_name
            )
            save_png(processed_image, output_path)
            successful_paths.append(output_path)
            report["processed"] += 1
            _increment_counts(report, record, "processed")
        except SkippedImageError as error:
            report["skipped"] += 1
            _increment_counts(report, record, "skipped")
            item = {"path": relative_source, "reason": str(error)}
            report["skipped_files"].append(item)
            print(f"SKIPPED: {record.source_path} -- {error}", file=sys.stderr)
        except Exception as error:  # Continue so one corrupt file cannot stop a run.
            report["failed"] += 1
            _increment_counts(report, record, "failed")
            item = {"path": relative_source, "reason": str(error)}
            report["failures"].append(item)
            print(f"FAILED: {record.source_path} -- {error}", file=sys.stderr)

        if position % 250 == 0 or position == len(records):
            print(
                f"Progress: {position}/{len(records)} | "
                f"processed={report['processed']} skipped={report['skipped']} "
                f"failed={report['failed']}"
            )

    results_dir.mkdir(parents=True, exist_ok=True)
    preview_path = results_dir / "preprocessing_preview.png"
    report["preview_created"] = create_preview(
        successful_paths,
        processed_dir,
        preview_path,
        preview_count,
        seed,
    )
    report["preview_path"] = str(preview_path.resolve()) if report["preview_created"] else None

    report_path = results_dir / "preprocessing_report.json"
    report_path.write_text(
        json.dumps(report, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(f"Report: {report_path}")
    if report["preview_created"]:
        print(f"Preview: {preview_path}")
    return report


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Normalize AkuRin handwriting datasets to centered 224x224 PNGs.",
    )
    parser.add_argument("--raw-dir", type=Path, default=DEFAULT_RAW_DIR)
    parser.add_argument("--processed-dir", type=Path, default=DEFAULT_PROCESSED_DIR)
    parser.add_argument("--results-dir", type=Path, default=DEFAULT_RESULTS_DIR)
    parser.add_argument(
        "--preview-count",
        type=int,
        default=25,
        help="Number of random processed images in the preview; use 0 to disable.",
    )
    parser.add_argument("--seed", type=int, default=319)
    parser.add_argument(
        "--limit-per-class",
        type=int,
        default=None,
        help="Optional smoke-test limit; omit to process every image.",
    )
    parser.add_argument(
        "--fail-on-error",
        action="store_true",
        help="Return a non-zero exit code if any readable operation failed.",
    )
    return parser


def main(argv: Iterable[str] | None = None) -> int:
    args = build_argument_parser().parse_args(argv)
    if args.preview_count < 0:
        raise SystemExit("--preview-count must be zero or greater")
    if args.limit_per_class is not None and args.limit_per_class < 1:
        raise SystemExit("--limit-per-class must be at least 1")

    report = prepare_dataset(
        raw_dir=args.raw_dir,
        processed_dir=args.processed_dir,
        results_dir=args.results_dir,
        preview_count=args.preview_count,
        seed=args.seed,
        limit_per_class=args.limit_per_class,
    )
    print(
        "Complete: "
        f"found={report['total_found']} processed={report['processed']} "
        f"skipped={report['skipped']} failed={report['failed']}"
    )
    return 1 if args.fail_on_error and report["failed"] else 0


if __name__ == "__main__":
    raise SystemExit(main())
