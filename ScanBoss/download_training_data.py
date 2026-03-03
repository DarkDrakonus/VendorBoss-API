"""
ScanBoss AI - Training Data Downloader

Downloads base card images from official APIs to train card identification.
Downloads 1 image per card (base version only).

Phase 1: Base card recognition (set + card number)
Phase 2: Variant detection (add real photos later: holos, full arts, etc.)

Supported sources:
- Pokemon: PokemonTCG.io API
- Magic: Scryfall API  
- FFTCG: User-provided images (future)

Usage:
    python download_training_data.py --game pokemon --limit 100    # Test with 100 cards
    python download_training_data.py --game pokemon               # Full download (~10K cards)
    python download_training_data.py --game magic --limit 500
    python download_training_data.py --all                        # Download all games

Output structure:
    /ScanBoss/training_data/
        pokemon/base1/001.jpg
        pokemon/base1/004.jpg
        magic/neo/123.jpg
"""

import requests
import os
import time
import argparse
from pathlib import Path
from PIL import Image
from io import BytesIO
import json

# Configuration
SCANBOSS_DIR = Path(__file__).parent
TRAINING_DATA_DIR = SCANBOSS_DIR / "training_data"

# API Configuration
POKEMON_API = "https://api.pokemontcg.io/v2"
SCRYFALL_API = "https://api.scryfall.com"

# API Keys (optional, increases rate limits)
POKEMON_API_KEY = os.getenv("POKEMONTCG_API_KEY")


class ScanBossDataDownloader:
    """ScanBoss AI Training Data Downloader"""
    
    def __init__(self, game: str):
        self.game = game.lower()
        self.training_dir = TRAINING_DATA_DIR / self.game
        self.training_dir.mkdir(parents=True, exist_ok=True)
        
        self.session = requests.Session()
        if POKEMON_API_KEY and game == 'pokemon':
            self.session.headers.update({'X-Api-Key': POKEMON_API_KEY})
        
        self.stats = {
            'total_cards': 0,
            'downloaded': 0,
            'skipped': 0,
            'errors': 0
        }
    
    def download_pokemon(self, limit: int = None):
        """Download Pokemon card training images"""
        print(f"\n{'='*60}")
        print("SCANBOSS AI - POKEMON TRAINING DATA DOWNLOAD")
        print(f"{'='*60}\n")
        
        # Get all sets first (with retries)
        print("Fetching Pokemon sets...")
        for attempt in range(3):
            try:
                sets_response = self.session.get(f"{POKEMON_API}/sets", timeout=30)
                sets_response.raise_for_status()
                sets = sets_response.json()['data']
                break
            except Exception as e:
                if attempt < 2:
                    print(f"  Retry {attempt + 1}/3 - API timeout, waiting 10 seconds...")
                    time.sleep(10)
                else:
                    print(f"\n✗ Failed to fetch sets after 3 attempts: {e}")
                    print("\nPokemon API might be down. Try again later or try Magic instead:")
                    print("  python3 download_training_data.py --game magic\n")
                    return
        
        print(f"Found {len(sets)} Pokemon sets\n")
        
        cards_downloaded = 0
        
        for set_data in sets:
            set_code = set_data['id']
            set_name = set_data['name']
            
            print(f"Processing: {set_name} ({set_code})")
            
            # Create set directory
            set_dir = self.training_dir / set_code
            set_dir.mkdir(exist_ok=True)
            
            # Fetch cards for this set
            page = 1
            while True:
                if limit and cards_downloaded >= limit:
                    print(f"\n✓ Limit reached ({limit} cards)")
                    return
                
                try:
                    url = f"{POKEMON_API}/cards"
                    params = {
                        'q': f'set.id:{set_code}',
                        'page': page,
                        'pageSize': 250
                    }
                    
                    response = self.session.get(url, params=params, timeout=30)
                    response.raise_for_status()
                    data = response.json()
                    
                    cards = data['data']
                    if not cards:
                        break
                    
                    for card in cards:
                        if limit and cards_downloaded >= limit:
                            break
                        
                        self._download_pokemon_card(card, set_dir)
                        cards_downloaded += 1
                    
                    page += 1
                    time.sleep(0.1)  # Rate limiting
                    
                except Exception as e:
                    print(f"  Error fetching page {page}: {e}")
                    break
            
            print(f"  → Downloaded {cards_downloaded} cards from {set_name}\n")
        
        self._print_stats()
    
    def _download_pokemon_card(self, card: dict, set_dir: Path):
        """Download a single Pokemon card (base image only)"""
        card_number = card['number']
        card_name = card['name']
        
        # Get image URLs
        images = card.get('images', {})
        image_url = images.get('large') or images.get('small')
        
        if not image_url:
            print(f"  ⚠ No image for {card_number}: {card_name}")
            self.stats['skipped'] += 1
            return
        
        # Single file per card (base image)
        filename = f"{card_number}.jpg"
        filepath = set_dir / filename
        
        # Skip if already downloaded
        if filepath.exists():
            self.stats['skipped'] += 1
            return
        
        try:
            # Download image
            img_response = self.session.get(image_url, timeout=10)
            img_response.raise_for_status()
            
            # Save image
            img = Image.open(BytesIO(img_response.content))
            
            # Resize to standard size (saves space, faster training)
            img = img.resize((400, 560), Image.Resampling.LANCZOS)
            img.save(filepath, 'JPEG', quality=95)
            
            self.stats['downloaded'] += 1
            self.stats['total_cards'] += 1
            
            print(f"  ✓ {card_number}: {card_name}")
            
            time.sleep(0.05)  # Small delay to be nice to API
            
        except Exception as e:
            print(f"  ✗ Error downloading {card_number}: {e}")
            self.stats['errors'] += 1
    
    # Removed - no longer needed for base card training
    
    def download_magic(self, limit: int = None):
        """Download Magic: The Gathering card training images"""
        print(f"\n{'='*60}")
        print("SCANBOSS AI - MAGIC THE GATHERING TRAINING DATA DOWNLOAD")
        print(f"{'='*60}\n")
        
        print("Fetching Magic sets...")
        
        # Get all sets
        response = self.session.get(f"{SCRYFALL_API}/sets")
        response.raise_for_status()
        sets = response.json()['data']
        
        # Filter to only main sets (not tokens, etc.)
        main_sets = [s for s in sets if s['set_type'] in ['expansion', 'core', 'masters']]
        print(f"Found {len(main_sets)} main Magic sets\n")
        
        cards_downloaded = 0
        
        for set_data in main_sets:
            if limit and cards_downloaded >= limit:
                break
            
            set_code = set_data['code']
            set_name = set_data['name']
            
            print(f"Processing: {set_name} ({set_code})")
            
            # Create set directory
            set_dir = self.training_dir / set_code
            set_dir.mkdir(exist_ok=True)
            
            try:
                # Get cards for this set
                search_url = f"{SCRYFALL_API}/cards/search"
                params = {
                    'q': f'set:{set_code}',
                    'unique': 'prints'
                }
                
                response = self.session.get(search_url, params=params)
                response.raise_for_status()
                data = response.json()
                
                while True:
                    cards = data.get('data', [])
                    
                    for card in cards:
                        if limit and cards_downloaded >= limit:
                            break
                        
                        self._download_magic_card(card, set_dir)
                        cards_downloaded += 1
                    
                    # Check for more pages
                    if not data.get('has_more'):
                        break
                    
                    next_page = data.get('next_page')
                    if not next_page:
                        break
                    
                    time.sleep(0.1)  # Scryfall rate limit: 10 req/sec
                    response = self.session.get(next_page)
                    response.raise_for_status()
                    data = response.json()
                
                print(f"  → Downloaded {cards_downloaded} cards from {set_name}\n")
                
            except Exception as e:
                print(f"  Error processing {set_name}: {e}\n")
                continue
        
        self._print_stats()
    
    def _download_magic_card(self, card: dict, set_dir: Path):
        """Download a single Magic card (base image only)"""
        collector_number = card.get('collector_number', 'unknown')
        card_name = card['name']
        
        # Get image URL
        image_uris = card.get('image_uris')
        if not image_uris:
            # Handle double-faced cards
            card_faces = card.get('card_faces', [])
            if card_faces:
                image_uris = card_faces[0].get('image_uris')
        
        if not image_uris:
            self.stats['skipped'] += 1
            return
        
        image_url = image_uris.get('large') or image_uris.get('normal')
        
        # Single file per card (base image)
        filename = f"{collector_number}.jpg"
        filepath = set_dir / filename
        
        if filepath.exists():
            self.stats['skipped'] += 1
            return
        
        try:
            img_response = self.session.get(image_url, timeout=10)
            img_response.raise_for_status()
            
            img = Image.open(BytesIO(img_response.content))
            img = img.resize((400, 560), Image.Resampling.LANCZOS)
            img.save(filepath, 'JPEG', quality=95)
            
            self.stats['downloaded'] += 1
            self.stats['total_cards'] += 1
            
            print(f"  ✓ {collector_number}: {card_name}")
            
            time.sleep(0.1)  # Scryfall rate limit
            
        except Exception as e:
            print(f"  ✗ Error downloading {collector_number}: {e}")
            self.stats['errors'] += 1
    
    # Removed - no longer needed for base card training
    
    def _print_stats(self):
        """Print download statistics"""
        print(f"\n{'='*60}")
        print("DOWNLOAD COMPLETE")
        print(f"{'='*60}")
        print(f"Total cards processed: {self.stats['total_cards']}")
        print(f"Downloaded: {self.stats['downloaded']}")
        print(f"Skipped (already exist): {self.stats['skipped']}")
        print(f"Errors: {self.stats['errors']}")
        print(f"{'='*60}\n")
        
        # Save metadata
        metadata = {
            'game': self.game,
            'stats': self.stats,
            'training_dir': str(self.training_dir)
        }
        
        metadata_file = self.training_dir / 'download_metadata.json'
        with open(metadata_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print(f"Metadata saved to: {metadata_file}\n")


def main():
    parser = argparse.ArgumentParser(
        description='CardSight AI - Training Data Downloader'
    )
    parser.add_argument('--game', choices=['pokemon', 'magic', 'all'],
                       help='Which game to download')
    parser.add_argument('--limit', type=int,
                       help='Limit number of cards (for testing)')
    
    args = parser.parse_args()
    
    print("\n" + "="*60)
    print("SCANBOSS AI - TRAINING DATA DOWNLOADER")
    print("="*60)
    print(f"Output directory: {TRAINING_DATA_DIR}")
    print("="*60 + "\n")
    
    if args.game == 'all':
        games = ['pokemon', 'magic']
    else:
        games = [args.game] if args.game else ['pokemon']
    
    for game in games:
        downloader = ScanBossDataDownloader(game)
        
        if game == 'pokemon':
            downloader.download_pokemon(limit=args.limit)
        elif game == 'magic':
            downloader.download_magic(limit=args.limit)
        
        time.sleep(1)


if __name__ == '__main__':
    main()
