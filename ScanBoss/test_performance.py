"""
Quick performance test for fuzzy matching
"""
import time
from pathlib import Path
import sys

sys.path.insert(0, '/Users/travisdewitt/Repos/VendorBoss2.0/vendorboss-api')

from database import get_db
import models

def test_fuzzy_matching_performance():
    """Test how long fuzzy matching takes with 3,421 fingerprints"""
    db = next(get_db())
    
    # Count fingerprints
    count = db.query(models.CardFingerprint).count()
    print(f"Total fingerprints in database: {count}")
    
    # Get all fingerprints
    print("\nFetching all fingerprints...")
    start = time.time()
    fingerprints = db.query(models.CardFingerprint).all()
    fetch_time = time.time() - start
    print(f"Fetch time: {fetch_time:.2f}s")
    
    # Simulate component comparison
    print("\nSimulating component comparison...")
    test_components = {
        'border': 'a' * 64,
        'name_region': 'b' * 64,
        'color_zones': 'c' * 64,
        'texture': 'd' * 64,
        'layout': 'e' * 64,
        'quadrant_0_0': 'f' * 64,
        'quadrant_0_1': 'g' * 64,
        'quadrant_0_2': 'h' * 64,
        'quadrant_1_0': 'i' * 64,
        'quadrant_1_1': 'j' * 64,
        'quadrant_1_2': 'k' * 64,
        'quadrant_2_0': 'l' * 64,
        'quadrant_2_1': 'm' * 64,
        'quadrant_2_2': 'n' * 64,
    }
    
    start = time.time()
    matches = []
    for fp in fingerprints:
        # Count matching components
        matching = 0
        if fp.border == test_components['border']: matching += 1
        if fp.name_region == test_components['name_region']: matching += 1
        if fp.color_zones == test_components['color_zones']: matching += 1
        if fp.texture == test_components['texture']: matching += 1
        if fp.layout == test_components['layout']: matching += 1
        if fp.quadrant_0_0 == test_components['quadrant_0_0']: matching += 1
        if fp.quadrant_0_1 == test_components['quadrant_0_1']: matching += 1
        if fp.quadrant_0_2 == test_components['quadrant_0_2']: matching += 1
        if fp.quadrant_1_0 == test_components['quadrant_1_0']: matching += 1
        if fp.quadrant_1_1 == test_components['quadrant_1_1']: matching += 1
        if fp.quadrant_1_2 == test_components['quadrant_1_2']: matching += 1
        if fp.quadrant_2_0 == test_components['quadrant_2_0']: matching += 1
        if fp.quadrant_2_1 == test_components['quadrant_2_1']: matching += 1
        if fp.quadrant_2_2 == test_components['quadrant_2_2']: matching += 1
        
        similarity = matching / 14.0
        if similarity >= 0.71:
            matches.append((fp, similarity, matching))
    
    comparison_time = time.time() - start
    print(f"Comparison time: {comparison_time:.2f}s")
    print(f"Found {len(matches)} potential matches")
    
    print("\n" + "="*60)
    print("PERFORMANCE SUMMARY")
    print("="*60)
    print(f"Database fetch: {fetch_time:.2f}s")
    print(f"Fuzzy matching: {comparison_time:.2f}s")
    print(f"TOTAL TIME: {fetch_time + comparison_time:.2f}s")
    print("="*60)

if __name__ == "__main__":
    test_fuzzy_matching_performance()
