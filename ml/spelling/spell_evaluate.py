"""Turns the cross-validation results into Table 1 and the A-vs-B comparison.

For each of the 6 combinations (3 models × feature sets A/B):
  accuracy, macro precision, macro recall, macro F1 (mean ± std over folds),
  confusion matrix and per-class report (test-fold predictions, first repeat).
A vs B per model: paired Wilcoxon signed-rank test on macro F1 over the
repeated folds (same children in the same test fold for A and B).
SHAP summary plot for the best model (refit on all data).
The control set (behaviour has no signal) is checked the same way: adding
behaviour there must not make the model worse.

Outputs (results/): <tag>_table1.csv/.md, <tag>_ab_tests.csv, <tag>_per_class.csv,
<tag>_confusion.csv/.png, shap_summary.png, shap_top_features.csv,
best_model.json, RESULTS.md

Usage:  python spell_evaluate.py --tag sim --control-tag sim_control --data data/sim_labelled.csv
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402
from scipy.stats import wilcoxon  # noqa: E402
from sklearn.metrics import classification_report, confusion_matrix  # noqa: E402

from spell_common import CLASSES, RESULTS, banner_for, read_features_csv, write_csv_with_banner, write_json  # noqa: E402
from spell_features import build_matrix, recipes  # noqa: E402
from spell_train import MODELS, fit_tuned  # noqa: E402

METRICS = ["accuracy", "precision_macro", "recall_macro", "f1_macro"]


def table1(m: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for (model, fs), g in m.groupby(["model", "feature_set"], sort=False):
        row = {"model": model, "feature_set": fs, "folds": len(g)}
        for k in METRICS:
            row[f"{k}_mean"] = g[k].mean()
            row[f"{k}_std"] = g[k].std(ddof=1)
        rows.append(row)
    order = {m: i for i, m in enumerate(MODELS)}
    return pd.DataFrame(rows).sort_values(["model", "feature_set"], key=lambda s: s.map(order) if s.name == "model" else s)


def ab_tests(m: pd.DataFrame) -> pd.DataFrame:
    rows = []
    for model in MODELS:
        a = m[(m.model == model) & (m.feature_set == "A")].set_index(["repeat", "fold"])["f1_macro"]
        b = m[(m.model == model) & (m.feature_set == "B")].set_index(["repeat", "fold"])["f1_macro"]
        a, b = a.align(b, join="inner")
        diff = b - a
        try:
            p_two = wilcoxon(b, a, alternative="two-sided").pvalue
            p_worse = wilcoxon(b, a, alternative="less").pvalue  # is B worse than A?
        except ValueError:  # all differences zero
            p_two = p_worse = 1.0
        rows.append({
            "model": model, "pairs": len(diff), "f1_A": a.mean(), "f1_B": b.mean(),
            "mean_diff_B_minus_A": diff.mean(), "median_diff": diff.median(),
            "B_better_in": int((diff > 0).sum()), "wilcoxon_p_two_sided": p_two, "wilcoxon_p_B_worse": p_worse,
        })
    return pd.DataFrame(rows)


def fmt(mean: float, std: float) -> str:
    return f"{mean:.3f} ± {std:.3f}"


def table1_markdown(t: pd.DataFrame, banner: str, title: str) -> str:
    lines = [f"**{banner}**", "", f"### {title}", "",
             "| Model | Features | Accuracy | Macro precision | Macro recall | Macro F1 |",
             "|---|---|---|---|---|---|"]
    for _, r in t.iterrows():
        fs = "A (correctness)" if r.feature_set == "A" else "B (+ behaviour)"
        lines.append(f"| {r.model} | {fs} | " + " | ".join(fmt(r[f'{k}_mean'], r[f'{k}_std']) for k in METRICS) + " |")
    lines.append("")
    lines.append(f"Mean ± standard deviation over {int(t['folds'].iloc[0])} grouped test folds (children never in both train and test).")
    return "\n".join(lines)


def ab_markdown(ab: pd.DataFrame) -> str:
    lines = ["| Model | F1 A | F1 B | B − A | B better in | Wilcoxon p (two-sided) | p (B worse) |",
             "|---|---|---|---|---|---|---|"]
    for _, r in ab.iterrows():
        lines.append(f"| {r.model} | {r.f1_A:.3f} | {r.f1_B:.3f} | {r.mean_diff_B_minus_A:+.3f} | "
                     f"{r.B_better_in}/{r.pairs} folds | {r.wilcoxon_p_two_sided:.4f} | {r.wilcoxon_p_B_worse:.4f} |")
    return "\n".join(lines)


def confusion(tag: str, preds: pd.DataFrame, banner: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    first = preds[preds["repeat"] == 0]
    cm_rows, report_rows = [], []
    fig, axes = plt.subplots(2, 3, figsize=(13, 8.5))
    for j, model in enumerate(MODELS):
        for i, fs in enumerate(["A", "B"]):
            g = first[(first.model == model) & (first.feature_set == fs)]
            cm = confusion_matrix(g.y_true, g.y_pred, labels=CLASSES)
            for t, row in zip(CLASSES, cm):
                cm_rows.append({"model": model, "feature_set": fs, "true": t, **{f"pred_{c}": int(v) for c, v in zip(CLASSES, row)}})
            rep = classification_report(g.y_true, g.y_pred, labels=CLASSES, output_dict=True, zero_division=0)
            for c in CLASSES:
                report_rows.append({"model": model, "feature_set": fs, "class": c, **{k: rep[c][k] for k in ["precision", "recall", "f1-score", "support"]}})
            ax = axes[i, j]
            norm = cm / cm.sum(axis=1, keepdims=True).clip(min=1)
            ax.imshow(norm, cmap="Blues", vmin=0, vmax=1)
            for a in range(3):
                for b in range(3):
                    ax.text(b, a, f"{cm[a, b]}\n{norm[a, b]:.0%}", ha="center", va="center",
                            color="white" if norm[a, b] > 0.5 else "black", fontsize=9)
            ax.set_xticks(range(3), CLASSES)
            ax.set_yticks(range(3), CLASSES)
            ax.set_xlabel("predicted")
            ax.set_ylabel("true")
            ax.set_title(f"{model} · {'A correctness' if fs == 'A' else 'B + behaviour'}", fontsize=10)
    fig.suptitle(f"Confusion matrices ({tag}, test folds of repeat 1)\n{banner}", fontsize=11)
    fig.tight_layout()
    fig.savefig(RESULTS / f"{tag}_confusion.png", dpi=130)
    plt.close(fig)
    return pd.DataFrame(cm_rows), pd.DataFrame(report_rows)


def shap_plot(data: Path, model_name: str, fs: str, banner: str) -> pd.DataFrame:
    import shap

    df = read_features_csv(data)
    rs = recipes(fs)
    names = [r["name"] for r in rs]
    X = build_matrix(df, rs)
    y = df["label"].map({c: i for i, c in enumerate(CLASSES)}).to_numpy()
    model, _ = fit_tuned(model_name, X, y, df["childId"].astype(str).to_numpy())
    sample = X[np.random.default_rng(0).choice(len(X), size=min(1000, len(X)), replace=False)]
    if model_name == "LogisticRegression":
        scaler, lr = model.named_steps["scale"], model.named_steps["lr"]
        values = shap.LinearExplainer(lr, scaler.transform(X)).shap_values(scaler.transform(sample))
    else:
        values = shap.TreeExplainer(model).shap_values(sample)
    arr = np.array(values)
    if arr.ndim == 3 and arr.shape[0] == len(CLASSES):  # (classes, rows, features)
        arr = np.moveaxis(arr, 0, -1)
    # arr: (rows, features, classes) → mean |SHAP| per feature and class
    imp = np.abs(arr).mean(axis=0)
    out = pd.DataFrame(imp, columns=[f"mean_abs_shap_{c}" for c in CLASSES])
    out.insert(0, "feature", names)
    out["mean_abs_shap_all"] = imp.sum(axis=1)
    out = out.sort_values("mean_abs_shap_all", ascending=False)

    top = out.head(20).iloc[::-1]
    fig, ax = plt.subplots(figsize=(9, 7))
    left = np.zeros(len(top))
    for c, color in zip(CLASSES, ["#6BCB77", "#FFB347", "#E8604C"]):
        ax.barh(top.feature, top[f"mean_abs_shap_{c}"], left=left, color=color, label=c)
        left += top[f"mean_abs_shap_{c}"].to_numpy()
    ax.set_xlabel("mean |SHAP value| (impact on the predicted class)")
    ax.legend(title="class")
    ax.set_title(f"Top 20 features — {model_name}, feature set {fs}\n{banner}", fontsize=10)
    fig.tight_layout()
    fig.savefig(RESULTS / "shap_summary.png", dpi=130)
    plt.close(fig)
    return out


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--tag", default="sim")
    ap.add_argument("--control-tag", default="sim_control")
    ap.add_argument("--data", default="data/sim_labelled.csv")
    args = ap.parse_args()
    banner = banner_for(args.data)

    out = {}
    for tag in [args.tag, args.control_tag]:
        mpath = RESULTS / f"{tag}_fold_metrics.csv"
        if not mpath.exists():
            print(f"skip {tag}: {mpath.name} not found")
            continue
        m = pd.read_csv(mpath, comment="#")
        t, ab = table1(m), ab_tests(m)
        write_csv_with_banner(t, RESULTS / f"{tag}_table1.csv", banner)
        (RESULTS / f"{tag}_table1.md").write_text(table1_markdown(t, banner, f"Table 1 — {tag}"), encoding="utf-8")
        write_csv_with_banner(ab, RESULTS / f"{tag}_ab_tests.csv", banner)
        preds = pd.read_csv(RESULTS / f"{tag}_oof_predictions.csv", comment="#")
        cm, rep = confusion(tag, preds, banner)
        write_csv_with_banner(cm, RESULTS / f"{tag}_confusion.csv", banner)
        write_csv_with_banner(rep, RESULTS / f"{tag}_per_class.csv", banner)
        out[tag] = (t, ab, rep)
        print(f"\n{tag}\n{table1_markdown(t, banner, 'Table 1')}\n\n{ab_markdown(ab)}")

    t, ab, rep = out[args.tag]
    best = t.sort_values("f1_macro_mean", ascending=False).iloc[0]
    write_json({"model": best.model, "feature_set": best.feature_set, "cv_f1_macro": best.f1_macro_mean,
                "chosen_on": args.data, "note": banner}, RESULTS / "best_model.json")
    shap_top = shap_plot(Path(args.data), best.model, best.feature_set, banner)
    write_csv_with_banner(shap_top, RESULTS / "shap_top_features.csv", banner)

    md = [f"# Spelling difficulty classifier — results", "", f"> **{banner}**", "",
          "Task: from one word's interaction log, predict how hard that skill currently is for the child "
          "(easy / medium / hard = how the child does on their next 3 words of the same skill).", "",
          table1_markdown(t, banner, f"Table 1 — {args.tag} (behaviour carries a signal)"), "",
          "### Does behaviour help? (feature set B vs A, paired over the same test folds)", "", ab_markdown(ab), ""]
    if args.control_tag in out:
        tc, abc, _ = out[args.control_tag]
        md += [table1_markdown(tc, banner, f"Control — {args.control_tag} (behaviour is random noise)"), "",
               "### Control: adding behaviour must not make it worse", "", ab_markdown(abc), "",
               "On the control set, behaviour features carry no information, so B should match A "
               "(no significant drop: `p (B worse)` well above 0.05).", ""]
    md += [f"### Best model: {best.model}, feature set {best.feature_set} (macro F1 {best.f1_macro_mean:.3f})", "",
           f"![confusion]({args.tag}_confusion.png)", "", "![shap](shap_summary.png)", "",
           "Top features (mean |SHAP|, all classes): " + ", ".join(shap_top.feature.head(8)), ""]
    (RESULTS / "RESULTS.md").write_text("\n".join(md), encoding="utf-8")
    print(f"\nbest: {best.model} / {best.feature_set}; wrote results/RESULTS.md")


if __name__ == "__main__":
    main()
