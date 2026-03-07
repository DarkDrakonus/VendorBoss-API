-- ============================================================================
-- VENDORBOSS 2.0 DATABASE SCHEMA
-- Updated to match models.py implementation
-- ============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================================================
-- CORE REFERENCE TABLES
-- ============================================================================

CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    category_type VARCHAR(20) NOT NULL DEFAULT 'tcg',  -- tcg, sports, non_sport
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE brands (
    brand_id SERIAL PRIMARY KEY,
    brand_name VARCHAR(100) NOT NULL UNIQUE,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE sets (
    set_id SERIAL PRIMARY KEY,
    set_name VARCHAR(200) NOT NULL,
    set_code VARCHAR(30),
    set_year INTEGER NOT NULL,
    category_id INTEGER REFERENCES categories(category_id),
    brand_id INTEGER REFERENCES brands(brand_id),
    total_cards INTEGER,
    release_date TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE product_types (
    product_type_id VARCHAR(50) PRIMARY KEY,
    product_type_name VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- USERS & AUTHENTICATION
-- ============================================================================

CREATE TABLE users (
    user_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    username VARCHAR(100) UNIQUE,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    business_name VARCHAR(200),
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);

-- ============================================================================
-- PRODUCTS
-- ============================================================================

CREATE TABLE products (
    product_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_type_id VARCHAR(50) REFERENCES product_types(product_type_id) NOT NULL,
    barcode VARCHAR(100) UNIQUE,
    sku VARCHAR(100),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_products_barcode ON products(barcode);
CREATE INDEX idx_products_type ON products(product_type_id);

-- ============================================================================
-- CARD DETAILS (Sports/Non-Sport Cards)
-- ============================================================================

CREATE TABLE card_details (
    card_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR(50) REFERENCES products(product_id) UNIQUE NOT NULL,
    category_id INTEGER REFERENCES categories(category_id),
    set_id INTEGER REFERENCES sets(set_id),
    
    -- Player info
    player VARCHAR(200) NOT NULL,
    team VARCHAR(100),
    position VARCHAR(50),
    
    -- Card info
    card_number VARCHAR(50),
    year INTEGER,
    
    -- Special attributes
    variant BOOLEAN DEFAULT false,
    variant_name VARCHAR(100),
    rookie_card BOOLEAN DEFAULT false,
    serial_number VARCHAR(50),
    autograph BOOLEAN DEFAULT false,
    relic BOOLEAN DEFAULT false,
    refractor BOOLEAN DEFAULT false,
    is_insert BOOLEAN DEFAULT false,
    is_sp BOOLEAN DEFAULT false,
    
    -- Grading
    graded BOOLEAN DEFAULT false,
    grading_company VARCHAR(50),
    grade VARCHAR(20),
    grade_numeric DECIMAL(4,2),
    cert_number VARCHAR(100),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_card_details_player ON card_details(player);
CREATE INDEX idx_card_details_year ON card_details(year);
CREATE INDEX idx_card_details_rookie ON card_details(rookie_card);

-- ============================================================================
-- TCG DETAILS (Trading Card Games)
-- ============================================================================

CREATE TABLE tcg_details (
    tcg_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR(50) REFERENCES products(product_id) UNIQUE NOT NULL,
    set_id INTEGER REFERENCES sets(set_id),
    category_id INTEGER REFERENCES categories(category_id),
    
    -- Universal TCG fields
    card_name VARCHAR(200) NOT NULL,
    card_number VARCHAR(50),
    rarity VARCHAR(50),
    card_type VARCHAR(100),
    
    -- Final Fantasy TCG
    element VARCHAR(50),
    cost INTEGER,
    power INTEGER,
    job VARCHAR(100),
    fftcg_category VARCHAR(100),
    
    -- Pokemon
    pokemon_type VARCHAR(50),
    hp INTEGER,
    stage VARCHAR(50),
    
    -- Magic: The Gathering
    mana_cost VARCHAR(100),
    color VARCHAR(50),
    
    -- Common fields
    text TEXT,
    set_code VARCHAR(20),
    variant_type VARCHAR(20) DEFAULT 'normal',
    is_foil BOOLEAN DEFAULT false,
    foil BOOLEAN DEFAULT false,
    variant BOOLEAN DEFAULT false,
    variant_name VARCHAR(100),
    image_url TEXT,
    flavor_text TEXT,
    artist VARCHAR(200),
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_tcg_details_name ON tcg_details(card_name);
CREATE INDEX idx_tcg_details_set_code ON tcg_details(set_code);

-- ============================================================================
-- BOX & PACK DETAILS
-- ============================================================================

CREATE TABLE box_details (
    box_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR(50) REFERENCES products(product_id) UNIQUE NOT NULL,
    set_id INTEGER REFERENCES sets(set_id),
    box_name VARCHAR(200),
    box_type VARCHAR(100),
    packs_per_box INTEGER,
    cards_per_pack INTEGER,
    box_year INTEGER,
    retail_price DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE TABLE pack_details (
    pack_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR(50) REFERENCES products(product_id) UNIQUE NOT NULL,
    set_id INTEGER REFERENCES sets(set_id),
    pack_name VARCHAR(200),
    cards_per_pack INTEGER,
    pack_year INTEGER,
    retail_price DECIMAL(10,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

-- ============================================================================
-- SHOWS
-- ============================================================================

CREATE TABLE shows (
    show_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR(50) REFERENCES users(user_id) NOT NULL,
    show_name VARCHAR(200) NOT NULL,
    show_date DATE NOT NULL,
    location VARCHAR(200),
    venue VARCHAR(200),
    table_number VARCHAR(50),
    table_cost DECIMAL(10,2),
    notes TEXT,
    is_active BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_shows_user ON shows(user_id);
CREATE INDEX idx_shows_date ON shows(show_date);
CREATE INDEX idx_shows_active ON shows(is_active);

-- ============================================================================
-- INVENTORY
-- ============================================================================

CREATE TABLE inventory (
    inventory_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR(50) REFERENCES users(user_id) NOT NULL,
    product_id VARCHAR(50) REFERENCES products(product_id) NOT NULL,
    
    -- Quantities
    quantity INTEGER DEFAULT 0,
    available_quantity INTEGER DEFAULT 0,
    
    -- Pricing
    purchase_price DECIMAL(10,2),
    current_market_price DECIMAL(10,2),
    asking_price DECIMAL(10,2),
    minimum_price DECIMAL(10,2),
    
    -- Storage
    storage_location VARCHAR(200),
    box_number VARCHAR(50),
    row_number VARCHAR(50),
    
    -- Notes
    notes TEXT,
    private_notes TEXT,
    
    -- Status
    for_sale BOOLEAN DEFAULT true,
    featured BOOLEAN DEFAULT false,
    condition VARCHAR(50),
    acquired_date DATE,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX idx_inventory_user ON inventory(user_id);
CREATE INDEX idx_inventory_product ON inventory(product_id);
CREATE INDEX idx_inventory_for_sale ON inventory(for_sale);

-- ============================================================================
-- TRANSACTIONS (Sales)
-- ============================================================================

CREATE TABLE inventory_transactions (
    transaction_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    inventory_id VARCHAR(50) REFERENCES inventory(inventory_id) NOT NULL,
    user_id VARCHAR(50) REFERENCES users(user_id) NOT NULL,
    
    transaction_type VARCHAR(50) NOT NULL,  -- 'sale', 'purchase', 'adjustment'
    quantity INTEGER NOT NULL,
    unit_price DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    
    -- Payment
    payment_method VARCHAR(50),
    payment_reference VARCHAR(100),
    
    -- Customer
    customer_name VARCHAR(200),
    customer_email VARCHAR(255),
    customer_phone VARCHAR(50),
    
    -- Show tracking
    show_name VARCHAR(200),
    show_date DATE,
    show_location VARCHAR(200),
    
    notes TEXT,
    transaction_date TIMESTAMP WITH TIME ZONE NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_transactions_user ON inventory_transactions(user_id);
CREATE INDEX idx_transactions_inventory ON inventory_transactions(inventory_id);
CREATE INDEX idx_transactions_type ON inventory_transactions(transaction_type);
CREATE INDEX idx_transactions_show ON inventory_transactions(show_name);
CREATE INDEX idx_transactions_date ON inventory_transactions(transaction_date);

-- ============================================================================
-- EXPENSES
-- ============================================================================

CREATE TABLE expenses (
    expense_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR(50) REFERENCES users(user_id) NOT NULL,
    show_id VARCHAR(50) REFERENCES shows(show_id),
    
    expense_type VARCHAR(100) NOT NULL,
    description VARCHAR(500) NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_method VARCHAR(50),
    receipt_image VARCHAR(500),
    notes TEXT,
    expense_date DATE NOT NULL,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_expenses_user ON expenses(user_id);
CREATE INDEX idx_expenses_show ON expenses(show_id);
CREATE INDEX idx_expenses_date ON expenses(expense_date);
CREATE INDEX idx_expenses_type ON expenses(expense_type);

-- ============================================================================
-- SCANNING & FINGERPRINTS (Legacy - kept for future use)
-- ============================================================================

CREATE TABLE scans (
    scan_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    user_id VARCHAR(50) REFERENCES users(user_id) NOT NULL,
    product_id VARCHAR(50) REFERENCES products(product_id),
    
    scan_type VARCHAR(50),
    scan_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    raw_data TEXT,
    ocr_confidence DECIMAL(4,3),
    
    -- Detected info
    detected_player VARCHAR(200),
    detected_sport VARCHAR(100),
    detected_team VARCHAR(100),
    detected_year INTEGER,
    detected_set VARCHAR(200),
    detected_card_number VARCHAR(50),
    detected_variant BOOLEAN,
    detected_variant_name VARCHAR(100),
    detected_grading_company VARCHAR(50),
    detected_grade VARCHAR(20),
    detected_cert_number VARCHAR(100),
    
    image_path VARCHAR(500),
    verified BOOLEAN DEFAULT false,
    edited BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_scans_user ON scans(user_id);
CREATE INDEX idx_scans_product ON scans(product_id);

-- ============================================================================
-- PRICE HISTORY
-- ============================================================================

CREATE TABLE price_history (
    price_id VARCHAR(50) PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR(50) REFERENCES products(product_id) NOT NULL,
    source VARCHAR(100) NOT NULL,
    price DECIMAL(10,2) NOT NULL,
    condition VARCHAR(50),
    price_date TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX idx_price_history_product ON price_history(product_id);
CREATE INDEX idx_price_history_source ON price_history(source);
CREATE INDEX idx_price_history_date ON price_history(price_date);

-- ============================================================================
-- SEED DATA
-- ============================================================================

-- Product types
INSERT INTO product_types (product_type_id, product_type_name) VALUES
('pt_card', 'Single Card'),
('pt_pack', 'Booster Pack'),
('pt_box', 'Sealed Box'),
('pt_case', 'Case'),
('pt_deck', 'Preconstructed Deck'),
('pt_accessory', 'Accessory');

-- Categories
INSERT INTO categories (category_name, category_type) VALUES
('Pokemon', 'tcg'),
('Magic: The Gathering', 'tcg'),
('Final Fantasy TCG', 'tcg'),
('One Piece', 'tcg'),
('Yu-Gi-Oh!', 'tcg'),
('Baseball', 'sports'),
('Basketball', 'sports'),
('Football', 'sports'),
('Hockey', 'sports'),
('Soccer', 'sports');

-- ============================================================================
-- END OF SCHEMA
-- ============================================================================
