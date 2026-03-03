"""
Test to verify Fixed Region Detector is working
"""

import cv2
from fixed_region_detector import FixedRegionDetector

print("="*60)
print("TESTING FIXED REGION DETECTOR")
print("="*60)

detector = FixedRegionDetector()

# Test with a sample image
camera = cv2.VideoCapture(0)
ret, frame = camera.read()

if ret:
    print(f"\nCaptured frame: {frame.shape}")
    
    # Simulate cropping to guide region (center 70% of height)
    h, w = frame.shape[:2]
    guide_height = int(h * 0.7)
    guide_width = int(guide_height / 1.4)
    
    x1 = (w - guide_width) // 2
    y1 = (h - guide_height) // 2
    x2 = x1 + guide_width
    y2 = y1 + guide_height
    
    guide_region = frame[y1:y2, x1:x2]
    
    print(f"Guide region: {guide_region.shape}")
    
    # Test detection
    result = detector.detect_card_in_frame(guide_region)
    
    print(f"\nResult: {result['detected']}")
    if result['detected']:
        card_img = result['card_image']
        print(f"Card image size: {card_img.shape}")
        cv2.imwrite('test_detected_card_fixed.jpg', card_img)
        print("✓ Saved to test_detected_card_fixed.jpg")
    else:
        print("✗ No card detected")

camera.release()

print("\n" + "="*60)
print("Look for files:")
print("  - debug_GUIDE_REGION_*.jpg (what detector received)")
print("  - test_detected_card_fixed.jpg (final output)")
print("="*60)
