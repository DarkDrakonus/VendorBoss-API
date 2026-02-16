# 🚀 ScanBoss Setup Guide

## Quick Start

### 1. Install Tesseract OCR (for automatic card reading)

**On macOS:**
```bash
brew install tesseract
```

**On Linux:**
```bash
sudo apt-get install tesseract-ocr
```

**On Windows:**
Download installer from: https://github.com/UB-Mannheim/tesseract/wiki

### 2. Install Python Dependencies

```bash
cd /Users/travisdewitt/Desktop/ScanBoss
pip install -r requirements.txt
```

Or install individually:
```bash
pip install opencv-python numpy Pillow requests PyQt6 pytesseract
```

### 3. Run ScanBoss

```bash
python3 scanboss_qt.py
```

---

## 🎯 Features

### ✅ **With OCR Enabled (Tesseract Installed):**
- 🤖 **Automatic card reading** - Player names, years, and sets detected automatically
- 📝 **Pre-filled forms** - OCR data auto-fills the card entry dialog
- ⚡ **Faster data entry** - Just verify and confirm

### ⚠️ **Without OCR (Tesseract Not Installed):**
- ✏️ Manual entry only
- App still works perfectly
- Shows warning message on startup

---

## 📋 Verify Installation

To check if Tesseract is installed correctly:

```bash
tesseract --version
```

Should show something like:
```
tesseract 5.3.0
```

---

## 🎨 Best Setup for Card Scanning

### Background:
- **Black or dark solid color** (mousepad, construction paper, t-shirt)
- **Matte finish** (no shine/reflections)

### Lighting:
- **Even overhead lighting**
- **Natural daylight** (not direct sunlight)
- Avoid shadows from your hands

### Card Position:
- Fill 60-80% of the green detection zone
- Keep card flat and straight
- Ensure entire card is visible

---

## 🐛 Troubleshooting

### "No card detected"
- Make sure card fills the green zone
- Use a dark, solid background
- Check lighting (not too dim, not too bright)

### OCR not working
- Verify Tesseract is installed: `tesseract --version`
- Reinstall pytesseract: `pip install --upgrade pytesseract`
- On macOS, you may need to set the path:
  ```python
  pytesseract.pytesseract.tesseract_cmd = '/opt/homebrew/bin/tesseract'
  ```

### Camera not found
- Check camera permissions in System Preferences
- Try a different camera index from the dropdown
- Run `python3 debug_camera.py` to test cameras

---

## 📁 Project Structure

```
ScanBoss/
├── scanboss_qt.py              # Main PyQt6 application
├── card_detector.py            # Card detection + OCR
├── api_client.py               # VendorBoss API client
├── requirements.txt            # Python dependencies
├── debug_card_detection_live.py # Visual debugging tool
└── README.md                   # Project documentation
```

---

## 🔧 Advanced

### Debug Card Detection:
```bash
python3 debug_card_detection_live.py
```
Shows live visualization of edge detection and contours.

### Test OCR Separately:
```python
import pytesseract
from PIL import Image

img = Image.open('card.png')
text = pytesseract.image_to_string(img)
print(text)
```

---

## ⚙️ Configuration

### Adjust Detection Sensitivity

Edit `card_detector.py`:
```python
self.min_area = 5000  # Lower = more sensitive (default: 5000)
```

### Adjust Detection Zone Size

Edit `scanboss_qt.py`:
```python
zone_w, zone_h = 350, 490  # Make larger/smaller as needed
```

---

## 🆘 Support

If you encounter issues:
1. Check this guide first
2. Run the debug visualizer to see what's being detected
3. Verify all dependencies are installed
4. Check camera permissions

Enjoy scanning! 🎯
