# 🚀 AI CONVERSION GUIDE - Python → C#

## 📋 What We're Converting:

1. **VGG16 Model** → ONNX format (for C# ONNX Runtime)
2. **Magic Database** → JSON (from pickle)
3. **FFTCG Database** → JSON (from pickle)

---

## ⚡ STEP 1: Convert VGG16 Model to ONNX

```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0/ScanBoss

# Install conversion tools (one-time)
pip install tf2onnx onnx --break-system-packages

# Convert VGG16 to ONNX (~5 minutes)
python3 convert_vgg16_to_onnx.py
```

**Output:** `models/vgg16.onnx` (~98 MB)

---

## ⚡ STEP 2: Convert Databases to JSON

```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0/ScanBoss

# Convert pickle → JSON (~1 minute)
python3 convert_databases_to_json.py
```

**Output:**
- `models/vgg16_db_magic.json` (~600 MB)
- `models/vgg16_db_fftcg.json` (~130 MB)

⚠️ **Note:** JSON files are larger than pickle (but C# can read them!)

---

## ⚡ STEP 3: Copy to C# Project

```bash
# Create Models directory in C# project
mkdir -p ../ScanBossCSharp/ScanBoss/Models

# Copy all converted files
cp models/vgg16.onnx ../ScanBossCSharp/ScanBoss/Models/
cp models/vgg16_db_magic.json ../ScanBossCSharp/ScanBoss/Models/
cp models/vgg16_db_fftcg.json ../ScanBossCSharp/ScanBoss/Models/
```

---

## ⚡ STEP 4: Test in C# App

```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0/ScanBossCSharp

# Run the app
dotnet run --project ScanBoss
```

**Expected Result:**
- Window opens ✅
- Select "Magic: The Gathering" → Shows "✓ 48,159 cards loaded"
- Select "Final Fantasy TCG" → Shows "✓ 3,421 cards loaded"

---

## 📁 Final Structure:

```
ScanBossCSharp/ScanBoss/Models/
├── vgg16.onnx              ← AI model (98 MB)
├── vgg16_db_magic.json     ← Magic database (600 MB)
└── vgg16_db_fftcg.json     ← FFTCG database (130 MB)
```

---

## 🎯 All-In-One Command:

```bash
# Do everything at once!
cd /Users/travisdewitt/Repos/VendorBoss2.0/ScanBoss

# 1. Install dependencies
pip install tf2onnx onnx --break-system-packages

# 2. Convert VGG16
python3 convert_vgg16_to_onnx.py

# 3. Convert databases
python3 convert_databases_to_json.py

# 4. Copy to C# project
mkdir -p ../ScanBossCSharp/ScanBoss/Models
cp models/vgg16.onnx ../ScanBossCSharp/ScanBoss/Models/
cp models/vgg16_db_magic.json ../ScanBossCSharp/ScanBoss/Models/
cp models/vgg16_db_fftcg.json ../ScanBossCSharp/ScanBoss/Models/

# 5. Run C# app
cd ../ScanBossCSharp
dotnet run --project ScanBoss
```

---

## ⏱️ Time Estimates:

- **VGG16 Conversion:** ~5 minutes
- **Database Conversion:** ~1 minute
- **File Copying:** ~10 seconds
- **Total:** ~6 minutes

---

## 💾 Disk Space Needed:

- ONNX model: 98 MB
- Magic JSON: ~600 MB
- FFTCG JSON: ~130 MB
- **Total:** ~830 MB

---

**Travis - run the all-in-one command above!** 

Then the C# app will have full AI capabilities! 🚀
