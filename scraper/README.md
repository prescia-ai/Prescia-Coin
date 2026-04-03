# US Coin Image Scraper

Comprehensive standalone tool to scrape high-quality images of **all major US
coins** from free, openly-licensed sources.  Images are automatically
detected, cropped (OpenCV circle detection), organised by coin type and error
category, and saved with a consistent file-naming convention.

---

## Quick Start

### 1. Install dependencies

```bash
cd scraper
pip install -r requirements.txt
```

### 2. Run the scraper

```bash
# From the repository root:
python scraper/scraper.py
```

### 3. Find your images

Images are saved to `scraper/output/coin-images/` organised by type, variety,
and error category.

---

## Command-Line Options

```
usage: scraper.py [-h] [--output OUTPUT] [--coins COINS [COINS ...]]
                  [--errors-only] [--limit LIMIT] [--resume] [--test]

options:
  -h, --help            Show this help message and exit
  --output OUTPUT       Output directory (default: ./scraper/output/coin-images)
  --coins COINS [...]   Specific coin types to scrape, e.g. Penny Nickel
  --errors-only         Only scrape error coins (skip Mint_Condition)
  --limit LIMIT         Maximum images per category
  --resume              Resume a previously interrupted scrape
  --test                Download 10 images to verify setup before a full run
```

### Examples

```bash
# Test setup (10 images only)
python scraper/scraper.py --test

# Scrape only pennies and nickels
python scraper/scraper.py --coins Penny Nickel

# Only error coins, limited to 5 per category
python scraper/scraper.py --errors-only --limit 5

# Resume an interrupted scrape
python scraper/scraper.py --resume

# Custom output directory
python scraper/scraper.py --output /path/to/output
```

---

## Configuration

Edit `scraper/config.yaml` to customise scraping behaviour:

```yaml
scraping:
  target_images_per_category: 50   # Mint condition images per variety
  target_errors_per_type: 20       # Error images per type

  sources:
    wikimedia:
      enabled: true
      rate_limit: 2   # requests/second

    numista:
      enabled: true
      api_key: null   # Register at https://en.numista.com/api/doc/
      rate_limit: 1

    pcgs:
      enabled: true
      api_key: null   # Register at https://www.pcgs.com/publicapi
      rate_limit: 1
```

### API Keys

| Source   | Required? | How to get                                    |
|----------|-----------|-----------------------------------------------|
| Wikimedia | No       | Public API, no key needed                     |
| Numista  | Yes       | Free registration at numista.com/api/doc/     |
| PCGS     | Yes       | Free registration at pcgs.com/publicapi       |

---

## Output Structure

```
scraper/output/coin-images/
├── Penny/
│   ├── Lincoln_Memorial/
│   │   ├── Mint_Condition/
│   │   │   └── Penny_Lincoln_Memorial_1982_P_Mint_Condition_001.jpg
│   │   ├── Doubled_Die/
│   │   ├── Off_Center_Strike/
│   │   └── ...
│   ├── Lincoln_Wheat/
│   └── Indian_Head/
├── Nickel/
├── Dime/
├── Quarter/
├── Half_Dollar/
└── Dollar/
```

### File Naming Convention

```
{CoinType}_{Variety}_{Year}_{MintMark}_{ErrorType}_{UniqueID}.jpg
```

Examples:
- `Penny_Lincoln_Memorial_1982_P_Mint_Condition_001.jpg`
- `Quarter_Washington_1965_NoMM_Mint_Condition_003.jpg`
- `Dollar_Morgan_1884_O_Mint_Condition_007.jpg`

---

## Coin Coverage

| Type        | Varieties                                                  |
|-------------|------------------------------------------------------------|
| Penny       | Lincoln Memorial, Bicentennial, Union Shield, Wheat, Indian Head |
| Nickel      | Jefferson, Buffalo, Shield, Liberty Head                   |
| Dime        | Roosevelt, Mercury, Barber                                 |
| Quarter     | Washington, State, America Beautiful, American Women, Standing Liberty, Barber |
| Half Dollar | Kennedy, Franklin, Walking Liberty, Barber                 |
| Dollar      | Sacagawea, Presidential, Morgan, Peace, Eisenhower, Susan B. Anthony, American Silver Eagle |

## Error Categories

Each variety folder contains subfolders for:

- `Mint_Condition`
- `Doubled_Die`
- `Off_Center_Strike`
- `Clipped_Planchet`
- `Wrong_Planchet`
- `Die_Crack_Cud`
- `Broadstrike`
- `Lamination_Error`
- `Struck_Through`
- `Multiple_Strike`
- `Missing_Clad_Layer` *(Quarter, Half Dollar, Dime only)*
- `Repunched_Mint_Mark`
- `Other_Errors`

---

## Estimated Runtime

| Scope              | Time         | Images        | Size   |
|--------------------|--------------|---------------|--------|
| Full scrape        | 2–3 days     | 15,000–25,000 | 3–5 GB |
| Single coin type   | 2–4 hours    | 500–1,000     | ~200 MB |
| Test mode (`--test`) | < 1 minute | 10            | < 2 MB |

---

## Module Overview

```
scraper/
├── scraper.py                  Main launcher
├── requirements.txt
├── config.yaml
├── sources/
│   ├── wikimedia_scraper.py    Wikimedia Commons (free, no key required)
│   ├── numista_scraper.py      Numista API (API key required)
│   ├── error_coin_scraper.py   Error coin images via Wikimedia search
│   └── pcgs_scraper.py         PCGS CoinFacts (API key required)
├── processors/
│   ├── circle_detector.py      OpenCV Hough Circle crop
│   ├── image_processor.py      Resize, sharpness filter
│   ├── feature_extractor.py    pHash, histogram, Hu moments
│   └── deduplicator.py         Perceptual hash deduplication
└── utils/
    ├── file_organizer.py       Directory creation & file saving
    ├── progress_tracker.py     Resume state & summary report
    └── metadata_generator.py   Per-image JSON sidecar files
```

---

## Legal & Attribution

All images sourced from **Wikimedia Commons** are freely licensed (Creative
Commons or Public Domain).  Images from **Numista** and **PCGS** are retrieved
via their official APIs in accordance with their terms of service.  Check each
source's terms before redistributing collected images.
