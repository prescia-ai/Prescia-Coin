"""
PCGS (Professional Coin Grading Service) public API scraper.

PCGS CoinFacts provides reference images and grading data for certified US
coins. Register for a free API key at https://www.pcgs.com/publicapi

Set 'pcgs.api_key' in config.yaml to enable this scraper. Without a key,
the scraper logs a warning and yields nothing.

API documentation: https://www.pcgs.com/publicapi
"""

import io
import time
import logging
from typing import Generator

import numpy as np
import requests
from PIL import Image

logger = logging.getLogger(__name__)

_API_BASE = "https://api.pcgs.com/publicapi"

# Map (coin_name, variety) → PCGS denomination code used in coin search
# PCGS denomination codes: 1C=cent, 5C=nickel, 10C=dime, 25C=quarter,
# 50C=half dollar, $1=dollar
_DENOMINATION_MAP = {
    'Penny': '1C',
    'Nickel': '5C',
    'Dime': '10C',
    'Quarter': '25C',
    'Half_Dollar': '50C',
    'Dollar': '$1',
}

# Map variety to a PCGS series keyword for filtering search results
_SERIES_MAP = {
    ('Penny', 'Lincoln_Memorial'): 'Lincoln Memorial',
    ('Penny', 'Lincoln_Bicentennial'): 'Lincoln Bicentennial',
    ('Penny', 'Lincoln_Union_Shield'): 'Lincoln Shield',
    ('Penny', 'Lincoln_Wheat'): 'Lincoln Wheat',
    ('Penny', 'Indian_Head'): 'Indian Cent',
    ('Nickel', 'Jefferson'): 'Jefferson',
    ('Nickel', 'Buffalo'): 'Buffalo',
    ('Nickel', 'Shield'): 'Shield',
    ('Nickel', 'Liberty_Head'): 'Liberty Head',
    ('Dime', 'Roosevelt'): 'Roosevelt',
    ('Dime', 'Mercury'): 'Mercury',
    ('Dime', 'Barber'): 'Barber',
    ('Quarter', 'Washington'): 'Washington',
    ('Quarter', 'State_Quarters'): 'State',
    ('Quarter', 'America_Beautiful'): 'America the Beautiful',
    ('Quarter', 'American_Women'): 'American Women',
    ('Quarter', 'Standing_Liberty'): 'Standing Liberty',
    ('Quarter', 'Barber'): 'Barber',
    ('Half_Dollar', 'Kennedy'): 'Kennedy',
    ('Half_Dollar', 'Franklin'): 'Franklin',
    ('Half_Dollar', 'Walking_Liberty'): 'Walking Liberty',
    ('Half_Dollar', 'Barber'): 'Barber',
    ('Dollar', 'Sacagawea'): 'Sacagawea',
    ('Dollar', 'Presidential'): 'Presidential',
    ('Dollar', 'Morgan'): 'Morgan',
    ('Dollar', 'Peace'): 'Peace',
    ('Dollar', 'Eisenhower'): 'Eisenhower',
    ('Dollar', 'Susan_B_Anthony'): 'Susan B Anthony',
    ('Dollar', 'American_Silver_Eagle'): 'American Silver Eagle',
}


class PCGSScraper:
    """Scrapes coin reference images from the PCGS public API."""

    def __init__(self, api_key: str | None = None, rate_limit: float = 1.0):
        """
        Args:
            api_key: PCGS API key. Required for API access.
            rate_limit: Maximum requests per second.
        """
        self.api_key = api_key
        self.rate_limit = rate_limit
        self._session = requests.Session()
        self._session.headers.update({
            'User-Agent': 'PresciaAI-CoinScraper/1.0 (educational)',
        })
        if api_key:
            self._session.headers['Authorization'] = f'Bearer {api_key}'

    def scrape(self, coin_config: dict, limit: int | None = None) -> Generator[dict, None, None]:
        """Yield image data dicts for the given coin configuration.

        Args:
            coin_config: Dict with 'name' and 'variety' keys.
            limit: Maximum images to yield.

        Yields:
            dict with image array and metadata.
        """
        if not self.api_key:
            logger.warning(
                "PCGS API key not configured – skipping PCGS scrape for %s/%s. "
                "Set 'pcgs.api_key' in config.yaml.",
                coin_config['name'], coin_config['variety'],
            )
            return

        key = (coin_config['name'], coin_config['variety'])
        denom = _DENOMINATION_MAP.get(coin_config['name'])
        series = _SERIES_MAP.get(key)
        if not denom or not series:
            logger.warning("No PCGS mapping for %s", key)
            return

        count = 0
        for coin_entry in self._search_coins(denom, series):
            if limit is not None and count >= limit:
                break
            for img_url in self._get_image_urls(coin_entry):
                if limit is not None and count >= limit:
                    break
                image_array = self._download_image(img_url)
                if image_array is None:
                    continue
                yield {
                    'image': image_array,
                    'source': 'pcgs',
                    'coin_name': coin_config['name'],
                    'variety': coin_config['variety'],
                    'year': coin_entry.get('year', 'Unknown'),
                    'mint_mark': coin_entry.get('mintMark', ''),
                    'error_type': 'Mint_Condition',
                    'condition': coin_entry.get('grade', 'Unknown'),
                    'original_url': img_url,
                }
                count += 1
                time.sleep(1.0 / self.rate_limit)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _search_coins(self, denomination: str, series: str) -> Generator[dict, None, None]:
        """Query PCGS CoinFacts for coin entries matching denomination + series."""
        params = {
            'denomination': denomination,
            'series': series,
            'pageSize': 20,
            'pageNumber': 1,
        }
        try:
            resp = self._session.get(
                f"{_API_BASE}/coindetail/getcoindetailbyseries",
                params=params,
                timeout=30,
            )
            resp.raise_for_status()
            data = resp.json()
            for coin in data.get('coins', data if isinstance(data, list) else []):
                yield coin
        except requests.RequestException as exc:
            logger.error("PCGS search failed for %s %s: %s", denomination, series, exc)

    def _get_image_urls(self, coin_entry: dict) -> list[str]:
        """Extract image URLs from a PCGS coin entry."""
        urls = []
        for key in ('obverseImageUrl', 'reverseImageUrl', 'imageUrl'):
            url = coin_entry.get(key)
            if url:
                urls.append(url)
        return urls

    def _download_image(self, url: str) -> np.ndarray | None:
        """Download image and return as BGR numpy array."""
        try:
            resp = self._session.get(url, timeout=60, stream=True)
            resp.raise_for_status()
            img = Image.open(io.BytesIO(resp.content)).convert('RGB')
            arr = np.array(img)
            return arr[:, :, ::-1].copy()
        except Exception as exc:
            logger.error("Failed to download PCGS image %s: %s", url, exc)
            return None
