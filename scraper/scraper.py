#!/usr/bin/env python3
"""
US Coin Image Scraper
Run from root: python scraper/scraper.py
"""

import argparse
import sys
from pathlib import Path

# Ensure the scraper package root is on the path when run directly
sys.path.insert(0, str(Path(__file__).parent))

from sources import wikimedia_scraper, numista_scraper, error_coin_scraper, pcgs_scraper
from processors import circle_detector, image_processor
from utils import file_organizer, progress_tracker


def main():
    parser = argparse.ArgumentParser(description='Scrape US coin images')
    parser.add_argument('--output', default='./scraper/output/coin-images', help='Output directory')
    parser.add_argument('--coins', nargs='+', help='Specific coins to scrape (default: all)')
    parser.add_argument('--errors-only', action='store_true', help='Only scrape error coins')
    parser.add_argument('--limit', type=int, help='Limit images per category')
    parser.add_argument('--resume', action='store_true', help='Resume interrupted scrape')
    parser.add_argument('--test', action='store_true', help='Test mode: download 10 images to verify setup')
    args = parser.parse_args()

    # Create directory structure
    organizer = file_organizer.FileOrganizer(args.output)
    organizer.create_structure()

    # Initialize scrapers
    scrapers = [
        wikimedia_scraper.WikimediaScraper(),
        numista_scraper.NumistaScraper(),
        error_coin_scraper.ErrorCoinScraper(),
        pcgs_scraper.PCGSScraper(),
    ]

    # Track progress
    tracker = progress_tracker.ProgressTracker(args.output)
    if args.resume:
        tracker.load_state()

    detector = circle_detector.CircleDetector()
    processor = image_processor.ImageProcessor()

    # Test mode: download 10 images and exit
    if args.test:
        print("=== TEST MODE: Downloading up to 10 images ===")
        count = 0
        for coin_config in get_all_coin_configs():
            if count >= 10:
                break
            for scraper in scrapers[:1]:  # Only use first scraper in test mode
                if count >= 10:
                    break
                images = scraper.scrape(coin_config, limit=1)
                for img_data in images:
                    if count >= 10:
                        break
                    cropped = detector.detect_and_crop(img_data['image'])
                    processed = processor.process(cropped)
                    filename = organizer.generate_filename(img_data)
                    saved_path = organizer.save_image(
                        processed, coin_config, img_data.get('error_type', 'Mint_Condition'), filename
                    )
                    tracker.mark_complete(filename)
                    print(f"✓ {filename}")
                    count += 1
        print(f"\nTest complete! {count} images saved to: {args.output}")
        return

    # Scrape each coin type
    for coin_config in get_all_coin_configs():
        if args.coins and coin_config['name'] not in args.coins:
            continue

        print(f"\n=== Scraping {coin_config['name']} – {coin_config['variety']} ===")

        for scraper in scrapers:
            images = scraper.scrape(coin_config, limit=args.limit)

            for img_data in images:
                error_type = img_data.get('error_type', 'Mint_Condition')

                # Skip non-errors when --errors-only is set
                if args.errors_only and error_type == 'Mint_Condition':
                    continue

                # Detect circle and crop
                cropped = detector.detect_and_crop(img_data['image'])

                # Process image
                processed = processor.process(cropped)

                # Organize and save
                filename = organizer.generate_filename(img_data)
                organizer.save_image(processed, coin_config, error_type, filename)

                # Track progress
                tracker.mark_complete(filename)
                print(f"✓ {filename}")

    # Generate summary report
    tracker.generate_report()
    print(f"\nComplete! Images saved to: {args.output}")


def get_all_coin_configs():
    """Returns configuration for all US coins."""
    return [
        # Pennies
        {'name': 'Penny', 'variety': 'Lincoln_Memorial', 'years': range(1959, 2009)},
        {'name': 'Penny', 'variety': 'Lincoln_Bicentennial', 'years': range(2009, 2010)},
        {'name': 'Penny', 'variety': 'Lincoln_Union_Shield', 'years': range(2010, 2026)},
        {'name': 'Penny', 'variety': 'Lincoln_Wheat', 'years': range(1909, 1959)},
        {'name': 'Penny', 'variety': 'Indian_Head', 'years': range(1859, 1910)},

        # Nickels
        {'name': 'Nickel', 'variety': 'Jefferson', 'years': range(1938, 2026)},
        {'name': 'Nickel', 'variety': 'Buffalo', 'years': range(1913, 1939)},
        {'name': 'Nickel', 'variety': 'Shield', 'years': range(1866, 1884)},
        {'name': 'Nickel', 'variety': 'Liberty_Head', 'years': range(1883, 1913)},

        # Dimes
        {'name': 'Dime', 'variety': 'Roosevelt', 'years': range(1946, 2026)},
        {'name': 'Dime', 'variety': 'Mercury', 'years': range(1916, 1946)},
        {'name': 'Dime', 'variety': 'Barber', 'years': range(1892, 1917)},

        # Quarters
        {'name': 'Quarter', 'variety': 'Washington', 'years': range(1932, 1999)},
        {'name': 'Quarter', 'variety': 'State_Quarters', 'years': range(1999, 2009)},
        {'name': 'Quarter', 'variety': 'America_Beautiful', 'years': range(2010, 2022)},
        {'name': 'Quarter', 'variety': 'American_Women', 'years': range(2022, 2026)},
        {'name': 'Quarter', 'variety': 'Standing_Liberty', 'years': range(1916, 1931)},
        {'name': 'Quarter', 'variety': 'Barber', 'years': range(1892, 1917)},

        # Half Dollars
        {'name': 'Half_Dollar', 'variety': 'Kennedy', 'years': range(1964, 2026)},
        {'name': 'Half_Dollar', 'variety': 'Franklin', 'years': range(1948, 1964)},
        {'name': 'Half_Dollar', 'variety': 'Walking_Liberty', 'years': range(1916, 1948)},
        {'name': 'Half_Dollar', 'variety': 'Barber', 'years': range(1892, 1916)},

        # Dollars
        {'name': 'Dollar', 'variety': 'Sacagawea', 'years': range(2000, 2026)},
        {'name': 'Dollar', 'variety': 'Presidential', 'years': range(2007, 2021)},
        {'name': 'Dollar', 'variety': 'Morgan', 'years': range(1878, 1922)},
        {'name': 'Dollar', 'variety': 'Peace', 'years': range(1921, 1936)},
        {'name': 'Dollar', 'variety': 'Eisenhower', 'years': range(1971, 1979)},
        {'name': 'Dollar', 'variety': 'Susan_B_Anthony', 'years': range(1979, 2000)},
        {'name': 'Dollar', 'variety': 'American_Silver_Eagle', 'years': range(1986, 2026)},
    ]


if __name__ == '__main__':
    main()
