# VendorBoss 2.0

**Card identification and inventory management system using visual fingerprinting**

## 🎯 Project Overview

VendorBoss 2.0 is a complete rewrite focused on **Final Fantasy Trading Card Game** as a proof of concept, with plans to expand to sports cards once fingerprinting is proven.

### Three Applications

1. **VendorBoss API** (This repo) - FastAPI backend with fingerprint database
2. **ScanBoss** - Learning application that builds the fingerprint database
3. **VendorBoss** - Consumer app for card identification and inventory

### Why Final Fantasy TCG First?

- Only 27 sets vs thousands of sports card sets
- Official card images available at https://fftcg.square-enix-games.com/na/card-browser
- Manageable scope to prove fingerprinting concept
- Structured data and consistent image quality

## 🏗️ Architecture

### Database Structure

**Products** - Generic table for all sellable items
- Cards (via `card_details` for sports, `tcg_details` for TCG)
- Packs (via `pack_details`)
- Boxes (via `box_details`)

**Fingerprints** - Multi-component visual fingerprints
- 14 components: border, name_region, color_zones, texture, layout, 9 quadrants
- MD5 hash (truncated to 16 hex chars) for each component
- SHA256 composite hash for exact matching
- Confidence scoring and verification tracking

**Pricing** - Market price tracking
- Multiple sources (eBay, COMC, 130Point)
- Raw and graded pricing
- 15-day rolling average with fallback to last known price

### API Endpoints

#### Fingerprints (core functionality)
- `POST /api/fingerprints/submit` - ScanBoss submits learned fingerprints (API key)
- `GET /api/fingerprints/model` - ScanBoss downloads high-confidence fingerprints (API key)
- `POST /api/fingerprints/identify` - VendorBoss identifies cards (public)
- `POST /api/fingerprints/confirm` - User confirms/corrects identification (public)

#### Authentication
- `POST /api/auth/register` - Create account
- `POST /api/auth/login` - Get JWT token
- `GET /api/auth/me` - Get current user

## 🚀 Getting Started

### Prerequisites

- Python 3.11+
- PostgreSQL 17+
- pip

### Installation

```bash
cd vendorboss-api
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Edit .env with your database credentials
```

### Environment Variables

```bash
DATABASE_URL=postgresql://user:password@host:port/database
SECRET_KEY=your-secret-key-for-jwt
SCANBOSS_API_KEY=your-scanboss-api-key
```

### Running Locally

```bash
uvicorn main:app --reload
```

API docs: http://localhost:8000/docs

## 📋 Roadmap

### Phase 1: Proof of Concept (Current)
- [x] Build clean API with fingerprint system
- [x] Add authentication (JWT + API keys)
- [x] Create TcgDetail model for FF TCG
- [ ] Seed database with FF TCG sets
- [ ] Manually add 50-100 FF TCG cards
- [ ] Build C++ fingerprint generator
- [ ] Test fingerprinting on FF TCG

### Phase 2: ScanBoss Alpha
- [ ] Build ScanBoss desktop app (C++ core)
- [ ] OpenCV image processing
- [ ] Camera integration
- [ ] Local fingerprint caching
- [ ] API submission workflow

### Phase 3: VendorBoss Alpha  
- [ ] Build VendorBoss mobile app
- [ ] Card scanning and identification
- [ ] Inventory management
- [ ] Show/expense tracking

### Phase 4: Expansion
- [ ] Add sports cards (hockey, baseball, football, basketball)
- [ ] Add more TCGs (Pokemon, Magic)
- [ ] Community features
- [ ] Marketplace integration

## 🔧 Technical Decisions

### Fingerprinting Approach

**Why not AI/ML for matching?**
We use exact hash matching instead of fuzzy AI matching because:
- Same set cards look nearly identical (different player photo only)
- Fuzzy matching could return Michael Jordan when you scanned Larry Bird
- Exact matching is fast, deterministic, and doesn't require training data
- Components handle lighting/angle variations for the same card

**Hash Algorithm Choice:**
- Individual components: MD5 truncated to 16 hex chars (2^64 values)
- Composite: SHA256 full 64 chars
- Why: Standard across platforms, deterministic, built-in everywhere

### Database Design

**Why separate detail tables?**
- Products table is generic for ALL sellable items
- card_details for sports cards (player, team, position)
- tcg_details for trading card games (element, cost, power)
- Allows future expansion (jerseys, boxes, packs, etc.)

### Authentication

- **ScanBoss**: API key (simple, sufficient for learning system)
- **VendorBoss**: JWT tokens (user-specific inventory/data)
- **Public endpoints**: No auth (identify, confirm)

## 📝 Development Notes

### Current Status

Clean rebuild with:
- ✅ models.py matching actual database schema
- ✅ Fingerprint endpoints with confirmation loop
- ✅ Authentication system
- ✅ Pricing system with 15-day rolling average
- ✅ TcgDetail model for FF TCG

---

**Version**: 2.0.0  
**Last Updated**: December 30, 2024
