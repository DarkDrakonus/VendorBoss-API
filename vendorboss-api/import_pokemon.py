"""
Pokémon TCG Catalog Importer
Pulls from pokemontcg.io (free API, generous rate limits with key).

Usage:
    python import_pokemon.py                      # import all sets
    python import_pokemon.py --sets sv1,sv2       # specific sets by ID
    python import_pokemon.py --dry-run            # count only, no DB writes
    python import_pokemon.py --resume             # skip sets that already have cards

Get a free API key at: https://pokemontcg.io/
Without a key: 1,000 requests/day.
With a key:    20,000 requests/day (plenty for a full import).

Set your key in the .env file or environment:
    POKEMON_TCG_API_KEY=your-key-here

The full Pokémon catalog is ~20,000+ cards across 100+ sets.
A full import takes ~30 minutes without a key, ~5 minutes with one.
"""

import os
import sys
import json
import urllib.request
import urllib.parse
import argparse
import time
from datetime import datetime

sys.path.insert(0, os.path.dirname(__file__))

from database import get_db
import models
from sqlalchemy.orm import Session
from sqlalchemy import func
from dotenv import load_dotenv

load_dotenv()

# ── Config ────────────────────────────────────────────────────────────────────

POKEMON_API_KEY  = os.getenv("POKEMON_TCG_API_KEY", "")
POKEMON_API_BASE = "https://api.pokemontcg.io/v2"
PAGE_SIZE        = 250   # max allowed by the API
BATCH_SIZE       = 250   # DB commit interval
REQUEST_DELAY    = 0.1   # seconds between requests (be polite)

# ── Helpers ───────────────────────────────────────────────────────────────────

def log(msg: str):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)


def pokemon_request(path: str, params: dict | None = None) -> dict:
    """Make a request to the Pokémon TCG API, handling rate limits."""
    url = f"{POKEMON_API_BASE}/{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params)

    headers = {"User-Agent": "VendorBoss/2.0"}
    if POKEMON_API_KEY:
        headers["X-Api-Key"] = POKEMON_API_KEY

    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers=headers)
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read())
        except urllib.error.HTTPError as e:
            if e.code == 429:
                wait = 60 * (attempt + 1)
                log(f"  Rate limited! Waiting {wait}s before retry...")
                time.sleep(wait)
            else:
                raise
        except Exception as e:
            if attempt == 2:
                raise
            log(f"  Request error (attempt {attempt+1}): {e}. Retrying...")
            time.sleep(5)
    raise RuntimeError(f"All retries failed for {url}")


def get_all_sets() -> list[dict]:
    """Fetch the full list of Pokémon TCG sets."""
    log("Fetching set list from pokemontcg.io...")
    result = pokemon_request("sets", {"pageSize": 250, "orderBy": "releaseDate"})
    sets = result.get("data", [])
    log(f"Found {len(sets)} sets")
    return sets


def get_cards_for_set(set_id: str) -> list[dict]:
    """Fetch all cards in a given set, handling pagination."""
    all_cards = []
    page = 1
    while True:
        result = pokemon_request("cards", {
            "q": f"set.id:{set_id}",
            "pageSize": PAGE_SIZE,
            "page": page,
            "orderBy": "number",
        })
        cards  = result.get("data", [])
        total  = result.get("totalCount", 0)
        all_cards.extend(cards)
        if len(all_cards) >= total or not cards:
            break
        page += 1
        time.sleep(REQUEST_DELAY)
    return all_cards


def get_or_create_category(db: Session, cache: dict) -> models.Category:
    key = "Pokémon TCG"
    if key not in cache:
        row = db.query(models.Category).filter(
            func.lower(models.Category.category_name) == key.lower()
        ).first()
        if not row:
            row = models.Category(category_name=key, category_type="tcg")
            db.add(row)
            db.flush()
        cache[key] = row
    return cache[key]


def get_or_create_brand(db: Session, cache: dict) -> models.Brand:
    key = "The Pokémon Company"
    if key not in cache:
        row = db.query(models.Brand).filter(
            func.lower(models.Brand.brand_name) == key.lower()
        ).first()
        if not row:
            row = models.Brand(brand_name=key, is_active=True)
            db.add(row)
            db.flush()
        cache[key] = row
    return cache[key]


def get_or_create_set_row(db, cache, set_data, category_id, brand_id) -> models.Set:
    set_code = set_data.get("id", "").lower()
    if set_code not in cache:
        row = db.query(models.Set).filter(
            func.lower(models.Set.set_code) == set_code
        ).first()
        if not row:
            # Parse year from releaseDate "YYYY/MM/DD" or "YYYY-MM-DD"
            release = set_data.get("releaseDate", "")
            year = int(release[:4]) if len(release) >= 4 else 0
            row = models.Set(
                set_name    = set_data.get("name", set_code),
                set_code    = set_code,
                set_year    = year,
                total_cards = set_data.get("total", 0),
                category_id = category_id,
                brand_id    = brand_id,
            )
            db.add(row)
            db.flush()
        cache[set_code] = row
    return cache[set_code]


def set_has_cards(db: Session, set_id: int) -> bool:
    """Check if we already imported any cards for this set."""
    return db.query(models.TcgDetail).filter(
        models.TcgDetail.set_id == set_id
    ).first() is not None


def card_already_exists(db: Session, set_code: str, card_number: str) -> bool:
    return db.query(models.TcgDetail).filter(
        models.TcgDetail.set_code == set_code,
        models.TcgDetail.card_number == card_number,
        models.TcgDetail.variant_type == "normal",
    ).first() is not None


def best_image_url(card: dict) -> str | None:
    images = card.get("images", {})
    return images.get("large") or images.get("small")


def map_rarity(raw: str | None) -> str | None:
    if not raw:
        return None
    # Normalise to shorter names
    rarity_map = {
        "Common":                    "Common",
        "Uncommon":                  "Uncommon",
        "Rare":                      "Rare",
        "Rare Holo":                 "Rare Holo",
        "Rare Holo EX":              "Rare Holo EX",
        "Rare Holo GX":              "Rare Holo GX",
        "Rare Holo V":               "Rare Holo V",
        "Rare Holo VMAX":            "Rare Holo VMAX",
        "Rare Holo VSTAR":           "Rare Holo VSTAR",
        "Rare Ultra":                "Ultra Rare",
        "Rare Secret":               "Secret Rare",
        "Amazing Rare":              "Amazing Rare",
        "Illustration Rare":         "Illustration Rare",
        "Special Illustration Rare": "Special Illustration Rare",
        "Hyper Rare":                "Hyper Rare",
        "Double Rare":               "Double Rare",
        "Trainer Gallery Rare Holo": "Trainer Gallery",
    }
    return rarity_map.get(raw, raw)


def build_tcg_detail(card, product_id, set_id, set_code, category_id, image_url):
    # Types e.g. ["Fire", "Water"]
    types = card.get("types") or []
    pokemon_type = ",".join(types) if types else None

    # HP
    hp_str = card.get("hp")
    hp = None
    if hp_str:
        try:
            hp = int(hp_str)
        except ValueError:
            pass

    # Stage: "Basic", "Stage 1", "Stage 2", "VMAX", "VSTAR" etc.
    stage = card.get("subtypes", [None])[0] if card.get("subtypes") else None

    # Card text — join all attack text + rules
    text_parts = []
    for attack in card.get("attacks") or []:
        name = attack.get("name", "")
        dmg  = attack.get("damage", "")
        txt  = attack.get("text", "")
        text_parts.append(f"{name} {dmg}: {txt}".strip(": "))
    for rule in card.get("rules") or []:
        text_parts.append(rule)
    full_text = "\n".join(text_parts)[:2000] if text_parts else None

    artist = card.get("artist")

    return models.TcgDetail(
        product_id   = product_id,
        set_id       = set_id,
        category_id  = category_id,
        card_name    = card.get("name", "Unknown"),
        card_number  = card.get("number", ""),
        rarity       = map_rarity(card.get("rarity")),
        card_type    = card.get("supertype", ""),        # "Pokémon", "Trainer", "Energy"
        pokemon_type = pokemon_type,
        hp           = hp,
        stage        = stage,
        text         = full_text,
        artist       = artist,
        foil         = False,
        is_foil      = False,
        variant_type = "normal",
        set_code     = set_code,
        image_url    = image_url,
    )


# ── Main import ───────────────────────────────────────────────────────────────

def run_import(filter_sets: list | None, dry_run: bool, resume: bool):
    if not POKEMON_API_KEY:
        log("WARNING: No POKEMON_TCG_API_KEY set. Rate limited to ~1,000 req/day.")
        log("Get a free key at https://pokemontcg.io/ and add to .env: POKEMON_TCG_API_KEY=...")

    # Fetch set list
    all_sets = get_all_sets()

    if filter_sets:
        fs_lower = [s.lower() for s in filter_sets]
        all_sets = [s for s in all_sets if s.get("id", "").lower() in fs_lower]
        log(f"Filtered to {len(all_sets)} sets: {[s['id'] for s in all_sets]}")

    if dry_run:
        total_cards = sum(s.get("total", 0) for s in all_sets)
        log(f"DRY RUN — {len(all_sets)} sets, ~{total_cards:,} total cards. Exiting.")
        return

    # DB setup
    db: Session = next(get_db())
    cat_cache   = {}
    brand_cache = {}
    set_cache   = {}

    category = get_or_create_category(db, cat_cache)
    brand    = get_or_create_brand(db, brand_cache)
    db.commit()
    log(f"Category='{category.category_name}' (id={category.category_id}), Brand='{brand.brand_name}' (id={brand.brand_id})")

    total_imported = 0
    total_skipped  = 0
    total_errors   = 0

    for set_idx, set_data in enumerate(all_sets):
        set_id_str = set_data.get("id", "")
        set_name   = set_data.get("name", set_id_str)
        log(f"\n[{set_idx+1}/{len(all_sets)}] Set: {set_name} ({set_id_str})")

        # Get or create set row
        set_row = get_or_create_set_row(db, set_cache, set_data, category.category_id, brand.brand_id)
        db.commit()

        # Skip if already imported (resume mode)
        if resume and set_has_cards(db, set_row.set_id):
            log(f"  SKIP (already imported)")
            continue

        # Fetch cards from API
        try:
            cards = get_cards_for_set(set_id_str)
            log(f"  Fetched {len(cards)} cards from API")
        except Exception as e:
            log(f"  ERROR fetching cards: {e}")
            total_errors += 1
            continue

        set_imported = 0
        set_skipped  = 0

        for card in cards:
            try:
                card_num  = card.get("number", "")
                set_code  = set_id_str.lower()

                if card_already_exists(db, set_code, card_num):
                    set_skipped += 1
                    continue

                img_url = best_image_url(card)

                product = models.Product(product_type_id="pt_card")
                db.add(product)
                db.flush()

                tcg = build_tcg_detail(card, product.product_id, set_row.set_id, set_code, category.category_id, img_url)
                db.add(tcg)
                set_imported += 1

                if set_imported % BATCH_SIZE == 0:
                    db.commit()
                    log(f"    {set_imported} imported so far...")

            except Exception as e:
                total_errors += 1
                if total_errors <= 20:
                    log(f"  ERROR on card '{card.get('name','?')}': {e}")
                db.rollback()
                db = next(get_db())
                cat_cache = {}
                brand_cache = {}
                set_cache = {}
                category = get_or_create_category(db, cat_cache)
                brand    = get_or_create_brand(db, brand_cache)

        try:
            db.commit()
        except Exception as e:
            log(f"  Commit error for set {set_name}: {e}")
            db.rollback()

        log(f"  Done: {set_imported} imported, {set_skipped} skipped")
        total_imported += set_imported
        total_skipped  += set_skipped

        time.sleep(REQUEST_DELAY)

    log("\n" + "=" * 60)
    log("Import complete!")
    log(f"  Imported : {total_imported:,}")
    log(f"  Skipped  : {total_skipped:,} (already existed)")
    log(f"  Errors   : {total_errors}")
    log(f"  Sets     : {len(set_cache)}")
    log("=" * 60)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import Pokémon TCG cards from pokemontcg.io")
    parser.add_argument("--sets",    type=str, help="Comma-separated set IDs (e.g. sv1,sv2,base1)")
    parser.add_argument("--dry-run", action="store_true", help="Count only, no DB writes")
    parser.add_argument("--resume",  action="store_true", help="Skip sets that already have cards in DB")
    args = parser.parse_args()

    filter_sets = [s.strip() for s in args.sets.split(",")] if args.sets else None
    run_import(filter_sets=filter_sets, dry_run=args.dry_run, resume=args.resume)
