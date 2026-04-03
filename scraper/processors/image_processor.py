"""
Image processor – resize, quality-filter, and convert coin images.

Applies the following pipeline to each cropped coin image:
  1. Validate minimum resolution.
  2. Check sharpness (Laplacian variance) and discard blurry images.
  3. Resize to the target size defined in config.yaml.
  4. Convert to JPEG-encoded bytes suitable for saving to disk.
"""

import logging

import cv2
import numpy as np
from PIL import Image

logger = logging.getLogger(__name__)


class ImageProcessor:
    """Resizes and quality-filters coin images."""

    def __init__(
        self,
        target_size: tuple[int, int] = (224, 224),
        min_resolution: tuple[int, int] = (200, 200),
        sharpness_threshold: float = 50.0,
        jpeg_quality: int = 85,
    ):
        """
        Args:
            target_size: Output (width, height) in pixels.
            min_resolution: Minimum acceptable (width, height).
            sharpness_threshold: Laplacian variance below this → image rejected.
            jpeg_quality: JPEG compression quality (1-95).
        """
        self.target_size = target_size
        self.min_resolution = min_resolution
        self.sharpness_threshold = sharpness_threshold
        self.jpeg_quality = jpeg_quality

    def process(self, image: np.ndarray) -> np.ndarray | None:
        """Apply the full processing pipeline.

        Args:
            image: BGR numpy array (as returned by OpenCV / circle_detector).

        Returns:
            Processed BGR numpy array, or *None* if the image was rejected.
        """
        if image is None or image.size == 0:
            logger.debug("Rejected: empty image")
            return None

        h, w = image.shape[:2]

        # 1. Minimum resolution check
        if w < self.min_resolution[0] or h < self.min_resolution[1]:
            logger.debug("Rejected: resolution %dx%d below minimum %dx%d",
                         w, h, *self.min_resolution)
            return None

        # 2. Sharpness check (Laplacian variance)
        gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        variance = cv2.Laplacian(gray, cv2.CV_64F).var()
        if variance < self.sharpness_threshold:
            logger.debug("Rejected: sharpness %.1f below threshold %.1f",
                         variance, self.sharpness_threshold)
            return None

        # 3. Resize to target size
        resized = cv2.resize(image, self.target_size, interpolation=cv2.INTER_LANCZOS4)
        return resized

    def encode_jpeg(self, image: np.ndarray) -> bytes:
        """Encode a BGR numpy array to JPEG bytes.

        Args:
            image: BGR numpy array.

        Returns:
            JPEG-encoded bytes.
        """
        success, buffer = cv2.imencode(
            '.jpg', image, [cv2.IMWRITE_JPEG_QUALITY, self.jpeg_quality]
        )
        if not success:
            raise RuntimeError("JPEG encoding failed")
        return buffer.tobytes()


# Convenience module-level function
_default_processor = ImageProcessor()


def process(image: np.ndarray) -> np.ndarray | None:
    """Module-level convenience wrapper around :class:`ImageProcessor`."""
    return _default_processor.process(image)
