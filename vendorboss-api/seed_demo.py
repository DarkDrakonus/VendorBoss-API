"""
Seed script — VendorBoss Demo Data
Run on the server: python3 seed_demo.py

Inserts realistic demo data for the VendorBoss Demo account.
Uses new schema: categories (int PK), brands (int PK), sets (int PK).
"""
import os
import uuid
from datetime import date, datetime, timedelta
from dotenv import load_dotenv
from sqlalchemy import create_engine, text

load_dotenv()
engine = create_engine(os.getenv("DATABASE_URL"))
db = engine.connect()

DEMO_EMAIL = "demo@vendorboss.com"

# Look up user_id dynamically so this script never breaks after re-registration
_user = db.execute(text("SELECT user_id FROM users WHERE email = :e"), {"e": DEMO_EMAIL}).fetchone()
if not _user:
    raise SystemExit(f"❌ User {DEMO_EMAIL} not found. Register the demo account first.")
USER_ID = _user[0]
print(f"  ✓ Demo user found: {USER_ID}")

def uid():
    return str(uuid.uuid4())

print("🌱 Seeding VendorBoss demo data...")

# ── Look up category and brand IDs ────────────────────────────────────────────
def cat_id(name):
    r = db.execute(text("SELECT category_id FROM categories WHERE category_name = :n"), {"n": name}).fetchone()
    if not r: raise ValueError(f"Category not found: {name}")
    return r[0]

def brand_id(name):
    r = db.execute(text("SELECT brand_id FROM brands WHERE brand_name = :n"), {"n": name}).fetchone()
    if not r: raise ValueError(f"Brand not found: {name}")
    return r[0]

CAT_POKEMON   = cat_id("Pokemon")
CAT_MAGIC     = cat_id("Magic: The Gathering")
CAT_ONEPIECE  = cat_id("One Piece")
CAT_BASEBALL  = cat_id("Baseball")
CAT_BBALL     = cat_id("Basketball")
CAT_HOCKEY    = cat_id("Hockey")
CAT_FOOTBALL  = cat_id("Football")

BRAND_POKEMON = brand_id("The Pokemon Company")
BRAND_WOTC    = brand_id("Wizards of the Coast")
BRAND_BANDAI  = brand_id("Bandai")
BRAND_TOPPS   = brand_id("Topps")
BRAND_PANINI  = brand_id("Panini")
BRAND_UD      = brand_id("Upper Deck")
BRAND_BOWMAN  = brand_id("Bowman")

print("  ✓ Categories and brands resolved")

# ── Ensure product_types exist ────────────────────────────────────────────────
db.execute(text("""
    INSERT INTO product_types (product_type_id, product_type_name) VALUES
        ('tcg',    'Trading Card Game'),
        ('sports', 'Sports Card')
    ON CONFLICT (product_type_id) DO NOTHING
"""))
db.commit()

# ── Sets ──────────────────────────────────────────────────────────────────────
print("  → Sets...")

def upsert_set(name, code, year, cat, brand):
    r = db.execute(text("""
        INSERT INTO sets (set_name, set_code, set_year, category_id, brand_id)
        VALUES (:name, :code, :year, :cat, :brand)
        ON CONFLICT (set_name, set_year, category_id) DO UPDATE SET set_code = EXCLUDED.set_code
        RETURNING set_id
    """), {"name": name, "code": code, "year": year, "cat": cat, "brand": brand}).fetchone()
    db.commit()
    return r[0]

SET_BASE        = upsert_set("Base Set",                 "base_set",        1999, CAT_POKEMON,  BRAND_POKEMON)
SET_PALDEA      = upsert_set("Paldea Evolved",           "paldea_evolved",  2023, CAT_POKEMON,  BRAND_POKEMON)
SET_SV_PROMO    = upsert_set("SV Black Star Promo",      "sv_promo",        2023, CAT_POKEMON,  BRAND_POKEMON)
SET_ALPHA       = upsert_set("Alpha",                    "alpha",           1993, CAT_MAGIC,    BRAND_WOTC)
SET_BRO         = upsert_set("The Brothers War",         "brothers_war",    2022, CAT_MAGIC,    BRAND_WOTC)
SET_RD          = upsert_set("Romance Dawn",             "romance_dawn",    2022, CAT_ONEPIECE, BRAND_BANDAI)
SET_OP06        = upsert_set("Wings of the Captain",     "op06",            2024, CAT_ONEPIECE, BRAND_BANDAI)
SET_TOPPS_23    = upsert_set("Topps Chrome 2023",        "topps_chrome_23", 2023, CAT_BASEBALL, BRAND_TOPPS)
SET_PRIZM_23    = upsert_set("Prizm 2023",               "prizm_23",        2023, CAT_BBALL,    BRAND_PANINI)
SET_UD_24       = upsert_set("Series 1 2024-25",         "ud_series1_24",   2024, CAT_HOCKEY,   BRAND_UD)
SET_BOWMAN_23   = upsert_set("Bowman 2023",              "bowman_23",       2023, CAT_BASEBALL, BRAND_BOWMAN)
SET_PRIZM_FB_23 = upsert_set("Prizm Football 2023",      "prizm_fb_23",     2023, CAT_FOOTBALL, BRAND_PANINI)

print(f"     12 sets upserted")

# ── Products + card details ───────────────────────────────────────────────────
print("  → Products & card details...")

tcg_cards = [
    # (card_name, card_number, set_id, category_id, rarity, is_foil, element, pokemon_type, hp, mana_cost, color, image_url)
    ("Charizard",         "4/102",   SET_BASE,     CAT_POKEMON, "Holo Rare",   True,  None, "Fire",      120, None, None,  "https://images.pokemontcg.io/base1/4.png"),
    ("Charizard ex",      "199/193", SET_PALDEA,   CAT_POKEMON, "Special Illustration Rare", True, None, "Fire", 330, None, None, "https://images.pokemontcg.io/sv2/199.png"),
    ("Pikachu ex",        "085/091", SET_SV_PROMO, CAT_POKEMON, "Promo",       False, None, "Lightning", 120, None, None,  None),
    ("Black Lotus",       "232",     SET_ALPHA,    CAT_MAGIC,   "Rare",        False, None, None,        None, "0",  "Colorless", "https://cards.scryfall.io/normal/front/b/d/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd.jpg"),
    ("Lightning Bolt",    "161",     SET_ALPHA,    CAT_MAGIC,   "Common",      False, None, None,        None, "R",  "Red",  None),
    ("Urza's Saga",       "259",     SET_BRO,      CAT_MAGIC,   "Rare",        False, None, None,        None, "3W", "White", None),
    ("Monkey D. Luffy",   "OP01-001",SET_RD,       CAT_ONEPIECE,"Leader",      False, None, None,        None, None, None,  None),
    ("Roronoa Zoro",      "OP01-002",SET_RD,       CAT_ONEPIECE,"Super Rare",  False, None, None,        None, None, None,  None),
    ("Trafalgar Law",     "OP06-119",SET_OP06,     CAT_ONEPIECE,"Secret Rare", True,  None, None,        None, None, None,  None),
]

sports_cards = [
    # (player, team, year, set_id, card_number, category_id, rookie, autograph, graded, grading_company, grade)
    ("Shohei Ohtani",    "Los Angeles Dodgers",  2023, SET_TOPPS_23,    "1",      CAT_BASEBALL, False, False, False, None,  None),
    ("Victor Wembanyama","San Antonio Spurs",    2023, SET_PRIZM_23,    "301",    CAT_BBALL,    True,  False, True,  "PSA", "10"),
    ("Connor McDavid",   "Edmonton Oilers",      2024, SET_UD_24,       "200",    CAT_HOCKEY,   False, False, False, None,  None),
    ("Patrick Mahomes",  "Kansas City Chiefs",   2023, SET_PRIZM_FB_23, "1",      CAT_FOOTBALL, False, True,  False, None,  None),
    ("Jackson Holliday", "Baltimore Orioles",    2023, SET_BOWMAN_23,   "BPP-1",  CAT_BASEBALL, True,  False, False, None,  None),
]

tcg_product_ids = []
for card in tcg_cards:
    pid = uid()
    tcg_product_ids.append(pid)
    db.execute(text("INSERT INTO products (product_id, product_type_id) VALUES (:pid, 'tcg')"), {"pid": pid})
    db.execute(text("""
        INSERT INTO tcg_details (tcg_id, product_id, set_id, category_id,
            card_name, card_number, rarity, is_foil,
            element, pokemon_type, hp, mana_cost, color, image_url)
        VALUES (:tid, :pid, :sid, :cid, :name, :num, :rarity, :foil,
                :element, :ptype, :hp, :mana, :color, :img)
    """), {
        "tid": uid(), "pid": pid, "sid": card[2], "cid": card[3],
        "name": card[0], "num": card[1], "rarity": card[4], "foil": card[5],
        "element": card[6], "ptype": card[7], "hp": card[8],
        "mana": card[9], "color": card[10], "img": card[11]
    })

sports_product_ids = []
for card in sports_cards:
    pid = uid()
    sports_product_ids.append(pid)
    db.execute(text("INSERT INTO products (product_id, product_type_id) VALUES (:pid, 'sports')"), {"pid": pid})
    db.execute(text("""
        INSERT INTO card_details (card_id, product_id, category_id, set_id,
            player, team, year, card_number,
            rookie_card, autograph, graded, grading_company, grade)
        VALUES (:cid, :pid, :cat, :sid,
                :player, :team, :year, :num,
                :rookie, :auto, :graded, :gc, :grade)
    """), {
        "cid": uid(), "pid": pid, "cat": card[5], "sid": card[3],
        "player": card[0], "team": card[1], "year": card[2], "num": card[4],
        "rookie": card[6], "auto": card[7], "graded": card[8],
        "gc": card[9], "grade": card[10]
    })

db.commit()
print(f"     {len(tcg_cards)} TCG cards, {len(sports_cards)} sports cards")

# ── Inventory ──────────────────────────────────────────────────────────────────
print("  → Inventory...")
today = date.today()

inventory_data = [
    # (product_id, qty, purchase, asking, condition, acquired_days_ago)
    (tcg_product_ids[0], 1, 150.00, 299.99, "LP",  90),   # Charizard Base
    (tcg_product_ids[1], 1,  45.00,  89.99, "NM",  30),   # Charizard ex
    (tcg_product_ids[2], 3,   2.00,   4.50, "NM",  14),   # Pikachu ex
    (tcg_product_ids[3], 1,8000.00,14000.00,"MP", 120),   # Black Lotus
    (tcg_product_ids[4], 5,  12.00,  22.00, "NM",   7),   # Lightning Bolt
    (tcg_product_ids[5], 2,   8.00,  18.00, "NM",  21),   # Urza's Saga
    (tcg_product_ids[6], 2,  18.00,  35.00, "NM",  45),   # Luffy
    (tcg_product_ids[7], 1,  22.00,  40.00, "NM",  60),   # Zoro
    (tcg_product_ids[8], 1,  55.00,  95.00, "NM",  10),   # Law Secret Rare
    (sports_product_ids[0], 1,  35.00,  65.00, "NM",  20), # Ohtani
    (sports_product_ids[1], 1, 400.00, 850.00, "NM", 15),  # Wembanyama PSA 10
    (sports_product_ids[2], 1,  40.00,  75.00, "NM",  30), # McDavid
    (sports_product_ids[3], 1,  80.00, 150.00, "NM",  45), # Mahomes auto
    (sports_product_ids[4], 1,  25.00,  55.00, "NM",   5), # Holliday rookie
]

inventory_ids = []
for inv in inventory_data:
    iid = uid()
    inventory_ids.append(iid)
    acquired = today - timedelta(days=inv[5])
    db.execute(text("""
        INSERT INTO inventory (inventory_id, user_id, product_id, quantity,
            available_quantity, purchase_price, asking_price, condition,
            for_sale, acquired_date, created_at)
        VALUES (:iid, :uid, :pid, :qty, :qty, :purchase, :asking,
                :cond, true, :acquired, now())
    """), {
        "iid": iid, "uid": USER_ID, "pid": inv[0],
        "qty": inv[1], "purchase": inv[2], "asking": inv[3],
        "cond": inv[4], "acquired": acquired
    })

db.commit()
print(f"     {len(inventory_ids)} inventory items")

# ── Shows ──────────────────────────────────────────────────────────────────────
print("  → Shows...")

shows = [
    (uid(), "Sioux Falls Card Show",         today + timedelta(days=7),   "Sioux Falls, SD", "Convention Center",           "B-12", 75.00,  True),
    (uid(), "Midwest TCG Expo",              today - timedelta(days=42),  "Omaha, NE",       "Omaha Convention Center",     "A-04", 100.00, False),
    (uid(), "Local Game Store Pop-Up",       today - timedelta(days=77),  "Sioux Falls, SD", "Dragon's Keep Games",         None,   25.00,  False),
    (uid(), "Dakota Card Fest",              today - timedelta(days=112), "Rapid City, SD",  "Rushmore Plaza Civic Center", "C-07", 150.00, False),
    (uid(), "Omaha Fall Collectibles Show",  today - timedelta(days=140), "Omaha, NE",       "Century Link Center",         "D-21", 120.00, False),
]

show_ids = [s[0] for s in shows]
for show in shows:
    db.execute(text("""
        INSERT INTO shows (show_id, user_id, show_name, show_date, location,
            venue, table_number, table_cost, is_active, created_at)
        VALUES (:sid, :uid, :name, :date, :loc, :venue, :table, :cost, :active, now())
    """), {
        "sid": show[0], "uid": USER_ID, "name": show[1], "date": show[2],
        "loc": show[3], "venue": show[4], "table": show[5],
        "cost": show[6], "active": show[7]
    })

db.commit()
print(f"     {len(shows)} shows  ({shows[0][1]} upcoming/active)")

# ── Sales ──────────────────────────────────────────────────────────────────────
print("  → Sales...")

def sale(inv_idx, show_idx, price, qty, payment, days_ago, show_name_override=None):
    t_date = datetime.now() - timedelta(days=days_ago)
    sname = shows[show_idx][1] if show_idx is not None else show_name_override
    sloc  = shows[show_idx][3] if show_idx is not None else None
    db.execute(text("""
        INSERT INTO inventory_transactions
            (transaction_id, inventory_id, user_id, transaction_type,
             quantity, unit_price, total_amount, payment_method,
             show_name, show_location, transaction_date, created_at)
        VALUES (:tid, :iid, :uid, 'sale', :qty, :price, :total,
                :payment, :sname, :sloc, :tdate, now())
    """), {
        "tid": uid(), "iid": inventory_ids[inv_idx], "uid": USER_ID,
        "qty": qty, "price": price, "total": price * qty,
        "payment": payment, "sname": sname, "sloc": sloc, "tdate": t_date
    })
    db.execute(text("""
        UPDATE inventory SET available_quantity = available_quantity - :qty
        WHERE inventory_id = :iid
    """), {"qty": qty, "iid": inventory_ids[inv_idx]})

# Midwest TCG Expo
sale(0,  1,  295.00, 1, "cash",  42)
sale(9,  1,   60.00, 1, "cash",  42)
sale(6,  1,   32.00, 1, "cash",  42)
sale(4,  1,   20.00, 1, "card",  42)
# LGS Pop-Up
sale(2,  2,    4.00, 2, "cash",  77)
sale(10, 2,  780.00, 1, "card",  77)
sale(8,  2,   90.00, 1, "card",  77)
# Dakota Card Fest
sale(3,  3,13500.00, 1, "card", 112)
sale(7,  3,   38.00, 1, "cash", 112)
sale(12, 3,  145.00, 1, "cash", 112)
# Omaha Fall
sale(11, 4,   70.00, 1, "cash", 140)
sale(5,  4,   16.00, 2, "cash", 140)
# Online
sale(1,  None, 85.00, 1, "card",  20, "Online — TCGPlayer")
sale(13, None, 52.00, 1, "card",  10, "Online — eBay")

db.commit()
print("     14 sales across 4 shows + 2 online")

# ── Expenses ───────────────────────────────────────────────────────────────────
print("  → Expenses...")

def expense(show_idx, etype, desc, amount, payment, days_ago):
    edate = (datetime.now() - timedelta(days=days_ago)).date()
    db.execute(text("""
        INSERT INTO expenses
            (expense_id, user_id, show_id, expense_type, description,
             amount, payment_method, expense_date, created_at)
        VALUES (:eid, :uid, :sid, :etype, :desc, :amount, :payment, :edate, now())
    """), {
        "eid": uid(), "uid": USER_ID,
        "sid": show_ids[show_idx] if show_idx is not None else None,
        "etype": etype, "desc": desc, "amount": amount,
        "payment": payment, "edate": edate
    })

# Midwest TCG Expo
expense(1, "table_fee", "Table fee",                100.00, "cash",  42)
expense(1, "travel",    "Gas — Omaha round trip",    45.00, "card",  42)
expense(1, "hotel",     "Holiday Inn — 1 night",    119.00, "card",  43)
expense(1, "food",      "Meals",                     28.00, "cash",  42)
# LGS Pop-Up
expense(2, "table_fee", "LGS table fee",             25.00, "cash",  77)
expense(2, "food",      "Lunch",                     11.00, "cash",  77)
# Dakota Card Fest
expense(3, "table_fee", "Table fee — Civic Center", 150.00, "cash", 112)
expense(3, "travel",    "Gas — Rapid City",          62.00, "card", 112)
expense(3, "hotel",     "Best Western — 1 night",    98.00, "card", 113)
expense(3, "food",      "Meals — both days",         42.00, "cash", 112)
# Omaha Fall
expense(4, "table_fee", "Table fee",                120.00, "cash", 140)
expense(4, "travel",    "Gas — Omaha",               45.00, "card", 140)
expense(4, "hotel",     "Marriott — 1 night",       135.00, "card", 141)
expense(4, "food",      "Meals",                     31.00, "cash", 140)
# General business
expense(None, "supplies", "Card sleeves & top loaders (500pk)", 32.00, "card", 30)
expense(None, "supplies", "Bubble mailers — 50pk",              18.00, "card", 25)
expense(None, "other",    "PSA submission — 2 cards",           75.00, "card", 60)

db.commit()
print("     17 expenses")

# ── Done ───────────────────────────────────────────────────────────────────────
db.close()
print("")
print("✅ Seed complete!")
print(f"   {len(inventory_ids)} inventory items")
print(f"   {len(shows)} shows")
print(f"   14 sales")
print(f"   17 expenses")
