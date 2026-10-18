"""Trains and cross-validates 3 models × 2 feature sets (6 combinations).

Models: Logistic Regression, Random Forest, XGBoost.
Feature sets: A (correctness only) and B (A + behaviour) — see spell_features.py.

Validation: grouped K-fold by child (5 folds), so no child is ever in both
the training and the test part. The 5-fold split is repeated with different
random child assignments (default 3 repeats = 15 paired folds), because a
paired Wilcoxon test over only 5 folds can never reach p < 0.05.
Hyper-parameters are tuned with a small grid search INSIDE each training
fold only (inner grouped 3-fold CV), so the test children are never used for
tuning. Classes are balanced with class weights.

Outputs (results/):
  <tag>_fold_metrics.csv     one row per repeat × fold × model × feature set
  <tag>_oof_predictions.csv  test-fold predictions (for confusion matrices)

Usage:  python spell_train.py data/sim_labelled.csv --tag sim
        python spell_train.py data/sim_control_labelled.csv --tag sim_control --repeats 1
        python spell_train.py data/pilot_labelled.csv --tag pilot
"""
from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path

import numpy as np
import pandas as pd
from joblib import Parallel, delayed
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import accuracy_score, precision_recall_fscore_support
from sklearn.model_selection import GridSearchCV, GroupKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import StandardScaler
from sklearn.utils.class_weight import compute_sample_weight
from xgboost import XGBClassifier

from spell_common import CLASSES, RESULTS, banner_for, read_features_csv, write_csv_with_banner
from spell_features import build_matrix, recipes

FEATURE_SETS = ["A", "B"]
MODELS = ["LogisticRegression", "RandomForest", "XGBoost"]


def make_model(name: str, n_jobs: int = -1):
    """Estimator + small hyper-parameter grid. XGBoost settings keep the
    model exportable with m2cgen (num_parallel_tree / base_score set)."""
    if name == "LogisticRegression":
        est = Pipeline([
            ("scale", StandardScaler()),
            ("lr", LogisticRegression(max_iter=3000, class_weight="balanced")),
        ])
        return est, {"lr__C": [0.01, 0.1, 1.0]}
    if name == "RandomForest":
        est = RandomForestClassifier(
            n_estimators=100, min_samples_leaf=10, class_weight="balanced_subsample", n_jobs=n_jobs, random_state=0,
        )
        return est, {"max_depth": [6, 10]}
    if name == "XGBoost":
        est = XGBClassifier(
            n_estimators=150, learning_rate=0.1, subsample=0.8, colsample_bytree=1.0,
            # tree_method="exact": m2cgen reproduces "hist" trees wrongly (checked:
            # up to 0.04 probability difference vs 2e-7 with "exact").
            num_parallel_tree=1, base_score=0.5, tree_method="exact", n_jobs=n_jobs, random_state=0,
        )
        # min_child_weight lets the inner CV pick a more cautious model when
        # extra columns carry no signal (checked with the control set).
        return est, {"max_depth": [2, 3, 5], "min_child_weight": [1, 10], "reg_lambda": [1, 10]}
    raise ValueError(name)


def fit_tuned(name: str, X: np.ndarray, y: np.ndarray, groups: np.ndarray, n_jobs: int = -1):
    est, grid = make_model(name, n_jobs)
    search = GridSearchCV(est, grid, scoring="f1_macro", cv=GroupKFold(n_splits=3), n_jobs=1, refit=True)
    fit_params = {"sample_weight": compute_sample_weight("balanced", y)} if name == "XGBoost" else {}
    search.fit(X, y, groups=groups, **fit_params)
    return search.best_estimator_, search.best_params_


def run_job(rep, k, fs, name, X, y, children, train):
    """Tunes and trains one model on the training children, scores the test children."""
    te = ~train
    model, params = fit_tuned(name, X[train], y[train], children[train], n_jobs=1)
    proba = model.predict_proba(X[te])
    pred = proba.argmax(axis=1)
    p, r, f1, _ = precision_recall_fscore_support(y[te], pred, average="macro", zero_division=0)
    metric = {
        "repeat": rep, "fold": k, "model": name, "feature_set": fs,
        "accuracy": accuracy_score(y[te], pred), "precision_macro": p, "recall_macro": r,
        "f1_macro": f1, "best_params": json.dumps(params),
    }
    pred_df = pd.DataFrame({
        "repeat": rep, "fold": k, "model": name, "feature_set": fs,
        "row": np.flatnonzero(te), "childId": children[te],
        "y_true": [CLASSES[i] for i in y[te]], "y_pred": [CLASSES[i] for i in pred],
        **{f"p_{c}": proba[:, i] for i, c in enumerate(CLASSES)},
    })
    return metric, pred_df


def group_folds(children: np.ndarray, n_folds: int, seed: int) -> dict[str, int]:
    """Random child → fold assignment (a grouped K-fold with a seed)."""
    rng = np.random.default_rng(seed)
    unique = np.array(sorted(set(children)))
    rng.shuffle(unique)
    return {c: i % n_folds for i, c in enumerate(unique)}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("labelled_csv")
    ap.add_argument("--tag", required=True, help="prefix for result files, e.g. sim / sim_control / pilot")
    ap.add_argument("--folds", type=int, default=5)
    ap.add_argument("--repeats", type=int, default=3)
    ap.add_argument("--workers", type=int, default=max(1, (os.cpu_count() or 2) - 2),
                    help="parallel processes (default: all CPU cores but 2)")
    args = ap.parse_args()

    src = Path(args.labelled_csv)
    banner = banner_for(src)
    df = read_features_csv(src).reset_index(drop=True)
    y = df["label"].map({c: i for i, c in enumerate(CLASSES)}).to_numpy()
    children = df["childId"].astype(str).to_numpy()
    X = {fs: build_matrix(df, recipes(fs)) for fs in FEATURE_SETS}
    print(f"{src.name}: {len(df)} rows, {len(set(children))} children; A={X['A'].shape[1]} B={X['B'].shape[1]} features")

    # One job per repeat × fold × feature set × model, run in parallel on
    # separate processes (each model single-threaded). Results are the same
    # as running them one after another.
    jobs = []
    for rep in range(args.repeats):
        fold_of = group_folds(children, args.folds, seed=rep)
        fold = np.array([fold_of[c] for c in children])
        for k in range(args.folds):
            for fs in FEATURE_SETS:
                for name in MODELS:
                    jobs.append((rep, k, fs, name, fold != k))
    t0 = time.time()
    print(f"{len(jobs)} fits on {args.workers} workers…")
    results = Parallel(n_jobs=args.workers, verbose=5)(
        delayed(run_job)(rep, k, fs, name, X[fs], y, children, train) for rep, k, fs, name, train in jobs
    )
    metrics = [m for m, _ in results]
    preds = [p for _, p in results]
    for rep in range(args.repeats):
        for k in range(args.folds):
            done = [m for m in metrics if m["repeat"] == rep and m["fold"] == k]
            print(f"  repeat {rep} fold {k}: " + ", ".join(
                f"{m['model'][:3]}/{m['feature_set']} F1 {m['f1_macro']:.3f}" for m in done))
    print(f"done in {time.time() - t0:.0f}s")

    write_csv_with_banner(pd.DataFrame(metrics), RESULTS / f"{args.tag}_fold_metrics.csv", banner)
    write_csv_with_banner(pd.concat(preds, ignore_index=True), RESULTS / f"{args.tag}_oof_predictions.csv", banner)
    print(f"saved results/{args.tag}_fold_metrics.csv and results/{args.tag}_oof_predictions.csv")


if __name__ == "__main__":
    main()
