"""
Test VendorBoss 2.0 Fingerprint System
Run against saved card images in Scans folder
"""
import cv2
import os
from card_detector import CardDetector
import json

def test_fingerprints():
    """Test fingerprint generation on saved card images"""
    
    print("=" * 70)
    print("VendorBoss 2.0 Fingerprint Test")
    print("=" * 70)
    print()
    
    # Initialize detector
    detector = CardDetector()
    print("✓ CardDetector initialized")
    print()
    
    # Get all images from Scans folder
    scans_dir = "Scans"
    if not os.path.exists(scans_dir):
        print(f"❌ Error: {scans_dir} folder not found!")
        return
    
    image_files = [f for f in os.listdir(scans_dir) if f.endswith(('.jpg', '.jpeg', '.png'))]
    
    if not image_files:
        print(f"❌ No images found in {scans_dir}/")
        return
    
    print(f"Found {len(image_files)} card images")
    print("-" * 70)
    print()
    
    results = []
    
    for i, image_file in enumerate(image_files, 1):
        print(f"[{i}/{len(image_files)}] Processing: {image_file}")
        
        # Load image
        image_path = os.path.join(scans_dir, image_file)
        image = cv2.imread(image_path)
        
        if image is None:
            print(f"  ❌ Failed to load image")
            print()
            continue
        
        print(f"  Image size: {image.shape[1]}x{image.shape[0]}")
        
        # Detect card (no contour needed for pre-cropped images)
        # Just resize and generate fingerprint
        h, w = image.shape[:2]
        
        # Resize to detection size
        resized = cv2.resize(image, (detector.detection_width, detector.detection_height))
        
        # Generate fingerprint
        fingerprint_data = detector._generate_14_component_fingerprint(resized)
        
        if not fingerprint_data:
            print(f"  ❌ Failed to generate fingerprint")
            print()
            continue
        
        # Display results
        fp_hash = fingerprint_data['fingerprint_hash']
        components = fingerprint_data['components']
        
        print(f"  ✓ Fingerprint generated!")
        print(f"  Hash: {fp_hash}")
        print(f"  Components:")
        print(f"    - border:      {components['border']}")
        print(f"    - name_region: {components['name_region']}")
        print(f"    - color_zones: {components['color_zones']}")
        print(f"    - texture:     {components['texture']}")
        print(f"    - layout:      {components['layout']}")
        print(f"    - quadrant_0_0: {components['quadrant_0_0']}")
        print(f"    - quadrant_0_1: {components['quadrant_0_1']}")
        print(f"    - quadrant_0_2: {components['quadrant_0_2']}")
        print(f"    - quadrant_1_0: {components['quadrant_1_0']}")
        print(f"    - quadrant_1_1: {components['quadrant_1_1']}")
        print(f"    - quadrant_1_2: {components['quadrant_1_2']}")
        print(f"    - quadrant_2_0: {components['quadrant_2_0']}")
        print(f"    - quadrant_2_1: {components['quadrant_2_1']}")
        print(f"    - quadrant_2_2: {components['quadrant_2_2']}")
        print()
        
        results.append({
            'filename': image_file,
            'fingerprint_hash': fp_hash,
            'components': components
        })
    
    print("=" * 70)
    print("Summary")
    print("=" * 70)
    print(f"Total images processed: {len(image_files)}")
    print(f"Successful fingerprints: {len(results)}")
    print()
    
    # Check for duplicates (same card scanned multiple times)
    if len(results) > 1:
        print("Checking for duplicate cards...")
        seen_hashes = {}
        duplicates_found = False
        
        for result in results:
            fp_hash = result['fingerprint_hash']
            filename = result['filename']
            
            if fp_hash in seen_hashes:
                duplicates_found = True
                print(f"  ⚠️  DUPLICATE FOUND!")
                print(f"      {filename} matches {seen_hashes[fp_hash]}")
                print(f"      Same fingerprint: {fp_hash[:32]}...")
            else:
                seen_hashes[fp_hash] = filename
        
        if not duplicates_found:
            print("  ✓ All fingerprints are unique")
        print()
    
    # Test consistency - re-scan first image
    if results:
        print("Testing fingerprint consistency...")
        print("Re-scanning first image to verify same fingerprint...")
        
        first_file = results[0]['filename']
        first_hash = results[0]['fingerprint_hash']
        
        image_path = os.path.join(scans_dir, first_file)
        image = cv2.imread(image_path)
        resized = cv2.resize(image, (detector.detection_width, detector.detection_height))
        
        # Generate fingerprint again
        fingerprint_data2 = detector._generate_14_component_fingerprint(resized)
        second_hash = fingerprint_data2['fingerprint_hash']
        
        if first_hash == second_hash:
            print(f"  ✓ PASS: Fingerprint is consistent!")
            print(f"    Both scans: {first_hash[:32]}...")
        else:
            print(f"  ❌ FAIL: Fingerprint changed!")
            print(f"    First:  {first_hash[:32]}...")
            print(f"    Second: {second_hash[:32]}...")
        print()
    
    # Save results to JSON
    output_file = "fingerprint_test_results.json"
    with open(output_file, 'w') as f:
        json.dump(results, f, indent=2)
    
    print(f"Results saved to: {output_file}")
    print()
    
    # Test API submission (optional)
    print("=" * 70)
    print("API Test (Optional)")
    print("=" * 70)
    print()
    
    test_api = input("Test API submission? (y/n): ").lower().strip()
    
    if test_api == 'y' and results:
        from api_client import APIClient
        
        api = APIClient()
        
        print("\nTesting card identification...")
        first_result = results[0]
        
        # Try to identify
        identify_response = api.identify_card({
            'fingerprint_hash': first_result['fingerprint_hash'],
            'components': first_result['components']
        })
        
        print(f"Response: {json.dumps(identify_response, indent=2)}")
        
        if identify_response.get('success'):
            data = identify_response.get('data', {})
            if data.get('found'):
                print(f"\n✓ Card identified!")
                product = data.get('product', {})
                print(f"  Card: {product.get('card_name', 'Unknown')}")
                print(f"  Set: {product.get('card_set', 'Unknown')}")
            else:
                print(f"\n⚠️  Card not in database (expected for new cards)")
        else:
            print(f"\n❌ API Error: {identify_response.get('error')}")
    
    print("\n" + "=" * 70)
    print("Test Complete!")
    print("=" * 70)


if __name__ == "__main__":
    test_fingerprints()
