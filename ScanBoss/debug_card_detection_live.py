#!/usr/bin/env python3
"""
Debug script to test card detection with live visualization
"""

import cv2
import numpy as np
from card_detector import CardDetector

detector = CardDetector()

# Open camera
cap = cv2.VideoCapture(0)
cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

print("Card Detection Debugger")
print("Press 'q' to quit")
print("Press 's' to save current frame for analysis")
print("-" * 50)

while True:
    ret, frame = cap.read()
    if not ret:
        break
    
    # Make a copy for visualization
    debug_frame = frame.copy()
    
    # Convert to grayscale and detect edges
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    edges = cv2.Canny(blurred, 50, 150)
    
    # Find contours
    contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    # Draw all contours and show areas
    print(f"\rFound {len(contours)} contours", end="")
    
    if contours:
        # Sort by area and show top 5
        sorted_contours = sorted(contours, key=cv2.contourArea, reverse=True)[:5]
        
        for i, contour in enumerate(sorted_contours):
            area = cv2.contourArea(contour)
            
            # Color code by area threshold
            if area > 10000:
                color = (0, 255, 0)  # Green - would be detected
            elif area > 5000:
                color = (255, 255, 0)  # Yellow - close
            else:
                color = (0, 0, 255)  # Red - too small
            
            # Draw contour
            cv2.drawContours(debug_frame, [contour], -1, color, 2)
            
            # Show area
            M = cv2.moments(contour)
            if M["m00"] != 0:
                cx = int(M["m10"] / M["m00"])
                cy = int(M["m01"] / M["m00"])
                cv2.putText(debug_frame, f"{int(area)}", (cx, cy),
                           cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2)
    
    # Draw detection zone
    h, w = debug_frame.shape[:2]
    center_x, center_y = w // 2, h // 2
    zone_w, zone_h = 200, 280
    cv2.rectangle(debug_frame,
                 (center_x - zone_w//2, center_y - zone_h//2),
                 (center_x + zone_w//2, center_y + zone_h//2),
                 (255, 0, 255), 2)
    
    # Add instructions
    cv2.putText(debug_frame, "Green = Detected | Yellow = Close | Red = Too Small",
               (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
    cv2.putText(debug_frame, "Press 'q' to quit | 's' to save",
               (10, 50), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
    
    # Show frames side by side
    edges_color = cv2.cvtColor(edges, cv2.COLOR_GRAY2BGR)
    combined = np.hstack([debug_frame, edges_color])
    
    cv2.imshow('Card Detection Debug (Camera | Edges)', combined)
    
    key = cv2.waitKey(1) & 0xFF
    if key == ord('q'):
        break
    elif key == ord('s'):
        cv2.imwrite('/tmp/debug_frame.png', frame)
        cv2.imwrite('/tmp/debug_edges.png', edges)
        print("\n✓ Saved frames to /tmp/debug_frame.png and /tmp/debug_edges.png")

cap.release()
cv2.destroyAllWindows()
print("\nDebug session ended")
