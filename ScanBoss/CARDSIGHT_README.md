# CardSight AI™

**Instant Card Recognition for Trading Card Professionals**

CardSight is VendorBoss's proprietary card detection AI, trained to instantly identify Pokemon, Magic: The Gathering, and FFTCG cards from photos.

---

## What CardSight Does

Input: Photo of a card
Output: Set, card number, variant, and price

**Target Accuracy:** 75-90%
**Speed:** <2 seconds per card

---

## Getting Started

### 1. Download Training Data

```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0/ScanBoss

# Install requirements
pip install requests Pillow

# Test with 100 Pokemon cards
python download_training_data.py --game pokemon --limit 100

# Full Pokemon download (~10K cards, ~2GB, 2-3 hours)
python download_training_data.py --game pokemon

# Magic download (~20K cards, ~4GB, 4-6 hours)
python download_training_data.py --game magic

# Both games
python download_training_data.py --all
```

### 2. Train the Model (Coming Next)

```bash
python train_cardsight.py --game pokemon --epochs 20
```

### 3. Use CardSight

```python
from cardsight import CardSightDetector

detector = CardSightDetector(game='pokemon')
result = detector.detect('photo.jpg')

print(f"Card: {result.name}")
print(f"Set: {result.set_name}")
print(f"Variant: {result.variant}")
print(f"Confidence: {result.confidence}%")
print(f"Price: ${result.market_price}")
```

---

## Directory Structure

```
ScanBoss/
├── training_data/          # Downloaded card images
│   ├── pokemon/
│   │   ├── base1/
│   │   │   ├── 001_standard.jpg
│   │   │   ├── 001_holo.jpg
│   │   │   └── 004_holo.jpg
│   │   └── swsh12/
│   ├── magic/
│   │   ├── neo/
│   │   └── war/
│   └── fftcg/
│
├── models/                 # Trained AI models
│   ├── cardsight_pokemon.h5
│   ├── cardsight_magic.h5
│   └── cardsight_fftcg.h5
│
├── download_training_data.py
├── train_cardsight.py      # Coming next
└── cardsight.py            # CardSight API
```

---

## Licensing Potential

CardSight AI is proprietary to VendorBoss and could be:
- Licensed to other card scanning apps
- Sold as standalone API service
- Integrated into POS systems
- White-labeled for card shops

---

## Next Steps

1. ✅ Download training data (this script)
2. ⏳ Train the model (next script)
3. ⏳ Test accuracy
4. ⏳ Deploy to ScanBoss service
5. ⏳ Integrate with mobile app
