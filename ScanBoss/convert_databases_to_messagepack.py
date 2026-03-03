"""
Convert VGG16 Pickle Databases to MessagePack for C#

MessagePack is MUCH more efficient than JSON for large numeric arrays.
"""

import pickle
import msgpack
import numpy as np
from pathlib import Path

def convert_database(pickle_path, msgpack_path, game_name):
    """Convert pickle database to MessagePack format"""
    print(f"\n{'='*60}")
    print(f"Converting {game_name} database...")
    print(f"{'='*60}")
    
    try:
        print(f"Loading: {pickle_path}")
        with open(pickle_path, 'rb') as f:
            data = pickle.load(f)
        
        vectors = data['vectors']
        card_ids = data['card_ids']
        
        print(f"✓ Loaded {len(card_ids):,} cards")
        print(f"✓ Vector shape: {vectors.shape}")
        
        print("Packing data...")
        packed_data = {
            'game': game_name,
            'card_count': len(card_ids),
            'vector_dimension': vectors.shape[1],
            'vectors': vectors.tobytes(),
            'card_ids': card_ids
        }
        
        print(f"Saving to: {msgpack_path}")
        with open(msgpack_path, 'wb') as f:
            msgpack.pack(packed_data, f)
        
        pickle_size = Path(pickle_path).stat().st_size / (1024*1024)
        msgpack_size = Path(msgpack_path).stat().st_size / (1024*1024)
        
        print(f"\n✓ CONVERSION COMPLETE!")
        print(f"  Cards: {len(card_ids):,}")
        print(f"  Pickle size: {pickle_size:.1f} MB")
        print(f"  MessagePack size: {msgpack_size:.1f} MB")
        
        return True
        
    except Exception as e:
        print(f"✗ ERROR: {e}")
        return False


def main():
    print("\n" + "="*60)
    print("VGG16 DATABASE CONVERTER")
    print("Pickle → MessagePack for C# ScanBoss")
    print("="*60)
    
    try:
        import msgpack
    except ImportError:
        print("\n⚠️  MessagePack not installed!")
        print("Run: pip install msgpack --break-system-packages")
        return
    
    models_dir = Path("models")
    
    # Convert Magic
    magic_pickle = models_dir / "vgg16_db_magic.pkl"
    magic_msgpack = models_dir / "vgg16_db_magic.msgpack"
    
    if magic_pickle.exists():
        convert_database(magic_pickle, magic_msgpack, "magic")
    
    # Convert FFTCG
    fftcg_pickle = models_dir / "vgg16_db_fftcg.pkl"
    fftcg_msgpack = models_dir / "vgg16_db_fftcg.msgpack"
    
    if fftcg_pickle.exists():
        convert_database(fftcg_pickle, fftcg_msgpack, "fftcg")
    
    print("\n" + "="*60)
    print("DONE! Copy .msgpack files to C# project")
    print("="*60 + "\n")


if __name__ == "__main__":
    main()
