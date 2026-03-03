#!/usr/bin/env python3
"""
Test fingerprint MATCHING accuracy
Queries the API with fingerprints to see if we get correct matches
"""

import sys
import requests
import json
from pathlib import Path

# Add parent directory to path
sys.path.insert(0, str(Path(__file__).parent))

from scanboss_fleet import FingerprintGenerator


def test_match(image_path: str, expected_set_code: str):
    """
    Test if fingerprinting can match a card correctly
    
    Args:
        image_path: Path to card image
        expected_set_code: What we expect to find (from filename)
    """
    print(f"\n{'='*70}")
    print(f"Testing: {image_path}")
    print(f"Expected: {expected_set_code}")
    print(f"{'='*70}")
    
    # Generate fingerprint
    generator = FingerprintGenerator()
    result = generator.generate_fingerprint(image_path)
    
    if not result or 'fingerprint' not in result:
        print("✗ Failed to generate fingerprint")
        return False
    
    fingerprint = result['fingerprint']
    print(f"✓ Fingerprint generated")
    
    # Query API for matches
    api_url = "http://192.168.1.37:8001/api/products/match"
    
    try:
        response = requests.post(api_url, json={
            'fingerprint': fingerprint,
            'top_n': 5
        })
        
        if response.status_code != 200:
            print(f"✗ API error: {response.status_code}")
            return False
        
        matches = response.json()
        
        if not matches:
            print("✗ No matches found")
            return False
        
        print(f"\nTop 5 matches:")
        print(f"{'Rank':<6} {'Set Code':<15} {'Name':<30} {'Score':<10}")
        print(f"{'-'*70}")
        
        correct_match = False
        for i, match in enumerate(matches[:5], 1):
            set_code = match.get('set_code', 'Unknown')
            name = match.get('name', 'Unknown')
            score = match.get('match_score', 0)
            
            marker = '✓' if set_code == expected_set_code else ' '
            print(f"{marker} {i:<5} {set_code:<15} {name:<30} {score:.3f}")
            
            if i == 1 and set_code == expected_set_code:
                correct_match = True
        
        if correct_match:
            print(f"\n✓ SUCCESS: Correct match in #1 position!")
            return True
        else:
            top_match = matches[0]
            print(f"\n✗ FAILED: Top match was {top_match.get('set_code')} (expected {expected_set_code})")
            return False
            
    except requests.exceptions.ConnectionError:
        print(f"✗ Could not connect to API at {api_url}")
        print("  Is the server running? (ssh drakonus@192.168.1.37)")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False


if __name__ == "__main__":
    # Test a few cards with known set codes
    test_cases = [
        ("Scans/eg/1-001H.jpg", "1-001H"),
        ("Scans/eg/27-001R_eg.jpg", "27-001R"),
        ("Scans/eg/27-002H_eg.jpg", "27-002H"),
        ("Scans/Re-003H.jpg", "Re-003H"),
    ]
    
    print("\n" + "="*70)
    print("FINGERPRINT MATCHING ACCURACY TEST")
    print("="*70)
    print(f"\nTesting against API: http://192.168.1.37:8001")
    print(f"Database should contain 3,421 reference fingerprints\n")
    
    results = []
    
    for image_path, expected in test_cases:
        full_path = Path(__file__).parent / image_path
        if full_path.exists():
            success = test_match(str(full_path), expected)
            results.append((expected, success))
        else:
            print(f"\n✗ File not found: {image_path}")
            results.append((expected, False))
    
    # Summary
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    
    passed = sum(1 for _, success in results if success)
    total = len(results)
    accuracy = (passed / total * 100) if total > 0 else 0
    
    for expected, success in results:
        status = "✓ PASS" if success else "✗ FAIL"
        print(f"{status}: {expected}")
    
    print(f"\nAccuracy: {passed}/{total} ({accuracy:.1f}%)")
    
    if accuracy >= 90:
        print("\n🎉 EXCELLENT! Fingerprinting works well - OCR not needed!")
    elif accuracy >= 70:
        print("\n👍 GOOD! Some tuning needed but fingerprinting is viable")
    else:
        print("\n⚠️  LOW accuracy - fingerprinting needs work")
