# VendorBoss App

Flutter mobile app for scanning and identifying FFTCG cards.

## Architecture

```
vendorboss_app (Flutter UI - This App)
    ↓ uses
vendorboss_core (Dart Package - Business Logic)
    ↓ connects to
VendorBoss API Server (192.168.1.37:8001)
    ↓ queries
PostgreSQL Database (3,421 FFTCG cards)
```

## Features

✅ **Camera Scanner** - Real-time card scanning with frame overlay
✅ **Fingerprint Generation** - Uses vendorboss_core to generate 14-component fingerprints
✅ **API Integration** - Connects to your local server
🚧 **Card Matching** - API endpoint needs to be added
🚧 **Manual Search** - Coming next
🚧 **Collection Tracking** - Future feature

## Running the App

### Prerequisites

- Flutter SDK installed
- Android device or emulator
- VendorBoss API server running on 192.168.1.37:8001

### Run on Android

```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0/vendorboss_app

# Get dependencies
flutter pub get

# Run on connected device/emulator
flutter run
```

### Run on iOS (requires Mac + Xcode)

```bash
flutter run -d ios
```

## Project Structure

```
lib/
├── main.dart                    # App entry point
└── screens/
    └── scanner_screen.dart      # Camera scanner UI
```

## How It Works

1. **User opens app** → Camera permission requested
2. **Camera preview** → Shows live feed with scan frame overlay
3. **User taps "Scan Card"** → Captures image
4. **Fingerprint generated** → vendorboss_core processes image
5. **API query** → Matches fingerprint against database (TODO: add endpoint)
6. **Result shown** → Card details displayed

## Current Status

### ✅ Working
- Camera initialization and permissions
- Image capture
- Fingerprint generation (14 components)
- UI with scan frame overlay

### 🚧 TODO
- Add `/api/cards/match-fingerprint` endpoint to server
- Display matched card results
- Manual search screen
- Card detail view
- Collection management

## Testing

Currently the app generates fingerprints and shows them in a dialog. Once the API endpoint is added, it will display actual card matches.

## Next Steps

1. Add fingerprint matching endpoint to API server
2. Build card result display screen
3. Add manual search UI
4. Implement collection tracking
