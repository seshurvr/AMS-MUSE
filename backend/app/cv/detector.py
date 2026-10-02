"""Person detection.

IMPORTANT: this module only DETECTS people (bounding boxes). It never
identifies anyone — no facial recognition, no face embeddings, no biometric
templates, no automatic face-to-name matching. A teacher manually maps each
detection to a student in the UI.
"""
import math
from abc import ABC, abstractmethod
from typing import List

import cv2
import numpy as np

from app.config import settings


class BaseDetector(ABC):
    """Detector contract.

    ``detect`` returns a list of dicts, each with keys:
    ``x, y, width, height`` (floats, original-image pixels) and
    ``confidence`` (float 0..1).
    """

    @abstractmethod
    def detect(self, image_path: str) -> List[dict]:
        raise NotImplementedError


class HOGPersonDetector(BaseDetector):
    """OpenCV HOG + linear SVM default people detector.

    A YOLO-based detector can subclass :class:`BaseDetector` and be swapped
    in here later without touching the service layer.
    """

    def __init__(
        self,
        confidence_threshold: float | None = None,
        max_dimension: int = 1024,
        nms_threshold: float = 0.45,
    ) -> None:
        self.hog = cv2.HOGDescriptor()
        self.hog.setSVMDetector(cv2.HOGDescriptor_getDefaultPeopleDetector())
        self.threshold = (
            settings.DETECTION_CONFIDENCE_THRESHOLD
            if confidence_threshold is None
            else confidence_threshold
        )
        self.max_dimension = max_dimension
        self.nms_threshold = nms_threshold

    def _confidence(self, weight: float) -> float:
        # HOG returns raw SVM decision values; map to 0..1 with a sigmoid
        # centred on the hit threshold so the threshold itself => 0.5.
        return round(1.0 / (1.0 + math.exp(-(weight - self.threshold) * 3.0)), 3)

    def detect(self, image_path: str) -> List[dict]:
        img = cv2.imread(image_path)
        if img is None:
            # Unreadable/corrupt input: no detections, no exception (the
            # teacher can retake/re-upload; the API stays 200).
            return []

        orig_h, orig_w = img.shape[:2]
        scale = 1.0
        if max(orig_h, orig_w) > self.max_dimension:
            scale = self.max_dimension / max(orig_h, orig_w)
            img = cv2.resize(
                img,
                (int(orig_w * scale), int(orig_h * scale)),
                interpolation=cv2.INTER_AREA,
            )

        rects, weights = self.hog.detectMultiScale(
            img,
            winStride=(8, 8),
            padding=(8, 8),
            scale=1.05,
            hitThreshold=self.threshold,
        )

        if len(rects) == 0:
            return []

        boxes: list[list[float]] = []
        scores: list[float] = []
        for (x, y, w, h), weight in zip(rects, weights):
            boxes.append([float(x), float(y), float(w), float(h)])
            scores.append(self._confidence(float(weight)))

        # Suppress overlapping boxes.
        indices = cv2.dnn.NMSBoxes(boxes, scores, score_threshold=0.0,
                                   nms_threshold=self.nms_threshold)
        if len(indices) == 0:
            return []
        kept = sorted({int(i) for i in np.array(indices).flatten()})

        inv = 1.0 / scale
        results = []
        for i in kept:
            x, y, w, h = boxes[i]
            results.append(
                {
                    "x": round(x * inv, 2),
                    "y": round(y * inv, 2),
                    "width": round(w * inv, 2),
                    "height": round(h * inv, 2),
                    "confidence": scores[i],
                }
            )
        return results
