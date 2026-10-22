"""Train, evaluate and export the Math & Memory next-attempt models.

Reproducible: fixed seeds, pinned requirements. Run from the repo root:

    docker run --rm -v "$PWD":/repo -w /repo/ml/math_memory python:3.12-slim \
        sh -c "pip install -q -r requirements.txt && python train.py"

Outputs
- app/assets/models/math_memory/*.json      model artifacts bundled in the app
- ml/math_memory/reports/evaluation.{json,md} metrics vs. baselines
- app/test/features/math_memory/fixtures/*_parity.json  Dart/Python parity cases
"""

from __future__ import annotations

import datetime as dt
import json
from pathlib import Path

import numpy as np
import sklearn
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, f1_score
from sklearn.model_selection import GroupShuffleSplit
from sklearn.tree import DecisionTreeClassifier

from features import MEMORY_LADDER, MM_CLASSES, MM_FEATURES, NQ_CLASSES, NQ_FEATURES
from simulate import generate_memory_match, generate_number_quest

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
ASSET_DIR = REPO / "app" / "assets" / "models" / "math_memory"
FIXTURE_DIR = REPO / "app" / "test" / "features" / "math_memory" / "fixtures"
REPORT_DIR = HERE / "reports"

MODEL_VERSION = "1.0.0"
SEED = 20261018


# ---------------------------------------------------------------- baselines


def stay_baseline(X, names):
    return np.zeros(len(X), dtype=int)


def nq_rule_baseline(X, names):
    """Threshold rules like the app's rules_v1 engine."""
    i = {n: k for k, n in enumerate(names)}
    out = []
    for row in X:
        first, eventual = row[i["first_try_acc"]], row[i["eventual_acc"]]
        if row[i["is_baseline"]] == 1:
            mastery = first + 0.5 * (eventual - first)
            out.append(1 if mastery >= 1.0 else (0 if mastery >= 0.5 else -1))
        elif first >= 0.75 and row[i["mean_rt_s"]] <= 20:
            out.append(1)
        elif first < 0.5:
            out.append(-1)
        else:
            out.append(0)
    return np.array(out)


def mm_rule_baseline(X, names):
    i = {n: k for k, n in enumerate(names)}
    first = X[:, i["first_try_acc"]]
    return np.where(first >= 0.83, 1, np.where(first <= 0.5, -1, 0))


# ---------------------------------------------------------------- metrics


def evaluate(y_true, y_pred, is_baseline):
    err = y_pred - y_true
    def acc(mask):
        return float(accuracy_score(y_true[mask], y_pred[mask])) if mask.any() else None
    return {
        "accuracy": float(accuracy_score(y_true, y_pred)),
        "macro_f1": float(f1_score(y_true, y_pred, average="macro")),
        "mean_abs_error_steps": float(np.mean(np.abs(err))),
        "within_one_step": float(np.mean(np.abs(err) <= 1)),
        "too_hard_rate": float(np.mean(err > 0)),  # harder than the expert target
        "too_easy_rate": float(np.mean(err < 0)),
        "accuracy_after_baseline": acc(is_baseline == 1),
        "accuracy_after_scored": acc(is_baseline == 0),
    }


# ---------------------------------------------------------------- export


def _format_artifact(value):
    """Compact JSON with one key per line (no indent); arrays stay inline."""
    if isinstance(value, dict):
        parts = [json.dumps(k) + ":" + _format_artifact(v) for k, v in value.items()]
        return "{" + ",\n".join(parts) + "}"
    if isinstance(value, (list, tuple)):
        return "[" + ",".join(_format_artifact(v) for v in value) + "]"
    return json.dumps(value)


def export_trees(model):
    estimators = model.estimators_ if hasattr(model, "estimators_") else [model]
    trees = []
    for est in estimators:
        t = est.tree_
        values = t.value[:, 0, :]
        values = values / values.sum(axis=1, keepdims=True)
        trees.append(
            {
                "feature": t.feature.tolist(),
                "threshold": [float(x) for x in t.threshold],
                "left": t.children_left.tolist(),
                "right": t.children_right.tolist(),
                "value": [[round(float(p), 6) for p in row] for row in values],
            }
        )
    return trees


def predict_from_export(artifact, row):
    """Reference evaluator over the exported JSON — the algorithm the app uses."""
    n_classes = len(artifact["classes"])
    total = [0.0] * n_classes
    for tree in artifact["trees"]:
        node = 0
        while tree["left"][node] != -1:
            x = float(np.float32(row[tree["feature"][node]]))
            node = tree["left"][node] if x <= tree["threshold"][node] else tree["right"][node]
        for k, p in enumerate(tree["value"][node]):
            total[k] += p
    probs = [p / len(artifact["trees"]) for p in total]
    best = max(range(n_classes), key=lambda k: (probs[k], -k))
    return artifact["classes"][best], probs


# ---------------------------------------------------------------- pipeline


def split(groups, seed):
    outer = GroupShuffleSplit(n_splits=1, test_size=0.30, random_state=seed)
    train_idx, rest = next(outer.split(np.zeros(len(groups)), groups=groups))
    inner = GroupShuffleSplit(n_splits=1, test_size=0.50, random_state=seed + 1)
    val_rel, test_rel = next(inner.split(np.zeros(len(rest)), groups=groups[rest]))
    return train_idx, rest[val_rel], rest[test_rel]


def candidates(single_tree_only=False):
    for depth in (4, 6, 8):
        yield f"decision_tree(depth={depth})", DecisionTreeClassifier(
            max_depth=depth, min_samples_leaf=25, class_weight="balanced", random_state=SEED
        )
    if single_tree_only:
        return
    for depth in (6, 8):
        yield f"random_forest(trees=30,depth={depth})", RandomForestClassifier(
            n_estimators=30,
            max_depth=depth,
            min_samples_leaf=25,
            class_weight="balanced",
            random_state=SEED,
            n_jobs=-1,
        )


def run(name, feature_names, classes, rows, y, groups, rule_baseline, extra_meta, single_tree_only=False):
    X = np.array([[r[f] for f in feature_names] for r in rows], dtype=float)
    tr, va, te = split(groups, SEED)
    base_col = feature_names.index("is_baseline")

    results = []
    for label, model in candidates(single_tree_only=single_tree_only):
        model.fit(X[tr], y[tr])
        val_acc = accuracy_score(y[va], model.predict(X[va]))
        results.append((val_acc, label, model))
        print(f"  {name} {label}: validation accuracy {val_acc:.3f}")
    # Best validation accuracy; prefer the simpler (earlier) model within 0.005.
    best_acc = max(r[0] for r in results)
    val_acc, chosen_label, chosen = next(r for r in results if r[0] >= best_acc - 0.005)

    # Refit on train+validation, evaluate once on the untouched test split.
    trval = np.concatenate([tr, va])
    chosen.fit(X[trval], y[trval])
    test_pred = chosen.predict(X[te])
    is_base = X[te, base_col]

    metrics = {
        "model": evaluate(y[te], test_pred, is_base),
        "baseline_stay": evaluate(y[te], stay_baseline(X[te], feature_names), is_base),
        "baseline_rules": evaluate(y[te], rule_baseline(X[te], feature_names), is_base),
        "validation": {label: float(acc) for acc, label, _ in results},
    }

    artifact = {
        "model_id": name,
        "model_version": MODEL_VERSION,
        "algorithm": chosen_label,
        "trained_at": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "sklearn_version": sklearn.__version__,
        "seed": SEED,
        "feature_names": feature_names,
        "classes": classes,
        "data": {
            "source": "synthetic (expert-authored learner simulator, ml/math_memory/simulate.py)",
            "real_learner_data": False,
            "rows": {"train": int(len(trval)), "test": int(len(te))},
            "split": "by simulated child (no child in both train and test)",
        },
        "test_metrics": metrics["model"],
        **extra_meta,
        "trees": export_trees(chosen),
    }

    # Exported JSON must reproduce sklearn exactly.
    exported = np.array([predict_from_export(artifact, row)[0] for row in X[te]])
    agreement = float(np.mean(exported == test_pred))
    metrics["export_agreement_with_sklearn"] = agreement
    assert agreement == 1.0, f"{name}: exported model disagrees with sklearn ({agreement:.4f})"

    ASSET_DIR.mkdir(parents=True, exist_ok=True)
    (ASSET_DIR / f"{name}.json").write_text(_format_artifact(artifact))

    rng = np.random.default_rng(SEED)
    picks = rng.choice(te, size=min(300, len(te)), replace=False)
    cases = []
    for idx in picks:
        cls, probs = predict_from_export(artifact, X[idx])
        cases.append({"features": X[idx].tolist(), "expected_class": int(cls), "probabilities": probs})
    FIXTURE_DIR.mkdir(parents=True, exist_ok=True)
    (FIXTURE_DIR / f"{name}_parity.json").write_text(json.dumps({"model_id": name, "cases": cases}))

    return {"chosen": chosen_label, "validation_accuracy": float(val_acc), **metrics}


def write_report(report):
    REPORT_DIR.mkdir(exist_ok=True)
    (REPORT_DIR / "evaluation.json").write_text(json.dumps(report, indent=2))

    lines = [
        "# Math & Memory next-attempt models — evaluation",
        "",
        f"Model version {MODEL_VERSION}, scikit-learn {sklearn.__version__}, seed {SEED}.",
        "",
        "> **Synthetic data.** Trained and tested on simulated learners (see `simulate.py`).",
        "> These numbers show the model recovers the expert target from noisy attempt data;",
        "> they are **not** evidence of benefit for real children.",
        "",
    ]
    for name, r in report.items():
        lines += [
            f"## {name}",
            "",
            f"Chosen: `{r['chosen']}` (validation accuracy {r['validation_accuracy']:.3f}). "
            f"Exported JSON matches scikit-learn on {r['export_agreement_with_sklearn']:.0%} of test rows.",
            "",
            "| Test set | Accuracy | Macro-F1 | Mean abs. error (steps) | Within 1 step | Too hard | Too easy |",
            "|---|---|---|---|---|---|---|",
        ]
        for label, key in [("**Trained model**", "model"), ("Rules baseline", "baseline_rules"), ("Keep same", "baseline_stay")]:
            m = r[key]
            lines.append(
                f"| {label} | {m['accuracy']:.3f} | {m['macro_f1']:.3f} | {m['mean_abs_error_steps']:.3f} | "
                f"{m['within_one_step']:.3f} | {m['too_hard_rate']:.3f} | {m['too_easy_rate']:.3f} |"
            )
        m = r["model"]
        lines += [
            "",
            f"Model accuracy after a baseline attempt: {m['accuracy_after_baseline']:.3f}; "
            f"after a scored attempt: {m['accuracy_after_scored']:.3f}.",
            "",
            "Validation accuracy of all candidates: "
            + ", ".join(f"`{k}` {v:.3f}" for k, v in r["validation"].items())
            + ".",
            "",
        ]
    (REPORT_DIR / "evaluation.md").write_text("\n".join(lines))


def main():
    report = {}

    print("Number Quest: simulating…")
    rows, y, groups = generate_number_quest(n_children=4000, seed=SEED)
    report["number_quest_next_level"] = run(
        "number_quest_next_level",
        NQ_FEATURES,
        NQ_CLASSES,
        rows,
        y,
        groups,
        nq_rule_baseline,
        {"output": "next level = ref_level + class, clamped to 1..5 (one row per skill)"},
    )

    print("Memory Match: simulating…")
    rows, y, groups = generate_memory_match(n_children=8000, seed=SEED + 7)
    report["memory_match_next_config"] = run(
        "memory_match_next_config",
        MM_FEATURES,
        MM_CLASSES,
        rows,
        y,
        groups,
        mm_rule_baseline,
        {
            "output": "next rung = ref_rung + class (max ±3 after baseline, ±2 after scored), clamped to the ladder",
            "ladder": [{"positions": p, "memorize_seconds": s} for p, s in MEMORY_LADDER],
        },
        single_tree_only=True,
    )

    write_report(report)
    for name, r in report.items():
        m, rules, stay = r["model"], r["baseline_rules"], r["baseline_stay"]
        print(
            f"{name}: model acc {m['accuracy']:.3f} (rules {rules['accuracy']:.3f}, keep-same {stay['accuracy']:.3f}); "
            f"MAE {m['mean_abs_error_steps']:.3f}; too hard {m['too_hard_rate']:.3f}"
        )


if __name__ == "__main__":
    main()
