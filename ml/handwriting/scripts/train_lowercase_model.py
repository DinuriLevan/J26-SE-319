#!/usr/bin/env python3
"""Train/evaluate a lowercase MobileNetV3-Small without touching other models."""

from __future__ import annotations

import argparse
import json
import math
import random
import shutil
from collections import Counter
from pathlib import Path
from typing import Iterable

import cv2
import matplotlib.pyplot as plt
import numpy as np
import tensorflow as tf
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.utils.class_weight import compute_class_weight

ROOT = Path(__file__).resolve().parents[1]
PROJECT_ROOT = ROOT.parents[1]
SPLIT_ROOT = ROOT / "datasets" / "split" / "english_lowercase"
GENERATED_ROOT = ROOT / "datasets" / "generated_lowercase_v2"
RESULTS_ROOT = ROOT / "results" / "lowercase_v2"
MODEL_ROOT = ROOT / "models"
ACTIVE_MODEL = PROJECT_ROOT / "app" / "assets" / "models" / "english_lowercase_model.tflite"
ACTIVE_LABELS = PROJECT_ROOT / "app" / "assets" / "models" / "english_lowercase_labels.txt"
LABELS = tuple(chr(ord("a") + index) for index in range(26))
PROBLEM_CLASSES = ("b", "d", "p", "q", "s", "c", "e")
PAIR_GROUPS = (("b", "d"), ("p", "q"), ("s", "c"), ("s", "e"), ("c", "e"))
IMAGE_SIZE = 224
SEED = 42


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--head-epochs", type=int, default=10)
    parser.add_argument("--fine-tune-epochs", type=int, default=8)
    parser.add_argument("--batch-size", type=int, default=16)
    parser.add_argument("--canvas-train-per-class", type=int, default=100)
    parser.add_argument("--canvas-test-per-class", type=int, default=30)
    parser.add_argument(
        "--evaluate-existing",
        action="store_true",
        help="Evaluate the existing v2 Keras/TFLite artifacts without retraining.",
    )
    parser.add_argument("--promote", action="store_true")
    return parser.parse_args()


def cubic_bezier(points: tuple[tuple[float, float], ...], samples: int = 50) -> np.ndarray:
    p0, p1, p2, p3 = (np.asarray(point, dtype=np.float32) for point in points)
    values = []
    for t in np.linspace(0, 1, samples):
        values.append((1 - t) ** 3 * p0 + 3 * (1 - t) ** 2 * t * p1 + 3 * (1 - t) * t**2 * p2 + t**3 * p3)
    return np.asarray(values, dtype=np.float32)


def ellipse_points(cx: float, cy: float, rx: float, ry: float, start: float = 0, end: float = 360, samples: int = 100) -> np.ndarray:
    radians = np.deg2rad(np.linspace(start, end, samples))
    return np.column_stack((cx + rx * np.cos(radians), cy + ry * np.sin(radians))).astype(np.float32)


def base_strokes(character: str) -> list[np.ndarray]:
    if character == "b":
        return [np.array([(72, 35), (72, 190)], np.float32), ellipse_points(111, 139, 39, 49)]
    if character == "d":
        return [ellipse_points(108, 139, 42, 49), np.array([(150, 190), (150, 35)], np.float32)]
    if character == "p":
        return [np.array([(73, 70), (73, 212)], np.float32), ellipse_points(111, 113, 38, 42)]
    if character == "q":
        return [ellipse_points(108, 113, 42, 42), np.array([(150, 75), (150, 210)], np.float32)]
    if character == "c":
        return [ellipse_points(112, 122, 51, 59, 45, 315)]
    if character == "e":
        return [ellipse_points(112, 122, 50, 57, 5, 350), np.array([(65, 122), (150, 122)], np.float32)]
    if character == "s":
        upper = cubic_bezier(((164, 72), (135, 43), (70, 54), (76, 108)), 55)
        middle = cubic_bezier(((76, 108), (84, 135), (151, 105), (157, 144)), 45)
        lower = cubic_bezier(((157, 144), (171, 197), (92, 205), (64, 174)), 55)
        return [np.vstack((upper, middle[1:], lower[1:]))]
    raise ValueError(f"No canvas generator for {character}")


def render_canvas_sample(character: str, seed: int) -> np.ndarray:
    rng = np.random.default_rng(seed)
    canvas = np.full((IMAGE_SIZE, IMAGE_SIZE, 3), 255, dtype=np.uint8)
    scale_x, scale_y = rng.uniform(0.86, 1.14, size=2)
    angle = math.radians(rng.uniform(-7.0, 7.0))
    translation = rng.uniform(-10, 10, size=2).astype(np.float32)
    center = np.array([112, 122], np.float32)
    rotation = np.array([[math.cos(angle), -math.sin(angle)], [math.sin(angle), math.cos(angle)]], np.float32)
    thickness = int(rng.integers(12, 22))
    for stroke in base_strokes(character):
        transformed = (stroke - center) * np.array([scale_x, scale_y], np.float32)
        transformed = transformed @ rotation.T + center + translation
        cv2.polylines(canvas, [np.rint(transformed).astype(np.int32)], False, (0, 0, 0), thickness, cv2.LINE_AA)
    return canvas


def generate_canvas_dataset(train_per_class: int, test_per_class: int) -> None:
    for split, count, seed_offset in (("train", train_per_class, 10_000), ("test", test_per_class, 1_000_000)):
        for class_index, class_name in enumerate(PROBLEM_CLASSES):
            target = GENERATED_ROOT / split / class_name
            target.mkdir(parents=True, exist_ok=True)
            for existing in target.glob("*.png"):
                existing.unlink()
            for index in range(count):
                seed = SEED + seed_offset + class_index * 10_000 + index
                cv2.imwrite(str(target / f"{class_name}_canvas_{index:04d}.png"), render_canvas_sample(class_name, seed))


def discover(split_dir: Path, classes: Iterable[str] = LABELS) -> tuple[list[str], list[int]]:
    paths: list[str] = []
    labels: list[int] = []
    for label, class_name in enumerate(classes):
        class_dir = split_dir / class_name
        if not class_dir.is_dir():
            continue
        for path in sorted(class_dir.glob("*.png")):
            paths.append(str(path))
            labels.append(label)
    return paths, labels


def decode_image(path: tf.Tensor, label: tf.Tensor) -> tuple[tf.Tensor, tf.Tensor]:
    image = tf.io.decode_png(tf.io.read_file(path), channels=3)
    image = tf.image.resize(image, (IMAGE_SIZE, IMAGE_SIZE), antialias=True)
    return tf.cast(image, tf.float32), label


def make_dataset(paths: list[str], labels: list[int], batch_size: int, training: bool) -> tf.data.Dataset:
    dataset = tf.data.Dataset.from_tensor_slices((paths, labels))
    if training:
        dataset = dataset.shuffle(len(paths), seed=SEED, reshuffle_each_iteration=True)
    dataset = dataset.map(decode_image, num_parallel_calls=tf.data.AUTOTUNE)
    return dataset.batch(batch_size).prefetch(tf.data.AUTOTUNE)


class RandomStrokeVariation(tf.keras.layers.Layer):
    """Training-only stroke dilation/erosion; never changes orientation."""

    def call(self, inputs: tf.Tensor, training: bool | None = None) -> tf.Tensor:
        if not training:
            return inputs
        ink = 255.0 - inputs
        thick = tf.nn.max_pool2d(ink, ksize=3, strides=1, padding="SAME")
        thin = -tf.nn.max_pool2d(-ink, ksize=3, strides=1, padding="SAME")
        choice = tf.random.uniform((), seed=SEED)
        varied = tf.cond(choice < 0.25, lambda: thick, lambda: tf.cond(choice < 0.5, lambda: thin, lambda: ink))
        return 255.0 - varied


def build_model() -> tuple[tf.keras.Model, tf.keras.Model]:
    augmentation = tf.keras.Sequential([
        tf.keras.layers.RandomRotation(0.02, fill_mode="constant", fill_value=255.0, seed=SEED),
        tf.keras.layers.RandomTranslation(0.055, 0.055, fill_mode="constant", fill_value=255.0, seed=SEED + 1),
        tf.keras.layers.RandomZoom((-0.08, 0.08), (-0.08, 0.08), fill_mode="constant", fill_value=255.0, seed=SEED + 2),
        tf.keras.layers.RandomContrast(0.08, seed=SEED + 3),
        RandomStrokeVariation(name="random_stroke_variation"),
    ], name="orientation_safe_augmentation")
    base = tf.keras.applications.MobileNetV3Small(
        input_shape=(IMAGE_SIZE, IMAGE_SIZE, 3), include_top=False, weights="imagenet", include_preprocessing=True
    )
    base.trainable = False
    inputs = tf.keras.Input((IMAGE_SIZE, IMAGE_SIZE, 3), dtype=tf.float32, name="handwriting_rgb")
    x = augmentation(inputs)
    features = base(x, training=False)
    # Global average pooling is useful for shape identity but weakens the exact
    # left/right layout that separates b/d and p/q.  Retain a small spatial
    # branch so the learned classifier can see stem-versus-loop orientation.
    semantic = tf.keras.layers.GlobalAveragePooling2D(name="semantic_pool")(features)
    spatial = tf.keras.layers.Conv2D(24, 1, activation="relu", name="spatial_projection")(features)
    spatial = tf.keras.layers.Flatten(name="spatial_flatten")(spatial)
    spatial = tf.keras.layers.Dense(64, activation="relu", name="spatial_embedding")(spatial)
    x = tf.keras.layers.Concatenate(name="combined_features")([semantic, spatial])
    x = tf.keras.layers.Dropout(0.30)(x)
    outputs = tf.keras.layers.Dense(len(LABELS), activation="softmax", name="character_scores")(x)
    return tf.keras.Model(inputs, outputs, name="akurin_lowercase_v2"), base


def compile_model(model: tf.keras.Model, learning_rate: float) -> None:
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate),
        loss=tf.keras.losses.SparseCategoricalCrossentropy(),
        metrics=[tf.keras.metrics.SparseCategoricalAccuracy(name="accuracy")],
    )


def class_weights(original_labels: list[int]) -> dict[int, float]:
    classes = np.arange(len(LABELS))
    weights = compute_class_weight("balanced", classes=classes, y=np.asarray(original_labels))
    return {index: float(np.clip(weight, 0.55, 2.5)) for index, weight in enumerate(weights)}


def predict_tflite(model_path: Path, paths: list[str], labels: list[int]) -> tuple[np.ndarray, np.ndarray]:
    interpreter = tf.lite.Interpreter(model_path=str(model_path))
    interpreter.allocate_tensors()
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    scores: list[np.ndarray] = []
    for path in paths:
        image = cv2.cvtColor(cv2.imread(path, cv2.IMREAD_COLOR), cv2.COLOR_BGR2RGB)
        image = cv2.resize(image, (int(input_detail["shape"][2]), int(input_detail["shape"][1])), interpolation=cv2.INTER_AREA)
        tensor = image.astype(input_detail["dtype"])[None, ...]
        interpreter.set_tensor(input_detail["index"], tensor)
        interpreter.invoke()
        scores.append(interpreter.get_tensor(output_detail["index"])[0].astype(np.float32))
    return np.asarray(labels), np.asarray(scores)


def metrics_for(truth: np.ndarray, scores: np.ndarray) -> dict[str, object]:
    prediction = np.argmax(scores, axis=1)
    report = classification_report(
        truth, prediction, labels=np.arange(len(LABELS)), target_names=LABELS, output_dict=True, zero_division=0
    )
    matrix = confusion_matrix(truth, prediction, labels=np.arange(len(LABELS)))
    pair_confusion: dict[str, object] = {}
    for left, right in PAIR_GROUPS:
        left_index, right_index = LABELS.index(left), LABELS.index(right)
        pair_confusion[f"{left}_vs_{right}"] = {
            f"{left}_as_{right}": int(matrix[left_index, right_index]),
            f"{right}_as_{left}": int(matrix[right_index, left_index]),
            f"{left}_recall": float(report[left]["recall"]),
            f"{right}_recall": float(report[right]["recall"]),
        }
    return {
        "accuracy": float(accuracy_score(truth, prediction)),
        "macro_precision": float(report["macro avg"]["precision"]),
        "macro_recall": float(report["macro avg"]["recall"]),
        "macro_f1": float(report["macro avg"]["f1-score"]),
        "per_class": {label: report[label] for label in LABELS},
        "problem_pair_confusion": pair_confusion,
        "confusion_matrix": matrix.tolist(),
    }


def plot_confusion(matrix: list[list[int]], path: Path, title: str) -> None:
    figure, axis = plt.subplots(figsize=(13, 12))
    image = axis.imshow(np.asarray(matrix), cmap="Blues")
    axis.set(
        xticks=np.arange(26), yticks=np.arange(26), xticklabels=LABELS, yticklabels=LABELS,
        xlabel="Predicted", ylabel="Actual", title=title,
    )
    figure.colorbar(image, ax=axis, fraction=0.046, pad=0.04)
    figure.tight_layout()
    figure.savefig(path, dpi=170)
    plt.close(figure)


def problem_macro_recall(metrics: dict[str, object]) -> float:
    per_class = metrics["per_class"]
    return float(np.mean([per_class[label]["recall"] for label in PROBLEM_CLASSES]))


def main() -> int:
    args = parse_args()
    random.seed(SEED)
    np.random.seed(SEED)
    tf.keras.utils.set_random_seed(SEED)
    RESULTS_ROOT.mkdir(parents=True, exist_ok=True)
    MODEL_ROOT.mkdir(parents=True, exist_ok=True)
    if not SPLIT_ROOT.is_dir() or not ACTIVE_MODEL.is_file():
        raise SystemExit("Missing lowercase split dataset or active lowercase model.")
    labels = tuple(line.strip() for line in ACTIVE_LABELS.read_text(encoding="utf-8").splitlines() if line.strip())
    if labels != LABELS:
        raise SystemExit(f"Unexpected lowercase label order: {labels}")

    generate_canvas_dataset(args.canvas_train_per_class, args.canvas_test_per_class)
    train_paths, original_train_labels = discover(SPLIT_ROOT / "train")
    generated_paths, generated_labels = discover(GENERATED_ROOT / "train")
    val_paths, val_labels = discover(SPLIT_ROOT / "val")
    test_paths, test_labels = discover(SPLIT_ROOT / "test")
    canvas_test_paths, canvas_test_labels = discover(GENERATED_ROOT / "test")
    combined_paths = train_paths + generated_paths
    combined_labels = original_train_labels + generated_labels
    print("Original train counts:", dict(sorted(Counter(LABELS[index] for index in original_train_labels).items())))
    print("Generated canvas counts:", dict(sorted(Counter(LABELS[index] for index in generated_labels).items())))

    # Weights must describe the data actually passed to fit().  Computing them
    # from only the original split over-weights d after balanced canvas samples
    # are added and can simply reverse the b/d bias instead of fixing it.
    weights = class_weights(combined_labels)
    best_path = MODEL_ROOT / "english_lowercase_model_v2.keras"
    candidate_tflite = MODEL_ROOT / "english_lowercase_model_v2.tflite"
    candidate_labels = MODEL_ROOT / "english_lowercase_labels_v2.txt"
    histories: dict[str, object] = {"head": {}, "fine_tune": {}}
    if args.evaluate_existing:
        if not best_path.is_file() or not candidate_tflite.is_file():
            raise SystemExit("Existing v2 Keras/TFLite artifacts were not found.")
    else:
        train_dataset = make_dataset(combined_paths, combined_labels, args.batch_size, True)
        val_dataset = make_dataset(val_paths, val_labels, args.batch_size, False)
        model, base = build_model()
        callbacks = [
            tf.keras.callbacks.ModelCheckpoint(str(best_path), monitor="val_accuracy", save_best_only=True, verbose=1),
            tf.keras.callbacks.EarlyStopping(monitor="val_accuracy", patience=4, restore_best_weights=True, verbose=1),
            tf.keras.callbacks.ReduceLROnPlateau(monitor="val_loss", factor=0.35, patience=2, min_lr=1e-7, verbose=1),
        ]
        compile_model(model, 3e-4)
        head_history = model.fit(
            train_dataset, validation_data=val_dataset, epochs=args.head_epochs, class_weight=weights,
            callbacks=callbacks, verbose=2,
        )
        base.trainable = True
        for layer in base.layers[:-35]:
            layer.trainable = False
        compile_model(model, 1e-5)
        fine_history = model.fit(
            train_dataset, validation_data=val_dataset, epochs=args.fine_tune_epochs, class_weight=weights,
            callbacks=callbacks, verbose=2,
        )
        model = tf.keras.models.load_model(
            str(best_path), custom_objects={"RandomStrokeVariation": RandomStrokeVariation}
        )
        converter = tf.lite.TFLiteConverter.from_keras_model(model)
        candidate_tflite.write_bytes(converter.convert())
        histories = {"head": head_history.history, "fine_tune": fine_history.history}
    candidate_labels.write_text("\n".join(LABELS) + "\n", encoding="utf-8")

    old_truth, old_scores = predict_tflite(ACTIVE_MODEL, test_paths, test_labels)
    new_truth, new_scores = predict_tflite(candidate_tflite, test_paths, test_labels)
    old_canvas_truth, old_canvas_scores = predict_tflite(ACTIVE_MODEL, canvas_test_paths, canvas_test_labels)
    new_canvas_truth, new_canvas_scores = predict_tflite(candidate_tflite, canvas_test_paths, canvas_test_labels)
    old_metrics = metrics_for(old_truth, old_scores)
    new_metrics = metrics_for(new_truth, new_scores)
    old_canvas_metrics = metrics_for(old_canvas_truth, old_canvas_scores)
    new_canvas_metrics = metrics_for(new_canvas_truth, new_canvas_scores)
    gates = {
        "original_accuracy_not_worse_by_more_than_2pct": new_metrics["accuracy"] >= old_metrics["accuracy"] - 0.02,
        "original_problem_recall_improved": problem_macro_recall(new_metrics) > problem_macro_recall(old_metrics),
        "canvas_accuracy_improved": new_canvas_metrics["accuracy"] > old_canvas_metrics["accuracy"],
        "canvas_macro_f1_improved": new_canvas_metrics["macro_f1"] > old_canvas_metrics["macro_f1"],
        "no_original_problem_class_recall_regresses_over_15pct": all(
            new_metrics["per_class"][label]["recall"] >= old_metrics["per_class"][label]["recall"] - 0.15
            for label in PROBLEM_CLASSES
        ),
        "no_canvas_problem_class_recall_regresses_over_10pct": all(
            new_canvas_metrics["per_class"][label]["recall"]
            >= old_canvas_metrics["per_class"][label]["recall"] - 0.10
            for label in PROBLEM_CLASSES
        ),
    }
    passed = all(gates.values())
    result = {
        "seed": SEED,
        "labels": list(LABELS),
        "counts": {
            "train_original": len(train_paths), "train_generated_canvas": len(generated_paths),
            "validation": len(val_paths), "test": len(test_paths), "unseen_canvas_test": len(canvas_test_paths),
        },
        "augmentation": {
            "rotation_degrees": 7, "translation_fraction": 0.055, "zoom_fraction": 0.08,
            "contrast_fraction": 0.08, "stroke_variation": "one-pixel dilation or erosion",
            "horizontal_flip": False, "vertical_flip": False,
        },
        "class_weights": {LABELS[index]: value for index, value in weights.items()},
        "old_original_test": old_metrics,
        "new_original_test": new_metrics,
        "old_unseen_canvas_test": old_canvas_metrics,
        "new_unseen_canvas_test": new_canvas_metrics,
        "promotion_gates": gates,
        "passed_promotion_gates": passed,
        "promoted": False,
        "artifacts": {"keras": str(best_path), "tflite": str(candidate_tflite), "labels": str(candidate_labels)},
        "history": histories,
    }
    if args.promote and passed:
        backup = MODEL_ROOT / "english_lowercase_model_v1_backup.tflite"
        shutil.copy2(ACTIVE_MODEL, backup)
        shutil.copy2(candidate_tflite, ACTIVE_MODEL)
        result["promoted"] = True
        result["artifacts"]["backup"] = str(backup)
    elif args.promote:
        print("Candidate failed promotion gates; active model was not replaced.")

    report_path = RESULTS_ROOT / "lowercase_model_v2_report.json"
    report_path.write_text(
        json.dumps(
            result,
            indent=2,
            default=lambda value: value.item() if isinstance(value, np.generic) else str(value),
        ),
        encoding="utf-8",
    )
    plot_confusion(old_metrics["confusion_matrix"], RESULTS_ROOT / "old_confusion_matrix.png", "Old lowercase model")
    plot_confusion(new_metrics["confusion_matrix"], RESULTS_ROOT / "new_confusion_matrix.png", "Lowercase model v2")
    summary = {
        "old_accuracy": old_metrics["accuracy"], "new_accuracy": new_metrics["accuracy"],
        "old_macro_f1": old_metrics["macro_f1"], "new_macro_f1": new_metrics["macro_f1"],
        "old_canvas_accuracy": old_canvas_metrics["accuracy"], "new_canvas_accuracy": new_canvas_metrics["accuracy"],
        "old_problem_recall": problem_macro_recall(old_metrics),
        "new_problem_recall": problem_macro_recall(new_metrics),
        "gates": gates, "promoted": result["promoted"], "report": str(report_path),
    }
    print(json.dumps(summary, indent=2))
    return 0 if passed else 2


if __name__ == "__main__":
    raise SystemExit(main())
