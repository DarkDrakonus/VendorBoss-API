#!/bin/bash
#
# ScanBoss Cleanup Script
# Removes old, broken, and unnecessary files
#

cd /Users/travisdewitt/Repos/VendorBoss2.0/ScanBoss

echo "============================================================"
echo "SCANBOSS CLEANUP"
echo "============================================================"
echo ""

# Create backup directory
echo "Creating backup directory..."
mkdir -p _backup_old_files
echo ""

echo "Moving old/broken files to backup..."
echo ""

# Old/broken detection files
echo "1. Old detection implementations..."
mv card_detector.py _backup_old_files/ 2>/dev/null && echo "   ✓ card_detector.py"
mv simple_card_detector.py _backup_old_files/ 2>/dev/null && echo "   ✓ simple_card_detector.py"

# Old training scripts (didn't work)
echo "2. Failed training approaches..."
mv train_scanboss_ai.py _backup_old_files/ 2>/dev/null && echo "   ✓ train_scanboss_ai.py"
mv train_with_roi.py _backup_old_files/ 2>/dev/null && echo "   ✓ train_with_roi.py"
mv define_roi.py _backup_old_files/ 2>/dev/null && echo "   ✓ define_roi.py"
mv reorganize_training_data.py _backup_old_files/ 2>/dev/null && echo "   ✓ reorganize_training_data.py"

# Incomplete/old app versions
echo "3. Old app versions..."
mv scanboss_hybrid.py _backup_old_files/ 2>/dev/null && echo "   ✓ scanboss_hybrid.py"
mv scanboss_qt.py _backup_old_files/ 2>/dev/null && echo "   ✓ scanboss_qt.py"
mv scanboss_fleet.py _backup_old_files/ 2>/dev/null && echo "   ✓ scanboss_fleet.py"
mv main.py _backup_old_files/ 2>/dev/null && echo "   ✓ main.py"

# Test scripts (one-time use)
echo "4. Test scripts..."
mv test_*.py _backup_old_files/ 2>/dev/null && echo "   ✓ All test_*.py files"
mv simple_match_test.py _backup_old_files/ 2>/dev/null && echo "   ✓ simple_match_test.py"
mv debug_card_detection_live.py _backup_old_files/ 2>/dev/null && echo "   ✓ debug_card_detection_live.py"

# Unused features
echo "5. Unused features..."
mv learning_engine.py _backup_old_files/ 2>/dev/null && echo "   ✓ learning_engine.py"
mv learning_model.json _backup_old_files/ 2>/dev/null && echo "   ✓ learning_model.json"
mv local_cache.py _backup_old_files/ 2>/dev/null && echo "   ✓ local_cache.py"
mv local_cache_old.py _backup_old_files/ 2>/dev/null && echo "   ✓ local_cache_old.py"
mv visualize_fingerprints.py _backup_old_files/ 2>/dev/null && echo "   ✓ visualize_fingerprints.py"
mv fingerprint_test_results.json _backup_old_files/ 2>/dev/null && echo "   ✓ fingerprint_test_results.json"

# Standalone tools (not needed)
echo "6. Standalone tools..."
mv search_vgg16.py _backup_old_files/ 2>/dev/null && echo "   ✓ search_vgg16.py"
mv patch_camera.py _backup_old_files/ 2>/dev/null && echo "   ✓ patch_camera.py"
mv comprehensive_fix.py _backup_old_files/ 2>/dev/null && echo "   ✓ comprehensive_fix.py"
mv update_requirements.py _backup_old_files/ 2>/dev/null && echo "   ✓ update_requirements.py"
mv workers.py _backup_old_files/ 2>/dev/null && echo "   ✓ workers.py"

# Old API files (may not be needed)
echo "7. Old API implementations..."
mv admin_dashboard.py _backup_old_files/ 2>/dev/null && echo "   ✓ admin_dashboard.py"
mv align_with_api.py _backup_old_files/ 2>/dev/null && echo "   ✓ align_with_api.py"
mv api_main_example.py _backup_old_files/ 2>/dev/null && echo "   ✓ api_main_example.py"
mv api_public_endpoints.py _backup_old_files/ 2>/dev/null && echo "   ✓ api_public_endpoints.py"
mv api_endpoints.py _backup_old_files/ 2>/dev/null && echo "   ✓ api_endpoints.py"

echo ""
echo "Removing debug images..."
rm -f debug_*.jpg 2>/dev/null && echo "   ✓ Deleted debug_*.jpg files"
rm -f test_detected_card_fixed.jpg 2>/dev/null && echo "   ✓ Deleted test images"

echo ""
echo "============================================================"
echo "CLEANUP COMPLETE"
echo "============================================================"
echo ""
echo "KEPT (essential files):"
echo "  ✓ scanboss_ai_live.py         - Main application"
echo "  ✓ vgg16_detector.py            - Card identification"
echo "  ✓ fixed_region_detector.py     - Card detection"
echo "  ✓ build_vgg16_database.py      - Database builder"
echo "  ✓ train_custom_ai.py           - Future training"
echo "  ✓ download_training_data.py    - Data downloader"
echo "  ✓ api_client.py                - VendorBoss API"
echo "  ✓ api_config.py                - API config"
echo "  ✓ requirements.txt             - Dependencies"
echo "  ✓ All README files             - Documentation"
echo "  ✓ models/                      - VGG16 database"
echo "  ✓ training_data/               - Card images"
echo ""
echo "MOVED TO BACKUP:"
echo "  → _backup_old_files/           - All old/broken files"
echo ""
echo "You can delete _backup_old_files/ later if everything works!"
echo "============================================================"
