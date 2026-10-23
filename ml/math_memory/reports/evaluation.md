# Math & Memory next-attempt models — evaluation

Model version 1.0.0, scikit-learn 1.5.2, seed 20261018.

> **Synthetic data.** Trained and tested on simulated learners (see `simulate.py`).
> These numbers show the model recovers the expert target from noisy attempt data;
> they are **not** evidence of benefit for real children.

## number_quest_next_level

Chosen: `decision_tree(depth=6)` (validation accuracy 0.792). Exported JSON matches scikit-learn on 100% of test rows.

| Test set | Accuracy | Macro-F1 | Mean abs. error (steps) | Within 1 step | Too hard | Too easy |
|---|---|---|---|---|---|---|
| **Trained model** | 0.795 | 0.753 | 0.223 | 0.982 | 0.130 | 0.074 |
| Rules baseline | 0.671 | 0.591 | 0.387 | 0.942 | 0.294 | 0.034 |
| Keep same | 0.197 | 0.110 | 0.803 | 1.000 | 0.460 | 0.343 |

Model accuracy after a baseline attempt: 0.737; after a scored attempt: 0.814.

Validation accuracy of all candidates: `decision_tree(depth=4)` 0.764, `decision_tree(depth=6)` 0.792, `decision_tree(depth=8)` 0.787, `random_forest(trees=30,depth=6)` 0.791, `random_forest(trees=30,depth=8)` 0.794.

## memory_match_next_config

Chosen: `random_forest(trees=30,depth=8)` (validation accuracy 0.739). Exported JSON matches scikit-learn on 100% of test rows.

| Test set | Accuracy | Macro-F1 | Mean abs. error (steps) | Within 1 step | Too hard | Too easy |
|---|---|---|---|---|---|---|
| **Trained model** | 0.725 | 0.629 | 0.391 | 0.899 | 0.131 | 0.144 |
| Rules baseline | 0.145 | 0.100 | 1.055 | 0.806 | 0.418 | 0.437 |
| Keep same | 0.078 | 0.021 | 1.801 | 0.271 | 0.433 | 0.489 |

Model accuracy after a baseline attempt: 0.668; after a scored attempt: 0.744.

Validation accuracy of all candidates: `decision_tree(depth=4)` 0.719, `decision_tree(depth=6)` 0.729, `decision_tree(depth=8)` 0.727, `random_forest(trees=30,depth=6)` 0.734, `random_forest(trees=30,depth=8)` 0.739.
