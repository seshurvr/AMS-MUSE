"""Unit tests for the CV layer: HOG detector + image quality.

Contract: person detection only (bounding boxes, never identity). Both
functions must be graceful on blank or corrupt input — no exceptions.
"""
import pytest

from app.cv.detector import HOGPersonDetector
from app.cv.image_quality import analyze

from .conftest import make_classroom_png

DETECTION_KEYS = {"x", "y", "width", "height", "confidence"}
QUALITY_KEYS = {"width", "height", "brightness", "blur_score", "warnings"}


@pytest.fixture(scope="module")
def detector():
    return HOGPersonDetector()


def _write(tmp_path, name: str, data: bytes) -> str:
    p = tmp_path / name
    p.write_bytes(data)
    return str(p)


def test_hog_blank_image_returns_empty_list(detector, tmp_path):
    """A blank image has no people: expect [], not an exception."""
    path = _write(tmp_path, "blank.png", make_classroom_png(people=0))
    assert detector.detect(path) == []


def test_hog_synthetic_image_no_exception(detector, tmp_path):
    """Synthetic drawings may yield 0 detections; the call must not blow up."""
    path = _write(tmp_path, "synth.png", make_classroom_png(people=3))
    dets = detector.detect(path)
    assert isinstance(dets, list)
    for d in dets:
        assert DETECTION_KEYS <= set(d), f"bad detection keys: {d}"
        assert d["width"] > 0 and d["height"] > 0
        assert 0.0 <= d["confidence"] <= 1.0


def test_hog_corrupt_input_no_exception(detector, tmp_path):
    path = _write(tmp_path, "corrupt.png", b"this is not an image at all")
    assert detector.detect(path) == []


def test_hog_missing_file_no_exception(detector, tmp_path):
    assert detector.detect(str(tmp_path / "does-not-exist.png")) == []


def test_image_quality_keys(detector, tmp_path):
    path = _write(tmp_path, "room.png", make_classroom_png())
    q = analyze(path)
    assert QUALITY_KEYS <= set(q), f"bad quality keys: {q}"
    assert q["width"] == 640 and q["height"] == 480
    assert 0 <= q["brightness"] <= 255
    assert q["blur_score"] >= 0
    assert isinstance(q["warnings"], list)


def test_image_quality_dark_image_warns(detector, tmp_path):
    dark = make_classroom_png()
    # Darken heavily via raw bytes manipulation is overkill; use a black PNG.
    import cv2
    import numpy as np

    black = np.zeros((480, 640, 3), dtype=np.uint8)
    ok, buf = cv2.imencode(".png", black)
    assert ok
    path = _write(tmp_path, "dark.png", bytes(buf))
    q = analyze(path)
    assert q["brightness"] < 60
    assert any("dark" in w.lower() for w in q["warnings"])


def test_image_quality_corrupt_input_no_exception(detector, tmp_path):
    path = _write(tmp_path, "corrupt.png", b"garbage bytes")
    q = analyze(path)
    assert QUALITY_KEYS <= set(q)
    assert isinstance(q["warnings"], list) and q["warnings"]
