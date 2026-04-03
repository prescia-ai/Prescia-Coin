"""
Wikimedia Commons scraper for US coin images.

Downloads freely-licensed coin images from Wikimedia Commons using the
MediaWiki API. Images on Wikimedia Commons are under various free licenses
(e.g., CC BY-SA, Public Domain) which permit redistribution and reuse.
"""

import io
import time
import logging
from typing import Generator

import numpy as np
import requests
from PIL import Image

logger = logging.getLogger(__name__)

# Wikimedia Commons MediaWiki API endpoint
_API_URL = "https://commons.wikimedia.org/w/api.php"

# Map coin names/varieties to relevant Wikimedia Commons categories
_CATEGORY_MAP = {
    ('Penny', 'Lincoln_Memorial'): 'Lincoln_Memorial_cent',
    ('Penny', 'Lincoln_Bicentennial'): 'Lincoln_Bicentennial_cent',
    ('Penny', 'Lincoln_Union_Shield'): 'Lincoln_Union_Shield_cent',
    ('Penny', 'Lincoln_Wheat'): 'Lincoln_Wheat_cent',
    ('Penny', 'Indian_Head'): 'Indian_Head_cent',
    ('Nickel', 'Jefferson'): 'Jefferson_nickel',
    ('Nickel', 'Buffalo'): 'Buffalo_nickel',
    ('Nickel', 'Shield'): 'Shield_nickel',
    ('Nickel', 'Liberty_Head'): 'Liberty_Head_nickel',
    ('Dime', 'Roosevelt'): 'Roosevelt_dime',
    ('Dime', 'Mercury'): 'Mercury_dime',
    ('Dime', 'Barber'): 'Barber_dime',
    ('Quarter', 'Washington'): 'Washington_quarter',
    ('Quarter', 'State_Quarters'): 'State_quarters_(United_States)',
    ('Quarter', 'America_Beautiful'): 'America_the_Beautiful_quarters',
    ('Quarter', 'American_Women'): 'American_Women_quarters',
    ('Quarter', 'Standing_Liberty'): 'Standing_Liberty_quarter',
    ('Quarter', 'Barber'): 'Barber_quarter',
    ('Half_Dollar', 'Kennedy'): 'Kennedy_half_dollar',
    ('Half_Dollar', 'Franklin'): 'Franklin_half_dollar',
    ('Half_Dollar', 'Walking_Liberty'): 'Walking_Liberty_half_dollar',
    ('Half_Dollar', 'Barber'): 'Barber_half_dollar',
    ('Dollar', 'Sacagawea'): 'Sacagawea_dollar',
    ('Dollar', 'Presidential'): 'Presidential_dollar_coin',
    ('Dollar', 'Morgan'): 'Morgan_dollar',
    ('Dollar', 'Peace'): 'Peace_dollar',
    ('Dollar', 'Eisenhower'): 'Eisenhower_dollar',
    ('Dollar', 'Susan_B_Anthony'): 'Susan_B._Anthony_dollar',
    ('Dollar', 'American_Silver_Eagle'): 'American_Silver_Eagle',
}


class WikimediaScraper:
    """Scrapes coin images from Wikimedia Commons."""

    def __init__(self, rate_limit: float = 2.0):
        """
        Args:
            rate_limit: Maximum requests per second.
        """
        self.rate_limit = rate_limit
        self._session = requests.Session()
        self._session.headers.update({'User-Agent': 'PresciaAI-CoinScraper/1.0 (educational)'})

    def scrape(self, coin_config: dict, limit: int | None = None) -> Generator[dict, None, None]:
        """Yield image data dicts for the given coin configuration.

        Args:
            coin_config: Dict with keys 'name' and 'variety'.
            limit: Maximum number of images to yield.

        Yields:
            dict with keys: 'image' (numpy array), 'source', 'coin_name',
                'variety', 'year', 'mint_mark', 'error_type', 'condition'.
        """
        key = (coin_config['name'], coin_config['variety'])
        category = _CATEGORY_MAP.get(key)
        if not category:
            logger.warning("No Wikimedia category mapped for %s", key)
            return

        count = 0
        for file_info in self._iter_category_images(category):
            if limit is not None and count >= limit:
                break
            image_array = self._download_image(file_info['url'])
            if image_array is None:
                continue
            yield {
                'image': image_array,
                'source': 'wikimedia',
                'coin_name': coin_config['name'],
                'variety': coin_config['variety'],
                'year': file_info.get('year', 'Unknown'),
                'mint_mark': file_info.get('mint_mark', ''),
                'error_type': 'Mint_Condition',
                'condition': 'Unknown',
                'original_url': file_info['url'],
            }
            count += 1
            time.sleep(1.0 / self.rate_limit)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _iter_category_images(self, category: str) -> Generator[dict, None, None]:
        """Iterate over image file info in a Wikimedia Commons category."""
        params = {
            'action': 'query',
            'list': 'categorymembers',
            'cmtitle': f'Category:{category}',
            'cmtype': 'file',
            'cmlimit': 50,
            'format': 'json',
        }
        while True:
            try:
                resp = self._session.get(_API_URL, params=params, timeout=30)
                resp.raise_for_status()
                data = resp.json()
            except requests.RequestException as exc:
                logger.error("Wikimedia API error for category %s: %s", category, exc)
                break

            members = data.get('query', {}).get('categorymembers', [])
            for member in members:
                title = member.get('title', '')
                if not title.startswith('File:'):
                    continue
                url = self._get_image_url(title)
                if url:
                    yield {'url': url, 'title': title}

            cont = data.get('continue', {}).get('cmcontinue')
            if not cont:
                break
            params['cmcontinue'] = cont
            time.sleep(1.0 / self.rate_limit)

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
        """Download image from URL and return as a numpy (BGR) array."""
        try:
            resp = self._session.get(url, timeout=60, stream=True)
            resp.raise_for_status()
            img = Image.open(io.BytesIO(resp.content)).convert('RGB')
            arr = np.array(img)
            # Convert RGB → BGR for OpenCV compatibility
            return arr[:, :, ::-1].copy()
        except Exception as exc:
            logger.error("Failed to download image %s: %s", url, exc)
            return None
