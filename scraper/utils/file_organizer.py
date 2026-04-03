"""
File organizer – creates the output directory tree and saves coin images.

Directory layout:
    <output>/
        <CoinType>/
            <Variety>/
                <ErrorType>/
                    <filename>.jpg
"""

import logging
import re
from pathlib import Path

import cv2
import numpy as np

logger = logging.getLogger(__name__)

# All top-level coin types and their varieties
COIN_STRUCTURE: dict[str, list[str]] = {
    'Penny': [
        'Lincoln_Memorial',
        'Lincoln_Bicentennial',
        'Lincoln_Union_Shield',
        'Lincoln_Wheat',
        'Indian_Head',
    ],
    'Nickel': [
        'Jefferson',
        'Buffalo',
        'Shield',
        'Liberty_Head',
    ],
    'Dime': [
        'Roosevelt',
        'Mercury',
        'Barber',
    ],
    'Quarter': [
        'Washington',
        'State_Quarters',
        'America_Beautiful',
        'American_Women',
        'Standing_Liberty',
        'Barber',
    ],
    'Half_Dollar': [
        'Kennedy',
        'Franklin',
        'Walking_Liberty',
        'Barber',
    ],
    'Dollar': [
        'Sacagawea',
        'Presidential',
        'Morgan',
        'Peace',
        'Eisenhower',
        'Susan_B_Anthony',
        'American_Silver_Eagle',
    ],
}

ERROR_CATEGORIES: list[str] = [
    'Mint_Condition',
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

# Coin types that can have Missing_Clad_Layer errors
_CLAD_COINS = {'Quarter', 'Half_Dollar', 'Dime'}


class FileOrganizer:
    """Creates the directory tree and saves processed coin images."""

    def __init__(self, output_dir: str | Path):
        self.output_dir = Path(output_dir)
        # Per-directory counters for unique ID generation
        self._counters: dict[Path, int] = {}

    def create_structure(self) -> None:
        """Create the full directory tree under *output_dir*."""
        for coin_type, varieties in COIN_STRUCTURE.items():
            for variety in varieties:
                for error in ERROR_CATEGORIES:
                    if error == 'Missing_Clad_Layer' and coin_type not in _CLAD_COINS:
                        continue
                    folder = self.output_dir / coin_type / variety / error
                    folder.mkdir(parents=True, exist_ok=True)
        logger.info("Directory structure created under %s", self.output_dir)

    def generate_filename(self, img_data: dict) -> str:
        """Produce a filename following the project naming convention.

        Format: ``{CoinType}_{Variety}_{Year}_{MintMark}_{ErrorType}_{ID}.jpg``

        Args:
            img_data: Dict with keys 'coin_name', 'variety', 'year',
                'mint_mark', 'error_type'.

        Returns:
            Filename string (no directory component).
        """
        coin = img_data.get('coin_name', 'Unknown')
        variety = img_data.get('variety', 'Unknown')
        year = img_data.get('year', 'Unknown')
        mint = img_data.get('mint_mark', '') or 'NoMM'
        error = img_data.get('error_type', 'Mint_Condition')

        # Determine target directory for counter tracking
        target_dir = self.output_dir / coin / variety / error
        uid = self._next_id(target_dir)

        # Sanitise each component so it's filesystem-safe
        parts = [coin, variety, str(year), mint, error, f"{uid:03d}"]
        parts = [re.sub(r'[^\w\-]', '_', p) for p in parts]
        return '_'.join(parts) + '.jpg'

    def save_image(
        self,
        image: np.ndarray | None,
        coin_config: dict,
        error_type: str,
        filename: str,
    ) -> Path | None:
        """Save *image* to the appropriate subdirectory.

        Args:
            image: BGR numpy array.  If None, the image is skipped.
            coin_config: Dict with 'name' and 'variety'.
            error_type: Error category folder name.
            filename: File name (no path) to write.

        Returns:
            Full :class:`~pathlib.Path` of the saved file, or None on failure.
        """
        if image is None:
            logger.debug("Skipped saving None image (%s)", filename)
            return None

        coin_type = coin_config['name']
        variety = coin_config['variety']
        folder = self.output_dir / coin_type / variety / error_type
        folder.mkdir(parents=True, exist_ok=True)

        out_path = folder / filename
        try:
            cv2.imwrite(str(out_path), image, [cv2.IMWRITE_JPEG_QUALITY, 85])
            logger.debug("Saved %s", out_path)
            return out_path
        except Exception as exc:
            logger.error("Failed to save image %s: %s", out_path, exc)
            return None

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _next_id(self, directory: Path) -> int:
        """Return and increment a per-directory counter."""
        current = self._counters.get(directory, 0) + 1
        self._counters[directory] = current
        return current
