-- ============================================
-- ScanBoss Learning System Database Schema
-- ============================================
-- This creates the tables needed for the fleet learning system
-- Run this on your VendorBoss API database

-- 1. Card Fingerprints Table
-- Stores unique card fingerprints and their consensus data
CREATE TABLE IF NOT EXISTS card_fingerprints (
    id SERIAL PRIMARY KEY,
    fingerprint VARCHAR(64) UNIQUE NOT NULL,
    
    -- Consensus card data (what most users agree on)
    consensus_player_name VARCHAR(255),
    consensus_card_year INTEGER,
    consensus_card_set VARCHAR(255),
    
    -- Learning metrics
    total_submissions INTEGER DEFAULT 0,
    confirmed_submissions INTEGER DEFAULT 0,
    confidence_score DECIMAL(4,3) DEFAULT 0.000,  -- 0.000 to 1.000
    agreement_rate DECIMAL(4,3) DEFAULT 0.000,    -- % of users who agree
    
    -- Status tracking
    status VARCHAR(20) DEFAULT 'learning',  -- learning, confirmed, disputed, needs_review
    
    -- Timestamps
    first_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    confirmed_at TIMESTAMP NULL,
    
    -- Optional: For future AI enhancements
    ocr_data JSONB NULL,
    image_url VARCHAR(500) NULL,
    
    -- Indexes for performance
    CONSTRAINT valid_confidence CHECK (confidence_score >= 0 AND confidence_score <= 1),
    CONSTRAINT valid_agreement CHECK (agreement_rate >= 0 AND agreement_rate <= 1)
);

CREATE INDEX idx_fingerprints_status ON card_fingerprints(status);
CREATE INDEX idx_fingerprints_confidence ON card_fingerprints(confidence_score DESC);
CREATE INDEX idx_fingerprints_last_seen ON card_fingerprints(last_seen DESC);

-- 2. Fingerprint Submissions Table
-- Tracks every individual submission for learning
CREATE TABLE IF NOT EXISTS fingerprint_submissions (
    id SERIAL PRIMARY KEY,
    fingerprint VARCHAR(64) NOT NULL,
    user_id INTEGER NULL,  -- NULL for anonymous submissions
    
    -- What the user said it was
    submitted_player_name VARCHAR(255),
    submitted_card_year INTEGER,
    submitted_card_set VARCHAR(255),
    
    -- Validation
    matches_consensus BOOLEAN NULL,  -- Updated after consensus is calculated
    flagged_as_incorrect BOOLEAN DEFAULT FALSE,
    
    -- Metadata
    app_version VARCHAR(20) NULL,
    ocr_data JSONB NULL,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    FOREIGN KEY (fingerprint) REFERENCES card_fingerprints(fingerprint) ON DELETE CASCADE
);

CREATE INDEX idx_submissions_fingerprint ON fingerprint_submissions(fingerprint);
CREATE INDEX idx_submissions_user ON fingerprint_submissions(user_id);
CREATE INDEX idx_submissions_created ON fingerprint_submissions(created_at DESC);

-- 3. Model Versions Table
-- Tracks model updates pushed to ScanBoss apps
CREATE TABLE IF NOT EXISTS model_versions (
    id SERIAL PRIMARY KEY,
    version VARCHAR(20) UNIQUE NOT NULL,
    
    -- What's in this version
    known_cards_count INTEGER DEFAULT 0,
    confidence_threshold DECIMAL(4,3) DEFAULT 0.700,
    
    -- Update metadata
    release_notes TEXT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Performance tracking
    downloads_count INTEGER DEFAULT 0,
    last_downloaded_at TIMESTAMP NULL
);

CREATE INDEX idx_versions_created ON model_versions(created_at DESC);

-- 4. User Contributions Table (Optional - for gamification)
-- Track which users are helping the most
CREATE TABLE IF NOT EXISTS user_contributions (
    user_id INTEGER PRIMARY KEY,
    
    -- Contribution stats
    total_submissions INTEGER DEFAULT 0,
    accurate_submissions INTEGER DEFAULT 0,  -- Matched consensus
    disputed_submissions INTEGER DEFAULT 0,   -- Disagreed with consensus
    
    -- Reputation/trust score (0.0 to 1.0)
    trust_score DECIMAL(4,3) DEFAULT 0.500,
    
    -- Timestamps
    first_contribution TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_contribution TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT valid_trust CHECK (trust_score >= 0 AND trust_score <= 1)
);

CREATE INDEX idx_contributions_trust ON user_contributions(trust_score DESC);

-- 5. Learning Stats View
-- Easy access to system-wide statistics
CREATE OR REPLACE VIEW learning_stats AS
SELECT 
    COUNT(*) as total_fingerprints,
    COUNT(*) FILTER (WHERE status = 'confirmed') as confirmed_cards,
    COUNT(*) FILTER (WHERE status = 'learning') as learning_cards,
    COUNT(*) FILTER (WHERE status = 'disputed') as disputed_cards,
    SUM(total_submissions) as total_submissions,
    AVG(confidence_score) as average_confidence,
    MAX(last_seen) as last_activity
FROM card_fingerprints;

-- ============================================
-- Helper Functions
-- ============================================

-- Function to calculate consensus for a fingerprint
CREATE OR REPLACE FUNCTION calculate_consensus(fp VARCHAR(64))
RETURNS TABLE (
    player_name VARCHAR(255),
    card_year INTEGER,
    card_set VARCHAR(255),
    total_count INTEGER,
    agreement_rate DECIMAL(4,3)
) AS $$
BEGIN
    RETURN QUERY
    WITH player_votes AS (
        SELECT 
            submitted_player_name,
            COUNT(*) as vote_count
        FROM fingerprint_submissions
        WHERE fingerprint = fp
        GROUP BY submitted_player_name
        ORDER BY vote_count DESC
        LIMIT 1
    ),
    year_votes AS (
        SELECT 
            submitted_card_year,
            COUNT(*) as vote_count
        FROM fingerprint_submissions
        WHERE fingerprint = fp
        GROUP BY submitted_card_year
        ORDER BY vote_count DESC
        LIMIT 1
    ),
    set_votes AS (
        SELECT 
            submitted_card_set,
            COUNT(*) as vote_count
        FROM fingerprint_submissions
        WHERE fingerprint = fp
        GROUP BY submitted_card_set
        ORDER BY vote_count DESC
        LIMIT 1
    ),
    totals AS (
        SELECT COUNT(*) as total
        FROM fingerprint_submissions
        WHERE fingerprint = fp
    )
    SELECT 
        p.submitted_player_name,
        y.submitted_card_year,
        s.submitted_card_set,
        t.total::INTEGER,
        CASE 
            WHEN t.total > 0 THEN (p.vote_count::DECIMAL / t.total)::DECIMAL(4,3)
            ELSE 0.000
        END as agreement_rate
    FROM player_votes p, year_votes y, set_votes s, totals t;
END;
$$ LANGUAGE plpgsql;

-- ============================================
-- Sample Data (for testing)
-- ============================================

-- Insert a sample confirmed card
INSERT INTO card_fingerprints (
    fingerprint,
    consensus_player_name,
    consensus_card_year,
    consensus_card_set,
    total_submissions,
    confirmed_submissions,
    confidence_score,
    agreement_rate,
    status,
    confirmed_at
) VALUES (
    'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6',
    'Michael Jordan',
    1997,
    'Upper Deck',
    10,
    10,
    1.000,
    1.000,
    'confirmed',
    CURRENT_TIMESTAMP
) ON CONFLICT (fingerprint) DO NOTHING;

-- Insert sample submissions
INSERT INTO fingerprint_submissions (
    fingerprint,
    submitted_player_name,
    submitted_card_year,
    submitted_card_set
) VALUES 
    ('a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6', 'Michael Jordan', 1997, 'Upper Deck'),
    ('a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6', 'Michael Jordan', 1997, 'Upper Deck'),
    ('a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6', 'Michael Jordan', 1997, 'Upper Deck')
ON CONFLICT DO NOTHING;

-- ============================================
-- Verification Queries
-- ============================================

-- Check if tables were created
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
  AND table_name IN ('card_fingerprints', 'fingerprint_submissions', 'model_versions', 'user_contributions')
ORDER BY table_name;

-- View initial stats
SELECT * FROM learning_stats;

COMMENT ON TABLE card_fingerprints IS 'Stores unique card fingerprints with consensus data from multiple user submissions';
COMMENT ON TABLE fingerprint_submissions IS 'Individual submissions from users for learning and consensus building';
COMMENT ON TABLE model_versions IS 'Tracks model updates distributed to ScanBoss applications';
COMMENT ON TABLE user_contributions IS 'User reputation and contribution tracking for quality control';
