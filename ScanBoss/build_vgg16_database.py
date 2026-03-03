"""
ScanBoss AI - VGG16 Database Builder

Builds VGG16 feature database from card images.
Supports Magic, FFTCG, Pokemon, and custom directories.

Usage:
    python build_vgg16_database.py --game magic
    python build_vgg16_database.py --game fftcg --image-dir Scans/eg/
"""

import numpy as np
from tensorflow.keras.applications.vgg16 import VGG16, preprocess_input
from tensorflow.keras.preprocessing import image
from pathlib import Path
import json
import pickle
from tqdm import tqdm
import argparse

SCANBOSS_DIR = Path(__file__).parent
TRAINING_DATA_DIR = SCANBOSS_DIR / "training_data"
MODELS_DIR = SCANBOSS_DIR / "models"
MODELS_DIR.mkdir(exist_ok=True)

# VGG16 produces 25,088-dimensional vectors (7x7x512)
VECTOR_DIM = 25088


class VGG16DatabaseBuilder:
    """Build searchable database of card feature vectors"""
    
    def __init__(self, game: str, image_dir: str = None):
        self.game = game
        
        # Allow custom image directory
        if image_dir:
            self.data_dir = Path(image_dir)
        else:
            self.data_dir = TRAINING_DATA_DIR / game
        
        if not self.data_dir.exists():
            raise ValueError(f"Image directory not found: {self.data_dir}")
        
        print(f"\n{'='*60}")
        print(f"SCANBOSS VGG16 DATABASE - {game.upper()}")
        print(f"{'='*60}\n")
        print(f"Image directory: {self.data_dir}")
        
        # Load VGG16 (without classification layers)
        print("\nLoading VGG16 model...")
        self.model = VGG16(weights='imagenet', include_top=False)
        print("✓ VGG16 loaded\n")
        
        self.vectors = []
        self.card_ids = []
    
    def extract_features(self, img_path: Path) -> np.ndarray:
        """Extract VGG16 features from image"""
        # Load and resize to 224x224 (VGG16 requirement)
        img = image.load_img(img_path, target_size=(224, 224))
        img_array = image.img_to_array(img)
        
        # Preprocess for VGG16
        x = preprocess_input(np.expand_dims(img_array.copy(), axis=0))
        
        # Extract features
        features = self.model.predict(x, verbose=0)
        
        # Flatten to 1D vector
        return features.flatten()
    
    def build_database(self):
        """Extract features from all cards"""
        print("Scanning for card images...\n")
        
        # Collect image files
        image_files = []
        
        # Check if this is a flat directory (FFTCG style) or nested (Magic style)
        sample_files = list(self.data_dir.glob("*.jpg"))[:5]
        
        if sample_files:
            # Flat directory - all images in one folder
            print(f"Detected flat directory structure")
            image_files = list(self.data_dir.glob("*.jpg"))
            # Card ID is filename without extension
            card_ids = [f.stem for f in image_files]
        else:
            # Nested directory - subdirectories with image.jpg
            print(f"Detected nested directory structure")
            card_dirs = [d for d in self.data_dir.iterdir() if d.is_dir()]
            for card_dir in card_dirs:
                img_path = card_dir / "image.jpg"
                if img_path.exists():
                    image_files.append(img_path)
                    card_ids.append(card_dir.name)
        
        if not image_files:
            raise ValueError(f"No card images found in {self.data_dir}")
        
        print(f"Found {len(image_files):,} card images\n")
        print("Extracting features...")
        print("This may take a while (1-2 hours for large datasets)...\n")
        
        # Extract features
        for img_path, card_id in tqdm(zip(image_files, card_ids), 
                                       total=len(image_files),
                                       desc="Processing"):
            try:
                vector = self.extract_features(img_path)
                self.vectors.append(vector)
                self.card_ids.append(card_id)
            except Exception as e:
                print(f"\nError processing {card_id}: {e}")
                continue
        
        # Convert to numpy array for fast search
        self.vectors = np.array(self.vectors)
        
        print(f"\n✓ Extracted features from {len(self.card_ids):,} cards")
        print(f"✓ Vector shape: {self.vectors.shape}")
    
    def save_database(self):
        """Save vectors and IDs to disk"""
        db_file = MODELS_DIR / f"vgg16_db_{self.game}.pkl"
        
        database = {
            'vectors': self.vectors,
            'card_ids': self.card_ids,
            'vector_dim': VECTOR_DIM
        }
        
        print(f"\nSaving database to {db_file}...")
        with open(db_file, 'wb') as f:
            pickle.dump(database, f)
        
        print(f"✓ Database saved ({db_file.stat().st_size / 1024 / 1024:.1f} MB)")
        
        # Save metadata
        meta_file = MODELS_DIR / f"vgg16_db_{self.game}_meta.json"
        metadata = {
            'game': self.game,
            'num_cards': len(self.card_ids),
            'vector_dim': VECTOR_DIM,
            'card_ids_sample': self.card_ids[:10]  # First 10 for reference
        }
        
        with open(meta_file, 'w') as f:
            json.dump(metadata, f, indent=2)
        
        print(f"✓ Metadata saved\n")
    
    def build(self):
        """Full build process"""
        self.build_database()
        self.save_database()
        
        print("="*60)
        print("DATABASE BUILD COMPLETE!")
        print("="*60)
        print(f"\nDatabase: models/vgg16_db_{self.game}.pkl")
        print(f"Cards:    {len(self.card_ids):,}")
        print("="*60 + "\n")


def main():
    parser = argparse.ArgumentParser(description="Build VGG16 feature database")
    parser.add_argument('--game', required=True, 
                       choices=['pokemon', 'magic', 'fftcg'],
                       help='Card game')
    parser.add_argument('--image-dir', 
                       help='Custom image directory (default: training_data/<game>/)')
    
    args = parser.parse_args()
    
    builder = VGG16DatabaseBuilder(args.game, args.image_dir)
    builder.build()


if __name__ == '__main__':
    main()
