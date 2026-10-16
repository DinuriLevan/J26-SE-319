# AkuRin handwriting dataset preprocessing

The preprocessing pipeline reads all class folders below
`datasets/raw/` and creates consistent `224x224` PNG images below
`datasets/processed/`. Raw images are opened read-only and are never renamed,
overwritten, or deleted.

## Setup

From the project root, create or activate a Python 3.10+ virtual environment,
then install only the handwriting preprocessing dependencies:

```powershell
python -m pip install -r ml/handwriting/requirements.txt
```

Do not install this file as the backend requirements file; the ML environment
is intentionally separate.

## Run

Process every discovered class and create a 25-image preview:

```powershell
python ml/handwriting/scripts/prepare_dataset.py
```

Run a quick smoke test with at most two images per class:

```powershell
python ml/handwriting/scripts/prepare_dataset.py --limit-per-class 2
```

Disable preview generation when needed:

```powershell
python ml/handwriting/scripts/prepare_dataset.py --preview-count 0
```

The script reports progress and prints every skipped or failed source path with
its reason. By default it continues past corrupt files. Add `--fail-on-error`
for CI jobs that should return a non-zero exit code when a file fails.

## Outputs

- Processed images: `ml/handwriting/datasets/processed/<dataset>/<class>/`
- Quality preview: `ml/handwriting/results/preprocessing_preview.png`
- JSON report: `ml/handwriting/results/preprocessing_report.json`

Processed filenames are deterministic and class-local, such as `A_00001.png`
or `ක_00001.png`. Existing processed files with the same generated name may be
replaced on a later run, but files under `datasets/raw/` are never changed.

## Tests

After installing dependencies:

```powershell
python -m unittest discover -s ml/handwriting/tests -v
```
