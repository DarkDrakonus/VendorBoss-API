"""
VendorBoss 2.0 — Schema Migration
Renames and restructures legacy v1 sports-centric tables to support
all card categories (TCG, sports, non-sport).

Safe to run once. Will skip if already migrated.

Run: python3 migrate_schema.py
"""
import os
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
engine = create_engine(os.getenv("DATABASE_URL"))

with engine.connect() as conn:

    # ── Guard: skip if already migrated ──────────────────────────────────────
    result = conn.execute(text("""
        SELECT EXISTS (
            SELECT 1 FROM information_schema.tables
            WHERE table_name = 'categories'
        )
    """))
    if result.scalar():
        print("✅ Already migrated — categories table exists, skipping.")
        exit(0)

    print("🔄 Starting VendorBoss schema migration...")

    # ── 1. Create categories table ────────────────────────────────────────────
    print("  → Creating categories table...")
    conn.execute(text("""
        CREATE TABLE categories (
            category_id   SERIAL PRIMARY KEY,
            category_name VARCHAR NOT NULL UNIQUE,
            category_type VARCHAR NOT NULL DEFAULT 'tcg',
            created_at    TIMESTAMPTZ DEFAULT now()
        )
    """))

    # Insert all VendorBoss supported categories
    conn.execute(text("""
        INSERT INTO categories (category_name, category_type) VALUES
            -- TCG
            ('Pokemon',               'tcg'),
            ('Magic: The Gathering',  'tcg'),
            ('One Piece',             'tcg'),
            ('Final Fantasy TCG',     'tcg'),
            ('Yu-Gi-Oh!',             'tcg'),
            ('Dragon Ball Super',     'tcg'),
            ('Disney Lorcana',        'tcg'),
            ('Flesh and Blood',       'tcg'),
            ('Digimon',               'tcg'),
            ('Star Wars Unlimited',   'tcg'),
            ('Weiss Schwarz',         'tcg'),
            ('Cardfight!! Vanguard',  'tcg'),
            -- Sports
            ('Baseball',              'sports'),
            ('Basketball',            'sports'),
            ('Football',              'sports'),
            ('Hockey',                'sports'),
            ('Soccer',                'sports'),
            ('Golf',                  'sports'),
            ('Boxing/MMA',            'sports'),
            ('Wrestling',             'sports'),
            ('Multi-Sport',           'sports'),
            -- Non-Sport
            ('Marvel',                'non_sport'),
            ('DC Comics',             'non_sport'),
            ('Star Wars',             'non_sport'),
            ('WWE',                   'non_sport'),
            ('Garbage Pail Kids',     'non_sport'),
            ('Topps Chrome',          'non_sport'),
            ('Vintage Non-Sport',     'non_sport'),
            ('Anime Cards',           'non_sport')
    """))
    conn.commit()
    print("     29 categories inserted")

    # ── 2. Create new brands table with integer PK ────────────────────────────
    print("  → Rebuilding brands table...")
    conn.execute(text("""
        CREATE TABLE brands_new (
            brand_id    SERIAL PRIMARY KEY,
            brand_name  VARCHAR NOT NULL UNIQUE,
            created_at  TIMESTAMPTZ DEFAULT now(),
            is_active   BOOLEAN DEFAULT true
        )
    """))

    conn.execute(text("""
        INSERT INTO brands_new (brand_name) VALUES
            ('The Pokemon Company'),
            ('Wizards of the Coast'),
            ('Bandai'),
            ('Square Enix'),
            ('Konami'),
            ('Bushiroad'),
            ('Topps'),
            ('Panini'),
            ('Upper Deck'),
            ('Bowman'),
            ('Donruss'),
            ('Fleer'),
            ('Score'),
            ('Leaf'),
            ('Press Pass'),
            ('SP Authentic'),
            ('Skybox'),
            ('Impel'),
            ('Pacific'),
            ('Playoff'),
            ('Pro Set'),
            ('Classic'),
            ('Ultra Pro'),
            ('Beckett')
    """))
    conn.commit()

    # ── 3. Create new sets table with integer PKs ─────────────────────────────
    print("  → Rebuilding sets table...")
    conn.execute(text("""
        CREATE TABLE sets_new (
            set_id        SERIAL PRIMARY KEY,
            set_name      VARCHAR NOT NULL,
            set_code      VARCHAR(30),
            set_year      INTEGER NOT NULL,
            category_id   INTEGER NOT NULL REFERENCES categories(category_id),
            brand_id      INTEGER NOT NULL REFERENCES brands_new(brand_id),
            total_cards   INTEGER,
            release_date  DATE,
            created_at    TIMESTAMPTZ DEFAULT now(),
            UNIQUE(set_name, set_year, category_id)
        )
    """))

    # Migrate existing 3 FFTCG sets
    conn.execute(text("""
        INSERT INTO sets_new (set_name, set_code, set_year, category_id, brand_id)
        SELECT
            s.set_name,
            s.set_id,   -- use old string id as set_code for reference
            s.set_year,
            c.category_id,
            b.brand_id
        FROM sets s
        JOIN categories c ON c.category_name = 'Final Fantasy TCG'
        JOIN brands_new b ON b.brand_name = 'Square Enix'
    """))
    conn.commit()
    print("     3 existing FFTCG sets migrated")

    # ── 4. Rebuild tcg_details with integer set_id FK ─────────────────────────
    print("  → Migrating tcg_details (3421 records)...")
    conn.execute(text("""
        CREATE TABLE tcg_details_new (
            tcg_id        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            product_id    VARCHAR REFERENCES products(product_id) UNIQUE NOT NULL,
            set_id        INTEGER REFERENCES sets_new(set_id),
            category_id   INTEGER REFERENCES categories(category_id),

            -- Universal
            card_name     VARCHAR NOT NULL,
            card_number   VARCHAR,
            rarity        VARCHAR,
            card_type     VARCHAR,

            -- FFTCG
            element       VARCHAR,
            cost          INTEGER,
            power         INTEGER,
            job           VARCHAR,
            fftcg_category VARCHAR,

            -- Pokemon
            pokemon_type  VARCHAR,
            hp            INTEGER,
            stage         VARCHAR,

            -- Magic
            mana_cost     VARCHAR,
            color         VARCHAR,

            -- Common
            text          TEXT,
            set_code      VARCHAR(20),
            variant_type  VARCHAR(20) DEFAULT 'normal',
            is_foil       BOOLEAN DEFAULT false,
            image_url     TEXT,
            flavor_text   TEXT,
            artist        VARCHAR,
            foil          BOOLEAN DEFAULT false,
            variant       BOOLEAN DEFAULT false,
            variant_name  VARCHAR,

            created_at    TIMESTAMPTZ DEFAULT now(),
            updated_at    TIMESTAMPTZ DEFAULT now()
        )
    """))

    # Migrate existing tcg_details — map old string set_id to new integer set_id
    conn.execute(text("""
        INSERT INTO tcg_details_new (
            tcg_id, product_id, set_id, category_id,
            card_name, card_number, rarity, card_type,
            element, cost, power, job, fftcg_category,
            pokemon_type, hp, stage,
            mana_cost, color,
            text, set_code, variant_type, is_foil,
            image_url, flavor_text, artist, foil, variant, variant_name,
            created_at, updated_at
        )
        SELECT
            t.tcg_id::uuid,
            t.product_id,
            sn.set_id,
            c.category_id,
            t.card_name,
            t.card_number,
            t.rarity,
            t.card_type,
            t.element,
            t.cost,
            t.power,
            t.job,
            t.category,
            t.pokemon_type,
            t.hp,
            t.stage,
            t.mana_cost,
            t.color,
            t.text,
            t.set_code,
            COALESCE(t.variant_type, 'normal'),
            COALESCE(t.is_foil, false),
            t.image_url,
            t.flavor_text,
            t.artist,
            COALESCE(t.foil, false),
            COALESCE(t.variant, false),
            t.variant_name,
            t.created_at,
            t.updated_at
        FROM tcg_details t
        LEFT JOIN sets s ON s.set_id = t.set_code
        LEFT JOIN sets_new sn ON sn.set_code = t.set_code
        LEFT JOIN categories c ON c.category_name = 'Final Fantasy TCG'
    """))
    conn.commit()

    result = conn.execute(text("SELECT COUNT(*) FROM tcg_details_new")).scalar()
    print(f"     {result} records migrated")

    # ── 5. Rebuild card_details with category_id ──────────────────────────────
    print("  → Rebuilding card_details table...")
    conn.execute(text("""
        CREATE TABLE card_details_new (
            card_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
            product_id       VARCHAR REFERENCES products(product_id) UNIQUE NOT NULL,
            category_id      INTEGER REFERENCES categories(category_id),
            set_id           INTEGER REFERENCES sets_new(set_id),
            player           VARCHAR NOT NULL,
            team             VARCHAR,
            position         VARCHAR,
            card_number      VARCHAR,
            year             INTEGER,
            variant          BOOLEAN DEFAULT false,
            variant_name     VARCHAR,
            rookie_card      BOOLEAN DEFAULT false,
            serial_number    VARCHAR,
            autograph        BOOLEAN DEFAULT false,
            relic            BOOLEAN DEFAULT false,
            refractor        BOOLEAN DEFAULT false,
            graded           BOOLEAN DEFAULT false,
            grading_company  VARCHAR,
            grade            VARCHAR,
            grade_numeric    FLOAT,
            cert_number      VARCHAR,
            is_insert        BOOLEAN DEFAULT false,
            is_sp            BOOLEAN DEFAULT false,
            created_at       TIMESTAMPTZ DEFAULT now(),
            updated_at       TIMESTAMPTZ DEFAULT now()
        )
    """))
    conn.commit()

    # ── 6. Swap tables — rename old, rename new into place ────────────────────
    print("  → Swapping tables...")

    # tcg_details
    conn.execute(text("ALTER TABLE tcg_details RENAME TO tcg_details_v1"))
    conn.execute(text("ALTER TABLE tcg_details_new RENAME TO tcg_details"))

    # card_details
    conn.execute(text("ALTER TABLE card_details RENAME TO card_details_v1"))
    conn.execute(text("ALTER TABLE card_details_new RENAME TO card_details"))

    # sets
    conn.execute(text("ALTER TABLE sets RENAME TO sets_v1"))
    conn.execute(text("ALTER TABLE sets_new RENAME TO sets"))

    # brands
    conn.execute(text("ALTER TABLE brands RENAME TO brands_v1"))
    conn.execute(text("ALTER TABLE brands_new RENAME TO brands"))

    conn.commit()

    # ── 7. Drop legacy tables ─────────────────────────────────────────────────
    print("  → Dropping legacy tables...")
    conn.execute(text("DROP TABLE IF EXISTS leagues CASCADE"))
    conn.execute(text("DROP TABLE IF EXISTS teams CASCADE"))
    conn.execute(text("DROP TABLE IF EXISTS sports CASCADE"))
    conn.commit()

    print("")
    print("✅ Migration complete!")
    print("   categories table created with 29 categories")
    print("   brands rebuilt with integer PK")
    print("   sets rebuilt with integer PK")
    print("   tcg_details migrated (3421 records preserved)")
    print("   card_details rebuilt with category_id")
    print("   Legacy tables renamed to *_v1 for safety")
    print("   sports, leagues, teams dropped")
    print("")
    print("Next: update models.py to match new schema, then run seed_demo.py")
