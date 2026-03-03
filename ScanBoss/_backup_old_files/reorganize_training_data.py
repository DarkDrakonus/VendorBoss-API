"""
Reorganize training data for TensorFlow

Current: training_data/magic/neo/123.jpg
Needed:  training_data/magic/neo-123/image.jpg
"""

from pathlib import Path
import shutil

TRAINING_DATA_DIR = Path(__file__).parent / "training_data"

def reorganize_game(game: str):
    game_dir = TRAINING_DATA_DIR / game
    if not game_dir.exists():
        print(f"Skipping {game} - not found")
        return
    
    print(f"\nReorganizing {game}...")
    
    # Create temp directory
    temp_dir = TRAINING_DATA_DIR / f"{game}_organized"
    temp_dir.mkdir(exist_ok=True)
    
    card_count = 0
    
    # Process each set
    for set_dir in game_dir.iterdir():
        if not set_dir.is_dir():
            continue
        
        set_code = set_dir.name
        print(f"  Processing {set_code}...")
        
        # Process each card image
        for card_file in set_dir.glob("*.jpg"):
            card_number = card_file.stem  # filename without extension
            
            # Create unique directory for this card
            card_class = f"{set_code}-{card_number}"
            card_dir = temp_dir / card_class
            card_dir.mkdir(exist_ok=True)
            
            # Move image to new location
            shutil.copy2(card_file, card_dir / "image.jpg")
            card_count += 1
    
    print(f"  ✓ Reorganized {card_count:,} cards")
    
    # Backup old structure
    backup_dir = TRAINING_DATA_DIR / f"{game}_original"
    if backup_dir.exists():
        shutil.rmtree(backup_dir)
    
    game_dir.rename(backup_dir)
    temp_dir.rename(game_dir)
    
    print(f"  ✓ Old structure backed up to {backup_dir.name}")
    print(f"  ✓ Ready for training!")

if __name__ == '__main__':
    print("="*60)
    print("REORGANIZING TRAINING DATA FOR TENSORFLOW")
    print("="*60)
    
    reorganize_game('magic')
    reorganize_game('pokemon')
    
    print("\n" + "="*60)
    print("DONE! Run training script now.")
    print("="*60 + "\n")
