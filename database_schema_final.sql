-- ============================================================================
-- VENDORBOSS DATABASE SCHEMA - MULTI-GAME EDITION
-- Designed for Pokemon, Magic the Gathering, FFTCG, and extensibility
-- ============================================================================

-- ============================================================================
-- PART 1: GAME CONFIGURATION
-- ============================================================================

CREATE TABLE games (
    game_id VARCHAR(20) PRIMARY KEY,  -- "Pokemon", "MagicTG", "FFTCG", "OnePiece"
    full_name VARCHAR(100) NOT NULL,
    publisher VARCHAR(100),
    
    -- Game characteristics
    uses_set_symbols BOOLEAN DEFAULT false,  -- true for Pokemon/MtG, false for FFTCG
    set_code_format VARCHAR(50),            -- "text", "image_symbol", "hybrid"
    
    -- Where to find identifiers on card
    set_indicator_location VARCHAR(50),     -- "bottom_center", "center_right", "bottom_left"
    card_number_location VARCHAR(50),
    rarity_indicator_location VARCHAR(50),
    
    active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW()
);

-- Set symbol images (for Pokemon, MtG, etc.)
CREATE TABLE set_symbols (
    symbol_id SERIAL PRIMARY KEY,
    game_id VARCHAR(20) REFERENCES games(game_id),
    set_code VARCHAR(20) NOT NULL,        -- "BS", "NEO", "SWSH12"
    
    -- Symbol data
    symbol_image_url VARCHAR(500),        -- URL to reference image
    symbol_hash VARCHAR(64),              -- Perceptual hash for matching
    symbol_features JSONB,                -- ML features if using CNN
    
    -- Metadata
    symbol_position VARCHAR(50),          -- Where on card this appears
    introduced_date DATE,
    
    UNIQUE(game_id, set_code)
);
CREATE INDEX idx_symbols_game ON set_symbols(game_id);
CREATE INDEX idx_symbols_hash ON set_symbols(symbol_hash);

-- Card sets (expansions, series)
CREATE TABLE card_sets (
    set_id SERIAL PRIMARY KEY,
    game_id VARCHAR(20) REFERENCES games(game_id),
    set_code VARCHAR(20) NOT NULL,        -- "1", "BS", "NEO", "OP01"
    set_name VARCHAR(200),
    
    -- Set info
    release_date DATE,
    total_cards INT,
    
    -- For symbol matching
    symbol_id INT REFERENCES set_symbols(symbol_id),
    
    UNIQUE(game_id, set_code)
);
CREATE INDEX idx_sets_game ON card_sets(game_id);
CREATE INDEX idx_sets_code ON card_sets(set_code);

-- ============================================================================
-- PART 2: BASE CARDS (Game-Agnostic)
-- ============================================================================

CREATE TABLE base_cards (
    base_card_id SERIAL PRIMARY KEY,
    game_id VARCHAR(20) REFERENCES games(game_id),
    set_id INT REFERENCES card_sets(set_id),
    
    -- Universal identifiers
    card_number VARCHAR(20) NOT NULL,     -- "001", "025", "045", etc.
    name VARCHAR(200) NOT NULL,
    
    -- Rarity (format varies by game)
    rarity_code VARCHAR(10),              -- "H", "R", "C", "★", "M", "U"
    rarity_name VARCHAR(50),              -- "Rare", "Uncommon", "Mythic Rare"
    
    -- Standard identifier: "GAME-SET-NUMBER"
    standard_code VARCHAR(100) GENERATED ALWAYS AS (
        game_id || '-' || (SELECT set_code FROM card_sets WHERE set_id = base_cards.set_id) || '-' || card_number
    ) STORED,
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(game_id, set_id, card_number)
);
CREATE INDEX idx_base_cards_standard_code ON base_cards(standard_code);
CREATE INDEX idx_base_cards_game_set ON base_cards(game_id, set_id);
CREATE INDEX idx_base_cards_name ON base_cards(name);

-- ============================================================================
-- PART 3: GAME-SPECIFIC ATTRIBUTES (Flexible Schema)
-- ============================================================================

-- Flexible attributes for different card games
CREATE TABLE card_attributes (
    attribute_id SERIAL PRIMARY KEY,
    base_card_id INT REFERENCES base_cards(base_card_id) ON DELETE CASCADE,
    
    -- All attributes stored as key-value pairs
    attributes JSONB NOT NULL,
    
    -- Common FFTCG attributes (indexed for performance)
    element VARCHAR(50),
    cost INT,
    power INT,
    card_type VARCHAR(50),
    
    -- Common Pokemon attributes (indexed for performance)
    hp INT,
    pokemon_type VARCHAR(20),              -- "Fire", "Water", "Grass"
    stage VARCHAR(20),                     -- "Basic", "Stage 1", "Stage 2"
    
    -- Common MtG attributes (indexed for performance)
    mana_cost VARCHAR(50),
    color_identity VARCHAR(20),
    card_type_mtg VARCHAR(100),            -- "Creature - Human Warrior"
    power_toughness VARCHAR(20),           -- "3/3"
    
    UNIQUE(base_card_id)
);
CREATE INDEX idx_attributes_base_card ON card_attributes(base_card_id);
CREATE INDEX idx_attributes_element ON card_attributes(element) WHERE element IS NOT NULL;
CREATE INDEX idx_attributes_pokemon_type ON card_attributes(pokemon_type) WHERE pokemon_type IS NOT NULL;
CREATE INDEX idx_attributes_gin ON card_attributes USING gin(attributes);

-- ============================================================================
-- PART 4: CARD VARIANTS (The Complex Part)
-- ============================================================================

CREATE TABLE card_variants (
    variant_id SERIAL PRIMARY KEY,
    base_card_id INT REFERENCES base_cards(base_card_id) ON DELETE CASCADE,
    
    -- Variant characteristics (game-agnostic terms)
    finish_type VARCHAR(30) DEFAULT 'Standard',  -- "Standard", "Foil", "Holo", "ReverseHolo", "Etched"
    art_treatment VARCHAR(50) DEFAULT 'Normal',  -- "Normal", "FullArt", "ExtendedArt", "Borderless", "Showcase", "AltArt"
    special_designation VARCHAR(50),             -- "1stEdition", "Shadowless", "Prerelease", "Promo", "SecretRare"
    
    -- Language & edition
    language VARCHAR(10) DEFAULT 'EN',
    edition VARCHAR(50),
    
    -- Full identifier includes all variant info
    full_code VARCHAR(200) GENERATED ALWAYS AS (
        (SELECT standard_code FROM base_cards WHERE base_card_id = card_variants.base_card_id) ||
        '-' || finish_type || 
        CASE WHEN art_treatment != 'Normal' THEN '-' || art_treatment ELSE '' END ||
        CASE WHEN special_designation IS NOT NULL THEN '-' || special_designation ELSE '' END ||
        CASE WHEN language != 'EN' THEN '-' || language ELSE '' END
    ) STORED,
    
    -- Variant-specific data
    image_url VARCHAR(500),
    
    -- Pricing
    tcgplayer_product_id VARCHAR(50),
    market_price DECIMAL(10,2),
    low_price DECIMAL(10,2),
    high_price DECIMAL(10,2),
    price_last_updated TIMESTAMP,
    
    -- Rarity factors
    print_run INT,
    is_promo BOOLEAN DEFAULT false,
    is_error BOOLEAN DEFAULT false,
    
    -- Game-specific variant data (flexible)
    variant_details JSONB,
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(base_card_id, finish_type, art_treatment, special_designation, language, edition)
);
CREATE INDEX idx_variants_full_code ON card_variants(full_code);
CREATE INDEX idx_variants_base_card ON card_variants(base_card_id);
CREATE INDEX idx_variants_finish ON card_variants(finish_type);
CREATE INDEX idx_variants_tcgplayer ON card_variants(tcgplayer_product_id);

-- ============================================================================
-- PART 5: DETECTION REFERENCES
-- ============================================================================

-- Reference fingerprints for card detection
CREATE TABLE reference_fingerprints (
    fingerprint_id SERIAL PRIMARY KEY,
    variant_id INT REFERENCES card_variants(variant_id) ON DELETE CASCADE,
    
    -- Fingerprint data
    fingerprint JSONB NOT NULL,
    composite_hash VARCHAR(64),
    
    -- What this fingerprint represents
    fingerprint_type VARCHAR(30),          -- "full_card", "art_only", "text_region"
    
    -- Source
    source_image_url VARCHAR(500),
    image_quality VARCHAR(20),
    scan_date TIMESTAMP DEFAULT NOW(),
    
    created_at TIMESTAMP DEFAULT NOW()
);
CREATE INDEX idx_fingerprints_variant ON reference_fingerprints(variant_id);
CREATE INDEX idx_fingerprints_composite ON reference_fingerprints(composite_hash);
CREATE INDEX idx_fingerprints_gin ON reference_fingerprints USING gin(fingerprint);

-- OCR regions and patterns (game-specific)
CREATE TABLE detection_config (
    config_id SERIAL PRIMARY KEY,
    game_id VARCHAR(20) REFERENCES games(game_id),
    
    -- OCR regions (as percentages of card dimensions)
    set_code_region JSONB,
    card_number_region JSONB,
    card_name_region JSONB,
    
    -- OCR patterns and whitelists
    set_code_pattern VARCHAR(200),
    card_number_pattern VARCHAR(200),
    ocr_whitelist VARCHAR(200),
    
    -- Detection methods
    uses_set_symbol_matching BOOLEAN DEFAULT false,
    uses_ocr_text BOOLEAN DEFAULT true,
    uses_fingerprint_fallback BOOLEAN DEFAULT true,
    
    -- Confidence thresholds
    min_ocr_confidence DECIMAL(3,2) DEFAULT 0.80,
    min_fingerprint_similarity DECIMAL(3,2) DEFAULT 0.85,
    
    created_at TIMESTAMP DEFAULT NOW(),
    
    UNIQUE(game_id)
);

-- ============================================================================
-- PART 6: USER INVENTORY (Same as before, works for all games)
-- ============================================================================

CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(100) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    
    account_type VARCHAR(20) DEFAULT 'free',
    subscription_expires_at TIMESTAMP,
    
    display_name VARCHAR(100),
    store_name VARCHAR(200),
    location VARCHAR(200),
    
    created_at TIMESTAMP DEFAULT NOW(),
    last_login TIMESTAMP
);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_account_type ON users(account_type);

-- Physical card inventory (partitioned by status)
CREATE TABLE inventory_barcodes (
    barcode_id VARCHAR(30) PRIMARY KEY,
    variant_id INT REFERENCES card_variants(variant_id),
    user_id INT REFERENCES users(user_id),
    
    status VARCHAR(20) DEFAULT 'active',
    condition VARCHAR(20),
    
    acquired_from VARCHAR(200),
    acquisition_date DATE,
    acquisition_cost DECIMAL(10,2),
    
    storage_location VARCHAR(200),
    
    created_at TIMESTAMP DEFAULT NOW(),
    last_scanned_at TIMESTAMP,
    status_updated_at TIMESTAMP,
    
    sold_to VARCHAR(200),
    sale_date DATE,
    sale_price DECIMAL(10,2)
) PARTITION BY LIST (status);

CREATE TABLE inventory_barcodes_active PARTITION OF inventory_barcodes FOR VALUES IN ('active');
CREATE TABLE inventory_barcodes_sold PARTITION OF inventory_barcodes FOR VALUES IN ('sold');
CREATE TABLE inventory_barcodes_released PARTITION OF inventory_barcodes FOR VALUES IN ('released');
CREATE TABLE inventory_barcodes_archived PARTITION OF inventory_barcodes FOR VALUES IN ('archived');

CREATE INDEX idx_barcodes_user ON inventory_barcodes(user_id);
CREATE INDEX idx_barcodes_variant ON inventory_barcodes(variant_id);
CREATE INDEX idx_barcodes_status ON inventory_barcodes(status);

-- Barcode history (same as before)
CREATE TABLE barcode_history (
    history_id BIGSERIAL PRIMARY KEY,
    barcode_id VARCHAR(30) REFERENCES inventory_barcodes(barcode_id),
    
    event_type VARCHAR(30) NOT NULL,
    from_user_id INT REFERENCES users(user_id),
    to_user_id INT REFERENCES users(user_id),
    
    event_data JSONB,
    signature VARCHAR(64),
    previous_signature VARCHAR(64),
    
    ip_address INET,
    device_info JSONB,
    notes TEXT,
    
    created_at TIMESTAMP DEFAULT NOW()
) PARTITION BY RANGE (created_at);

CREATE TABLE barcode_history_2026_02 PARTITION OF barcode_history 
    FOR VALUES FROM ('2026-02-01') TO ('2026-03-01');

CREATE INDEX idx_history_barcode ON barcode_history(barcode_id);
CREATE INDEX idx_history_user ON barcode_history(from_user_id);
CREATE INDEX idx_history_event ON barcode_history(event_type);

-- ============================================================================
-- PART 7: VIEWS FOR COMMON QUERIES
-- ============================================================================

-- Complete card view with all variant info
CREATE VIEW vw_complete_cards AS
SELECT 
    bc.base_card_id,
    bc.game_id,
    g.full_name as game_name,
    cs.set_code,
    cs.set_name,
    bc.card_number,
    bc.name as card_name,
    bc.rarity_code,
    bc.standard_code,
    
    cv.variant_id,
    cv.finish_type,
    cv.art_treatment,
    cv.special_designation,
    cv.language,
    cv.full_code,
    cv.image_url,
    cv.market_price,
    
    ca.element,
    ca.cost,
    ca.power,
    ca.card_type,
    ca.hp,
    ca.pokemon_type,
    ca.mana_cost,
    ca.attributes
FROM base_cards bc
JOIN games g ON bc.game_id = g.game_id
JOIN card_sets cs ON bc.set_id = cs.set_id
LEFT JOIN card_variants cv ON bc.base_card_id = cv.base_card_id
LEFT JOIN card_attributes ca ON bc.base_card_id = ca.base_card_id;

-- ============================================================================
-- PART 8: SEED DATA FOR INITIAL GAMES
-- ============================================================================

-- Insert supported games
INSERT INTO games (game_id, full_name, publisher, uses_set_symbols, set_code_format, 
                   set_indicator_location, card_number_location, rarity_indicator_location) VALUES
('Pokemon', 'Pokémon Trading Card Game', 'The Pokémon Company', true, 'image_symbol', 
 'bottom_left', 'bottom_right', 'bottom_left'),
('MagicTG', 'Magic: The Gathering', 'Wizards of the Coast', true, 'image_symbol', 
 'center_right', 'bottom_left', 'center_right'),
('FFTCG', 'Final Fantasy Trading Card Game', 'Square Enix', false, 'text', 
 'bottom_center', 'bottom_center', 'bottom_center'),
('OnePiece', 'One Piece Card Game', 'Bandai', false, 'text', 
 'bottom_center', 'bottom_center', 'bottom_right');

-- Insert detection configs
INSERT INTO detection_config (game_id, set_code_region, card_number_region, 
                              uses_set_symbol_matching, uses_ocr_text) VALUES
-- Pokemon: Uses set symbol matching primarily
('Pokemon', 
 '{"x": 0.05, "y": 0.88, "w": 0.15, "h": 0.08}'::jsonb,
 '{"x": 0.75, "y": 0.92, "w": 0.20, "h": 0.06}'::jsonb,
 true, true),

-- MtG: Uses set symbol matching primarily  
('MagicTG',
 '{"x": 0.80, "y": 0.45, "w": 0.15, "h": 0.10}'::jsonb,
 '{"x": 0.05, "y": 0.92, "w": 0.15, "h": 0.06}'::jsonb,
 true, true),

-- FFTCG: Uses OCR text only
('FFTCG',
 '{"x": 0.36, "y": 0.93, "w": 0.30, "h": 0.05}'::jsonb,
 '{"x": 0.36, "y": 0.93, "w": 0.30, "h": 0.05}'::jsonb,
 false, true),

-- One Piece: Uses OCR text  
('OnePiece',
 '{"x": 0.30, "y": 0.92, "w": 0.40, "h": 0.06}'::jsonb,
 '{"x": 0.30, "y": 0.92, "w": 0.40, "h": 0.06}'::jsonb,
 false, true);

-- ============================================================================
-- PART 9: HELPER FUNCTIONS
-- ============================================================================

-- Generate unique barcode ID
CREATE OR REPLACE FUNCTION generate_barcode_id()
RETURNS VARCHAR(30) AS $$
DECLARE
    new_id VARCHAR(30);
    collision BOOLEAN := TRUE;
BEGIN
    WHILE collision LOOP
        new_id := 'VB-' || upper(substring(md5(random()::text) from 1 for 10));
        SELECT EXISTS(SELECT 1 FROM inventory_barcodes WHERE barcode_id = new_id) INTO collision;
    END LOOP;
    RETURN new_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================

COMMENT ON DATABASE vendorboss IS 'VendorBoss multi-game TCG inventory and scanning system';
