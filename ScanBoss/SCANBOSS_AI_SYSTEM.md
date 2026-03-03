# ScanBoss AI - Complete System

## 🎯 The Vision

ScanBoss AI is a **three-phase hybrid system** that gets better over time:

### Phase 1: VGG16 (NOW) - Immediate Detection
- **Works today** with pre-trained VGG16
- 80-90% accuracy on clean scans
- No training needed

### Phase 2: Data Collection (ONGOING)
- Every confirmed scan → Training dataset
- Collects **real-world** scanning conditions:
  - Odd angles
  - Poor lighting
  - Damaged cards
  - Cards in sleeves
  - Wear & tear

### Phase 3: Custom AI (FUTURE)
- Trained on YOUR real scans
- **Surpasses VGG16** for real-world conditions
- Future capabilities:
  - Damage assessment / grading
  - Market value prediction
  - Counterfeit detection
  - Multi-angle recognition

---

## 🚀 Quick Start

### Step 1: Build VGG16 Database (30-60 min)
```bash
python3 build_vgg16_database.py --game magic
```

This extracts features from all 48K Magic cards (one-time setup).

### Step 2: Start Scanning
```bash
python3 scanboss_hybrid.py --scan card.jpg --game magic
```

Interactive mode:
- Scans card
- Shows top 5 matches
- You confirm correct card
- **Saves scan to training dataset**

### Step 3: Train Custom AI (Later)
After collecting 100+ cards with 5+ scans each:
```bash
python3 train_custom_ai.py --game magic --epochs 30
```

Custom AI trains on YOUR real scans and replaces VGG16!

---

## 📁 File Structure

```
ScanBoss/
├── training_data/           # API card images (48K cards)
│   └── magic/
│       ├── neo-123/
│       │   └── image.jpg
│       └── war-456/
│           └── image.jpg
│
├── real_scans/              # YOUR scans (training data for custom AI)
│   └── magic/
│       ├── neo-123/         # Multiple real scans of same card
│       │   ├── scan_0001_20260220_143022.jpg
│       │   ├── scan_0002_20260220_145033.jpg
│       │   └── scan_0003_20260221_091544.json
│       └── metadata.json
│
├── models/
│   ├── vgg16_db_magic.pkl              # VGG16 feature database
│   ├── scanboss_custom_magic.h5        # Custom trained model (Phase 3)
│   └── scanboss_custom_magic_classes.json
│
├── roi_configs/             # Region definitions per set
│   ├── magic_neo.json
│   └── magic_war.json
│
└── scripts/
    ├── build_vgg16_database.py      # Phase 1: Build VGG16 DB
    ├── scanboss_hybrid.py           # Main scanning tool
    ├── train_custom_ai.py           # Phase 3: Train custom model
    └── search_vgg16.py              # Direct VGG16 search
```

---

## 🔧 How It Works

### Phase 1: VGG16 Detection

```
User scans card
    ↓
Extract VGG16 features (25,088 dimensions)
    ↓
Compare with database (48K cards)
    ↓
Return top 5 matches with confidence scores
```

**Accuracy:** 80-90% on clean scans

### Phase 2: Data Collection Loop

```
User scans card
    ↓
VGG16 suggests card
    ↓
User confirms correct card
    ↓
Save scan + metadata to real_scans/
    ↓
Build training dataset for custom AI
```

**Goal:** Collect 5-10 scans per card from different angles/conditions

### Phase 3: Custom AI

```
After 1000s of real scans collected
    ↓
Train MobileNetV2 on real-world data
    ↓
Custom model learns:
  - Odd angles
  - Damage patterns
  - Lighting variations
  - Cards in sleeves
    ↓
Custom AI replaces VGG16
```

**Expected Accuracy:** 90-95%+ on real-world scans

---

## 📊 Progress Tracking

Check your training dataset status:
```bash
python3 scanboss_hybrid.py --scan test.jpg --game magic
```

Output shows:
```
📊 TRAINING DATASET STATUS:
   Total scans: 1,523
   Unique cards: 287
   Cards with 5+ scans: 143

   Status: READY FOR PILOT TRAINING! 🎯
   Run: python train_custom_ai.py --game magic
```

---

## 🎓 Training Requirements

### Pilot Training (Test)
- **100+ cards** with 5+ scans each
- Trains in ~2 hours
- Good for testing the concept

### Production Training (Real Use)
- **1,000+ cards** with 10+ scans each  
- Trains in ~8-12 hours
- Production-ready accuracy

### Ultimate Goal
- **10,000+ cards** with 20+ scans each
- Trained on diverse conditions
- Commercial-grade accuracy

---

## 🔮 Future Capabilities

Once custom AI is trained, we can add:

### 1. Damage Grading
```python
result = detector.assess_condition(scan)
# Returns: "Near Mint" | "Lightly Played" | "Heavily Played" | "Damaged"
```

### 2. Market Value
```python
result = detector.detect_with_value(scan)
# Returns: {
#   'card': 'neo-123',
#   'condition': 'Near Mint',
#   'market_value': 45.99,
#   'trending': 'up'
# }
```

### 3. Counterfeit Detection
```python
result = detector.verify_authenticity(scan)
# Returns: confidence score + suspicious areas
```

### 4. Multi-Angle Recognition
```python
# Works even with:
# - Card at 45° angle
# - Partial view
# - Cards stacked
# - Poor lighting
```

---

## 🆚 Why This Beats Competitors

### Ludex / Kronozio
- **They use:** Cloud AI (Gemini, etc.)
- **We use:** Self-trained custom AI
- **Our advantage:**
  - Works offline
  - No API costs
  - Learns YOUR specific use cases
  - Vendor-specific features

### VGG16 Alone
- **Accuracy:** 80-90% on clean scans
- **Custom AI:** 90-95%+ on real scans
- **Difference:** Trained on YOUR data

---

## 💡 Best Practices

### For Best Detection:
1. Good lighting (avoid glare)
2. Card flat on table
3. Camera parallel to card
4. Fill frame with card

### For Building Training Data:
1. Scan same card from multiple angles
2. Try different lighting conditions
3. Include damaged/worn cards
4. Scan cards in sleeves too
5. Confirm every scan correctly

### For Training Custom AI:
1. Start with pilot (100 cards)
2. Test accuracy on real scans
3. Collect more data if needed
4. Retrain periodically with new scans

---

## 🛠️ Technical Details

### VGG16 Feature Extraction
- Pre-trained on ImageNet (1.4M images)
- Outputs 25,088-dimensional vector
- Represents high-level features
- Cosine similarity for matching

### Custom AI Architecture
- Base: MobileNetV2 (transfer learning)
- Fine-tuned last 20 layers
- Heavy data augmentation
- Dropout for regularization
- Multi-task learning ready

### Data Augmentation
- Rotation: ±20°
- Zoom: ±20%
- Brightness: 70-130%
- Shear: ±10% (perspective)
- No flipping (cards have orientation)

---

## 📈 Roadmap

### ✅ Phase 1: VGG16 (COMPLETE)
- [x] Download 48K Magic cards
- [x] Build VGG16 database
- [x] Search functionality
- [x] 80-90% accuracy

### 🔄 Phase 2: Data Collection (IN PROGRESS)
- [x] Interactive scanning
- [x] Confirmation workflow
- [x] Training dataset storage
- [ ] Collect 1,000+ confirmed scans

### 🔮 Phase 3: Custom AI (PLANNED)
- [x] Training script ready
- [ ] Pilot training (100 cards)
- [ ] Production training (1,000 cards)
- [ ] Deploy custom model

### 🚀 Phase 4: Advanced Features (FUTURE)
- [ ] Damage grading
- [ ] Market value prediction
- [ ] Counterfeit detection
- [ ] Multi-angle recognition

---

## 🤝 Contributing

**Every scan you confirm helps train ScanBoss AI!**

Your contributions:
1. Improve detection accuracy
2. Add new card coverage
3. Handle edge cases
4. Build damage detection dataset

The more scans collected, the smarter ScanBoss gets! 🧠

---

## 📞 Support

Having issues? Check:
1. VGG16 database built? (`models/vgg16_db_magic.pkl`)
2. TensorFlow installed? (`pip3 install tensorflow`)
3. Enough training data? (Use `scanboss_hybrid.py` to check)

---

## 🎯 Summary

**ScanBoss AI = VGG16 (now) + Custom AI (later)**

- Start detecting **today** with VGG16
- Build training dataset **automatically**
- Train custom AI **when ready**
- Get **better accuracy** over time
- Add **advanced features** in future

**The more you use it, the better it gets!** 🚀
