# ScanBoss AI - Clean Architecture

## 🎯 Essential Files (What We're Keeping)

### Main Application
- **`scanboss_ai_live.py`** - Main GUI application with live detection

### Core Detection System
- **`vgg16_detector.py`** - Card identification using VGG16 + Scryfall API
- **`fixed_region_detector.py`** - Card detection in guide brackets

### Database & Training
- **`build_vgg16_database.py`** - Builds VGG16 feature database (one-time setup)
- **`train_custom_ai.py`** - Future: train custom model on real scans
- **`download_training_data.py`** - Downloads card images from Scryfall

### VendorBoss Integration
- **`api_client.py`** - VendorBoss API client
- **`api_config.py`** - API configuration

### Data & Config
- **`requirements.txt`** - Python dependencies
- **`models/`** - VGG16 database (vgg16_db_magic.pkl)
- **`training_data/`** - Downloaded card images (48K+ cards)
- **`roi_configs/`** - Region configs (unused but kept)

### Documentation
- **`README.md`** - Main readme
- **`SCANBOSS_AI_SYSTEM.md`** - System architecture
- **`QUICK_START.md`** - Quick start guide
- All other .md files

---

## 💰 Price Data Source

### Scryfall API (FREE!)

**Location in code:** `vgg16_detector.py` line ~160

```python
def _fetch_card_details(self, set_code: str, card_number: str):
    url = f"https://api.scryfall.com/cards/{set_code}/{card_number}"
    response = requests.get(url, timeout=5)
    data = response.json()
    
    return {
        'prices': {
            'usd': data.get('prices', {}).get('usd'),
            'usd_foil': data.get('prices', {}).get('usd_foil'),
        }
    }
```

**What Scryfall Provides:**
- USD prices (regular + foil)
- EUR prices
- TIX (MTGO) prices  
- Paper prices
- Cardmarket prices
- TCGPlayer integration
- **No API key required!**
- Updated daily

**Rate Limits:**
- 10 requests/second (we're well under this)
- Cached after first fetch per session

---

## 🗑️ What Gets Moved to Backup

### Old/Broken Detection Files
- `card_detector.py` - Broken edge detector (found art/text instead of card)
- `simple_card_detector.py` - Also broken

### Failed Training Approaches
- `train_scanboss_ai.py` - Tried 48K class training (failed)
- `train_with_roi.py` - Region-based training (didn't use)
- `define_roi.py` - ROI definition tool (didn't use)
- `reorganize_training_data.py` - One-time script (already ran)

### Old App Versions
- `scanboss_hybrid.py` - Hybrid approach (incomplete)
- `scanboss_qt.py` - Old GUI version
- `scanboss_fleet.py` - Unknown/unused
- `main.py` - Old main

### Test Scripts (17 files!)
- All `test_*.py` files
- `simple_match_test.py`
- `debug_card_detection_live.py`

### Unused Features
- `learning_engine.py` - Attempted learning system
- `local_cache.py` - Unused caching
- `visualize_fingerprints.py` - Fingerprint visualization
- And more...

### Standalone Tools
- `search_vgg16.py` - Command-line search (not needed in GUI)
- Various utility scripts

### Old API Files
- Various old API implementation attempts

### Debug Images
- All `debug_*.jpg` files (100+ files during testing!)

---

## 📊 File Count

**Before Cleanup:**
- ~70+ Python files
- ~50+ debug images
- Total: 120+ files

**After Cleanup:**
- ~12 essential Python files
- 0 debug images
- Total: ~15 files + directories

**Space Saved:** ~50MB+ (mostly debug images)

---

## 🚀 How to Clean Up

```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0/ScanBoss
python3 cleanup.py
```

This will:
1. Create `_backup_old_files/` directory
2. Move old/broken files to backup
3. Delete debug images
4. Show summary

**To permanently delete backup later:**
```bash
rm -rf _backup_old_files/
```

---

## ✅ After Cleanup - What You Should See

```
ScanBoss/
├── scanboss_ai_live.py          ← MAIN APP
├── vgg16_detector.py             ← Card ID
├── fixed_region_detector.py      ← Card detection
├── build_vgg16_database.py       ← Database builder
├── train_custom_ai.py            ← Future training
├── download_training_data.py     ← Data downloader
├── api_client.py                 ← API integration
├── api_config.py                 ← API config
├── cleanup.py                    ← This cleanup script
├── requirements.txt              ← Dependencies
├── models/
│   └── vgg16_db_magic.pkl        ← 48K card database
├── training_data/
│   └── magic/                    ← 48K card images
└── *.md files                    ← Documentation
```

**Clean. Simple. Works.** 🎯
