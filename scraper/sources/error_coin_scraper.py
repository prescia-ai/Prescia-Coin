"""
Error coin scraper – searches Wikimedia Commons for known error coin images.

Error coins are minting mistakes that make coins valuable to collectors.
This scraper queries Wikimedia Commons categories that specifically contain
photographs of error coins, so all images remain freely licensed.
"""

import io
import time
import logging
from typing import Generator

import numpy as np
import requests
from PIL import Image

logger = logging.getLogger(__name__)

_API_URL = "https://commons.wikimedia.org/w/api.php"

# Known error types and associated Wikimedia Commons search terms / categories.
# The scraper combines coin variety name with these keywords to find images.
ERROR_TYPES = [
    'Doubled_Die',
    'Off_Center_Strike',
    'Clipped_Planchet',
    'Wrong_Planchet',
    'Die_Crack_Cud',
    'Broadstrike',
    'Lamination_Error',
    'Struck_Through',
    'Multiple_Strike',
    'Missing_Clad_Layer',
    'Repunched_Mint_Mark',
    'Other_Errors',
]

# Map internal error type names to Wikimedia search keywords
_ERROR_KEYWORDS = {
    'Doubled_Die': 'doubled die',
    'Off_Center_Strike': 'off center strike',
    'Clipped_Planchet': 'clipped planchet',
    'Wrong_Planchet': 'wrong planchet',
    'Die_Crack_Cud': 'die crack cud',
    'Broadstrike': 'broadstrike',
    'Lamination_Error': 'lamination error',
    'Struck_Through': 'struck through',
    'Multiple_Strike': 'double struck',
    'Missing_Clad_Layer': 'missing clad layer',
    'Repunched_Mint_Mark': 'repunched mint mark',
    'Other_Errors': 'mint error',
}

# Only certain coin types have clad layers
_CLAD_COINS = {'Quarter', 'Half_Dollar', 'Dime'}


class ErrorCoinScraper:
    """Scrapes error coin images from Wikimedia Commons."""

    def __init__(self, rate_limit: float = 1.0):
        self.rate_limit = rate_limit
        self._session = requests.Session()
        self._session.headers.update({'User-Agent': 'PresciaAI-CoinScraper/1.0 (educational)'})

    def scrape(self, coin_config: dict, limit: int | None = None) -> Generator[dict, None, None]:
        """Yield error coin image data for the given coin configuration.

        Args:
            coin_config: Dict with 'name' and 'variety' keys.
            limit: Maximum images to yield per error type.

        Yields:
            dict with image array and metadata.
        """
        coin_name = coin_config['name']
        variety = coin_config['variety']
        # Produce a human-readable coin label for keyword construction
        coin_label = variety.replace('_', ' ')

        per_error_limit = max(1, (limit or 20))
        count = 0

        for error_type in ERROR_TYPES:
            # Skip Missing_Clad_Layer for non-clad coins
            if error_type == 'Missing_Clad_Layer' and coin_name not in _CLAD_COINS:
                continue

            keyword = _ERROR_KEYWORDS[error_type]
            search_query = f"{coin_label} {keyword}"

            for file_info in self._search_images(search_query):
                if count >= per_error_limit:
                    break
                image_array = self._download_image(file_info['url'])
                if image_array is None:
                    continue
                yield {
                    'image': image_array,
                    'source': 'wikimedia_error',
                    'coin_name': coin_name,
                    'variety': variety,
                    'year': 'Unknown',
                    'mint_mark': '',
                    'error_type': error_type,
                    'condition': 'Unknown',
                    'original_url': file_info['url'],
                }
                count += 1
                time.sleep(1.0 / self.rate_limit)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _search_images(self, query: str) -> Generator[dict, None, None]:
        """Use Wikimedia Commons full-text search to find coin error images."""
        params = {
            'action': 'query',
            'list': 'search',
            'srsearch': f'filetype:bitmap {query}',
            'srnamespace': 6,  # File namespace
            'srlimit': 20,
            'format': 'json',
        }
        try:
            resp = self._session.get(_API_URL, params=params, timeout=30)
            resp.raise_for_status()
            results = resp.json().get('query', {}).get('search', [])
            for result in results:
                title = result.get('title', '')
                url = self._get_image_url(title)
                if url:
                    yield {'url': url, 'title': title}
        except requests.RequestException as exc:
            logger.error("Error coin search failed for '%s': %s", query, exc)

    def _get_image_url(self, title: str) -> str | None:
        """Resolve the direct URL of a Wikimedia file."""
        params = {
            'action': 'query',
            'titles': title,
            'prop': 'imageinfo',
            'iiprop': 'url',
            'format': 'json',
        }
        try:
            resp = self._session.get(_API_URL, params=params, timeout=30)
            resp.raise_for_status()
            pages = resp.json().get('query', {}).get('pages', {})
            for page in pages.values():
                imageinfo = page.get('imageinfo', [])
                if imageinfo:
                    return imageinfo[0].get('url')
        except requests.RequestException as exc:
            logger.error("Could not resolve URL for %s: %s", title, exc)
        return None

    def _download_image(self, url: str) -> np.ndarray | None:
        """Download image and return as BGR numpy array."""
        try:
            resp = self._session.get(url, timeout=60, stream=True)
            resp.raise_for_status()
            img = Image.open(io.BytesIO(resp.content)).convert('RGB')
            arr = np.array(img)
            return arr[:, :, ::-1].copy()
        except Exception as exc:
            logger.error("Failed to download error coin image %s: %s", url, exc)
            return None
