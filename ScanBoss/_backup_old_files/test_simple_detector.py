"""
Test Simple Card Detector

Quick test to see if card detection works
"""

import cv2
from simple_card_detector import SimpleCardDetector

detector = SimpleCardDetector()
camera = cv2.VideoCapture(0)

print("="*60)
print("SIMPLE CARD DETECTOR TEST")
print("="*60)
print("Instructions:")
print("  - Hold a card in front of camera")
print("  - Green overlay = card detected")
print("  - Press SPACE to save detected card")
print("  - Press Q to quit")
print("="*60 + "\n")

while True:
    ret, frame = camera.read()
    if not ret:
        break
    
    # Detect with visualization
    vis_frame, result = detector.detect_with_visualization(frame)
    
    # Show visualization
    cv2.imshow('Card Detection Test', vis_frame)
    
    key = cv2.waitKey(1) & 0xFF
    
    if key == ord(' '):  # SPACE to save
        if result['detected']:
            card_img = result['card_image']
            cv2.imwrite('detected_card.jpg', card_img)
            print("✓ Saved detected card to: detected_card.jpg")
            print(f"  Size: {card_img.shape}")
        else:
            print("✗ No card detected - can't save")
    
    elif key == ord('q'):
        break

camera.release()
cv2.destroyAllWindows()
