"""
OpenCV circle detector and coin cropper.

Detects the circular boundary of a coin in an image using the Hough Circle
Transform, then crops the image to a square bounding box around the detected
circle.  When no circle is detected the module falls back to a centre-square
crop – matching the logic used in the iOS OpenCV wrapper
(CoinScanAI/OpenCV/OpenCVWrapper.mm).
"""

import logging
from typing import Union

import cv2
import numpy as np

logger = logging.getLogger(__name__)


class CircleDetector:
    """Detects and crops coins from images using Hough Circle Transform."""

    def detect_and_crop(
        self,
        image: Union[str, np.ndarray],
        padding_ratio: float = 0.1,
    ) -> np.ndarray:
        """Detect the coin circle in *image* and return a cropped array.

        Args:
            image: Either a file path (str) or a BGR numpy array.
            padding_ratio: Extra padding around the detected circle as a
                fraction of the circle radius.

        Returns:
            BGR numpy array cropped to the coin area.
        """
        img = self._load(image)
        if img is None:
            raise ValueError("Could not load image")

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        gray_blurred = cv2.medianBlur(gray, 5)

        # Detect circles using HoughCircles – parameters mirror the iOS wrapper
        circles = cv2.HoughCircles(
            gray_blurred,
            cv2.HOUGH_GRADIENT,
            dp=1,
            minDist=100,
            param1=50,
            param2=30,
            minRadius=50,
            maxRadius=0,
        )

        if circles is not None:
            circles = np.uint16(np.around(circles))
            # Use the largest detected circle (by radius)
            largest = max(circles[0, :], key=lambda c: c[2])
            x, y, r = int(largest[0]), int(largest[1]), int(largest[2])

            padding = int(r * padding_ratio)
            x1 = max(0, x - r - padding)
            y1 = max(0, y - r - padding)
            x2 = min(img.shape[1], x + r + padding)
            y2 = min(img.shape[0], y + r + padding)

            cropped = img[y1:y2, x1:x2]
            logger.debug("Circle detected at (%d,%d) r=%d; cropped to %dx%d", x, y, r,
                         cropped.shape[1], cropped.shape[0])
            return cropped

        # Fallback: centre-square crop (matches iOS app behaviour)
        logger.debug("No circle detected; falling back to centre-square crop")
        h, w = img.shape[:2]
        size = min(h, w)
        x1 = (w - size) // 2
        y1 = (h - size) // 2
        return img[y1:y1 + size, x1:x1 + size]

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    @staticmethod
    def _load(image: Union[str, np.ndarray]) -> np.ndarray | None:
        if isinstance(image, str):
            return cv2.imread(image)
        if isinstance(image, np.ndarray):
            return image
        return None


# Convenience module-level function so callers can use
# ``circle_detector.detect_and_crop(img)`` without instantiation.
_default_detector = CircleDetector()


def detect_and_crop(image: Union[str, np.ndarray], padding_ratio: float = 0.1) -> np.ndarray:
    """Module-level convenience wrapper around :class:`CircleDetector`."""
    return _default_detector.detect_and_crop(image, padding_ratio=padding_ratio)
