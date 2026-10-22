from __future__ import annotations

import sys
import tempfile
import unittest
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw


SCRIPTS_DIR = Path(__file__).resolve().parents[1] / "scripts"
sys.path.insert(0, str(SCRIPTS_DIR))

from prepare_dataset import (  # noqa: E402
    OUTPUT_SIZE,
    SkippedImageError,
    preprocess_image,
    validate_paths,
)


class PrepareDatasetTests(unittest.TestCase):
    def _save(self, directory: Path, name: str, image: Image.Image) -> Path:
        path = directory / name
        image.save(path)
        return path

    def _assert_standard_output(self, output: np.ndarray) -> None:
        self.assertEqual(output.shape, (OUTPUT_SIZE, OUTPUT_SIZE))
        self.assertEqual(output.dtype, np.uint8)
        self.assertGreaterEqual(int(output[0, 0]), 250)
        self.assertGreater(int(np.count_nonzero(output < 128)), 20)

    def test_transparent_image_is_composited_on_white(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            image = Image.new("RGBA", (120, 90), (0, 0, 0, 0))
            draw = ImageDraw.Draw(image)
            draw.line((35, 70, 60, 15, 85, 70), fill=(15, 15, 15, 255), width=7)
            source = self._save(directory, "transparent.png", image)

            self._assert_standard_output(preprocess_image(source))

    def test_white_handwriting_on_black_is_inverted(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            image = Image.new("RGB", (100, 140), "black")
            draw = ImageDraw.Draw(image)
            draw.ellipse((25, 20, 75, 115), outline="white", width=8)
            source = self._save(directory, "dark-background.png", image)

            output = preprocess_image(source)
            self._assert_standard_output(output)
            self.assertGreater(float(output.mean()), 180.0)

    def test_coloured_and_faint_handwriting_is_retained(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            image = Image.new("RGB", (160, 110), (225, 225, 225))
            draw = ImageDraw.Draw(image)
            draw.arc((35, 18, 125, 98), 35, 325, fill=(85, 115, 170), width=5)
            source = self._save(directory, "faint-blue-pencil.jpg", image)

            self._assert_standard_output(preprocess_image(source))

    def test_shape_is_centered_without_stretching(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            image = Image.new("L", (240, 80), 255)
            draw = ImageDraw.Draw(image)
            draw.rectangle((45, 30, 195, 49), fill=0)
            source = self._save(directory, "wide-stroke.png", image)

            output = preprocess_image(source)
            points = cv2.findNonZero(np.where(output < 128, 255, 0).astype(np.uint8))
            self.assertIsNotNone(points)
            x, y, width, height = cv2.boundingRect(points)
            self.assertGreater(width, height * 4)
            self.assertAlmostEqual(x + width / 2, OUTPUT_SIZE / 2, delta=2)
            self.assertAlmostEqual(y + height / 2, OUTPUT_SIZE / 2, delta=2)

    def test_blank_image_is_skipped(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            source = self._save(directory, "blank.png", Image.new("L", (80, 80), 255))
            with self.assertRaises(SkippedImageError):
                preprocess_image(source)

    def test_page_frame_and_remote_speck_do_not_control_crop(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            image = Image.new("L", (220, 220), 255)
            draw = ImageDraw.Draw(image)
            draw.line((0, 0, 219, 0, 219, 219), fill=0, width=3)
            draw.ellipse((65, 60, 155, 165), outline=0, width=7)
            draw.ellipse((12, 195, 14, 197), fill=0)
            source = self._save(directory, "framed-page.png", image)

            output = preprocess_image(source)
            ink = np.where(output < 128, 255, 0).astype(np.uint8)
            points = cv2.findNonZero(ink)
            self.assertIsNotNone(points)
            x, y, width, height = cv2.boundingRect(points)
            self.assertGreater(width, 100)
            self.assertGreater(height, 100)
            self.assertGreaterEqual(x, 20)
            self.assertGreaterEqual(y, 20)

    def test_output_cannot_be_inside_raw(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            raw = Path(temporary) / "raw"
            raw.mkdir()
            with self.assertRaises(ValueError):
                validate_paths(raw, raw / "processed")


if __name__ == "__main__":
    unittest.main()
