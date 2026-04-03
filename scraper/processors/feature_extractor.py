"""
Feature extractor – computes visual features from coin images.

Extracts a compact feature vector that describes a coin image.  These
features are used by the deduplicator and can be stored in the per-image
metadata JSON for downstream machine-learning tasks.

Features extracted:
- Perceptual hash (via imagehash library) – compact image fingerprint.
- Colour histogram (HSV) – 3 × 32 bins = 96-dimensional vector.
- Laplacian sharpness score.
- Hu moments – shape/texture descriptor (7 values).
"""

import logging
from typing import Any

import cv2
import imagehash
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)


class FeatureExtractor:
    """Computes visual feature descriptors for a coin image."""

    def extract(self, image: np.ndarray) -> dict[str, Any]:
        """Extract features from a BGR numpy array.

        Args:
            image: BGR numpy array.

        Returns:
            dict containing:
                'phash'      – perceptual hash hex string
                'hist'       – list[float], normalised HSV histogram
                'sharpness'  – float, Laplacian variance
                'hu_moments' – list[float], 7 Hu moment values
        """
        features: dict[str, Any] = {}

        # Perceptual hash
        pil_img = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        features['phash'] = str(imagehash.phash(pil_img))

        # HSV colour histogram
        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)
        hist = []
        for ch in range(3):
            ch_hist = cv2.calcHist([hsv], [ch], None, [32], [0, 256])
            cv2.normalize(ch_hist, ch_hist)
            hist.extend(ch_hist.flatten().tolist())
        features['hist'] = hist

        # Sharpness
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        features['sharpness'] = float(cv2.Laplacian(gray, cv2.CV_64F).var())

        # Hu moments
        moments = cv2.moments(gray)
        hu = cv2.HuMoments(moments).flatten().tolist()
        features['hu_moments'] = hu

        return features

    def phash(self, image: np.ndarray) -> imagehash.ImageHash:
        """Return the perceptual hash object for *image*."""
        pil_img = Image.fromarray(cv2.cvtColor(image, cv2.COLOR_BGR2RGB))
        return imagehash.phash(pil_img)
