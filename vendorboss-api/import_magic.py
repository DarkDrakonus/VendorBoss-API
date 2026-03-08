"""
Magic: The Gathering Catalog Importer
Pulls from Scryfall bulk data (free, no rate limits) and inserts into VendorBoss catalog.

Usage:
    python import_magic.py                   # downloads fresh bulk data + imports
    python import_magic.py --skip-download   # re-uses existing bulk file if present
    python import_magic.py --dry-run         # parse + count, no DB writes
    python import_magic.py --sets eld,thb    # only import specific set codes

Local images are matched from:
    /Users/travisdewitt/Repos/Scans/training_data/magic/{set_code}-{collector_number}/image.jpg
    /Users/travisdewitt/Repos/Scans/training_data/magic/{set_code}-{collector_number}★/image.jpg  (foil)

If a local image doesn't exist, falls back to Scryfall CDN URL.
"""

import os
import sys
import json
import urllib.request
import urllib.error
import ssl
import argparse
from pathlib import Path
from datetime import datetime
import time

# ── Path setup ────────────────────────────────────────────────────────────────
# Run from vendorboss-api/ directory
sys.path.insert(0, os.path.dirname(__file__))

from database import get_db, engine
import models
from sqlalchemy.orm import Session
from sqlalchemy import func

# ── Config ────────────────────────────────────────────────────────────────────

SCRYFALL_BULK_URL = "https://data.scryfall.io/default-cards/default-cards-20250101.json"
BULK_INDEX_URL    = "https://api.scryfall.com/bulk-data"
LOCAL_BULK_FILE   = "/tmp/scryfall_default_cards.json"
LOCAL_IMAGES_BASE = "/Users/travisdewitt/Repos/Scans/training_data/magic"

# Cards we skip — not physical cards that a vendor would sell
SKIP_LAYOUTS = {"art_series", "emblem", "planar", "scheme", "vanguard", "token", "double_faced_token"}

# Batch size for DB commits
BATCH_SIZE = 500

# ── Helpers ───────────────────────────────────────────────────────────────────

def log(msg: str):
    print(f"[{datetime.now().strftime('%H:%M:%S')}] {msg}")


def fetch_latest_bulk_url() -> str:
    """Ask Scryfall API for the current default-cards download URL."""
    log("Fetching latest bulk data URL from Scryfall...")
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(BULK_INDEX_URL, headers={"User-Agent": "VendorBoss/2.0"})
    with urllib.request.urlopen(req, timeout=15, context=ctx) as resp:
        data = json.loads(resp.read())
    for item in data.get("data", []):
        if item.get("type") == "default_cards":
            url = item["download_uri"]
            log(f"Latest bulk URL: {url}")
            return url
    raise RuntimeError("Could not find default_cards in Scryfall bulk index")


def download_bulk_data(url: str, dest: str):
    """Download the bulk JSON file with a progress indicator."""
    log(f"Downloading bulk data to {dest}...")
    log("This is ~300MB and may take a few minutes...")

    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(url, headers={"User-Agent": "VendorBoss/2.0"})
    with urllib.request.urlopen(req, timeout=120, context=ctx) as resp:
        total = int(resp.headers.get("Content-Length", 0))
        downloaded = 0
        chunk_size = 1024 * 1024  # 1MB chunks
        last_log = 0

        with open(dest, "wb") as f:
            while True:
                chunk = resp.read(chunk_size)
                if not chunk:
                    break
                f.write(chunk)
                downloaded += len(chunk)
                mb = downloaded / (1024 * 1024)
                if mb - last_log >= 50:
                    if total:
                        pct = downloaded / total * 100
                        log(f"  {mb:.0f} MB / {total/(1024*1024):.0f} MB ({pct:.0f}%)")
                    else:
                        log(f"  {mb:.0f} MB downloaded...")
                    last_log = mb

    log(f"Download complete: {os.path.getsize(dest)/(1024*1024):.1f} MB")


def local_image_path(set_code: str, collector_number: str, is_foil: bool) -> str | None:
    """
    Returns the local path for a card image if it exists, else None.
    Folder naming: {set_code}-{collector_number}  or  {set_code}-{collector_number}★
    """
    base = Path(LOCAL_IMAGES_BASE)
    suffix = "★" if is_foil else ""
    folder = base / f"{set_code}-{collector_number}{suffix}"
    img = folder / "image.jpg"
    if img.exists():
        return str(img)
    # Some foil cards might not have a ★ folder — check non-foil folder
    if is_foil:
        fallback = base / f"{set_code}-{collector_number}" / "image.jpg"
        if fallback.exists():
            return str(fallback)
    return None


def scryfall_image_url(card: dict) -> str | None:
    """Extract the best available image URL from a Scryfall card object."""
    uris = card.get("image_uris")
    if uris:
        return uris.get("normal") or uris.get("large") or uris.get("small")
    # Double-faced cards have faces
    faces = card.get("card_faces", [])
    if faces:
        uris = faces[0].get("image_uris", {})
        return uris.get("normal") or uris.get("large")
    return None


def get_or_create_category(db: Session, cache: dict) -> models.Category:
    """Get or create the MTG category row, cached."""
    key = "Magic: The Gathering"
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
    """Get or create the WotC brand row, cached."""
    key = "Wizards of the Coast"
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


def get_or_create_set(
    db: Session, cache: dict,
    set_code: str, set_name: str, set_year: int,
    category_id: int, brand_id: int
) -> models.Set:
    """Get or create a Set row, keyed by set_code, cached."""
    if set_code not in cache:
        row = db.query(models.Set).filter(
            func.lower(models.Set.set_code) == set_code.lower()
        ).first()
        if not row:
            row = models.Set(
                set_name=set_name,
                set_code=set_code,
                set_year=set_year,
                category_id=category_id,
                brand_id=brand_id,
            )
            db.add(row)
            db.flush()
        cache[set_code] = row
    return cache[set_code]


def card_already_exists(db: Session, set_code: str, collector_number: str, is_foil: bool) -> bool:
    """
    Quick check — does a tcg_details row already exist for this card?
    Keyed by set_code + card_number + foil flag.
    """
    variant_type = "foil" if is_foil else "normal"
    row = (
        db.query(models.TcgDetail)
        .filter(
            models.TcgDetail.set_code == set_code,
            models.TcgDetail.card_number == collector_number,
            models.TcgDetail.variant_type == variant_type,
        )
        .first()
    )
    return row is not None


def extract_year(card: dict) -> int:
    """Pull year from released_at or set release date."""
    released = card.get("released_at", "")
    if released and len(released) >= 4:
        try:
            return int(released[:4])
        except ValueError:
            pass
    return 0


def build_tcg_detail_row(
    card: dict, product_id: str, set_id: int, category_id: int,
    is_foil: bool, image_url: str | None
) -> models.TcgDetail:
    """Map a Scryfall card dict to a TcgDetail model instance."""
    set_code       = card.get("set", "").lower()
    collector_num  = card.get("collector_number", "")
    type_line      = card.get("type_line", "")
    oracle_text    = card.get("oracle_text", "") or ""
    flavor_text    = card.get("flavor_text", "") or ""
    # For DFCs, concat both halves
    for face in card.get("card_faces", []):
        if face.get("oracle_text"):
            oracle_text += ("\n\n" if oracle_text else "") + face["oracle_text"]

    # Colors — join list to string e.g. "W,U"
    colors = ",".join(card.get("colors") or card.get("color_identity") or [])

    return models.TcgDetail(
        product_id    = product_id,
        set_id        = set_id,
        category_id   = category_id,
        card_name     = card.get("name", "Unknown"),
        card_number   = collector_num,
        rarity        = card.get("rarity", "").capitalize(),
        card_type     = type_line,
        mana_cost     = card.get("mana_cost", ""),
        color         = colors,
        text          = oracle_text[:2000] if oracle_text else None,
        flavor_text   = flavor_text[:1000] if flavor_text else None,
        artist        = card.get("artist", ""),
        foil          = is_foil,
        is_foil       = is_foil,
        variant_type  = "foil" if is_foil else "normal",
        set_code      = set_code,
        image_url     = image_url,
    )


# ── Main import ───────────────────────────────────────────────────────────────

def run_import(skip_download: bool, dry_run: bool, filter_sets: list[str] | None):
    # ── Step 1: Download bulk data if needed ─────────────────────────────────
    if not skip_download or not os.path.exists(LOCAL_BULK_FILE):
        url = fetch_latest_bulk_url()
        download_bulk_data(url, LOCAL_BULK_FILE)
    else:
        log(f"Using existing bulk file: {LOCAL_BULK_FILE} ({os.path.getsize(LOCAL_BULK_FILE)/(1024*1024):.1f} MB)")

    # ── Step 2: Parse JSON ────────────────────────────────────────────────────
    log("Parsing JSON (this may take 10-20 seconds for large file)...")
    t0 = time.time()
    with open(LOCAL_BULK_FILE, "r", encoding="utf-8") as f:
        all_cards = json.load(f)
    log(f"Loaded {len(all_cards):,} card entries in {time.time()-t0:.1f}s")

    # ── Step 3: Filter ────────────────────────────────────────────────────────
    cards = [
        c for c in all_cards
        if c.get("layout", "") not in SKIP_LAYOUTS
        and c.get("lang", "en") == "en"
        and not c.get("digital", False)  # skip Arena-only cards
    ]
    log(f"After filtering: {len(cards):,} physical English cards")

    if filter_sets:
        filter_sets_lower = [s.lower() for s in filter_sets]
        cards = [c for c in cards if c.get("set", "").lower() in filter_sets_lower]
        log(f"After set filter ({', '.join(filter_sets)}): {len(cards):,} cards")

    if dry_run:
        sets_found = set(c.get("set") for c in cards)
        log(f"DRY RUN — would import {len(cards):,} cards across {len(sets_found)} sets. Exiting.")
        return

    # ── Step 4: DB import ─────────────────────────────────────────────────────
    db: Session = next(get_db())
    category_cache: dict = {}
    brand_cache:    dict = {}
    set_cache:      dict = {}

    category = get_or_create_category(db, category_cache)
    brand     = get_or_create_brand(db, brand_cache)
    db.commit()
    log(f"Category ID: {category.category_id}, Brand ID: {brand.brand_id}")

    imported  = 0
    skipped   = 0
    errors    = 0
    batch_new = []

    for i, card in enumerate(cards):
        try:
            set_code      = card.get("set", "").lower()
            collector_num = card.get("collector_number", "")
            is_foil       = card.get("finishes", []) == ["foil"] or \
                            (card.get("foil", False) and not card.get("nonfoil", True))

            # Get or create set
            set_year = extract_year(card)
            set_obj  = get_or_create_set(
                db, set_cache,
                set_code, card.get("set_name", set_code),
                set_year, category.category_id, brand.brand_id
            )

            # Skip if already in DB (idempotent re-runs)
            if card_already_exists(db, set_code, collector_num, is_foil):
                skipped += 1
                continue

            # Determine image URL
            local_path = local_image_path(set_code, collector_num, is_foil)
            img_url    = local_path if local_path else scryfall_image_url(card)

            # Create product
            product = models.Product(product_type_id="pt_card")
            db.add(product)
            db.flush()  # get product_id

            # Create tcg_detail
            tcg = build_tcg_detail_row(card, product.product_id, set_obj.set_id, category.category_id, is_foil, img_url)
            db.add(tcg)
            imported += 1

            # Commit in batches
            if imported % BATCH_SIZE == 0:
                db.commit()
                log(f"  Progress: {imported:,} imported | {skipped:,} skipped | {i+1:,}/{len(cards):,} processed")

        except Exception as e:
            errors += 1
            if errors <= 10:
                log(f"  ERROR on card '{card.get('name', '?')}' ({card.get('set','?')}-{card.get('collector_number','?')}): {e}")
            db.rollback()
            # Re-establish session state after rollback
            db = next(get_db())
            # Rebuild caches since session is new
            category_cache = {"Magic: The Gathering": db.merge(category)}
            brand_cache    = {"Wizards of the Coast": db.merge(brand)}
            set_cache      = {k: db.merge(v) for k, v in set_cache.items()}

    # Final commit
    try:
        db.commit()
    except Exception as e:
        log(f"Final commit error: {e}")
        db.rollback()

    log("=" * 60)
    log(f"Import complete!")
    log(f"  Imported : {imported:,}")
    log(f"  Skipped  : {skipped:,} (already existed)")
    log(f"  Errors   : {errors}")
    log(f"  Sets     : {len(set_cache)}")
    log("=" * 60)


# ── CLI ───────────────────────────────────────────────────────────────────────

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Import Magic: The Gathering cards from Scryfall bulk data")
    parser.add_argument("--skip-download", action="store_true", help="Re-use existing bulk file if present")
    parser.add_argument("--dry-run",       action="store_true", help="Parse and count only, no DB writes")
    parser.add_argument("--sets",          type=str,            help="Comma-separated set codes to import (e.g. eld,thb,znr)")
    args = parser.parse_args()

    filter_sets = [s.strip() for s in args.sets.split(",")] if args.sets else None

    run_import(
        skip_download=args.skip_download,
        dry_run=args.dry_run,
        filter_sets=filter_sets,
    )
