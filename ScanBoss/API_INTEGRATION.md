# ScanBoss → VendorBoss API Integration

## 🎯 Complete Architecture

```
┌──────────────────────────────────────────────────────────────┐
│                    SCANBOSS AI (CLIENT)                       │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  1. User places card in green brackets                        │
│  2. Click "Scan Now"                                          │
│                                                                │
│  ┌─────────────────────────────────────┐                     │
│  │  Fixed Region Detector              │                     │
│  │  - Crops guide bracket area         │                     │
│  │  - Enhances image quality           │                     │
│  │  - Returns 500x700px card image     │                     │
│  └─────────────────────────────────────┘                     │
│                    ↓                                          │
│  ┌─────────────────────────────────────┐                     │
│  │  VGG16 Detector                     │                     │
│  │  - Extracts 25,088-dim features     │                     │
│  │  - Searches 48K card database       │                     │
│  │  - Returns: m20-129 (73% confidence)│                     │
│  └─────────────────────────────────────┘                     │
│                    ↓                                          │
│  ┌─────────────────────────────────────┐                     │
│  │  Scryfall API                       │                     │
│  │  - Fetches card details             │                     │
│  │  - Gets USD prices (regular + foil) │                     │
│  │  - Returns full card metadata       │                     │
│  └─────────────────────────────────────┘                     │
│                    ↓                                          │
│  3. Display card details to user                             │
│     - Card image                                              │
│     - Name, type, set                                         │
│     - Price, rarity                                           │
│     - Confidence score                                        │
│                                                                │
│  4. User clicks "✓ Correct Card"                             │
│                                                                │
│  ┌─────────────────────────────────────┐                     │
│  │  Magic API Client                   │                     │
│  │  POST /api/inventory/magic/scan     │                     │
│  │  {                                   │                     │
│  │    card_id, confidence,              │                     │
│  │    name, set, prices, ...            │                     │
│  │    condition, quantity, is_foil      │                     │
│  │  }                                   │                     │
│  └─────────────────────────────────────┘                     │
│                    ↓                                          │
└──────────────────────────────────────────────────────────────┘
                     │
                     │ HTTP POST
                     ↓
┌──────────────────────────────────────────────────────────────┐
│                  VENDORBOSS API (SERVER)                      │
├──────────────────────────────────────────────────────────────┤
│                                                                │
│  POST /api/inventory/magic/scan                              │
│                    ↓                                          │
│  ┌─────────────────────────────────────┐                     │
│  │  Phase 1: Simple Validation         │                     │
│  │  ✓ Confidence > 60%?                │                     │
│  │  ✓ Card exists in Scryfall?         │                     │
│  │  ✓ Price seems reasonable?          │                     │
│  │  ✓ Set code valid?                  │                     │
│  │  ✓ No duplicate in last 10 sec?     │                     │
│  └─────────────────────────────────────┘                     │
│                    ↓                                          │
│  ✓ Validation passed                                         │
│                    ↓                                          │
│  ┌─────────────────────────────────────┐                     │
│  │  Add to Database                    │                     │
│  │  - Save to inventory table          │                     │
│  │  - Log scan metadata                │                     │
│  │  - Return inventory ID              │                     │
│  └─────────────────────────────────────┘                     │
│                    ↓                                          │
│  Response: {"success": true, ...}                            │
│                                                                │
└──────────────────────────────────────────────────────────────┘
                     │
                     │ HTTP Response
                     ↓
┌──────────────────────────────────────────────────────────────┐
│                    SCANBOSS AI (CLIENT)                       │
│                                                                │
│  5. Show success message                                     │
│     "✓ Chandra's Embercat added to inventory!"              │
│                                                                │
│  6. Reset for next scan                                      │
│                                                                │
└──────────────────────────────────────────────────────────────┘
```

---

## 🔧 API Endpoints Needed on Server

### **POST /api/inventory/magic/scan**
Add scanned card to inventory

**Request:**
```json
{
  "card_id": "m20-129",
  "confidence": 0.732,
  
  "name": "Chandra's Embercat",
  "set": "m20",
  "set_name": "Core Set 2020",
  "collector_number": "129",
  "type_line": "Creature — Elemental Cat",
  "mana_cost": "{1}{R}",
  "rarity": "Common",
  "image_url": "https://cards.scryfall.io/...",
  "prices": {
    "usd": "0.25",
    "usd_foil": "0.50"
  },
  "oracle_text": "Elemental spells...",
  "power": "2",
  "toughness": "2",
  "scryfall_uri": "https://scryfall.com/...",
  
  "condition": "Near Mint",
  "quantity": 1,
  "is_foil": false,
  
  "scanned_at": "2026-02-22T18:30:00Z",
  "scanner_version": "ScanBoss AI v1.0"
}
```

**Response:**
```json
{
  "success": true,
  "data": {
    "inventory_id": "uuid-here",
    "card": {
      "name": "Chandra's Embercat",
      "set": "m20",
      "price": 0.25
    },
    "message": "Card added successfully"
  }
}
```

**Validation Rules:**
1. ✅ `confidence >= 0.60` (configurable threshold)
2. ✅ `card_id` format valid (set-number)
3. ✅ `set` exists in valid MTG sets
4. ✅ `prices.usd` is reasonable (0.01 - 10000.00)
5. ✅ No duplicate scan in last 10 seconds (prevent double-add)

---

### **POST /api/inventory/magic/validate**
Validate scan before adding (optional pre-check)

**Request:** Same as `/scan`

**Response:**
```json
{
  "success": true,
  "valid": true,
  "warnings": [],
  "info": {
    "estimated_value": 0.25,
    "similar_cards_in_inventory": 0
  }
}
```

---

### **GET /api/inventory/magic**
Get inventory with filters

**Query Params:**
```
?set=m20&rarity=Rare&page=1&per_page=50
```

---

### **GET /api/health**
Health check endpoint

**Response:**
```json
{
  "status": "healthy",
  "version": "2.0.0",
  "database": "connected"
}
```

---

## 📊 Phase 2: AI Gatekeeper (Future)

When you're ready to add server-side AI verification:

### **POST /api/inventory/magic/scan**
Enhanced with AI verification

```
CLIENT sends card_image + card_data
    ↓
SERVER runs VGG16 on image too
    ↓
Compare:
  - Client confidence: 73%
  - Server confidence: 75%
  - Match: TRUE (both agree on m20-129)
    ↓
If mismatch:
  - Log for review
  - Flag low-confidence
  - Request human verification
    ↓
Add to inventory with verification status
```

**Benefits:**
- Catch client-side errors
- Detect tampering
- Build training dataset from mismatches
- Improve model over time

**When to add:**
- After you have 1000+ scans
- If you see data quality issues
- When scaling to multiple users

---

## 🔑 API Key Strategy

### Development (Now):
```python
api_client = MagicAPIClient(
    base_url="http://localhost:8000"
    # No API key needed for local dev
)
```

### Production (Later):
```python
api_client = MagicAPIClient(
    base_url="https://api.vendorboss.com",
    api_key="scanboss_live_abc123xyz"  # Secure key
)
```

**API Key Scopes:**
- `scanboss:read` - Read inventory
- `scanboss:write` - Add cards
- `scanboss:admin` - Full access

---

## 🎯 Current Status

### ✅ Client Side (ScanBoss):
- VGG16 detection working (60-90% accuracy)
- Scryfall integration working (free prices)
- API client ready
- Settings dialog created
- API disabled by default

### ⏳ Server Side (VendorBoss):
- Need to implement `/api/inventory/magic/scan` endpoint
- Need to implement `/api/inventory/magic/validate` endpoint  
- Need to implement `/api/health` endpoint
- Need database schema for Magic inventory

---

## 🚀 Next Steps

### 1. Test Current Setup
```bash
python3 scanboss_ai_live.py
```
- Scan a few cards
- Confirm detection works
- Try clicking ✓ (will show "API disabled")

### 2. Enable API (When Ready)
- Click "⚙️ API Settings"
- Check "Enable VendorBoss API Integration"
- Enter API URL
- Click "Test Connection"
- Click OK

### 3. Build Server Endpoints
Need to create on VendorBoss side:
- Magic inventory table
- Scan logging table
- Validation logic
- Endpoints listed above

---

## 💡 Recommendations

### Start Simple (Phase 1):
✅ Client does AI detection
✅ Server does simple validation
✅ Human (user) confirms each scan
✅ Fast, reliable, works today

### Add Later (Phase 2):
🔮 Server also runs VGG16
🔮 Compare client vs server
🔮 Flag mismatches
🔮 Build training dataset
🔮 Train better models

**Why?**
- Your current setup already has 3 layers of quality control:
  1. VGG16 confidence score (60-90%)
  2. User visual confirmation (✓ or ✗)
  3. Server validation (price, set, duplicates)
  
- Adding AI on server is optimization, not requirement
- Start simple, add complexity only if needed

---

## 📝 Summary

**You asked: "Should we have AI on API as gatekeeper?"**

**Answer: Not yet! Here's why:**

1. **You already have quality control:**
   - VGG16 confidence scores
   - Human verification (✓ button)
   - Simple server validation
   
2. **Phase 1 is faster:**
   - No server-side ML setup
   - Lower server resources
   - Faster responses
   - Simpler to debug

3. **Phase 2 when needed:**
   - After 1000+ scans
   - If data quality issues appear
   - When scaling to multiple users
   - When you want to train better models

**Start with Phase 1, add Phase 2 only if you see bad data getting through!**

The API integration is ready on the client side. Now you just need to build the server endpoints! 🚀
