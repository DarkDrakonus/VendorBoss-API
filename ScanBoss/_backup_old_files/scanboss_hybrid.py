"""
ScanBoss AI - Hybrid Detection System

Phase 1: Uses VGG16 for immediate detection
Phase 2: Collects real scans to build training dataset
Phase 3: Trains custom AI on real-world data

Future capabilities:
- Odd angle detection
- Damage assessment / grading
- Market value prediction
- Counterfeit detection

Usage:
    python scanboss_hybrid.py --scan card.jpg --game magic
"""

import numpy as np
from tensorflow.keras.applications.vgg16 import VGG16, preprocess_input
from tensorflow.keras.preprocessing import image
from pathlib import Path
import pickle
import json
from datetime import datetime
from scipy.spatial.distance import cosine
import shutil
import cv2

SCANBOSS_DIR = Path(__file__).parent
TRAINING_DATA_DIR = SCANBOSS_DIR / "training_data"
MODELS_DIR = SCANBOSS_DIR / "models"
REAL_SCANS_DIR = SCANBOSS_DIR / "real_scans"  # New: Real-world training data
REAL_SCANS_DIR.mkdir(exist_ok=True)


class ScanBossHybrid:
    """Hybrid system: VGG16 now, Custom AI later"""
    
    def __init__(self, game: str):
        self.game = game
        
        # Phase 1: Load VGG16 for immediate detection
        print("Loading VGG16 detector...")
        self.vgg16_model = VGG16(weights='imagenet', include_top=False)
        
        # Load VGG16 database
        db_file = MODELS_DIR / f"vgg16_db_{game}.pkl"
        with open(db_file, 'rb') as f:
            db = pickle.load(f)
        
        self.vectors = db['vectors']
        self.card_ids = db['card_ids']
        
        print(f"✓ Loaded {len(self.card_ids):,} cards")
        
        # Phase 2: Check if custom AI exists
        custom_model_file = MODELS_DIR / f"scanboss_custom_{game}.h5"
        if custom_model_file.exists():
            print("✓ Custom AI model found (using for detection)")
            self.custom_model = self._load_custom_model(custom_model_file)
            self.use_custom = True
        else:
            print("⚡ Using VGG16 (custom AI not trained yet)")
            self.custom_model = None
            self.use_custom = False
        
        # Real scan storage
        self.scans_dir = REAL_SCANS_DIR / game
        self.scans_dir.mkdir(exist_ok=True)
        
        # Scan counter
        self.scan_count = self._get_scan_count()
        
        print(f"✓ Collected {self.scan_count} real scans so far")
        print()
    
    def _load_custom_model(self, model_path):
        """Load custom trained model (Phase 3)"""
        from tensorflow import keras
        return keras.models.load_model(model_path)
    
    def _get_scan_count(self):
        """Count real scans collected"""
        metadata_file = self.scans_dir / "metadata.json"
        if metadata_file.exists():
            with open(metadata_file) as f:
                data = json.load(f)
                return data.get('total_scans', 0)
        return 0
    
    def extract_vgg16_features(self, img_path: str) -> np.ndarray:
        """Extract VGG16 features"""
        img = image.load_img(img_path, target_size=(224, 224))
        img_array = image.img_to_array(img)
        x = preprocess_input(np.expand_dims(img_array.copy(), axis=0))
        features = self.vgg16_model.predict(x, verbose=0)
        return features.flatten()
    
    def detect_card_vgg16(self, img_path: str, top_k: int = 5):
        """Phase 1: VGG16 detection"""
        query_vector = self.extract_vgg16_features(img_path)
        
        # Compute similarity
        similarities = []
        for i, db_vector in enumerate(self.vectors):
            similarity = 1 - cosine(query_vector, db_vector)
            similarities.append((similarity, i))
        
        similarities.sort(reverse=True, key=lambda x: x[0])
        
        # Return top results
        results = []
        for sim, idx in similarities[:top_k]:
            card_id = self.card_ids[idx]
            results.append({
                'card_id': card_id,
                'similarity': sim,
                'confidence': sim,
                'method': 'VGG16'
            })
        
        return results
    
    def detect_card_custom(self, img_path: str):
        """Phase 3: Custom AI detection (future)"""
        # TODO: Implement when custom model is trained
        # This will handle odd angles, damage, etc.
        pass
    
    def detect_card(self, img_path: str, top_k: int = 5):
        """Detect card using best available method"""
        
        print(f"Scanning: {img_path}")
        print("="*60)
        
        if self.use_custom:
            # Phase 3: Use custom AI
            results = self.detect_card_custom(img_path)
        else:
            # Phase 1: Use VGG16
            results = self.detect_card_vgg16(img_path, top_k)
        
        # Display results
        self._display_results(results)
        
        return results
    
    def _display_results(self, results):
        """Display detection results"""
        print("\nDETECTION RESULTS:")
        print("-"*60)
        
        for i, result in enumerate(results, 1):
            card_id = result['card_id']
            set_code = card_id.split('-')[0]
            card_num = card_id.split('-')[1]
            confidence = result['confidence']
            
            print(f"{i}. {set_code} #{card_num}")
            print(f"   Confidence: {confidence:.1%}")
            print(f"   Method: {result['method']}")
            
            # Confidence interpretation
            if confidence > 0.90:
                print(f"   Status: ✓ EXACT MATCH")
            elif confidence > 0.80:
                print(f"   Status: ✓ Very Likely")
            elif confidence > 0.70:
                print(f"   Status: ~ Probably Correct")
            else:
                print(f"   Status: ? Uncertain")
            print()
        
        print("="*60)
    
    def save_confirmed_scan(self, img_path: str, confirmed_card_id: str, metadata: dict = None):
        """Phase 2: Save confirmed scan to training dataset"""
        
        # Create directory for this card
        card_dir = self.scans_dir / confirmed_card_id
        card_dir.mkdir(exist_ok=True)
        
        # Generate unique filename
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        scan_num = len(list(card_dir.glob("*.jpg"))) + 1
        
        filename = f"scan_{scan_num:04d}_{timestamp}.jpg"
        dest_path = card_dir / filename
        
        # Copy scan
        shutil.copy2(img_path, dest_path)
        
        # Save metadata
        meta_file = card_dir / f"{filename.replace('.jpg', '.json')}"
        scan_metadata = {
            'card_id': confirmed_card_id,
            'timestamp': timestamp,
            'original_path': str(img_path),
            'scan_number': scan_num,
            **(metadata or {})
        }
        
        with open(meta_file, 'w') as f:
            json.dump(scan_metadata, f, indent=2)
        
        # Update global counter
        self.scan_count += 1
        self._update_scan_count()
        
        print(f"\n✓ Saved scan #{self.scan_count} to training dataset")
        print(f"  Card: {confirmed_card_id}")
        print(f"  File: {dest_path}")
        
        # Check if ready to train custom AI
        self._check_training_readiness()
    
    def _update_scan_count(self):
        """Update scan counter"""
        metadata_file = self.scans_dir / "metadata.json"
        data = {
            'total_scans': self.scan_count,
            'last_updated': datetime.now().isoformat()
        }
        with open(metadata_file, 'w') as f:
            json.dump(data, f, indent=2)
    
    def _check_training_readiness(self):
        """Check if enough data to train custom AI"""
        
        # Count cards with multiple scans
        cards_with_scans = {}
        for card_dir in self.scans_dir.iterdir():
            if card_dir.is_dir() and card_dir.name != "metadata.json":
                scan_count = len(list(card_dir.glob("*.jpg")))
                if scan_count > 0:
                    cards_with_scans[card_dir.name] = scan_count
        
        total_cards = len(cards_with_scans)
        cards_with_5plus = sum(1 for c in cards_with_scans.values() if c >= 5)
        
        print(f"\n📊 TRAINING DATASET STATUS:")
        print(f"   Total scans: {self.scan_count}")
        print(f"   Unique cards: {total_cards}")
        print(f"   Cards with 5+ scans: {cards_with_5plus}")
        
        # Recommendations
        if cards_with_5plus < 100:
            print(f"\n   Need: {100 - cards_with_5plus} more cards with 5+ scans")
            print(f"   Status: Keep collecting! 🔄")
        elif cards_with_5plus < 1000:
            print(f"\n   Status: READY FOR PILOT TRAINING! 🎯")
            print(f"   Run: python train_custom_ai.py --game {self.game}")
        else:
            print(f"\n   Status: READY FOR FULL TRAINING! 🚀")
            print(f"   Run: python train_custom_ai.py --game {self.game} --full")
        
        print()
    
    def analyze_scan_quality(self, img_path: str):
        """Future: Analyze scan for damage, condition, etc."""
        # TODO: Implement in Phase 3
        # Will assess:
        # - Card condition (Near Mint, Played, Damaged)
        # - Edge wear
        # - Surface scratches
        # - Corner damage
        # - Centering
        pass


def interactive_scan(game: str, img_path: str):
    """Interactive scanning with confirmation"""
    
    detector = ScanBossHybrid(game)
    
    # Detect card
    results = detector.detect_card(img_path, top_k=5)
    
    # Ask for confirmation
    print("\nIs the detection correct?")
    print("1-5: Select correct card from results")
    print("n: None of these are correct")
    print("q: Quit without saving")
    
    choice = input("\nYour choice: ").strip().lower()
    
    if choice in ['1', '2', '3', '4', '5']:
        idx = int(choice) - 1
        if idx < len(results):
            confirmed_card = results[idx]['card_id']
            
            # Optional: Ask about condition
            print("\nCard condition (optional):")
            print("1: Near Mint")
            print("2: Lightly Played")
            print("3: Moderately Played")
            print("4: Heavily Played")
            print("5: Damaged")
            print("(Press Enter to skip)")
            
            condition_choice = input("Condition: ").strip()
            conditions = {
                '1': 'Near Mint',
                '2': 'Lightly Played',
                '3': 'Moderately Played',
                '4': 'Heavily Played',
                '5': 'Damaged'
            }
            
            metadata = {
                'condition': conditions.get(condition_choice, 'Unknown'),
                'confidence': results[idx]['confidence']
            }
            
            # Save to training dataset
            detector.save_confirmed_scan(img_path, confirmed_card, metadata)
            
            print("\n✓ Scan saved to training dataset!")
            print("  Your contribution helps improve ScanBoss AI!")
    
    elif choice == 'n':
        print("\n⚠ Detection failed. This scan won't be saved.")
        print("  Try scanning again with better lighting/angle.")
    
    elif choice == 'q':
        print("\n✗ Cancelled")


def main():
    import argparse
    
    parser = argparse.ArgumentParser()
    parser.add_argument('--scan', required=True, help='Path to card image')
    parser.add_argument('--game', required=True, choices=['pokemon', 'magic'])
    parser.add_argument('--auto', action='store_true', help='Auto-detect without confirmation')
    args = parser.parse_args()
    
    if args.auto:
        detector = ScanBossHybrid(args.game)
        detector.detect_card(args.scan)
    else:
        interactive_scan(args.game, args.scan)


if __name__ == '__main__':
    main()
