# ScanBoss Batch Scanner

## 🎯 Two Scanning Modes

### Mode 1: Live Camera Scanning
**Best for:**
- Scanning cards one at a time
- Immediate feedback
- Real-time detection

**Run:**
```bash
python3 scanboss_ai_live.py
```

### Mode 2: Batch Folder Scanning ⭐ NEW!
**Best for:**
- Bulk scanning collections (10s, 100s, 1000s of cards!)
- Using phone camera photos
- Processing later
- No webcam needed

**Run:**
```bash
python3 scanboss_batch.py
```

### Or use the launcher:
```bash
python3 scanboss.py
```

---

## 📸 Batch Scanning Workflow

### Step 1: Take Photos with Phone

**Tips for best results:**
1. **Good lighting** - Natural light or bright overhead
2. **Flat surface** - Card on table, phone parallel
3. **Fill frame** - Card should be 70-80% of photo
4. **One card per photo** - Don't stack multiple cards
5. **Keep it simple** - White/dark background works best

**Example setup:**
```
Phone Camera
    ↓
┌─────────────┐
│   [CARD]    │  ← Card on white paper
└─────────────┘
    Table
```

### Step 2: Transfer Photos to Computer

**Options:**
- **AirDrop** (Mac + iPhone)
- **Google Photos** sync
- **USB cable** copy
- **Email** to yourself
- **Cloud storage** (Dropbox, OneDrive)

**Organize in folder:**
```
~/Pictures/card_scans_2024/
├── IMG_0001.jpg
├── IMG_0002.jpg
├── IMG_0003.jpg
├── ...
└── IMG_0234.jpg
```

### Step 3: Run Batch Scanner

```bash
python3 scanboss_batch.py
```

1. Click **"📂 Select Folder"**
2. Choose your folder with card photos
3. Click **"▶️ Start Scan"**
4. Watch it process all images!

### Step 4: Review Results

**Results table shows:**
- ✓ Checkbox (check to include in inventory)
- Filename
- Card Name
- Set
- Confidence %
- Price
- Status (✓ Detected / ✗ Failed)

**Color coding:**
- 🟢 Green = High confidence (80%+)
- 🟡 Yellow = Medium confidence (60-80%)
- 🔴 Red = Low confidence (<60%)

### Step 5: Export or Add to Inventory

**Export to CSV:**
```bash
Click "💾 Export Results"
```
Creates: `scanboss_batch_20260222_183045.csv`

**Add to Inventory (when API ready):**
```bash
1. Check cards you want to add
2. Click "✅ Add All to Inventory"
```

---

## 🎯 Use Cases

### 1. Scanning Your Collection
**Scenario:** You have 500 Magic cards to inventory

**Old way:**
- Sit at webcam
- Scan one card
- Wait for detection
- Confirm
- Next card
- **Time: ~10 hours** (500 cards × ~1 min each)

**New way:**
- Take 500 photos with phone (15 min)
- Transfer to computer (2 min)
- Batch process (10 min)
- Review & export (15 min)
- **Time: ~45 minutes**

**12x faster!** 🚀

### 2. Store Purchases
**Scenario:** Bought a collection, need to inventory quickly

1. Spread cards on table
2. Take photos systematically
3. Batch scan while eating lunch
4. Review results
5. Export for pricing analysis

### 3. Trading
**Scenario:** Need to list cards for trade

1. Photo your trade binder
2. Batch scan
3. Export CSV
4. Share with potential traders

### 4. Insurance Documentation
**Scenario:** Document valuable cards

1. Photo entire collection
2. Batch scan
3. Export CSV with prices
4. Save for insurance records

---

## 💡 Pro Tips

### For Better Detection:

**DO:**
- ✅ One card per photo
- ✅ Card fills 70-80% of frame
- ✅ Good, even lighting
- ✅ Flat, parallel to camera
- ✅ Plain background (white paper)

**DON'T:**
- ❌ Multiple cards in one photo
- ❌ Card at extreme angle
- ❌ Glare on card surface
- ❌ Card too small in frame
- ❌ Busy/patterned background

### Organizing Your Photos:

**By Set:**
```
~/card_scans/
├── core_2020/
├── war_of_spark/
└── eldraine/
```

**By Date:**
```
~/card_scans/
├── 2024-02-20_store_purchase/
├── 2024-02-21_collection/
└── 2024-02-22_trades/
```

**By Type:**
```
~/card_scans/
├── commons/
├── uncommons/
├── rares/
└── mythics/
```

### Speeding Up Photos:

**Phone camera burst mode:**
1. Hold phone steady over table
2. Slide cards under camera
3. Tap photo for each card
4. 10-20 cards/minute possible!

---

## 📊 Batch Scanner Features

### Progress Tracking
- Real-time progress bar
- Current/Total count
- Detected vs Failed stats

### Results Table
- Sortable columns
- Color-coded confidence
- Checkbox selection
- Scrollable for large batches

### Export Options
- CSV format (Excel compatible)
- Includes all card details
- Prices, rarity, set info
- Detection confidence

### Selective Import
- Uncheck low-confidence detections
- Review before adding to inventory
- Skip failed detections
- Add only what you want

---

## 🔧 Technical Details

### Supported Image Formats
- JPG/JPEG (recommended)
- PNG
- BMP  
- WEBP

### Performance
- **Speed:** ~2-3 cards/second
- **100 cards:** ~30-45 seconds
- **1000 cards:** ~5-8 minutes

### Memory Usage
- Loads one image at a time
- Safe for large batches (1000+)
- Progress saved in results table

### Detection Threshold
- Default: 50% confidence
- Lower than live mode (60%)
- Batch mode is more lenient
- You review & confirm manually

---

## 🆚 Live vs Batch Mode

| Feature | Live Camera | Batch Folder |
|---------|------------|--------------|
| **Setup** | Webcam required | Any camera (phone OK!) |
| **Speed** | 1 card/min | 100+ cards/hour |
| **Workflow** | Scan → Confirm → Next | Photo all → Process all → Review all |
| **Best for** | Few cards | Many cards |
| **Feedback** | Immediate | After processing |
| **Flexibility** | Must scan now | Photo anytime, process later |

---

## 🚀 Future Enhancements

### Planned Features:
- [ ] Auto-crop cards from photo
- [ ] Detect multiple cards in one photo
- [ ] Smartphone app integration
- [ ] Cloud sync for photos
- [ ] Damage/condition detection
- [ ] Automatic price alerts
- [ ] Duplicate detection
- [ ] Collection value tracking

---

## 🎓 Examples

### Example 1: Small Collection (50 cards)
```
1. Take photos: 5 min
2. Transfer to ~/card_scans
3. python3 scanboss_batch.py
4. Select folder, click Start
5. Review results (1-2 min)
6. Export CSV
Total time: ~10 minutes
```

### Example 2: Large Collection (500 cards)
```
1. Photo session: 20-30 min
2. Transfer to computer
3. Batch scan: 3-4 min
4. Review results: 10 min
5. Export + Add to inventory
Total time: ~45 minutes
```

### Example 3: Store Inventory (2000 cards)
```
1. Photo marathon: 1-2 hours
2. Transfer (maybe break into folders)
3. Multiple batch scans: 15-20 min total
4. Review & verify: 30 min
5. Bulk import to inventory
Total time: ~3 hours vs 30+ hours manual!
```

---

## ✅ Summary

**Batch scanning is a game-changer for:**
- 📸 Use your phone camera (better quality!)
- ⚡ Process hundreds of cards quickly
- 📊 Export results for analysis
- 🎯 Review before committing to inventory
- 💰 Calculate collection value
- 📝 Document for insurance/trading

**Perfect complement to live camera mode!**

---

**Run the launcher to choose your mode:**
```bash
python3 scanboss.py
```

🎴 Happy scanning! 🚀
