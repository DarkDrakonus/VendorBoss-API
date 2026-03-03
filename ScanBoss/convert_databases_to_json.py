"""
Convert VGG16 Pickle Databases to JSON for C#

Converts:
- vgg16_db_magic.pkl → vgg16_db_magic.json
- vgg16_db_fftcg.pkl → vgg16_db_fftcg.json

These JSON files can be loaded by the C# application.
"""

import pickle
import json
import numpy as np
from pathlib import Path

def convert_database(pickle_path, json_path, game_name):
    """Convert pickle database to JSON format"""
    print(f"\n{'='*60}")
    print(f"Converting {game_name} database...")
    print(f"{'='*60}")
    
    try:
        # Load pickle file
        print(f"Loading: {pickle_path}")
        with open(pickle_path, 'rb') as f:
            data = pickle.load(f)
        
        # Extract data
        vectors = data['vectors']  # numpy array of feature vectors
        card_ids = data['card_ids']  # list of card IDs
        
        print(f"✓ Loaded {len(card_ids):,} cards")
        print(f"✓ Vector shape: {vectors.shape}")
        
        # Convert numpy arrays to lists (JSON serializable)
        print("Converting numpy arrays to lists...")
        vectors_list = vectors.tolist()
        card_ids_list = list(card_ids)
        
        # Create JSON structure
        json_data = {
            "game": game_name,
            "card_count": len(card_ids_list),
            "vector_dimension": vectors.shape[1],
            "vectors": vectors_list,
            "card_ids": card_ids_list
        }
        
        # Save to JSON
        print(f"Saving to: {json_path}")
        with open(json_path, 'w') as f:
            json.dump(json_data, f)
        
        # Get file sizes
        pickle_size = Path(pickle_path).stat().st_size / (1024*1024)  # MB
        json_size = Path(json_path).stat().st_size / (1024*1024)  # MB
        
        print(f"\n✓ CONVERSION COMPLETE!")
        print(f"  Cards: {len(card_ids_list):,}")
        print(f"  Pickle size: {pickle_size:.1f} MB")
        print(f"  JSON size: {json_size:.1f} MB")
        
        return True
        
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False


def main():
    print("\n" + "="*60)
    print("VGG16 DATABASE CONVERTER")
    print("Pickle → JSON for C# ScanBoss")
    print("="*60)
    
    models_dir = Path("models")
    
    # Convert Magic database
    magic_pickle = models_dir / "vgg16_db_magic.pkl"
    magic_json = models_dir / "vgg16_db_magic.json"
    
    if magic_pickle.exists():
        convert_database(magic_pickle, magic_json, "magic")
    else:
        print(f"\n⚠️  Magic database not found: {magic_pickle}")
    
    # Convert FFTCG database
    fftcg_pickle = models_dir / "vgg16_db_fftcg.pkl"
    fftcg_json = models_dir / "vgg16_db_fftcg.json"
    
    if fftcg_pickle.exists():
        convert_database(fftcg_pickle, fftcg_json, "fftcg")
    else:
        print(f"\n⚠️  FFTCG database not found: {fftcg_pickle}")
    
    print("\n" + "="*60)
    print("CONVERSION COMPLETE!")
    print("="*60)
    print("\nNext steps:")
    print("1. Copy JSON files to C# project:")
    print(f"   cp models/*.json ../ScanBossCSharp/ScanBoss/Models/")
    print("2. Run C# app - databases will load!")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()
