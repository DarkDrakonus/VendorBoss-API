"""
VendorBoss 2.0 SQLAlchemy Models
Matches actual database schema with TcgDetail added for Final Fantasy TCG
Version: 2.0.0
"""
from sqlalchemy import Column, String, Integer, Boolean, DateTime, Date, Text, ForeignKey, Numeric, Float
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from sqlalchemy.dialects.postgresql import JSONB, UUID
from database import Base
import uuid

def generate_uuid():
    return str(uuid.uuid4())

# ========== Core Reference Tables ==========

class Sport(Base):
    __tablename__ = "sports"
    sport_id = Column(String, primary_key=True)
    sport_name = Column(String, nullable=False, unique=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class League(Base):
    __tablename__ = "leagues"
    league_id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    sport_id = Column(String, ForeignKey("sports.sport_id"), nullable=False)

class Team(Base):
    __tablename__ = "teams"
    team_id = Column(Integer, primary_key=True)
    name = Column(String, nullable=False)
    sport_id = Column(String, ForeignKey("sports.sport_id"), nullable=False)
    league_id = Column(Integer, ForeignKey("leagues.league_id"))

class Brand(Base):
    __tablename__ = "brands"
    brand_id = Column(String, primary_key=True)
    brand_name = Column(String, nullable=False, unique=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    is_active = Column(Boolean, default=True)

class Set(Base):
    __tablename__ = "sets"
    set_id = Column(String, primary_key=True)
    set_name = Column(String, nullable=False)
    set_year = Column(Integer, nullable=False)
    sport_id = Column(String, ForeignKey("sports.sport_id"), nullable=False)
    brand_id = Column(String, ForeignKey("brands.brand_id"), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class ProductType(Base):
    __tablename__ = "product_types"
    product_type_id = Column(String, primary_key=True)
    product_type_name = Column(String, nullable=False, unique=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

# ========== Users & Auth ==========

class User(Base):
    __tablename__ = "users"
    user_id = Column(String, primary_key=True, default=generate_uuid)
    username = Column(String, unique=True, index=True)
    email = Column(String, unique=True, index=True, nullable=False)
    password_hash = Column(String, nullable=False)
    first_name = Column(String)
    last_name = Column(String)
    is_verified = Column(Boolean)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True))

# ========== Products ==========

class Product(Base):
    __tablename__ = "products"
    product_id = Column(String, primary_key=True, default=generate_uuid)
    product_type_id = Column(String, ForeignKey("product_types.product_type_id"), nullable=False)
    barcode = Column(String, unique=True, index=True)
    sku = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True))

class CardDetail(Base):
    """Sports card specific details"""
    __tablename__ = "card_details"
    card_id = Column(String, primary_key=True, default=generate_uuid)
    product_id = Column(String, ForeignKey("products.product_id"), unique=True, nullable=False)
    sport_id = Column(String, ForeignKey("sports.sport_id"))
    set_id = Column(String, ForeignKey("sets.set_id"))
    team = Column(String)
    player = Column(String, index=True, nullable=False)
    position = Column(String)
    card_number = Column(String)
    year = Column(Integer, index=True)
    variant = Column(Boolean)
    variant_name = Column(String)
    rookie_card = Column(Boolean, index=True)
    serial_number = Column(String)
    autograph = Column(Boolean)
    relic = Column(Boolean)
    refractor = Column(Boolean)
    graded = Column(Boolean)
    grading_company = Column(String)
    grade = Column(String)
    grade_numeric = Column(Float)
    cert_number = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True))
    is_insert = Column(Boolean, default=False)
    is_sp = Column(Boolean, default=False)

class TcgDetail(Base):
    """Trading Card Game specific details (Final Fantasy, Pokemon, Magic, etc)"""
    __tablename__ = "tcg_details"
    tcg_id = Column(String, primary_key=True, default=generate_uuid)
    product_id = Column(String, ForeignKey("products.product_id"), unique=True, nullable=False)
    set_id = Column(String, ForeignKey("sets.set_id"))
    
    # Universal TCG fields
    card_name = Column(String, nullable=False, index=True)
    card_number = Column(String)
    rarity = Column(String)
    card_type = Column(String)
    
    # Final Fantasy TCG specific
    element = Column(String)  # Fire, Ice, Wind, Earth, Lightning, Water, Light, Dark
    cost = Column(Integer)
    power = Column(Integer)
    job = Column(String)
    category = Column(String)  # Which FF game
    
    # Pokemon TCG specific
    pokemon_type = Column(String)
    hp = Column(Integer)
    stage = Column(String)
    
    # Magic TCG specific
    mana_cost = Column(String)
    color = Column(String)
    
    # Common fields
    text = Column(Text)
    set_code = Column(String(20), index=True)
    variant_type = Column(String(20), default='normal')
    is_foil = Column(Boolean, default=False)
    image_url = Column(Text)
    flavor_text = Column(Text)
    artist = Column(String)
    foil = Column(Boolean, default=False)
    variant = Column(Boolean, default=False)
    variant_name = Column(String)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True))

class BoxDetail(Base):
    __tablename__ = "box_details"
    box_id = Column(String, primary_key=True)
    product_id = Column(String, ForeignKey("products.product_id"), unique=True, nullable=False)
    set_id = Column(String, ForeignKey("sets.set_id"))
    box_name = Column(String)
    box_type = Column(String)
    packs_per_box = Column(Integer)
    cards_per_pack = Column(Integer)
    box_year = Column(Integer)
    retail_price = Column(Numeric(10, 2))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True))

class PackDetail(Base):
    __tablename__ = "pack_details"
    pack_id = Column(String, primary_key=True)
    product_id = Column(String, ForeignKey("products.product_id"), unique=True, nullable=False)
    set_id = Column(String, ForeignKey("sets.set_id"))
    pack_name = Column(String)
    cards_per_pack = Column(Integer)
    pack_year = Column(Integer)
    retail_price = Column(Numeric(10, 2))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True))

# ========== Inventory & Transactions ==========

class Inventory(Base):
    __tablename__ = "inventory"
    inventory_id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.user_id"), nullable=False, index=True)
    product_id = Column(String, ForeignKey("products.product_id"), nullable=False, index=True)
    quantity = Column(Integer)
    available_quantity = Column(Integer)
    purchase_price = Column(Numeric(10, 2))
    current_market_price = Column(Numeric(10, 2))
    asking_price = Column(Numeric(10, 2))
    minimum_price = Column(Numeric(10, 2))
    storage_location = Column(String)
    box_number = Column(String)
    row_number = Column(String)
    notes = Column(Text)
    private_notes = Column(Text)
    for_sale = Column(Boolean)
    featured = Column(Boolean)
    condition = Column(String)
    acquired_date = Column(Date)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True))

class InventoryTransaction(Base):
    __tablename__ = "inventory_transactions"
    transaction_id = Column(String, primary_key=True, default=generate_uuid)
    inventory_id = Column(String, ForeignKey("inventory.inventory_id"), nullable=False, index=True)
    user_id = Column(String, ForeignKey("users.user_id"), nullable=False, index=True)
    transaction_type = Column(String, nullable=False)
    quantity = Column(Integer, nullable=False)
    unit_price = Column(Numeric(10, 2), nullable=False)
    total_amount = Column(Numeric(10, 2), nullable=False)
    payment_method = Column(String)
    payment_reference = Column(String)
    customer_name = Column(String)
    customer_email = Column(String)
    customer_phone = Column(String)
    show_name = Column(String, index=True)
    show_date = Column(Date)
    show_location = Column(String)
    notes = Column(Text)
    transaction_date = Column(DateTime(timezone=True), nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Expense(Base):
    __tablename__ = "expenses"
    expense_id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.user_id"), nullable=False, index=True)
    show_id = Column(String, ForeignKey("shows.show_id"), index=True)
    expense_type = Column(String, nullable=False)
    description = Column(String, nullable=False)
    amount = Column(Numeric(10, 2), nullable=False)
    payment_method = Column(String)
    receipt_image = Column(String)
    notes = Column(Text)
    expense_date = Column(Date, nullable=False)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Show(Base):
    __tablename__ = "shows"
    show_id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.user_id"), nullable=False, index=True)
    show_name = Column(String, nullable=False)
    show_date = Column(Date, nullable=False)
    location = Column(String)
    venue = Column(String)
    table_number = Column(String)
    table_cost = Column(Numeric(10, 2))
    notes = Column(Text)
    is_active = Column(Boolean)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True))

# ========== Scanning & Fingerprints ==========

class Scan(Base):
    __tablename__ = "scans"
    scan_id = Column(String, primary_key=True, default=generate_uuid)
    user_id = Column(String, ForeignKey("users.user_id"), nullable=False)
    product_id = Column(String, ForeignKey("products.product_id"))
    scan_type = Column(String)
    scan_date = Column(DateTime(timezone=True), server_default=func.now())
    raw_data = Column(Text)
    ocr_confidence = Column(Float)
    detected_player = Column(String)
    detected_sport = Column(String)
    detected_team = Column(String)
    detected_year = Column(Integer)
    detected_set = Column(String)
    detected_card_number = Column(String)
    detected_variant = Column(Boolean)
    detected_variant_name = Column(String)
    detected_grading_company = Column(String)
    detected_grade = Column(String)
    detected_cert_number = Column(String)
    image_path = Column(String)
    verified = Column(Boolean)
    edited = Column(Boolean)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class CardFingerprint(Base):
    """Visual fingerprints for card identification with quadrant_row_col naming"""
    __tablename__ = "card_fingerprints"
    fingerprint_id = Column(UUID(as_uuid=True), primary_key=True, server_default=func.uuid_generate_v4())
    product_id = Column(String, ForeignKey("products.product_id"))
    
    # Composite fingerprint hash (SHA256)
    fingerprint_hash = Column(String(64), unique=True, nullable=False, index=True)
    
    # Feature components (64 char hashes)
    border = Column(String(64))
    name_region = Column(String(64))
    color_zones = Column(String(64))
    texture = Column(String(64))
    layout = Column(String(64))
    
    # 9 quadrants (3x3 grid) using row_col naming
    quadrant_0_0 = Column(String(64))
    quadrant_0_1 = Column(String(64))
    quadrant_0_2 = Column(String(64))
    quadrant_1_0 = Column(String(64))
    quadrant_1_1 = Column(String(64))
    quadrant_1_2 = Column(String(64))
    quadrant_2_0 = Column(String(64))
    quadrant_2_1 = Column(String(64))
    quadrant_2_2 = Column(String(64))
    
    # Raw data for debugging
    raw_components = Column(JSONB)
    
    # Metadata
    confidence_score = Column(Numeric(4, 3), default=1.000)
    times_matched = Column(Integer, default=0)
    last_matched_at = Column(DateTime)
    verified = Column(Boolean, default=False)
    auto_generated = Column(Boolean, default=True)
    
    created_at = Column(DateTime, server_default=func.current_timestamp())
    updated_at = Column(DateTime, server_default=func.current_timestamp())

class FingerprintSubmission(Base):
    """User submissions for learning and consensus"""
    __tablename__ = "fingerprint_submissions"
    id = Column(Integer, primary_key=True)
    fingerprint = Column(String(64), nullable=False, index=True)
    user_id = Column(Integer, index=True)
    submitted_player_name = Column(String(255))
    submitted_card_year = Column(Integer)
    submitted_card_set = Column(String(255))
    created_at = Column(DateTime, server_default=func.current_timestamp())

class UserContribution(Base):
    """User reputation tracking"""
    __tablename__ = "user_contributions"
    user_id = Column(Integer, primary_key=True)
    total_submissions = Column(Integer, default=0)
    accurate_submissions = Column(Integer, default=0)
    disputed_submissions = Column(Integer, default=0)
    trust_score = Column(Numeric(4, 3), default=0.500)
    first_contribution = Column(DateTime, server_default=func.current_timestamp())
    last_contribution = Column(DateTime, server_default=func.current_timestamp())

class ModelVersion(Base):
    """Tracks model versions for ScanBoss"""
    __tablename__ = "model_versions"
    version = Column(String(20), primary_key=True)
    known_cards_count = Column(Integer, default=0)
    created_at = Column(DateTime, server_default=func.current_timestamp())

# ========== Pricing ==========

class PriceHistory(Base):
    __tablename__ = "price_history"
    price_id = Column(String, primary_key=True, default=generate_uuid)
    product_id = Column(String, ForeignKey("products.product_id"), nullable=False, index=True)
    source = Column(String, nullable=False, index=True)
    price = Column(Numeric(10, 2), nullable=False)
    condition = Column(String)  # "NM", "NM-MT", "PSA 10", "BGS 9.5", etc
    price_date = Column(DateTime(timezone=True), server_default=func.now(), index=True)
