"""
ScanBoss AI - VGG16 Search

Search for cards using VGG16 feature vectors.

Usage:
    python search_vgg16.py --image test_card.jpg --game magic --top 5
"""

import numpy as np
from tensorflow.keras.applications.vgg16 import VGG16, preprocess_input
from tensorflow.keras.preprocessing import image
from pathlib import Path
import pickle
import argparse
from scipy.spatial.distance import cosine

SCANBOSS_DIR = Path(__file__).parent
TRAINING_DATA_DIR = SCANBOSS_DIR / "training_data"
MODELS_DIR = SCANBOSS_DIR / "models"


class VGG16Searcher:
    """Search for similar cards using VGG16 features"""
    
    def __init__(self, game: str):
        self.game = game
        
        # Load VGG16
        print("Loading VGG16 model...")
        self.model = VGG16(weights='imagenet', include_top=False)
        
        # Load database
        db_file = MODELS_DIR / f"vgg16_db_{game}.pkl"
        if not db_file.exists():
            raise FileNotFoundError(
                f"Database not found: {db_file}\n"
                f"Run: python build_vgg16_database.py --game {game}"
            )
        
        print(f"Loading database from {db_file}...")
        with open(db_file, 'rb') as f:
            db = pickle.load(f)
        
        self.vectors = db['vectors']
        self.card_ids = db['card_ids']
        
        print(f"✓ Loaded {len(self.card_ids):,} cards\n")
    
    def extract_features(self, img_path: str) -> np.ndarray:
        """Extract VGG16 features from image"""
        img = image.load_img(img_path, target_size=(224, 224))
        img_array = image.img_to_array(img)
        x = preprocess_input(np.expand_dims(img_array.copy(), axis=0))
        features = self.model.predict(x, verbose=0)
        return features.flatten()
    
    def search(self, img_path: str, top_k: int = 5):
        """Find most similar cards"""
        print(f"Searching for: {img_path}")
        
        # Extract features from query image
        query_vector = self.extract_features(img_path)
        
        # Compute cosine similarity with all cards
        similarities = []
        for i, db_vector in enumerate(self.vectors):
            similarity = 1 - cosine(query_vector, db_vector)
            similarities.append((similarity, i))
        
        # Sort by similarity (highest first)
        similarities.sort(reverse=True, key=lambda x: x[0])
        
        # Get top K
        results = []
        for sim, idx in similarities[:top_k]:
            card_id = self.card_ids[idx]
            results.append({
                'card_id': card_id,
                'similarity': sim,
                'set': card_id.split('-')[0],
                'number': card_id.split('-')[1]
            })
        
        return results
    
    def display_results(self, results):
        """Display search results"""
        print(f"\n{'='*60}")
        print("SEARCH RESULTS")
        print(f"{'='*60}\n")
        
        for i, result in enumerate(results, 1):
            print(f"{i}. {result['set']} #{result['number']}")
            print(f"   Similarity: {result['similarity']:.3f} ({result['similarity']*100:.1f}%)")
            print(f"   Card ID: {result['card_id']}")
            
            # Show image path
            img_path = TRAINING_DATA_DIR / self.game / result['card_id'] / "image.jpg"
            print(f"   Image: {img_path}")
            print()
        
        print("="*60)
        
        # Interpretation guide
        print("\nSIMILARITY GUIDE:")
        print("  0.90-1.00 = Exact match!")
        print("  0.80-0.90 = Very likely correct")
        print("  0.70-0.80 = Probably correct")
        print("  0.60-0.70 = Maybe correct")
        print("  <0.60     = Likely wrong")
        print("="*60 + "\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--image', required=True, help='Path to card image')
    parser.add_argument('--game', required=True, choices=['pokemon', 'magic'])
    parser.add_argument('--top', type=int, default=5, help='Number of results')
    args = parser.parse_args()
    
    searcher = VGG16Searcher(args.game)
    results = searcher.search(args.image, top_k=args.top)
    searcher.display_results(results)


if __name__ == '__main__':
    main()
