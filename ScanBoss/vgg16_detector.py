"""
VGG16 Card Detector for ScanBoss

Real-time card detection with VGG16 + Scryfall integration
"""

import numpy as np
from tensorflow.keras.applications.vgg16 import VGG16, preprocess_input
from tensorflow.keras.preprocessing import image as keras_image
import pickle
from pathlib import Path
from scipy.spatial.distance import cosine
import requests
import cv2
from PIL import Image
import io


class VGG16Detector:
    """VGG16-based card detector with Scryfall integration"""
    
    def __init__(self, game: str = "magic"):
        self.game = game
        self.models_dir = Path(__file__).parent / "models"
        
        # Load VGG16 model
        print("Loading VGG16 model...")
        self.vgg16_model = VGG16(weights='imagenet', include_top=False)
        
        # Load card database
        db_file = self.models_dir / f"vgg16_db_{game}.pkl"
        if not db_file.exists():
            raise FileNotFoundError(
                f"VGG16 database not found: {db_file}\n"
                f"Run: python3 build_vgg16_database.py --game {game}"
            )
        
        print(f"Loading card database...")
        with open(db_file, 'rb') as f:
            db = pickle.load(f)
        
        self.vectors = db['vectors']
        self.card_ids = db['card_ids']
        
        print(f"✓ Loaded {len(self.card_ids):,} cards")
        
        # Scryfall API cache
        self.card_cache = {}
    
    def extract_features(self, img_array: np.ndarray) -> np.ndarray:
        """Extract VGG16 features from image array (OpenCV/PIL)"""
        
        # Convert BGR to RGB if needed (OpenCV uses BGR)
        if len(img_array.shape) == 3 and img_array.shape[2] == 3:
            img_rgb = cv2.cvtColor(img_array, cv2.COLOR_BGR2RGB)
        else:
            img_rgb = img_array
        
        # Resize to 224x224 for VGG16
        img_resized = cv2.resize(img_rgb, (224, 224))
        
        # Convert to format VGG16 expects
        img_expanded = np.expand_dims(img_resized, axis=0)
        
        # Preprocess
        x = preprocess_input(img_expanded.astype(np.float32))
        
        # Extract features
        features = self.vgg16_model.predict(x, verbose=0)
        
        return features.flatten()
    
    def detect_card(self, img_array: np.ndarray, confidence_threshold: float = 0.60):
        """
        Detect card from image array
        
        Args:
            img_array: Image as numpy array (from OpenCV or PIL)
            confidence_threshold: Minimum confidence to return result
        
        Returns:
            dict with card info or None if confidence too low
        """
        
        # Extract features
        query_vector = self.extract_features(img_array)
        
        # Find most similar card
        best_similarity = -1
        best_idx = -1
        
        for i, db_vector in enumerate(self.vectors):
            similarity = 1 - cosine(query_vector, db_vector)
            if similarity > best_similarity:
                best_similarity = similarity
                best_idx = i
        
        # Check confidence threshold first
        if best_similarity < confidence_threshold:
            return None
        
        # Show result
        print(f"✓ Detected: {self.card_ids[best_idx]} ({best_similarity:.1%})")
        
        # Get card info  
        card_id = self.card_ids[best_idx]
        set_code = card_id.split('-')[0]
        card_number = card_id.split('-')[1]
        
        # Fetch detailed card info from Scryfall
        card_details = self._fetch_card_details(set_code, card_number)
        
        if card_details:
            card_details['confidence'] = best_similarity
            card_details['card_id'] = card_id
            return card_details
        
        # Fallback if Scryfall fails
        return {
            'card_id': card_id,
            'set': set_code,
            'collector_number': card_number,
            'confidence': best_similarity,
            'name': 'Unknown',
            'type_line': 'Unknown'
        }
    
    def _fetch_card_details(self, set_code: str, card_number: str):
        """Fetch card details from Scryfall API"""
        
        cache_key = f"{set_code}-{card_number}"
        
        # Check cache
        if cache_key in self.card_cache:
            return self.card_cache[cache_key]
        
        try:
            # Scryfall API endpoint
            url = f"https://api.scryfall.com/cards/{set_code}/{card_number}"
            
            response = requests.get(url, timeout=5)
            response.raise_for_status()
            
            data = response.json()
            
            # Extract relevant info
            card_info = {
                'name': data.get('name', 'Unknown'),
                'set': set_code,
                'set_name': data.get('set_name', 'Unknown'),
                'collector_number': card_number,
                'type_line': data.get('type_line', 'Unknown'),
                'mana_cost': data.get('mana_cost', ''),
                'rarity': data.get('rarity', 'unknown').capitalize(),
                'image_url': data.get('image_uris', {}).get('normal', ''),
                'prices': {
                    'usd': data.get('prices', {}).get('usd'),
                    'usd_foil': data.get('prices', {}).get('usd_foil'),
                },
                'oracle_text': data.get('oracle_text', ''),
                'power': data.get('power'),
                'toughness': data.get('toughness'),
                'scryfall_uri': data.get('scryfall_uri', '')
            }
            
            # Cache it
            self.card_cache[cache_key] = card_info
            
            return card_info
            
        except Exception as e:
            print(f"Error fetching card details: {e}")
            return None
    
    def detect_from_frame(self, frame: np.ndarray, roi: tuple = None):
        """
        Detect card from camera frame
        
        Args:
            frame: Camera frame (OpenCV format)
            roi: Optional (x, y, w, h) region of interest
        
        Returns:
            Card info dict or None
        """
        
        if roi:
            x, y, w, h = roi
            card_region = frame[y:y+h, x:x+w]
        else:
            card_region = frame
        
        return self.detect_card(card_region)
