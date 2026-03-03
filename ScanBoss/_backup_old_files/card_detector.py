import cv2
import numpy as np
import hashlib
from typing import Dict, List, Tuple, Optional

class CardDetector:
    """
    VendorBoss 2.0 CardDetector - 14-Component Fingerprint System
    Compatible with VendorBoss mobile apps and API
    """
    
    def __init__(self):
        self.detection_width = 300
        self.detection_height = 420
        
        # Detection stability tracking
        self.detection_frames = 0
        self.required_frames = 5  # Card must be detected for 5 consecutive frames
        
    def detect_card_in_frame(self, frame: np.ndarray) -> Optional[Dict]:
        """Detect card in camera frame and generate 14-component fingerprint"""
        try:
            # Convert to grayscale for edge detection
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            
            # Apply Gaussian blur
            blurred = cv2.GaussianBlur(gray, (5, 5), 0)
            
            # Edge detection - more sensitive thresholds (30, 100 instead of 50, 150)
            edges = cv2.Canny(blurred, 30, 100)
            
            # Find contours
            contours, _ = cv2.findContours(edges, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            # Find largest rectangular contour (potential card)
            card_contour = self._find_card_contour(contours)
            
            if card_contour is not None:
                # Extract card region
                card_region = self._extract_card_region(frame, card_contour)
                
                if card_region is not None:
                    # Generate VendorBoss 2.0 14-component fingerprint
                    fingerprint_data = self._generate_14_component_fingerprint(card_region)
                    
                    return {
                        'detected': True,
                        'fingerprint_data': fingerprint_data,
                        'contour': card_contour.tolist(),
                        'region': card_region
                    }
            
            return {'detected': False}
            
        except Exception as e:
            print(f"Error in card detection: {e}")
            return {'detected': False}
    
    def detect_and_draw(self, frame: np.ndarray) -> Dict:
        """Detect card and draw detection zone (for UI display)"""
        h, w = frame.shape[:2]
        
        # Detection zone (center of frame) - SMALLER, landscape for desktop webcam
        # Use 50% of width and 50% of height, max 600x400 to ensure it fits
        zone_w = min(int(w * 0.5), 600)
        zone_h = min(int(h * 0.5), 400)
        x1 = (w - zone_w) // 2
        y1 = (h - zone_h) // 2
        x2 = x1 + zone_w
        y2 = y1 + zone_h
        
        # Try to detect card
        detection = self.detect_card_in_frame(frame)
        
        # Update detection stability counter
        if detection.get('detected'):
            self.detection_frames += 1
        else:
            self.detection_frames = 0
        
        # Only consider "detected" if stable for required frames
        is_stable = self.detection_frames >= self.required_frames
        
        if is_stable:
            # Card detected and STABLE - draw GREEN detection zone
            cv2.rectangle(frame, (x1, y1), (x2, y2), (0, 255, 0), 3)
            
            # Draw detected card contour (also green)
            contour = np.array(detection['contour'], dtype=np.int32)
            cv2.drawContours(frame, [contour], -1, (0, 255, 0), 2)
            
            # Add "CARD DETECTED" text
            cv2.putText(frame, "CARD DETECTED", (x1, y1 - 10),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 255, 0), 2)
            
            return {
                'frame': frame,
                'detected': True,
                'region': detection['region'],
                'fingerprint_data': detection['fingerprint_data']
            }
        else:
            # No stable card - draw RED or YELLOW detection zone
            if self.detection_frames > 0:
                # Detecting but not stable yet - YELLOW
                color = (0, 165, 255)  # Orange/yellow
                text = f"HOLD STEADY... ({self.detection_frames}/{self.required_frames})"
            else:
                # No detection - RED
                color = (0, 0, 255)
                text = "POSITION CARD IN ZONE"
            
            cv2.rectangle(frame, (x1, y1), (x2, y2), color, 2)
            cv2.putText(frame, text, (x1 + 10, y1 - 10),
                       cv2.FONT_HERSHEY_SIMPLEX, 0.6, color, 2)
        
        return {'frame': frame, 'detected': False}
    
    def _find_card_contour(self, contours: List) -> Optional[np.ndarray]:
        """Find the contour that best represents a card"""
        for contour in sorted(contours, key=cv2.contourArea, reverse=True):
            # Approximate contour to polygon
            epsilon = 0.02 * cv2.arcLength(contour, True)
            approx = cv2.approxPolyDP(contour, epsilon, True)
            
            # Check if it's roughly rectangular (4-8 corners, relaxed from exactly 4)
            if 4 <= len(approx) <= 8:
                area = cv2.contourArea(contour)
                # Reduced minimum area from 10000 to 5000 for better detection
                if area > 5000:
                    return approx
        
        return None
    
    def _extract_card_region(self, frame: np.ndarray, contour: np.ndarray) -> Optional[np.ndarray]:
        """Extract and normalize card region"""
        try:
            # Get bounding rectangle
            x, y, w, h = cv2.boundingRect(contour)
            
            # Extract region with some padding
            padding = 10
            x1 = max(0, x - padding)
            y1 = max(0, y - padding)
            x2 = min(frame.shape[1], x + w + padding)
            y2 = min(frame.shape[0], y + h + padding)
            
            card_region = frame[y1:y2, x1:x2]
            
            # Resize to standard detection size
            resized = cv2.resize(card_region, (self.detection_width, self.detection_height))
            
            return resized
            
        except Exception as e:
            print(f"Error extracting card region: {e}")
            return None
    
    def _clamp(self, value: float) -> int:
        """Clamp value to 0-255 range"""
        return max(0, min(255, int(value)))
    
    def _generate_14_component_fingerprint(self, card_region: np.ndarray) -> Dict:
        """
        Generate VendorBoss 2.0 compatible 14-component fingerprint
        
        Components:
        1. border - Edge density around card perimeter
        2. name_region - Top 20% of card (where name appears)
        3. color_zones - Dominant colors in 5 strategic zones
        4. texture - Edge pattern analysis
        5. layout - Structural features
        6-14. quadrant_X_Y - 3x3 grid analysis (9 quadrants)
        
        Returns:
        {
            'fingerprint_hash': '64-char SHA-256',
            'components': {
                'border': '16-char MD5',
                'name_region': '16-char MD5',
                ...
            },
            'raw_components': {...}  # For debugging
        }
        """
        try:
            components = {}
            raw_components = {}
            
            # 1. BORDER - Edge density around perimeter
            border_features = self._extract_border_features(card_region)
            raw_components['border'] = border_features
            components['border'] = hashlib.md5(bytes(border_features)).hexdigest()[:16]
            
            # 2. NAME REGION - Top 20% of card
            h = card_region.shape[0]
            name_region = card_region[0:int(h*0.2), :]
            name_features = self._extract_region_features(name_region)
            raw_components['name_region'] = name_features
            components['name_region'] = hashlib.md5(bytes(name_features)).hexdigest()[:16]
            
            # 3. COLOR ZONES - Dominant colors in 5 zones
            color_features = self._extract_color_zones(card_region)
            raw_components['color_zones'] = color_features
            components['color_zones'] = hashlib.md5(bytes(color_features)).hexdigest()[:16]
            
            # 4. TEXTURE - Edge patterns
            texture_features = self._extract_texture(card_region)
            raw_components['texture'] = texture_features
            components['texture'] = hashlib.md5(bytes(texture_features)).hexdigest()[:16]
            
            # 5. LAYOUT - Structural features
            layout_features = self._extract_layout(card_region)
            raw_components['layout'] = layout_features
            components['layout'] = hashlib.md5(bytes(layout_features)).hexdigest()[:16]
            
            # 6-14. 3x3 GRID QUADRANTS
            h, w = card_region.shape[:2]
            quadrant_raw = {}
            for row in range(3):
                for col in range(3):
                    y1 = int(h * row / 3)
                    y2 = int(h * (row + 1) / 3)
                    x1 = int(w * col / 3)
                    x2 = int(w * (col + 1) / 3)
                    
                    quadrant = card_region[y1:y2, x1:x2]
                    quad_features = self._extract_region_features(quadrant)
                    
                    key = f'quadrant_{row}_{col}'
                    quadrant_raw[key] = quad_features
                    components[key] = hashlib.md5(bytes(quad_features)).hexdigest()[:16]
            
            raw_components['quadrants'] = quadrant_raw
            
            # Generate final fingerprint hash (SHA-256 of all components)
            all_components = ''.join([components[k] for k in sorted(components.keys())])
            fingerprint_hash = hashlib.sha256(all_components.encode()).hexdigest()
            
            return {
                'fingerprint_hash': fingerprint_hash,
                'components': components,
                'raw_components': raw_components
            }
            
        except Exception as e:
            print(f"Error generating fingerprint: {e}")
            import traceback
            traceback.print_exc()
            return None
    
    def _extract_border_features(self, card_region: np.ndarray) -> List[int]:
        """Extract edge density around card perimeter"""
        gray = cv2.cvtColor(card_region, cv2.COLOR_BGR2GRAY)
        edges = cv2.Canny(gray, 50, 150)
        
        h, w = edges.shape
        border_width = 20  # pixels
        
        features = []
        
        # Top border
        top = edges[0:border_width, :]
        val = np.sum(top) / max(1, border_width * w * 255) * 255
        features.append(self._clamp(val))
        
        # Bottom border
        bottom = edges[h-border_width:h, :]
        val = np.sum(bottom) / max(1, border_width * w * 255) * 255
        features.append(self._clamp(val))
        
        # Left border
        left = edges[:, 0:border_width]
        val = np.sum(left) / max(1, h * border_width * 255) * 255
        features.append(self._clamp(val))
        
        # Right border
        right = edges[:, w-border_width:w]
        val = np.sum(right) / max(1, h * border_width * 255) * 255
        features.append(self._clamp(val))
        
        return features
    
    def _extract_region_features(self, region: np.ndarray) -> List[int]:
        """Extract features from a region (edges, corners, color histogram)"""
        features = []
        
        # Convert to grayscale
        gray = cv2.cvtColor(region, cv2.COLOR_BGR2GRAY)
        
        # Edge density
        edges = cv2.Canny(gray, 50, 150)
        edge_density = np.sum(edges) / max(1, edges.shape[0] * edges.shape[1] * 255.0)
        features.append(self._clamp(edge_density * 255))
        
        # Corner count
        corners = cv2.goodFeaturesToTrack(gray, maxCorners=50, qualityLevel=0.01, minDistance=10)
        corner_count = len(corners) if corners is not None else 0
        features.append(self._clamp(corner_count))
        
        # Color histogram (3 channels, 4 bins each = 12 values)
        for channel in range(3):
            hist = cv2.calcHist([region], [channel], None, [4], [0, 256])
            max_hist = hist.max()
            scale = 255.0 / max_hist if max_hist > 0 else 1.0
            features.extend([self._clamp(x[0] * scale) for x in hist])
        
        return features
    
    def _extract_color_zones(self, card_region: np.ndarray) -> List[int]:
        """Extract dominant colors from 5 strategic zones"""
        h, w = card_region.shape[:2]
        features = []
        
        # Define 5 zones: center, 4 corners
        zones = [
            (int(h*0.4), int(h*0.6), int(w*0.4), int(w*0.6)),  # Center
            (0, int(h*0.3), 0, int(w*0.3)),                     # Top-left
            (0, int(h*0.3), int(w*0.7), w),                     # Top-right
            (int(h*0.7), h, 0, int(w*0.3)),                     # Bottom-left
            (int(h*0.7), h, int(w*0.7), w),                     # Bottom-right
        ]
        
        for y1, y2, x1, x2 in zones:
            zone = card_region[y1:y2, x1:x2]
            
            # Get average color (BGR)
            avg_color = np.mean(zone, axis=(0, 1))
            features.extend([self._clamp(c) for c in avg_color])
        
        return features
    
    def _extract_texture(self, card_region: np.ndarray) -> List[int]:
        """Extract texture features using edge patterns"""
        gray = cv2.cvtColor(card_region, cv2.COLOR_BGR2GRAY)
        
        # Sobel gradients
        sobelx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
        sobely = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
        
        # Gradient magnitude
        magnitude = np.sqrt(sobelx**2 + sobely**2)
        
        # Divide into 4 quadrants and get average magnitude
        h, w = magnitude.shape
        features = []
        
        for row in range(2):
            for col in range(2):
                y1 = int(h * row / 2)
                y2 = int(h * (row + 1) / 2)
                x1 = int(w * col / 2)
                x2 = int(w * (col + 1) / 2)
                
                quad_mag = magnitude[y1:y2, x1:x2]
                avg_mag = np.mean(quad_mag)
                features.append(self._clamp(avg_mag))
        
        return features
    
    def _extract_layout(self, card_region: np.ndarray) -> List[int]:
        """Extract layout/structural features"""
        gray = cv2.cvtColor(card_region, cv2.COLOR_BGR2GRAY)
        
        features = []
        
        # Horizontal projection (sum each row)
        h_projection = np.sum(gray, axis=1)
        # Downsample to 8 values
        h_bins = np.array_split(h_projection, 8)
        for b in h_bins:
            avg = np.mean(b) if len(b) > 0 else 0
            # Normalize to 0-255 range (gray values are already 0-255)
            features.append(self._clamp(avg / 255.0 * 255.0))
        
        # Vertical projection (sum each column)
        v_projection = np.sum(gray, axis=0)
        # Downsample to 8 values
        v_bins = np.array_split(v_projection, 8)
        for b in v_bins:
            avg = np.mean(b) if len(b) > 0 else 0
            # Normalize to 0-255 range
            features.append(self._clamp(avg / 255.0 * 255.0))
        
        return features
