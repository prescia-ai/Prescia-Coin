"""
Progress tracker – persists scrape state and generates summary reports.

State is stored as a JSON file in the output directory so interrupted scrapes
can be resumed with ``--resume``.
"""

import json
import logging
import time
from datetime import datetime
from pathlib import Path

logger = logging.getLogger(__name__)

_STATE_FILE = 'scrape_state.json'
_REPORT_FILE = 'scrape_report.txt'


class ProgressTracker:
    """Tracks completed downloads and generates summary reports."""

    def __init__(self, output_dir: str | Path):
        self.output_dir = Path(output_dir)
        self._completed: set[str] = set()
        self._start_time: float = time.time()
        self._state_path = self.output_dir / _STATE_FILE

    # ------------------------------------------------------------------
    # State persistence
    # ------------------------------------------------------------------

    def load_state(self) -> None:
        """Load previously saved state from disk.

        Should be called when ``--resume`` is passed so the scraper can skip
        already-downloaded files.
        """
        if not self._state_path.exists():
            logger.info("No saved state found at %s; starting fresh.", self._state_path)
            return
        try:
            data = json.loads(self._state_path.read_text())
            self._completed = set(data.get('completed', []))
            logger.info("Resumed with %d completed files.", len(self._completed))
        except (json.JSONDecodeError, OSError) as exc:
            logger.warning("Could not load state file: %s", exc)

    def _save_state(self) -> None:
        """Persist current state to disk."""
        try:
            self.output_dir.mkdir(parents=True, exist_ok=True)
            self._state_path.write_text(
                json.dumps({'completed': sorted(self._completed)}, indent=2)
            )
        except OSError as exc:
            logger.error("Could not save state file: %s", exc)

    # ------------------------------------------------------------------
    # Tracking
    # ------------------------------------------------------------------

    def is_complete(self, filename: str) -> bool:
        """Return True if *filename* has already been downloaded."""
        return filename in self._completed

    def mark_complete(self, filename: str) -> None:
        """Record *filename* as successfully downloaded."""
        self._completed.add(filename)
        # Persist state periodically (every 50 completions)
        if len(self._completed) % 50 == 0:
            self._save_state()

    @property
    def completed_count(self) -> int:
        return len(self._completed)

    # ------------------------------------------------------------------
    # Reporting
    # ------------------------------------------------------------------

    def generate_report(self) -> Path:
        """Write a summary report to disk and return its path.

        Returns:
            Path to the written report file.
        """
        elapsed = time.time() - self._start_time
        report_path = self.output_dir / _REPORT_FILE

        lines = [
            "=" * 60,
            "US Coin Image Scraper – Summary Report",
            f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}",
            "=" * 60,
            f"Total images downloaded : {len(self._completed):,}",
            f"Elapsed time            : {elapsed / 60:.1f} minutes",
            "",
            "Downloaded files:",
        ]
        for filename in sorted(self._completed):
            lines.append(f"  {filename}")
        lines.append("=" * 60)

        report_text = "\n".join(lines)
        try:
            report_path.write_text(report_text)
            logger.info("Report written to %s", report_path)
        except OSError as exc:
            logger.error("Could not write report: %s", exc)

        # Final state save
        self._save_state()
        print(report_text)
        return report_path
