"""
Deduplicator – removes near-duplicate coin images using perceptual hashing.

Two images are considered duplicates if their perceptual hash (pHash) Hamming
distance is ≤ *threshold* bits.  The default threshold of 10 bits tolerates
minor JPEG artefacts and slight differences in cropping while still catching
true duplicates.
"""

import logging
from pathlib import Path
from typing import Iterator

import imagehash
import numpy as np
from PIL import Image

from processors.feature_extractor import FeatureExtractor

logger = logging.getLogger(__name__)


class Deduplicator:
    """Tracks seen images and detects near-duplicates via perceptual hashing."""

    def __init__(self, threshold: int = 10):
        """
        Args:
            threshold: Maximum Hamming distance between pHashes to be
                considered a duplicate (0 = exact match only).
        """
        self.threshold = threshold
        self._seen: list[imagehash.ImageHash] = []
        self._extractor = FeatureExtractor()

    def is_duplicate(self, image: np.ndarray) -> bool:
        """Return True if *image* is a near-duplicate of a previously seen image.

        If not a duplicate, the image's hash is recorded for future checks.

        Args:
            image: BGR numpy array.

        Returns:
            True if the image is a duplicate; False otherwise.
        """
        new_hash = self._extractor.phash(image)
        for seen_hash in self._seen:
            if abs(new_hash - seen_hash) <= self.threshold:
                logger.debug("Duplicate detected (distance=%d)", abs(new_hash - seen_hash))
                return True
        self._seen.append(new_hash)
        return False

    def filter(self, images: Iterator[np.ndarray]) -> Iterator[np.ndarray]:
        """Yield only unique images from *images*.

        Args:
            images: Iterable of BGR numpy arrays.

        Yields:
            Non-duplicate BGR numpy arrays.
        """
        for image in images:
            if not self.is_duplicate(image):
                yield image

    def reset(self) -> None:
        """Clear the internal seen-hash registry."""
        self._seen.clear()

    def scan_directory(self, directory: Path) -> None:
        """Pre-populate the seen-hash registry from existing images on disk.

        Useful when resuming a scrape so already-downloaded images are not
        re-downloaded as duplicates.

        Args:
            directory: Path to a directory of JPEG/PNG images.
        """
        import cv2

        for img_path in sorted(directory.rglob('*.jpg')):
            img = cv2.imread(str(img_path))
            if img is not None:
                h = self._extractor.phash(img)
                self._seen.append(h)
        logger.info("Deduplicator pre-loaded %d hashes from %s", len(self._seen), directory)
