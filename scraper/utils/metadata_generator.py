"""
Metadata generator – writes per-image JSON sidecar files.

For each saved coin image, a corresponding ``<filename>.json`` file is
created in the same directory.  The JSON contains all known metadata about
the image: coin type, variety, year, mint mark, error type, source URL, and
computed visual features.
"""

import json
import logging
from datetime import datetime
from pathlib import Path
from typing import Any

logger = logging.getLogger(__name__)


class MetadataGenerator:
    """Writes JSON sidecar metadata files alongside saved coin images."""

    def write(
        self,
        image_path: Path,
        img_data: dict[str, Any],
        features: dict[str, Any] | None = None,
    ) -> Path | None:
        """Write a JSON sidecar file for *image_path*.

        Args:
            image_path: Full path to the saved image file.
            img_data: Raw metadata dict from the scraper (source, coin_name,
                variety, year, mint_mark, error_type, condition, original_url).
            features: Optional feature dict from :class:`FeatureExtractor`.

        Returns:
            Path to the written JSON file, or None on failure.
        """
        meta: dict[str, Any] = {
            'coin_name': img_data.get('coin_name', 'Unknown'),
            'variety': img_data.get('variety', 'Unknown'),
            'year': img_data.get('year', 'Unknown'),
            'mint_mark': img_data.get('mint_mark', ''),
            'error_type': img_data.get('error_type', 'Mint_Condition'),
            'condition': img_data.get('condition', 'Unknown'),
            'source': img_data.get('source', 'Unknown'),
            'original_url': img_data.get('original_url', ''),
            'image_file': image_path.name,
            'scraped_at': datetime.utcnow().isoformat() + 'Z',
        }

        if features:
            # Store lightweight features; skip large histogram array to keep
            # JSON files small – full hist can be regenerated from the image.
            meta['features'] = {
                'phash': features.get('phash', ''),
                'sharpness': features.get('sharpness', 0.0),
                'hu_moments': features.get('hu_moments', []),
            }

        json_path = image_path.with_suffix('.json')
        try:
            json_path.write_text(json.dumps(meta, indent=2))
            logger.debug("Metadata written to %s", json_path)
            return json_path
        except OSError as exc:
            logger.error("Failed to write metadata for %s: %s", image_path, exc)
            return None

    def read(self, image_path: Path) -> dict[str, Any] | None:
        """Read and return the JSON sidecar for *image_path*.

        Args:
            image_path: Path to the image file.

        Returns:
            Parsed metadata dict, or None if not found.
        """
        json_path = image_path.with_suffix('.json')
        if not json_path.exists():
            return None
        try:
            return json.loads(json_path.read_text())
        except (json.JSONDecodeError, OSError) as exc:
            logger.error("Failed to read metadata %s: %s", json_path, exc)
            return None
