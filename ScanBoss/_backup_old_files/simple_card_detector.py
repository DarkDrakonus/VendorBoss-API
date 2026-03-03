"""
Simple Card Detector - OpenCV Edge Detection

Based on proven techniques from working card scanners.
Uses edge detection + contour finding to locate cards.
"""

import cv2
import numpy as np


class SimpleCardDetector:
    """Simple, reliable card detector using edge detection"""
    
    def __init__(self):
        # Card should fill most of the focused region
        # If we're only looking at guide area, card should be 30-95% of that area
        self.min_card_area = 30000   # Minimum area for card (pixels) - lowered for focused region
        self.max_card_area = 2000000  # Maximum area
    
    def detect_card_in_frame(self, frame):
        """
        Detect card in camera frame using edge detection
        
        Returns:
            dict with 'detected' (bool) and 'card_image' (cropped card)
        """
        
        # Convert to grayscale
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        # Heavy blur to ignore internal card features (text boxes, etc)
        blurred = cv2.GaussianBlur(gray, (11, 11), 0)
        
        # Adaptive threshold to handle varying lighting
        thresh = cv2.adaptiveThreshold(blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C,
                                       cv2.THRESH_BINARY, 11, 2)
        
        # Invert if needed (card should be white/bright)
        if np.mean(thresh) < 127:
            thresh = cv2.bitwise_not(thresh)
        
        # Morphological operations to close gaps
        kernel = np.ones((5,5), np.uint8)
        thresh = cv2.morphologyEx(thresh, cv2.MORPH_CLOSE, kernel)
        
        # Edge detection on cleaned image
        edges = cv2.Canny(thresh, 50, 150)
        
        # Find contours
        contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        if not contours:
            return {'detected': False, 'card_image': None}
        
        # Find THE LARGEST contour (outer card edge)
        # Sort by area, take the biggest
        contours_sorted = sorted(contours, key=cv2.contourArea, reverse=True)
        
        best_contour = None
        
        # Try top 5 largest contours
        for contour in contours_sorted[:5]:
            area = cv2.contourArea(contour)
            
            print(f"Checking contour: area={area}")
            
            # Filter by size
            if area < self.min_card_area or area > self.max_card_area:
                print(f"  Skipped: area out of range ({self.min_card_area}-{self.max_card_area})")
                continue
            
            # Approximate contour to polygon
            perimeter = cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, 0.02 * perimeter, True)
            
            print(f"  Sides: {len(approx)}")
            
            # Look for 4-sided shapes (rectangles)
            if len(approx) == 4:
                # Check aspect ratio (cards are ~1.4:1)
                rect = cv2.minAreaRect(contour)
                width, height = rect[1]
                if width == 0 or height == 0:
                    continue
                
                aspect_ratio = max(width, height) / min(width, height)
                print(f"  Aspect ratio: {aspect_ratio:.2f}")
                
                # Playing cards are roughly 2.5" x 3.5" = 1.4:1
                # Accept 1.1 to 2.0 to be very flexible
                if 1.1 <= aspect_ratio <= 2.0:
                    best_contour = approx
                    print(f"  ✓ FOUND CARD! Area={area}")
                    break
                else:
                    print(f"  Skipped: aspect ratio not card-like")
            else:
                print(f"  Skipped: not 4-sided")
        
        if best_contour is None:
            return {'detected': False, 'card_image': None}
        
        # Extract and warp card to rectangle
        try:
            card_image = self._warp_card(frame, best_contour)
            return {
                'detected': True,
                'card_image': card_image
            }
        except Exception as e:
            print(f"Error warping card: {e}")
            return {'detected': False, 'card_image': None}
    
    def _warp_card(self, frame, contour):
        """Warp card to flat rectangle"""
        
        # Get the 4 corners
        points = contour.reshape(4, 2).astype(np.float32)
        
        # Order points: top-left, top-right, bottom-right, bottom-left
        rect = self._order_points(points)
        
        # Calculate dimensions
        width_top = np.linalg.norm(rect[1] - rect[0])
        width_bottom = np.linalg.norm(rect[2] - rect[3])
        width = int(max(width_top, width_bottom))
        
        height_left = np.linalg.norm(rect[3] - rect[0])
        height_right = np.linalg.norm(rect[2] - rect[1])
        height = int(max(height_left, height_right))
        
        # Destination points
        dst = np.array([
            [0, 0],
            [width - 1, 0],
            [width - 1, height - 1],
            [0, height - 1]
        ], dtype=np.float32)
        
        # Perspective transform
        M = cv2.getPerspectiveTransform(rect, dst)
        warped = cv2.warpPerspective(frame, M, (width, height))
        
        # Resize to consistent size for VGG16
        # Standard card aspect ratio: 2.5" x 3.5" ≈ 5:7
        target_width = 500
        target_height = 700
        warped = cv2.resize(warped, (target_width, target_height))
        
        # Ensure card is portrait orientation
        h, w = warped.shape[:2]
        if w > h:
            warped = cv2.rotate(warped, cv2.ROTATE_90_CLOCKWISE)
        
        return warped
    
    def _order_points(self, pts):
        """Order points: top-left, top-right, bottom-right, bottom-left"""
        
        # Sort by y coordinate
        y_sorted = pts[np.argsort(pts[:, 1])]
        
        # Top 2 points
        top = y_sorted[:2]
        top = top[np.argsort(top[:, 0])]  # Sort by x
        
        # Bottom 2 points
        bottom = y_sorted[2:]
        bottom = bottom[np.argsort(bottom[:, 0])]  # Sort by x
        
        return np.array([
            top[0],      # top-left
            top[1],      # top-right
            bottom[1],   # bottom-right
            bottom[0]    # bottom-left
        ], dtype=np.float32)
    
    def detect_with_visualization(self, frame):
        """
        Detect card and return visualization
        Useful for debugging
        """
        
        result = self.detect_card_in_frame(frame)
        
        # Draw visualization
        vis_frame = frame.copy()
        
        if result['detected']:
            # Convert to grayscale for edge detection
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            blurred = cv2.GaussianBlur(gray, (5, 5), 0)
            edges = cv2.Canny(blurred, 50, 150)
            contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            # Draw all contours
            cv2.drawContours(vis_frame, contours, -1, (0, 255, 0), 2)
            
            # Add text
            cv2.putText(vis_frame, "Card Detected!", (10, 30),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        else:
            cv2.putText(vis_frame, "No Card", (10, 30),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
        
        return vis_frame, result
