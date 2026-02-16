# 🚀 VendorBoss 2.0 - Quick Start Guide

## ✅ What's Been Created

Your complete API is ready! Here's what you have:

```
VendorBoss2.0/
├── README.md              # Full documentation
├── .gitignore            # Git ignore rules
└── vendorboss-api/
    ├── .env.example      # Environment template
    ├── requirements.txt  # Python dependencies
    ├── main.py          # FastAPI application
    ├── database.py      # Database connection
    ├── models.py        # All database models (with TcgDetail!)
    ├── schemas.py       # Request/response schemas
    ├── auth.py          # JWT authentication
    └── api/
        └── fingerprints.py  # Fingerprint endpoints (CORRECTED quadrants)
```

## 🎯 Next Steps (5 minutes)

### 1. Set Up Python Environment

```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0/vendorboss-api

# Create virtual environment
python3 -m venv venv

# Activate it
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure Environment

```bash
# Copy the template
cp .env.example .env

# Edit .env (it already has your Railway DB URL!)
# Just need to generate the secret keys:
```

Generate keys with:
```bash
python -c "import secrets; print('SECRET_KEY=' + secrets.token_urlsafe(32))"
python -c "import secrets; print('SCANBOSS_API_KEY=' + secrets.token_urlsafe(32))"
```

Then paste those into your `.env` file.

### 3. Run the API

```bash
uvicorn main:app --reload
```

Visit: **http://localhost:8000/docs**

You'll see the interactive API documentation! 🎉

## 📊 Create the TcgDetail Table

Your database has everything EXCEPT the `tcg_details` table. Connect to Railway and run:

```sql
CREATE TABLE tcg_details (
    tcg_id VARCHAR PRIMARY KEY DEFAULT gen_random_uuid()::text,
    product_id VARCHAR NOT NULL UNIQUE REFERENCES products(product_id),
    set_id VARCHAR REFERENCES sets(set_id),
    
    card_name VARCHAR NOT NULL,
    card_number VARCHAR,
    rarity VARCHAR,
    card_type VARCHAR,
    
    -- Final Fantasy TCG
    element VARCHAR,
    cost INTEGER,
    power INTEGER,
    job VARCHAR,
    category VARCHAR,
    
    -- Pokemon TCG
    pokemon_type VARCHAR,
    hp INTEGER,
    stage VARCHAR,
    
    -- Magic TCG
    mana_cost VARCHAR,
    color VARCHAR,
    
    -- Common
    text TEXT,
    flavor_text TEXT,
    artist VARCHAR,
    foil BOOLEAN DEFAULT FALSE,
    variant BOOLEAN DEFAULT FALSE,
    variant_name VARCHAR,
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE
);

CREATE INDEX ix_tcg_details_card_name ON tcg_details(card_name);
CREATE INDEX ix_tcg_details_product_id ON tcg_details(product_id);
CREATE INDEX ix_tcg_details_set_id ON tcg_details(set_id);
```

## 🎮 Test It Out

### Register a User

```bash
curl -X POST http://localhost:8000/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@vendorboss.com",
    "password": "test123",
    "username": "testuser"
  }'
```

Or just use the interactive docs at http://localhost:8000/docs

## 🎯 What's Different from Old VendorBoss?

✅ **FIXED:**
- Models match actual database exactly
- Quadrants use correct naming (quadrant_0_0 not quadrant_1)
- TcgDetail table for Final Fantasy TCG
- Clean code, no legacy cruft
- Proper environment variables

✅ **READY FOR:**
- Final Fantasy TCG proof of concept
- Sports cards expansion later
- C++ fingerprint generator
- ScanBoss and VendorBoss apps

## 📝 Next Phase: Data

Once the API is running:

1. Add FF TCG sets to `sets` table
2. Manually add 50-100 cards to test
3. Build C++ fingerprint generator
4. Test identification accuracy
5. Build ScanBoss app

## 🐛 Troubleshooting

**Can't activate venv?**
```bash
# Make sure you're in the right directory
cd /Users/travisdewitt/Repos/VendorBoss2.0/vendorboss-api
source venv/bin/activate
```

**Import errors?**
```bash
# Make sure venv is activated (you should see (venv) in your prompt)
# Then reinstall:
pip install -r requirements.txt
```

**Database connection error?**
- Check `.env` file exists
- Verify DATABASE_URL is correct
- Test connection to Railway PostgreSQL

**SECRET_KEY not set?**
- Make sure you copied `.env.example` to `.env`
- Generate and add SECRET_KEY and SCANBOSS_API_KEY

---

**You're all set!** 🎉 Run `uvicorn main:app --reload` and start testing!
