"""
Seed script — VendorBoss Demo Data
Run on the server: python3 seed_demo.py

Inserts realistic demo data for the VendorBoss Demo account.
Safe to re-run — uses ON CONFLICT DO NOTHING where possible.
"""
import os
import uuid
from datetime import date, datetime, timedelta
from decimal import Decimal
from dotenv import load_dotenv

load_dotenv()

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

DATABASE_URL = os.getenv("DATABASE_URL")
engine = create_engine(DATABASE_URL)
Session = sessionmaker(bind=engine)
db = Session()

USER_ID = "ad1d0a61-767a-4e7a-b264-20df53ca9ac4"

def uid():
    return str(uuid.uuid4())

print("🌱 Seeding VendorBoss demo data...")

# ── 1. Ensure product_types exist ─────────────────────────────────────────────
print("  → Product types...")
db.execute(text("""
    INSERT INTO product_types (product_type_id, product_type_name) VALUES
        ('tcg',    'Trading Card Game'),
        ('sports', 'Sports Card')
    ON CONFLICT (product_type_name) DO NOTHING
"""))

# ── 2. Ensure sports exist ────────────────────────────────────────────────────
print("  → Sports...")
db.execute(text("""
    INSERT INTO sports (sport_id, sport_name) VALUES
        ('pokemon',  'Pokemon'),
        ('magic',    'Magic: The Gathering'),
        ('onepiece', 'One Piece'),
        ('baseball', 'Baseball'),
        ('basketball','Basketball'),
        ('football', 'Football'),
        ('hockey',   'Hockey')
    ON CONFLICT (sport_name) DO NOTHING
"""))

# ── 3. Ensure brands exist ────────────────────────────────────────────────────
print("  → Brands...")
db.execute(text("""
    INSERT INTO brands (brand_id, brand_name) VALUES
        ('wizards',  'Wizards of the Coast'),
        ('pokemon_co','The Pokemon Company'),
        ('bandai',   'Bandai'),
        ('topps',    'Topps'),
        ('panini',   'Panini'),
        ('upperdeck','Upper Deck'),
        ('bowman',   'Bowman')
    ON CONFLICT (brand_name) DO NOTHING
"""))

# ── 4. Ensure sets exist ──────────────────────────────────────────────────────
print("  → Sets...")
db.execute(text("""
    INSERT INTO sets (set_id, set_name, set_year, sport_id, brand_id) VALUES
        ('base_set',        'Base Set',          1999, 'pokemon',   'pokemon_co'),
        ('paldea_evolved',  'Paldea Evolved',    2023, 'pokemon',   'pokemon_co'),
        ('sv_promo',        'SV Black Star Promo',2023,'pokemon',   'pokemon_co'),
        ('alpha',           'Alpha',             1993, 'magic',     'wizards'),
        ('brothers_war',    'The Brothers War',  2022, 'magic',     'wizards'),
        ('romance_dawn',    'Romance Dawn',      2022, 'onepiece',  'bandai'),
        ('op06',            'Wings of the Captain',2024,'onepiece', 'bandai'),
        ('topps_chrome_23', 'Topps Chrome 2023', 2023, 'baseball',  'topps'),
        ('prizm_23',        'Prizm 2023',        2023, 'basketball','panini'),
        ('ud_series1_24',   'Series 1 2024-25',  2024, 'hockey',    'upperdeck'),
        ('bowman_23',       'Bowman 2023',       2023, 'baseball',  'bowman')
    ON CONFLICT (set_id) DO NOTHING
"""))
db.commit()

# ── 5. Products + TCG/Card details ───────────────────────────────────────────
print("  → Products & card details...")

tcg_cards = [
    # (product_id, card_name, card_number, set_id, rarity, is_foil, element, pokemon_type, hp, mana_cost, color, image_url)
    (uid(), "Charizard",          "4/102",    "base_set",       "Holo Rare",      True,  None, "Fire",   120, None,      None,    "https://images.pokemontcg.io/base1/4.png"),
    (uid(), "Charizard ex",       "199/193",  "paldea_evolved", "Special Illustration Rare", True, None, "Fire", 330, None, None, "https://images.pokemontcg.io/sv2/199.png"),
    (uid(), "Pikachu ex",         "085/091",  "sv_promo",       "Promo",          False, None, "Lightning", 120, None, None, None),
    (uid(), "Black Lotus",        "232",      "alpha",          "Rare",           False, None, None,     None, "0",  "Colorless", "https://cards.scryfall.io/normal/front/b/d/bd8fa327-dd41-4737-8f19-2cf5eb1f7cdd.jpg"),
    (uid(), "Lightning Bolt",     "161",      "alpha",          "Common",         False, None, None,     None, "R",  "Red",  None),
    (uid(), "Urza's Saga",        "259",      "brothers_war",   "Rare",           False, None, None,     None, "3W", "White", None),
    (uid(), "Monkey D. Luffy",    "OP01-001", "romance_dawn",   "Leader",         False, None, None,     None, None, None,   None),
    (uid(), "Roronoa Zoro",       "OP01-002", "romance_dawn",   "Super Rare",     False, None, None,     None, None, None,   None),
    (uid(), "Trafalgar Law",      "OP06-119", "op06",           "Secret Rare",    True,  None, None,     None, None, None,   None),
]

sports_cards = [
    # (product_id, player, team, year, set_id, card_number, sport_id, rookie_card, autograph, graded, grading_company, grade)
    (uid(), "Shohei Ohtani",   "Los Angeles Dodgers", 2023, "topps_chrome_23", "1",   "baseball",   False, False, False, None, None),
    (uid(), "Victor Wembanyama","San Antonio Spurs",  2023, "prizm_23",        "301", "basketball", True,  False, True,  "PSA", "10"),
    (uid(), "Connor McDavid",  "Edmonton Oilers",     2024, "ud_series1_24",   "200", "hockey",     False, False, False, None, None),
    (uid(), "Patrick Mahomes", "Kansas City Chiefs",  2023, "prizm_23",        "1",   "football",   False, True,  False, None, None),
    (uid(), "Jackson Holliday","Baltimore Orioles",   2023, "bowman_23",       "BPP-1","baseball",  True,  False, False, None, None),
]

# Insert products and their details
tcg_product_ids = []
for card in tcg_cards:
    pid = card[0]
    tcg_product_ids.append(pid)
    db.execute(text("""
        INSERT INTO products (product_id, product_type_id) VALUES (:pid, 'tcg')
        ON CONFLICT (product_id) DO NOTHING
    """), {"pid": pid})
    db.execute(text("""
        INSERT INTO tcg_details (tcg_id, product_id, card_name, card_number, set_id,
            rarity, is_foil, element, pokemon_type, hp, mana_cost, color, image_url)
        VALUES (:tid, :pid, :name, :num, :sid, :rarity, :foil,
                :element, :ptype, :hp, :mana, :color, :img)
        ON CONFLICT (product_id) DO NOTHING
    """), {
        "tid": uid(), "pid": pid, "name": card[1], "num": card[2],
        "sid": card[3], "rarity": card[4], "foil": card[5],
        "element": card[6], "ptype": card[7], "hp": card[8],
        "mana": card[9], "color": card[10], "img": card[11]
    })

sports_product_ids = []
for card in sports_cards:
    pid = card[0]
    sports_product_ids.append(pid)
    db.execute(text("""
        INSERT INTO products (product_id, product_type_id) VALUES (:pid, 'sports')
        ON CONFLICT (product_id) DO NOTHING
    """), {"pid": pid})
    db.execute(text("""
        INSERT INTO card_details (card_id, product_id, player, team, year, set_id,
            card_number, sport_id, rookie_card, autograph, graded, grading_company, grade)
        VALUES (:cid, :pid, :player, :team, :year, :sid,
                :num, :sport, :rookie, :auto, :graded, :gc, :grade)
        ON CONFLICT (product_id) DO NOTHING
    """), {
        "cid": uid(), "pid": pid, "player": card[1], "team": card[2],
        "year": card[3], "sid": card[4], "num": card[5], "sport": card[6],
        "rookie": card[7], "auto": card[8], "graded": card[9],
        "gc": card[10], "grade": card[11]
    })

db.commit()
print(f"    {len(tcg_cards)} TCG cards, {len(sports_cards)} sports cards")

# ── 6. Inventory ──────────────────────────────────────────────────────────────
print("  → Inventory...")

today = date.today()

inventory_data = [
    # (product_id, qty, purchase, asking, condition, acquired_days_ago)
    # TCG
    (tcg_product_ids[0], 1, 150.00, 299.99, "LP",  90),  # Charizard Base
    (tcg_product_ids[1], 1,  45.00,  89.99, "NM",  30),  # Charizard ex
    (tcg_product_ids[2], 3,   2.00,   4.50, "NM",  14),  # Pikachu ex
    (tcg_product_ids[3], 1,8000.00,14000.00,"MP", 120),  # Black Lotus
    (tcg_product_ids[4], 5,  12.00,  22.00, "NM",   7),  # Lightning Bolt
    (tcg_product_ids[5], 2,   8.00,  18.00, "NM",  21),  # Urza's Saga
    (tcg_product_ids[6], 2,  18.00,  35.00, "NM",  45),  # Luffy
    (tcg_product_ids[7], 1,  22.00,  40.00, "NM",  60),  # Zoro
    (tcg_product_ids[8], 1,  55.00,  95.00, "NM",  10),  # Law Secret Rare
    # Sports
    (sports_product_ids[0], 1,  35.00,  65.00, "NM",  20),  # Ohtani
    (sports_product_ids[1], 1, 400.00, 850.00, "NM",  15),  # Wembanyama PSA 10
    (sports_product_ids[2], 1,  40.00,  75.00, "NM",  30),  # McDavid
    (sports_product_ids[3], 1,  80.00, 150.00, "NM",  45),  # Mahomes auto
    (sports_product_ids[4], 1,  25.00,  55.00, "NM",   5),  # Holliday rookie
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
                :condition, true, :acquired, now())
    """), {
        "iid": iid, "uid": USER_ID, "pid": inv[0],
        "qty": inv[1], "purchase": inv[2], "asking": inv[3],
        "condition": inv[4], "acquired": acquired
    })

db.commit()
print(f"    {len(inventory_ids)} inventory items")

# ── 7. Shows ──────────────────────────────────────────────────────────────────
print("  → Shows...")

shows = [
    # (show_id, name, date, location, venue, table_number, table_cost, is_active)
    (uid(), "Sioux Falls Card Show",        today + timedelta(days=7), "Sioux Falls, SD", "Convention Center",          "B-12", 75.00,  True),
    (uid(), "Midwest TCG Expo",             today - timedelta(days=42),"Omaha, NE",       "Omaha Convention Center",    "A-04", 100.00, False),
    (uid(), "Local Game Store Pop-Up",      today - timedelta(days=77),"Sioux Falls, SD", "Dragon's Keep Games",        None,   25.00,  False),
    (uid(), "Dakota Card Fest",             today - timedelta(days=112),"Rapid City, SD", "Rushmore Plaza Civic Center","C-07", 150.00, False),
    (uid(), "Omaha Fall Collectibles Show", today - timedelta(days=140),"Omaha, NE",      "Century Link Center",        "D-21", 120.00, False),
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
print(f"    {len(shows)} shows ({shows[0][1]} is upcoming/active)")

# ── 8. Sales (inventory_transactions) ────────────────────────────────────────
print("  → Sales...")

def sale(inv_idx, show_idx, unit_price, qty, payment, days_ago, show_name=None, show_location=None):
    t_date = datetime.now() - timedelta(days=days_ago)
    sname = shows[show_idx][1] if show_idx is not None else show_name
    sloc  = shows[show_idx][3] if show_idx is not None else show_location
    db.execute(text("""
        INSERT INTO inventory_transactions
            (transaction_id, inventory_id, user_id, transaction_type,
             quantity, unit_price, total_amount, payment_method,
             show_name, show_location, transaction_date, created_at)
        VALUES (:tid, :iid, :uid, 'sale', :qty, :price, :total,
                :payment, :sname, :sloc, :tdate, now())
    """), {
        "tid": uid(), "iid": inventory_ids[inv_idx], "uid": USER_ID,
        "qty": qty, "price": unit_price, "total": unit_price * qty,
        "payment": payment, "sname": sname, "sloc": sloc, "tdate": t_date
    })
    # Decrement available_quantity
    db.execute(text("""
        UPDATE inventory SET available_quantity = available_quantity - :qty
        WHERE inventory_id = :iid
    """), {"qty": qty, "iid": inventory_ids[inv_idx]})

# Show 1 — Midwest TCG Expo (42 days ago)
sale(0,  1,  295.00, 1, "cash",  42)   # Charizard Base
sale(9,  1,   60.00, 1, "cash",  42)   # Ohtani
sale(6,  1,   32.00, 1, "cash",  42)   # Luffy
sale(4,  1,   20.00, 1, "card",  42)   # Lightning Bolt

# Show 2 — Local Game Store Pop-Up (77 days ago)
sale(2,  2,    4.00, 2, "cash",  77)   # Pikachu ex x2
sale(10, 2,  780.00, 1, "card",  77)   # Wembanyama
sale(8,  2,   90.00, 1, "card",  77)   # Law Secret Rare

# Show 3 — Dakota Card Fest (112 days ago)
sale(3,  3,13500.00, 1, "card", 112)   # Black Lotus
sale(7,  3,   38.00, 1, "cash", 112)   # Zoro
sale(12, 3,  145.00, 1, "cash", 112)   # Mahomes auto

# Show 4 — Omaha Fall (140 days ago)
sale(11, 4,   70.00, 1, "cash", 140)   # McDavid
sale(5,  4,   16.00, 2, "cash", 140)   # Urza's Saga x2

# General (online) sales
sale(1,  None, 85.00, 1, "card", 20, "Online", None)   # Charizard ex — TCGPlayer
sale(13, None, 52.00, 1, "card", 10, "Online", None)   # Mahomes rookie

db.commit()
print("    14 sales across 4 shows + 2 online")

# ── 9. Expenses ───────────────────────────────────────────────────────────────
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

# Show 1 — Midwest TCG Expo
expense(1, "table_fee", "Table fee",              100.00, "cash", 42)
expense(1, "travel",    "Gas — Omaha round trip",  45.00, "card", 42)
expense(1, "hotel",     "Holiday Inn — 1 night",  119.00, "card", 43)
expense(1, "food",      "Meals",                   28.00, "cash", 42)

# Show 2 — LGS Pop-Up
expense(2, "table_fee", "LGS table fee",           25.00, "cash", 77)
expense(2, "food",      "Lunch",                   11.00, "cash", 77)

# Show 3 — Dakota Card Fest
expense(3, "table_fee", "Table fee — Civic Center",150.00,"cash", 112)
expense(3, "travel",    "Gas — Rapid City",         62.00, "card", 112)
expense(3, "hotel",     "Best Western — 1 night",   98.00, "card", 113)
expense(3, "food",      "Meals — both days",         42.00, "cash", 112)

# Show 4 — Omaha Fall
expense(4, "table_fee", "Table fee",               120.00, "cash", 140)
expense(4, "travel",    "Gas — Omaha",              45.00, "card", 140)
expense(4, "hotel",     "Marriott — 1 night",      135.00, "card", 141)
expense(4, "food",      "Meals",                    31.00, "cash", 140)

# General business expenses
expense(None, "supplies", "Card sleeves & top loaders (500pk)", 32.00, "card", 30)
expense(None, "supplies", "Bubble mailers — 50pk",              18.00, "card", 25)
expense(None, "other",    "PSA submission — 2 cards",           75.00, "card", 60)

db.commit()
print("    17 expenses across 4 shows + 3 general")

# ── Done ──────────────────────────────────────────────────────────────────────
print("")
print("✅ Seed complete!")
print(f"   {len(inventory_ids)} inventory items")
print(f"   {len(shows)} shows")
print(f"   14 sales")
print(f"   17 expenses")
print("")
print("Login: demo@vendorboss.com")
