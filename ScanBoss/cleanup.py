"""
ScanBoss Cleanup Script
Moves old/broken files to backup directory
"""

import os
import shutil
from pathlib import Path

SCANBOSS_DIR = Path(__file__).parent
BACKUP_DIR = SCANBOSS_DIR / "_backup_old_files"

# Files to move to backup
OLD_FILES = [
    # Old/broken detection
    "card_detector.py",
    "simple_card_detector.py",
    
    # Failed training approaches
    "train_scanboss_ai.py",
    "train_with_roi.py",
    "define_roi.py",
    "reorganize_training_data.py",
    
    # Old app versions
    "scanboss_hybrid.py",
    "scanboss_qt.py",
    "scanboss_fleet.py",
    "main.py",
    
    # Test scripts
    "test_card_detection.py",
    "test_simple_detector.py",
    "test_fixed_detector.py",
    "test_camera.py",
    "test_end_to_end.py",
    "test_fingerprints.py",
    "test_fuzzy_matching.py",
    "test_fuzzy_quick.py",
    "test_fuzzy_simple.py",
    "test_matching_accuracy.py",
    "test_performance.py",
    "test_public_api.py",
    "simple_match_test.py",
    "debug_card_detection_live.py",
    
    # Unused features
    "learning_engine.py",
    "learning_model.json",
    "local_cache.py",
    "local_cache_old.py",
    "visualize_fingerprints.py",
    "fingerprint_test_results.json",
    
    # Standalone tools
    "search_vgg16.py",
    "patch_camera.py",
    "comprehensive_fix.py",
    "update_requirements.py",
    "workers.py",
    
    # Old API files
    "admin_dashboard.py",
    "align_with_api.py",
    "api_main_example.py",
    "api_public_endpoints.py",
    "api_endpoints.py",
]

def main():
    print("=" * 60)
    print("SCANBOSS CLEANUP")
    print("=" * 60)
    print()
    
    # Create backup directory
    BACKUP_DIR.mkdir(exist_ok=True)
    print(f"✓ Created backup directory: {BACKUP_DIR}")
    print()
    
    # Move old files
    moved_count = 0
    for filename in OLD_FILES:
        filepath = SCANBOSS_DIR / filename
        if filepath.exists():
            dest = BACKUP_DIR / filename
            shutil.move(str(filepath), str(dest))
            print(f"  ✓ {filename}")
            moved_count += 1
    
    print()
    print(f"Moved {moved_count} old files to backup")
    print()
    
    # Delete debug images
    debug_images = list(SCANBOSS_DIR.glob("debug_*.jpg"))
    test_images = list(SCANBOSS_DIR.glob("test_detected_*.jpg"))
    
    deleted_count = 0
    for img in debug_images + test_images:
        img.unlink()
        deleted_count += 1
    
    if deleted_count > 0:
        print(f"✓ Deleted {deleted_count} debug/test images")
        print()
    
    print("=" * 60)
    print("CLEANUP COMPLETE")
    print("=" * 60)
    print()
    print("KEPT (essential files):")
    print("  ✓ scanboss_ai_live.py         - Main application")
    print("  ✓ vgg16_detector.py            - Card identification")
    print("  ✓ fixed_region_detector.py     - Card detection")
    print("  ✓ build_vgg16_database.py      - Database builder")
    print("  ✓ train_custom_ai.py           - Future training")
    print("  ✓ download_training_data.py    - Data downloader")
    print("  ✓ api_client.py                - VendorBoss API")
    print("  ✓ api_config.py                - API config")
    print("  ✓ requirements.txt             - Dependencies")
    print("  ✓ All README/documentation files")
    print("  ✓ models/                      - VGG16 database")
    print("  ✓ training_data/               - Card images")
    print()
    print("MOVED TO BACKUP:")
    print(f"  → {BACKUP_DIR}/")
    print()
    print("You can delete _backup_old_files/ later if everything works!")
    print("=" * 60)

if __name__ == '__main__':
    main()
