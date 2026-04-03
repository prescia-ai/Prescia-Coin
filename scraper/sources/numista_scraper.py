"""
Numista API scraper for US coin images.

Numista (https://en.numista.com) provides a free REST API for querying coin
data including reference images. An API key can be obtained for free at
https://en.numista.com/api/doc/

Set 'numista.api_key' in config.yaml to enable authenticated requests.
Without an API key the scraper gracefully skips and logs a warning.
"""

import io
import time
import logging
from typing import Generator

import numpy as np
import requests
from PIL import Image

logger = logging.getLogger(__name__)

_API_BASE = "https://api.numista.com/api/v3"

# Numista uses ISO 3166-1 alpha-2 country code 'US' for United States coins.
# Denomination search terms map our internal variety names to Numista keywords.
_SEARCH_TERMS = {
    ('Penny', 'Lincoln_Memorial'): 'Lincoln cent',
    ('Penny', 'Lincoln_Bicentennial'): 'Lincoln bicentennial cent',
    ('Penny', 'Lincoln_Union_Shield'): 'Lincoln shield cent',
    ('Penny', 'Lincoln_Wheat'): 'Lincoln wheat cent',
    ('Penny', 'Indian_Head'): 'Indian head cent',
    ('Nickel', 'Jefferson'): 'Jefferson nickel',
    ('Nickel', 'Buffalo'): 'Buffalo nickel',
    ('Nickel', 'Shield'): 'Shield nickel',
    ('Nickel', 'Liberty_Head'): 'Liberty head nickel',
    ('Dime', 'Roosevelt'): 'Roosevelt dime',
    ('Dime', 'Mercury'): 'Mercury dime',
    ('Dime', 'Barber'): 'Barber dime',
    ('Quarter', 'Washington'): 'Washington quarter',
    ('Quarter', 'State_Quarters'): 'State quarter',
    ('Quarter', 'America_Beautiful'): 'America the Beautiful quarter',
    ('Quarter', 'American_Women'): 'American Women quarter',
    ('Quarter', 'Standing_Liberty'): 'Standing Liberty quarter',
    ('Quarter', 'Barber'): 'Barber quarter',
    ('Half_Dollar', 'Kennedy'): 'Kennedy half dollar',
    ('Half_Dollar', 'Franklin'): 'Franklin half dollar',
    ('Half_Dollar', 'Walking_Liberty'): 'Walking Liberty half dollar',
    ('Half_Dollar', 'Barber'): 'Barber half dollar',
    ('Dollar', 'Sacagawea'): 'Sacagawea dollar',
    ('Dollar', 'Presidential'): 'Presidential dollar',
    ('Dollar', 'Morgan'): 'Morgan dollar',
    ('Dollar', 'Peace'): 'Peace dollar',
    ('Dollar', 'Eisenhower'): 'Eisenhower dollar',
    ('Dollar', 'Susan_B_Anthony'): 'Susan B Anthony dollar',
    ('Dollar', 'American_Silver_Eagle'): 'American Silver Eagle',
}


class NumistaScraper:
    """Scrapes coin images from the Numista API."""

    def __init__(self, api_key: str | None = None, rate_limit: float = 1.0):
        """
        Args:
            api_key: Numista API key. If None, requests will be unauthenticated
                     and will likely be rejected; a warning is logged.
            rate_limit: Maximum requests per second.
        """
        self.api_key = api_key
        self.rate_limit = rate_limit
        self._session = requests.Session()
        self._session.headers.update({'User-Agent': 'PresciaAI-CoinScraper/1.0 (educational)'})
        if api_key:
            self._session.headers['Numista-API-Key'] = api_key

    def scrape(self, coin_config: dict, limit: int | None = None) -> Generator[dict, None, None]:
        """Yield image data dicts for the given coin configuration.

        Args:
            coin_config: Dict with keys 'name' and 'variety'.
            limit: Maximum number of images to yield.

        Yields:
            dict with image array and metadata.
        """
        if not self.api_key:
            logger.warning(
                "Numista API key not configured – skipping Numista scrape for %s/%s. "
                "Set 'numista.api_key' in config.yaml.",
                coin_config['name'], coin_config['variety'],
            )
            return

        key = (coin_config['name'], coin_config['variety'])
        search_term = _SEARCH_TERMS.get(key)
        if not search_term:
            logger.warning("No Numista search term for %s", key)
            return

        count = 0
        for coin_entry in self._search_coins(search_term):
            if limit is not None and count >= limit:
                break
            coin_id = coin_entry.get('id')
            if not coin_id:
                continue
            for img_url in self._get_coin_image_urls(coin_id):
                if limit is not None and count >= limit:
                    break
                image_array = self._download_image(img_url)
                if image_array is None:
                    continue
                yield {
                    'image': image_array,
                    'source': 'numista',
                    'coin_name': coin_config['name'],
                    'variety': coin_config['variety'],
                    'year': coin_entry.get('min_year', 'Unknown'),
                    'mint_mark': '',
                    'error_type': 'Mint_Condition',
                    'condition': 'Unknown',
                    'original_url': img_url,
                }
                count += 1
                time.sleep(1.0 / self.rate_limit)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _search_coins(self, query: str) -> Generator[dict, None, None]:
        """Search Numista for coins matching query, filtering to US country."""
        params = {
            'q': query,
            'issuer': 'united-states',
            'count': 20,
            'lang': 'en',
        }
        try:
            resp = self._session.get(f"{_API_BASE}/coins", params=params, timeout=30)
            resp.raise_for_status()
            data = resp.json()
            for coin in data.get('coins', []):
                yield coin
        except requests.RequestException as exc:
            logger.error("Numista search failed for '%s': %s", query, exc)

    def _get_coin_image_urls(self, coin_id: int) -> list[str]:
        """Return image URLs for a specific Numista coin entry."""
        try:
            resp = self._session.get(f"{_API_BASE}/coins/{coin_id}", timeout=30)
            resp.raise_for_status()
            data = resp.json()
            urls = []
            for side in ('obverse', 'reverse'):
                picture = data.get(side, {}).get('picture')
                if picture:
                    urls.append(picture)
            return urls
        except requests.RequestException as exc:
            logger.error("Failed to get coin details for id=%s: %s", coin_id, exc)
            return []

    def _download_image(self, url: str) -> np.ndarray | None:
        """Download image and return as BGR numpy array."""
        try:
            resp = self._session.get(url, timeout=60, stream=True)
            resp.raise_for_status()
            img = Image.open(io.BytesIO(resp.content)).convert('RGB')
            arr = np.array(img)
            return arr[:, :, ::-1].copy()
        except Exception as exc:
            logger.error("Failed to download Numista image %s: %s", url, exc)
            return None
