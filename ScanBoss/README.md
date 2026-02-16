# ScanBoss - AI Card Scanner

Professional desktop application for scanning sports cards with **automatic text recognition** and building the VendorBoss fingerprint database.

## 🎯 Features

- **🤖 Automatic Card Reading (OCR)**: Tesseract OCR extracts player names, years, and card sets automatically
- **🔍 AI-Enhanced Detection**: Advanced computer vision for accurate card boundary detection
- **🔐 Compatible Fingerprinting**: Uses identical SHA-256 algorithm as VendorBoss mobile app
- **👥 Crowd-Sourced Database**: Users help build comprehensive card database
- **⚡ Real-time Scanning**: Live camera preview with auto-detection
- **🌐 API Integration**: Connects to VendorBoss API for card lookup and storage
- **🖥️ Modern UI**: Professional PyQt6 interface with dark theme

## 📦 Installation

### Quick Setup (macOS)

```bash
# Install Tesseract OCR for automatic card reading
brew install tesseract

# Install Python dependencies
pip install -r requirements.txt

# Run ScanBoss
python3 scanboss_qt.py
```

### Detailed Setup

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for complete installation instructions for macOS, Linux, and Windows.

## 🚀 Usage

1. **Install & Launch**: Follow setup instructions above
2. **Login**: Enter VendorBoss credentials to access API
3. **Scan Cards**: 
   - **Manual**: Click "Scan Card" button
   - **Auto**: Enable "Auto Scan" for continuous detection
4. **Card Processing**:
   - **Match Found**: Verify card details are correct
   - **New Card**: OCR auto-fills player/year/set - review and submit
5. **Database Building**: Each scan improves accuracy for all users

## 🎨 Best Practices

### Background Setup
- Use **black or dark solid color** background
- **Matte finish** (avoid shiny surfaces)
- Examples: mousepad, construction paper, dark t-shirt

### Lighting
- **Even overhead lighting**
- **Natural daylight** (not direct sunlight)
- Avoid shadows and reflections

### Card Positioning
- Fill 60-80% of the green detection zone
- Keep card flat and straight
- Center card in frame

## 🔬 Technical Details

### OCR Technology
- **Engine**: Tesseract OCR 5.x (Google's open-source OCR)
- **Preprocessing**: CLAHE contrast enhancement, denoising
- **Parsing**: Regex pattern matching for player names, years, and brands
- **Accuracy**: ~70-85% depending on card condition and lighting

### Fingerprinting
- **Algorithm**: Identical SHA-256 hash as VendorBoss mobile
- **Features**: Edge density, corner detection, color histograms, aspect ratio
- **Compatibility**: Cross-platform consistency guaranteed

### Computer Vision
- **Detection**: OpenCV Canny edge detection with contour analysis
- **Threshold**: 5,000+ pixel minimum area
- **Zone**: 350x490 pixel detection area
- **Processing**: Background thread to prevent UI freezing

## 🏗️ Architecture

```
ScanBoss → CardDetector → OCR + Fingerprint → API → Database
    ↓
VendorBoss Mobile Apps benefit from expanded database
```

### Tech Stack
- **UI**: PyQt6 (modern, native-looking)
- **Vision**: OpenCV (card detection)
- **OCR**: Tesseract (text extraction)
- **API**: Requests (REST client)
- **Language**: Python 3.8+

## 📁 Project Structure

```
ScanBoss/
├── scanboss_qt.py              # Main PyQt6 application
├── card_detector.py            # Card detection + OCR engine
├── api_client.py               # VendorBoss API client
├── requirements.txt            # Python dependencies
├── debug_card_detection_live.py # Visual debugging tool
├── SETUP_GUIDE.md              # Installation guide
└── README.md                   # This file
```

## 🐛 Troubleshooting

### Card Not Detected
- Ensure card fills the green detection zone
- Use a dark, solid-colored background
- Improve lighting (even, not too bright/dim)

### OCR Not Working
```bash
# Verify Tesseract is installed
tesseract --version

# Reinstall if needed
brew reinstall tesseract
pip install --upgrade pytesseract
```

### Camera Issues
```bash
# Run camera debug tool
python3 debug_camera.py
```

See [SETUP_GUIDE.md](SETUP_GUIDE.md) for more troubleshooting tips.

## 🔧 Configuration

### Adjust Detection Sensitivity
Edit `card_detector.py`:
```python
self.min_area = 5000  # Lower = more sensitive
```

### Adjust Detection Zone
Edit `scanboss_qt.py`:
```python
zone_w, zone_h = 350, 490  # Larger zone for easier scanning
```

## 🤝 Contributing

This app helps build the VendorBoss card database. Every scan you make improves the system for all users!

## 📄 License

This project integrates with VendorBoss API and uses open-source components:
- Tesseract OCR (Apache 2.0)
- OpenCV (Apache 2.0)
- PyQt6 (GPL/Commercial)

## 🆘 Support

For issues or questions, see [SETUP_GUIDE.md](SETUP_GUIDE.md) or check:
- Tesseract: https://github.com/tesseract-ocr/tesseract
- PyQt6: https://www.riverbankcomputing.com/software/pyqt/
- OpenCV: https://opencv.org/

---

**Happy Scanning!** 🎯📸
