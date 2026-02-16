"""
Performance optimizations for VendorBoss 2.0 API
Add database indexes for faster fuzzy matching
"""
from sqlalchemy import text
from database import engine

def add_performance_indexes():
    """Add indexes to speed up fingerprint queries"""
    
    print("Adding performance indexes...")
    
    with engine.connect() as conn:
        # Index on fingerprint_hash for exact matches (should already exist as unique)
        # Index on individual components for faster fuzzy matching
        indexes = [
            "CREATE INDEX IF NOT EXISTS idx_fp_border ON card_fingerprints(border);",
            "CREATE INDEX IF NOT EXISTS idx_fp_name_region ON card_fingerprints(name_region);",
            "CREATE INDEX IF NOT EXISTS idx_fp_color_zones ON card_fingerprints(color_zones);",
            "CREATE INDEX IF NOT EXISTS idx_fp_texture ON card_fingerprints(texture);",
            "CREATE INDEX IF NOT EXISTS idx_fp_layout ON card_fingerprints(layout);",
            "CREATE INDEX IF NOT EXISTS idx_fp_product ON card_fingerprints(product_id);",
            "CREATE INDEX IF NOT EXISTS idx_fp_confidence ON card_fingerprints(confidence_score);",
        ]
        
        for idx_sql in indexes:
            print(f"  Creating index: {idx_sql.split('idx_')[1].split(' ')[0]}...")
            conn.execute(text(idx_sql))
            conn.commit()
    
    print("✓ Indexes created!")
    print("\nNote: Fuzzy matching still requires O(n) comparisons.")
    print("For production with 100k+ cards, consider:")
    print("  1. Pre-filter by high-discrimination components")
    print("  2. Use locality-sensitive hashing (LSH)")
    print("  3. Cache frequently-matched cards")

if __name__ == "__main__":
    add_performance_indexes()
