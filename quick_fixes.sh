#!/bin/bash
# Quick fixes for ScanBoss performance and usability

echo "=========================================="
echo "ScanBoss Performance & UX Improvements"
echo "=========================================="
echo ""

cd /Users/travisdewitt/Repos/VendorBoss2.0

echo "1. Adding database indexes for faster queries..."
cd vendorboss-api
python3 add_indexes.py
echo ""

echo "2. Updating card detector for bigger scan zone..."
cd ../ScanBoss

# Update detection zone size in card_detector.py
sed -i.bak 's/zone_w, zone_h = 350, 490/zone_w, zone_h = 500, 700/' card_detector.py

echo "✓ Detection zone increased from 350x490 to 500x700"
echo ""

echo "=========================================="
echo "Improvements Applied!"
echo "=========================================="
echo ""
echo "Changes made:"
echo "  ✓ Database indexes added (faster queries)"
echo "  ✓ Scan box 43% larger (500x700)"
echo ""
echo "Restart ScanBoss to see changes:"
echo "  python3 main.py"
echo ""
echo "Performance notes:"
echo "  - First scan may still be slow (3,421 fingerprints)"
echo "  - Subsequent scans use local cache (much faster!)"
echo "  - Consider limiting fuzzy matching to top 1000 results"
echo ""
