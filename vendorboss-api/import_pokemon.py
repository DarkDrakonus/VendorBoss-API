"""
Pokémon TCG Catalog Importer
Reads from locally cloned PokemonTCG/pokemon-tcg-data GitHub repo.
No API key, no rate limits, completely offline.

Setup:
    git clone --depth 1 https://github.com/PokemonTCG/pokemon-tcg-data.git /tmp/pokemon-tcg-data

Usage:
    python3 import_pokemon.py                        # import all sets
    python3 import_pokemon.py --sets base1,base2     # specific sets
    python3 import_pokemon.py --dry-run              # count only, no DB writes
    python3 import_pokemon.py --resume               # skip sets already in DB
"""

import os
import sys
import json
import argparse
from pathlib import Path
from datetime import datetime

sys.path.insert(0, os.path.dirname(__file__))

from database import get_db
import models
from sqlalchemy.orm import Session
from sqlalchemy import func

DATA_DIR   = Path("/tmp/pokemon-tcg-data")
CARDS_DIR  = DATA_DIR / "cards" / "en"
SETS_FILE  = DATA_DIR / "sets" / "en.json"
BATCH_SIZE = 250

def log(msg):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}", flush=True)

def load_set_metadata():
    if not SETS_FILE.exists():
        log(f"WARNING: {SETS_FILE} not found")
        return {}
    with open(SETS_FILE) as f:
        sets = json.load(f)
    return {s["id"]: s for s in sets}

def get_or_create_category(db, cache):
    key = "Pokémon TCG"
    if key not in cache:
        row = db.query(models.Category).filter(func.lower(models.Category.category_name) == key.lower()).first()
        if not row:
            row = models.Category(category_name=key, category_type="tcg")
            db.add(row)
            db.flush()
        cache[key] = row
    return cache[key]

def get_or_create_brand(db, cache):
    key = "The Pokémon Company"
    if key not in cache:
        row = db.query(models.Brand).filter(func.lower(models.Brand.brand_name) == key.lower()).first()
        if not row:
            row = models.Brand(brand_name=key, is_active=True)
            db.add(row)
            db.flush()
        cache[key] = row
    return cache[key]

def get_or_create_set_row(db, cache, set_code, set_meta, category_id, brand_id):
    if set_code not in cache:
        row = db.query(models.Set).filter(func.lower(models.Set.set_code) == set_code.lower()).first()
        if not row:
            release = set_meta.get("releaseDate", "") if set_meta else ""
            year = int(release[:4]) if len(release) >= 4 else 0
            row = models.Set(
                set_name    = set_meta.get("name", set_code) if set_meta else set_code,
                set_code    = set_code,
                set_year    = year,
                total_cards = set_meta.get("total", 0) if set_meta else 0,
                category_id = category_id,
                brand_id    = brand_id,
            )
            db.add(row)
            db.flush()
        cache[set_code] = row
    return cache[set_code]

def set_has_cards(db, set_id):
    return db.query(models.TcgDetail).filter(models.TcgDetail.set_id == set_id).first() is not None

def card_already_exists(db, set_code, card_number):
    return db.query(models.TcgDetail).filter(
        models.TcgDetail.set_code == set_code,
        models.TcgDetail.card_number == card_number,
        models.TcgDetail.variant_type == "normal",
    ).first() is not None

def build_card_text(card):
    parts = []
    for ability in card.get("abilities") or []:
        parts.append(f"[{ability.get('type','')}] {ability.get('name','')}: {ability.get('text','')}".strip())
    for attack in card.get("attacks") or []:
        cost = ",".join(attack.get("cost") or [])
        parts.append(f"{attack.get('name','')} ({cost}) {attack.get('damage','')}: {attack.get('text','')}".strip(": "))
    return "\n".join(parts)[:2000] if parts else None

def build_tcg_detail(card, product_id, set_id, set_code, category_id):
    types = card.get("types") or []
    hp = None
    try:
        hp = int(card.get("hp", "")) if card.get("hp") else None
    except (ValueError, TypeError):
        pass
    subtypes = card.get("subtypes") or []
    images = card.get("images", {})
    image_url = images.get("large") or images.get("small") if images else None
    return models.TcgDetail(
        product_id   = product_id,
        set_id       = set_id,
        category_id  = category_id,
        card_name    = card.get("name", "Unknown"),
        card_number  = card.get("number", ""),
        rarity       = card.get("rarity"),
        card_type    = card.get("supertype", ""),
        pokemon_type = ",".join(types) if types else None,
        hp           = hp,
        stage        = subtypes[0] if subtypes else None,
        text         = build_card_text(card),
        flavor_text  = (card.get("flavorText") or "")[:1000] or None,
        artist       = card.get("artist"),
        foil         = False,
        is_foil      = False,
        variant_type = "normal",
        set_code     = set_code,
        image_url    = image_url,
    )

def run_import(filter_sets, dry_run, resume):
    if not CARDS_DIR.exists():
        log(f"ERROR: {CARDS_DIR} not found.")
        log("Run: git clone --depth 1 https://github.com/PokemonTCG/pokemon-tcg-data.git /tmp/pokemon-tcg-data")
        sys.exit(1)

    set_meta_index = load_set_metadata()
    set_files = sorted(CARDS_DIR.glob("*.json"))
    log(f"Found {len(set_files)} set files")

    if filter_sets:
        fs_lower = [s.lower() for s in filter_sets]
        set_files = [f for f in set_files if f.stem.lower() in fs_lower]
        log(f"Filtered to {len(set_files)} sets")

    if dry_run:
        total = sum(len(json.load(open(sf))) for sf in set_files)
        log(f"DRY RUN — {len(set_files)} sets, {total:,} total cards. Exiting.")
        return

    db = next(get_db())
    cat_cache = {}
    brand_cache = {}
    set_cache = {}
    category = get_or_create_category(db, cat_cache)
    brand    = get_or_create_brand(db, brand_cache)
    db.commit()
    log(f"Category='{category.category_name}' (id={category.category_id}), Brand='{brand.brand_name}' (id={brand.brand_id})")

    total_imported = 0
    total_skipped  = 0
    total_errors   = 0

    for idx, set_file in enumerate(set_files):
        set_code = set_file.stem
        set_meta = set_meta_index.get(set_code)
        set_name = set_meta.get("name", set_code) if set_meta else set_code
        log(f"\n[{idx+1}/{len(set_files)}] {set_name} ({set_code})")

        try:
            cards = json.load(open(set_file))
        except Exception as e:
            log(f"  ERROR reading file: {e}")
            total_errors += 1
            continue

        set_row = get_or_create_set_row(db, set_cache, set_code, set_meta, category.category_id, brand.brand_id)
        db.commit()

        if resume and set_has_cards(db, set_row.set_id):
            log(f"  SKIP (already imported)")
            continue

        set_imported = 0
        set_skipped  = 0

        for card in cards:
            try:
                card_num = card.get("number", "")
                if card_already_exists(db, set_code, card_num):
                    set_skipped += 1
                    continue
                product = models.Product(product_type_id="pt_card")
                db.add(product)
                db.flush()
                tcg = build_tcg_detail(card, product.product_id, set_row.set_id, set_code, category.category_id)
                db.add(tcg)
                set_imported += 1
                if set_imported % BATCH_SIZE == 0:
                    db.commit()
                    log(f"    {set_imported} imported...")
            except Exception as e:
                total_errors += 1
                if total_errors <= 20:
                    log(f"  ERROR on '{card.get('name','?')}': {e}")
                db.rollback()
                db = next(get_db())
                cat_cache = {}; brand_cache = {}; set_cache = {}
                category = get_or_create_category(db, cat_cache)
                brand    = get_or_create_brand(db, brand_cache)

        try:
            db.commit()
        except Exception as e:
            log(f"  Commit error: {e}")
            db.rollback()

        log(f"  Done: {set_imported} imported, {set_skipped} skipped")
        total_imported += set_imported
        total_skipped  += set_skipped

    log("\n" + "=" * 60)
    log("Import complete!")
    log(f"  Imported : {total_imported:,}")
    log(f"  Skipped  : {total_skipped:,} (already existed)")
    log(f"  Errors   : {total_errors}")
    log(f"  Sets     : {len(set_cache)}")
    log("=" * 60)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import Pokémon TCG cards from local GitHub data")
    parser.add_argument("--sets",    type=str, help="Comma-separated set codes (e.g. base1,base2)")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--resume",  action="store_true", help="Skip sets already in DB")
    args = parser.parse_args()
    filter_sets = [s.strip() for s in args.sets.split(",")] if args.sets else None
    run_import(filter_sets=filter_sets, dry_run=args.dry_run, resume=args.resume)
