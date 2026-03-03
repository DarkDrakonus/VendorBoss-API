#!/usr/bin/env python3
"""
Simple API matching test - no complex imports needed
Tests if the API can match fingerprinted cards correctly
"""

import cv2
import numpy as np
import requests
import json
from pathlib import Path
import hashlib


def generate_simple_fingerprint(image_path):
    """
    Simplified fingerprint generation for testing
    (Uses same logic as CardDetector but standalone)
    """
    img = cv2.imread(image_path)
    if img is None:
        return None
    
    # Normalize size
    normalized = cv2.resize(img, (400, 600))
    
    # Generate perceptual hashes for different regions
    def phash(region, is_gray=False):
        """Generate perceptual hash"""
        if is_gray:
            gray = region
        else:
            gray = cv2.cvtColor(region, cv2.COLOR_BGR2GRAY)
        resized = cv2.resize(gray, (8, 8))
        avg = resized.mean()
        bits = (resized > avg).astype(int)
        hash_str = ''.join(str(b) for row in bits for b in row)
        return format(int(hash_str, 2), '016x')
    
    h, w = normalized.shape[:2]
    
    # Create 14-component fingerprint
    gray_normalized = cv2.cvtColor(normalized, cv2.COLOR_BGR2GRAY)
    
    components = {
        'border': phash(normalized[0:20, :]),
        'name_region': phash(normalized[10:80, 50:350]),
        'color_zones': phash(normalized[:, :w//3]),
        'texture': phash(np.uint8(np.absolute(cv2.Laplacian(gray_normalized, cv2.CV_64F))), is_gray=True),
        'layout': phash(cv2.Canny(gray_normalized, 100, 200), is_gray=True),
    }
    
    # Add 9 quadrant hashes
    quad_h, quad_w = h // 3, w // 3
    for i in range(3):
        for j in range(3):
            y1, y2 = i * quad_h, (i + 1) * quad_h
            x1, x2 = j * quad_w, (j + 1) * quad_w
            quadrant = normalized[y1:y2, x1:x2]
            components[f'quadrant_{i}_{j}'] = phash(quadrant)
    
    # Create composite hash
    all_hashes = ''.join(components.values())
    composite = hashlib.sha256(all_hashes.encode()).hexdigest()
    
    return {
        'composite_hash': composite,
        'components': components
    }


def test_match(image_path, expected_set_code, api_url):
    """Test if API can match a card correctly"""
    
    print(f"\n{'='*70}")
    print(f"Testing: {Path(image_path).name}")
    print(f"Expected: {expected_set_code}")
    print(f"{'='*70}")
    
    # Generate fingerprint
    fingerprint = generate_simple_fingerprint(image_path)
    
    if not fingerprint:
        print("✗ Failed to generate fingerprint")
        return False
    
    print(f"✓ Fingerprint generated: {fingerprint['composite_hash'][:32]}...")
    
    # Query API
    try:
        response = requests.post(f"{api_url}/api/scan/fingerprint/check", json={
            'fingerprint': fingerprint['composite_hash'],
            'confidence_threshold': 0.5
        }, timeout=10)
        
        if response.status_code != 200:
            print(f"✗ API error: {response.status_code}")
            print(f"  Response: {response.text[:200]}")
            return False
        
        matches = response.json()
        
        if not matches:
            print("✗ No matches found in database")
            return False
        
        print(f"\nTop 5 matches:")
        print(f"{'Rank':<6} {'Set Code':<15} {'Name':<30} {'Score':<10}")
        print(f"{'-'*70}")
        
        correct_match = False
        for i, match in enumerate(matches[:5], 1):
            set_code = match.get('set_code', 'Unknown')
            name = match.get('name', 'Unknown')[:28]
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
        print("  Is the server running?")
        return False
    except Exception as e:
        print(f"✗ Error: {e}")
        return False


if __name__ == "__main__":
    API_URL = "http://192.168.1.37:8001"
    
    # Test cases (image_path, expected_set_code)
    # Using files from eg/ folder that ARE in the database
    test_cases = [
        ("Scans/eg/1-001H.jpg", "1-001H"),
        ("Scans/eg/1-002R.jpg", "1-002R"),
        ("Scans/eg/1-003C.jpg", "1-003C"),
        ("Scans/eg/10-001H.jpg", "10-001H"),
    ]
    
    print("\n" + "="*70)
    print("FINGERPRINT MATCHING ACCURACY TEST")
    print("="*70)
    print(f"\nAPI Server: {API_URL}")
    print("Testing against database of 3,421 cards\n")
    
    results = []
    
    for image_path, expected in test_cases:
        full_path = Path(__file__).parent / image_path
        if full_path.exists():
            success = test_match(str(full_path), expected, API_URL)
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
        print("\n🎉 EXCELLENT! Fingerprinting works - you don't need OCR!")
    elif accuracy >= 70:
        print("\n👍 GOOD! Fingerprinting is viable with some tuning")
    else:
        print("\n⚠️  LOW accuracy - needs improvement")
