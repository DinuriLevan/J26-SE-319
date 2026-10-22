import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "split_dataset.py"
SPEC = importlib.util.spec_from_file_location("split_dataset", SCRIPT)
split_dataset = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
SPEC.loader.exec_module(split_dataset)


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


class SplitDatasetTests(unittest.TestCase):
    def test_target_counts_for_forty_images(self):
        self.assertEqual(split_dataset.target_counts(40, (0.70, 0.15, 0.15)), [28, 6, 6])

    def test_invalid_ratios_are_rejected(self):
        with self.assertRaises(ValueError):
            split_dataset.validate_ratios((0.70, 0.20, 0.20))

    def test_reproducible_copy_and_duplicate_grouping(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            source_class = root / "processed" / "english_uppercase" / "A"
            source_class.mkdir(parents=True)
            for index in range(20):
                (source_class / f"A_{index:05d}.png").write_bytes(f"image-{index}".encode())
            # These are distinct filenames with identical content and must remain together.
            (source_class / "A_duplicate_1.png").write_bytes(b"duplicate-family")
            (source_class / "A_duplicate_2.png").write_bytes(b"duplicate-family")

            source_before = {
                path.name: digest(path) for path in source_class.iterdir() if path.is_file()
            }
            mappings = []
            for run_number in (1, 2):
                args = split_dataset.parse_args(
                    [
                        "--input", str(root / "processed"),
                        "--output", str(root / f"split-{run_number}"),
                        "--report", str(root / f"report-{run_number}.json"),
                    ]
                )
                report = split_dataset.run(args)
                self.assertEqual(report["total_images"], 22)
                mapping = {}
                for split_name in split_dataset.SPLIT_NAMES:
                    folder = root / f"split-{run_number}" / "english_uppercase" / split_name / "A"
                    for path in folder.iterdir():
                        mapping[path.name] = split_name
                mappings.append(mapping)
                self.assertEqual(len(mapping), 22)
                self.assertEqual(mapping["A_duplicate_1.png"], mapping["A_duplicate_2.png"])

            self.assertEqual(mappings[0], mappings[1])
            source_after = {
                path.name: digest(path) for path in source_class.iterdir() if path.is_file()
            }
            self.assertEqual(source_before, source_after)

    def test_small_class_is_reported_without_crashing(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            class_dir = root / "processed" / "sinhala" / "අ"
            class_dir.mkdir(parents=True)
            for index in range(5):
                (class_dir / f"අ_{index}.png").write_bytes(f"sample-{index}".encode())
            staging = root / "staging"
            staging.mkdir()
            report = split_dataset.build_split(
                root / "processed", staging, (0.70, 0.15, 0.15), 42
            )
            self.assertEqual(report["total_images"], 5)
            self.assertTrue(any("only contains 5" in item for item in report["warnings"]))


if __name__ == "__main__":
    unittest.main()
