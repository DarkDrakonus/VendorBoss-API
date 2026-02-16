-- VendorBoss 2.0 Database Schema
-- PostgreSQL 17+
-- Run this to create all tables from scratch

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CORE REFERENCE TABLES
-- ============================================================================

CREATE TABLE sports (
    sport_id VARCHAR PRIMARY KEY,
    sport_name VARCHAR NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE leagues (
    league_id SERIAL PRIMARY KEY,
    name VARCHAR NOT NULL,
    sport_id VARCHAR NOT NULL REFERENCES sports(sport_id)
);

CREATE TABLE teams (
    team_id SERIAL PRIMARY KEY,
    name VARCHAR NOT NULL,
    sport_id VARCHAR NOT NULL REFERENCES sports(sport_id),
    league_id INTEGER REFERENCES leagues(league_id)
);

CREATE TABLE brands (
    brand_id VARCHAR PRIMARY KEY,
    brand_name VARCHAR NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE sets (
    set_id VARCHAR PRIMARY KEY,
    set_name VARCHAR NOT NULL,
    set_year INTEGER NOT NULL,
    sport_id VARCHAR NOT NULL REFERENCES sports(sport_id),
    brand_id VARCHAR NOT NULL REFERENCES brands(brand_id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE product_types (
    product_type_id VARCHAR PRIMARY KEY,
    product_type_name VARCHAR NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- USERS & AUTH
-- ============================================================================

CREATE TABLE users (
    user_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    username VARCHAR UNIQUE,
    email VARCHAR UNIQUE NOT NULL,
    password_hash VARCHAR NOT NULL,
    first_name VARCHAR,
    last_name VARCHAR,
    is_verified BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_users_email ON users(email);
CREATE INDEX ix_users_username ON users(username);

-- ============================================================================
-- PRODUCTS
-- ============================================================================

CREATE TABLE products (
    product_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_type_id VARCHAR NOT NULL REFERENCES product_types(product_type_id),
    barcode VARCHAR UNIQUE,
    sku VARCHAR,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_products_barcode ON products(barcode);
CREATE INDEX ix_products_product_type_id ON products(product_type_id);

-- Sports card details
CREATE TABLE card_details (
    card_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR UNIQUE NOT NULL REFERENCES products(product_id),
    sport_id VARCHAR REFERENCES sports(sport_id),
    set_id VARCHAR REFERENCES sets(set_id),
    team VARCHAR,
    player VARCHAR NOT NULL,
    position VARCHAR,
    card_number VARCHAR,
    year INTEGER,
    variant BOOLEAN,
    variant_name VARCHAR,
    rookie_card BOOLEAN,
    serial_number VARCHAR,
    autograph BOOLEAN,
    relic BOOLEAN,
    refractor BOOLEAN,
    graded BOOLEAN,
    grading_company VARCHAR,
    grade VARCHAR,
    grade_numeric FLOAT,
    cert_number VARCHAR,
    is_insert BOOLEAN DEFAULT FALSE,
    is_sp BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_card_details_player ON card_details(player);
CREATE INDEX ix_card_details_year ON card_details(year);
CREATE INDEX ix_card_details_rookie_card ON card_details(rookie_card);

-- Trading card game details (NEW!)
CREATE TABLE tcg_details (
    tcg_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR UNIQUE NOT NULL REFERENCES products(product_id),
    set_id VARCHAR REFERENCES sets(set_id),
    
    -- Universal TCG fields
    card_name VARCHAR NOT NULL,
    card_number VARCHAR,
    rarity VARCHAR,
    card_type VARCHAR,
    
    -- Final Fantasy TCG specific
    element VARCHAR,
    cost INTEGER,
    power INTEGER,
    job VARCHAR,
    category VARCHAR,
    
    -- Pokemon TCG specific
    pokemon_type VARCHAR,
    hp INTEGER,
    stage VARCHAR,
    
    -- Magic TCG specific
    mana_cost VARCHAR,
    color VARCHAR,
    
    -- Common fields
    text TEXT,
    flavor_text TEXT,
    artist VARCHAR,
    foil BOOLEAN DEFAULT FALSE,
    variant BOOLEAN DEFAULT FALSE,
    variant_name VARCHAR,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_tcg_details_card_name ON tcg_details(card_name);
CREATE INDEX ix_tcg_details_product_id ON tcg_details(product_id);
CREATE INDEX ix_tcg_details_set_id ON tcg_details(set_id);

-- Box details
CREATE TABLE box_details (
    box_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR UNIQUE NOT NULL REFERENCES products(product_id),
    set_id VARCHAR REFERENCES sets(set_id),
    box_name VARCHAR,
    box_type VARCHAR,
    packs_per_box INTEGER,
    cards_per_pack INTEGER,
    box_year INTEGER,
    retail_price NUMERIC(10, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- Pack details
CREATE TABLE pack_details (
    pack_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR UNIQUE NOT NULL REFERENCES products(product_id),
    set_id VARCHAR REFERENCES sets(set_id),
    pack_name VARCHAR,
    cards_per_pack INTEGER,
    pack_year INTEGER,
    retail_price NUMERIC(10, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- INVENTORY & TRANSACTIONS
-- ============================================================================

CREATE TABLE inventory (
    inventory_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR NOT NULL REFERENCES users(user_id),
    product_id VARCHAR NOT NULL REFERENCES products(product_id),
    quantity INTEGER,
    available_quantity INTEGER,
    purchase_price NUMERIC(10, 2),
    current_market_price NUMERIC(10, 2),
    asking_price NUMERIC(10, 2),
    minimum_price NUMERIC(10, 2),
    storage_location VARCHAR,
    box_number VARCHAR,
    row_number VARCHAR,
    notes TEXT,
    private_notes TEXT,
    for_sale BOOLEAN,
    featured BOOLEAN,
    condition VARCHAR,
    acquired_date DATE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_inventory_user_id ON inventory(user_id);
CREATE INDEX ix_inventory_product_id ON inventory(product_id);

CREATE TABLE inventory_transactions (
    transaction_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    inventory_id VARCHAR NOT NULL REFERENCES inventory(inventory_id),
    user_id VARCHAR NOT NULL REFERENCES users(user_id),
    transaction_type VARCHAR NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(10, 2) NOT NULL,
    total_amount NUMERIC(10, 2) NOT NULL,
    payment_method VARCHAR,
    payment_reference VARCHAR,
    customer_name VARCHAR,
    customer_email VARCHAR,
    customer_phone VARCHAR,
    show_name VARCHAR,
    show_date DATE,
    show_location VARCHAR,
    notes TEXT,
    transaction_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX ix_inventory_transactions_inventory_id ON inventory_transactions(inventory_id);
CREATE INDEX ix_inventory_transactions_user_id ON inventory_transactions(user_id);
CREATE INDEX ix_inventory_transactions_show_name ON inventory_transactions(show_name);

-- ============================================================================
-- SHOWS & EXPENSES
-- ============================================================================

CREATE TABLE shows (
    show_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR NOT NULL REFERENCES users(user_id),
    show_name VARCHAR NOT NULL,
    show_date DATE NOT NULL,
    location VARCHAR,
    venue VARCHAR,
    table_number VARCHAR,
    table_cost NUMERIC(10, 2),
    notes TEXT,
    is_active BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_shows_user_id ON shows(user_id);

CREATE TABLE expenses (
    expense_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR NOT NULL REFERENCES users(user_id),
    show_id VARCHAR REFERENCES shows(show_id),
    expense_type VARCHAR NOT NULL,
    description VARCHAR NOT NULL,
    amount NUMERIC(10, 2) NOT NULL,
    payment_method VARCHAR,
    receipt_image VARCHAR,
    notes TEXT,
    expense_date DATE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX ix_expenses_user_id ON expenses(user_id);
CREATE INDEX ix_expenses_show_id ON expenses(show_id);

-- ============================================================================
-- SCANNING & FINGERPRINTS
-- ============================================================================

CREATE TABLE scans (
    scan_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR NOT NULL REFERENCES users(user_id),
    product_id VARCHAR REFERENCES products(product_id),
    scan_type VARCHAR,
    scan_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    raw_data TEXT,
    ocr_confidence FLOAT,
    detected_player VARCHAR,
    detected_sport VARCHAR,
    detected_team VARCHAR,
    detected_year INTEGER,
    detected_set VARCHAR,
    detected_card_number VARCHAR,
    detected_variant BOOLEAN,
    detected_variant_name VARCHAR,
    detected_grading_company VARCHAR,
    detected_grade VARCHAR,
    detected_cert_number VARCHAR,
    image_path VARCHAR,
    verified BOOLEAN,
    edited BOOLEAN,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE card_fingerprints (
    fingerprint_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id VARCHAR REFERENCES products(product_id),
    
    -- Composite fingerprint hash (SHA256)
    fingerprint_hash VARCHAR(64) UNIQUE NOT NULL,
    
    -- Feature components (64 char hashes)
    border VARCHAR(64),
    name_region VARCHAR(64),
    color_zones VARCHAR(64),
    texture VARCHAR(64),
    layout VARCHAR(64),
    
    -- 9 quadrants (3x3 grid)
    quadrant_0_0 VARCHAR(64),
    quadrant_0_1 VARCHAR(64),
    quadrant_0_2 VARCHAR(64),
    quadrant_1_0 VARCHAR(64),
    quadrant_1_1 VARCHAR(64),
    quadrant_1_2 VARCHAR(64),
    quadrant_2_0 VARCHAR(64),
    quadrant_2_1 VARCHAR(64),
    quadrant_2_2 VARCHAR(64),
    
    -- Raw data for debugging
    raw_components JSONB,
    
    -- Metadata
    confidence_score NUMERIC(4, 3) DEFAULT 1.000,
    times_matched INTEGER DEFAULT 0,
    last_matched_at TIMESTAMP,
    verified BOOLEAN DEFAULT FALSE,
    auto_generated BOOLEAN DEFAULT TRUE,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_card_fingerprints_hash ON card_fingerprints(fingerprint_hash);
CREATE INDEX ix_card_fingerprints_product_id ON card_fingerprints(product_id);

CREATE TABLE fingerprint_submissions (
    id SERIAL PRIMARY KEY,
    fingerprint VARCHAR(64) NOT NULL,
    user_id INTEGER,
    submitted_player_name VARCHAR(255),
    submitted_card_year INTEGER,
    submitted_card_set VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX ix_fingerprint_submissions_fingerprint ON fingerprint_submissions(fingerprint);
CREATE INDEX ix_fingerprint_submissions_user_id ON fingerprint_submissions(user_id);

CREATE TABLE user_contributions (
    user_id INTEGER PRIMARY KEY,
    total_submissions INTEGER DEFAULT 0,
    accurate_submissions INTEGER DEFAULT 0,
    disputed_submissions INTEGER DEFAULT 0,
    trust_score NUMERIC(4, 3) DEFAULT 0.500,
    first_contribution TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_contribution TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT valid_trust CHECK (trust_score >= 0 AND trust_score <= 1)
);

CREATE TABLE model_versions (
    version VARCHAR(20) PRIMARY KEY,
    known_cards_count INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- PRICING
-- ============================================================================

CREATE TABLE price_history (
    price_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR NOT NULL REFERENCES products(product_id),
    source VARCHAR NOT NULL,
    price NUMERIC(10, 2) NOT NULL,
    condition VARCHAR,
    price_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX ix_price_history_product_id ON price_history(product_id);
CREATE INDEX ix_price_history_source ON price_history(source);
CREATE INDEX ix_price_history_price_date ON price_history(price_date);

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- Product types
INSERT INTO product_types (product_type_id, product_type_name) VALUES
    ('pt_card', 'Card'),
    ('pt_pack', 'Pack'),
    ('pt_box', 'Box');

-- Sports
INSERT INTO sports (sport_id, sport_name) VALUES
    ('sport_tcg', 'Trading Card Game'),
    ('sport_hockey', 'Hockey'),
    ('sport_baseball', 'Baseball'),
    ('sport_football', 'Football'),
    ('sport_basketball', 'Basketball');

-- Brands
INSERT INTO brands (brand_id, brand_name, is_active) VALUES
    ('brand_square_enix', 'Square Enix', true),
    ('brand_pokemon', 'Pokemon Company', true),
    ('brand_wotc', 'Wizards of the Coast', true);

-- Final Fantasy TCG Sets (starting with a few)
INSERT INTO sets (set_id, set_name, set_year, sport_id, brand_id) VALUES
    ('set_opus_i', 'Opus I', 2016, 'sport_tcg', 'brand_square_enix'),
    ('set_opus_ii', 'Opus II', 2017, 'sport_tcg', 'brand_square_enix'),
    ('set_opus_iii', 'Opus III', 2017, 'sport_tcg', 'brand_square_enix');

-- ============================================================================
-- COMPLETE!
-- ============================================================================
