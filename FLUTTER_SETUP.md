# VendorBoss 2.0 - Flutter Setup Guide

## 🏗️ Architecture

```
VendorBoss2.0/
├── vendorboss-api/          # FastAPI backend (✅ Done)
├── vendorboss-core/         # Shared Flutter code (all platforms)
└── vendorboss-and/          # Android app shell
    └── (future: vendorboss-ios, vendorboss-mac, vendorboss-win)
```

## 📦 Install Flutter

### Option 1: Homebrew (Recommended)
```bash
brew install --cask flutter
```

### Option 2: Manual Download
1. Download from: https://flutter.dev/docs/get-started/install/macos
2. Extract to `/Users/travisdewitt/flutter`
3. Add to PATH:
```bash
export PATH="$PATH:/Users/travisdewitt/flutter/bin"
```

### Verify Installation
```bash
flutter doctor
```

This will check for:
- ✅ Flutter SDK
- ✅ Android toolchain (for building Android apps)
- ✅ Xcode (for iOS/Mac apps)
- ✅ Android Studio (recommended)

## 🚀 Create Project Structure

Once Flutter is installed, run these commands:

### 1. Create Core Package (Shared Code)
```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0
flutter create --template=package vendorboss_core
```

This creates a Flutter package with shared:
- API client
- Models/data classes
- Business logic
- Reusable UI components
- State management

### 2. Create Android App
```bash
flutter create --platforms=android vendorboss_and
```

This creates a minimal Android app shell that imports vendorboss_core.

### 3. Link Core to Android App
Edit `vendorboss_and/pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  vendorboss_core:
    path: ../vendorboss_core
```

## 🔧 Connect Your Tablet

### Enable Developer Mode on Samsung Tablet
1. Go to Settings → About tablet
2. Tap "Build number" 7 times
3. Go back → Developer options
4. Enable "USB debugging"

### Connect via USB
```bash
# List connected devices
adb devices

# Should show your tablet
```

## 📱 Run on Tablet

```bash
cd vendorboss_and
flutter run
```

Flutter will:
1. Build the APK
2. Install on your tablet
3. Launch the app
4. Enable hot reload (instant updates!)

## 🎯 What Goes Where?

### vendorboss-core/ (Shared)
```
lib/
├── models/
│   ├── card.dart
│   ├── fingerprint.dart
│   └── pricing.dart
├── services/
│   ├── api_client.dart
│   └── fingerprint_service.dart
├── screens/
│   ├── home_screen.dart
│   ├── scan_screen.dart
│   └── result_screen.dart
└── widgets/
    ├── card_display.dart
    └── price_display.dart
```

### vendorboss-and/ (Android Shell)
```
lib/
└── main.dart  (imports vendorboss_core and runs app)
android/
└── app/
    └── (Android-specific configs)
```

## 🚀 Build APK for Installation

```bash
cd vendorboss_and

# Build release APK
flutter build apk --release

# APK will be at:
# build/app/outputs/flutter-apk/app-release.apk
```

Then:
1. Copy APK to your tablet
2. Install it (enable "Install unknown apps" if needed)
3. Launch!

## 🔄 Development Workflow

1. **Edit code** in vendorboss-core/
2. **Save** - Flutter hot reloads automatically
3. **See changes** instantly on tablet
4. **Build APK** when ready to share

## 📝 Next Steps

After Flutter is installed:
1. Run `flutter doctor` to verify setup
2. Create vendorboss_core package
3. Create vendorboss_and app
4. I'll help you build the UI and API integration!

---

**Run this now:**
```bash
brew install --cask flutter
flutter doctor
```

Then let me know when it's ready and I'll create all the Dart code! 🎯
