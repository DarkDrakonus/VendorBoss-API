"""
Fixed-Region Card Detector

Simple approach: If card is in the guide brackets, just use that region.
Much more reliable than trying to detect edges.
"""

import cv2
import numpy as np


class FixedRegionDetector:
    """Simple detector - just uses the guide region"""
    
    def __init__(self):
        pass
    
    def detect_card_in_frame(self, frame):
        """
        Simple detection: assume card fills the frame
        (frame is already cropped to guide region by caller)
        
        Returns:
            dict with 'detected' (True) and 'card_image' (the frame)
        """
        
        # Simple background check - is there enough contrast?
        # If the image is all one color (no card), it will have low variance
        gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        variance = np.var(gray)
        
        # If variance is too low, probably no card (just background)
        if variance < 100:
            return {'detected': False, 'card_image': None}
        
        # Clean up the image
        # Try to remove background and enhance card
        cleaned = self._clean_card_image(frame)
        
        # Resize to standard card size
        target_width = 500
        target_height = 700
        card_image = cv2.resize(cleaned, (target_width, target_height))
        
        return {
            'detected': True,
            'card_image': card_image
        }
    
    def _clean_card_image(self, frame):
        """
        Clean up the card image
        - Remove slight rotation if any
        - Enhance contrast
        """
        
        # Sharpen the image
        kernel = np.array([[-1,-1,-1],
                          [-1, 9,-1],
                          [-1,-1,-1]])
        sharpened = cv2.filter2D(frame, -1, kernel)
        
        # Enhance contrast
        lab = cv2.cvtColor(sharpened, cv2.COLOR_BGR2LAB)
        l, a, b = cv2.split(lab)
        clahe = cv2.createCLAHE(clipLimit=3.0, tileGridSize=(8,8))
        l = clahe.apply(l)
        enhanced = cv2.merge([l, a, b])
        enhanced = cv2.cvtColor(enhanced, cv2.COLOR_LAB2BGR)
        
        return enhanced
    
    def detect_with_visualization(self, frame):
        """For testing"""
        result = self.detect_card_in_frame(frame)
        
        vis_frame = frame.copy()
        
        if result['detected']:
            cv2.putText(vis_frame, "Card in frame", (10, 30),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        else:
            cv2.putText(vis_frame, "No card", (10, 30),
                       cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
        
        return vis_frame, result
