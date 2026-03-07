# VendorBoss Web - Quick Start

## \ud83d\ude80 Get Started in 3 Steps

### 1. Install
```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0/vendorboss_web
npm install
```

### 2. Run
```bash
npm run dev
```

### 3. Open
Go to **http://localhost:3000**

---

## \u2705 What's Built

All pages are complete with dark theme:

- **Login/Register** - Full authentication
- **Dashboard** - Sales, expenses, profit overview
- **Inventory** - View all cards with search
- **Shows** - Create shows, view performance
- **Sales** - Transaction history with filtering
- **Expenses** - Expense tracking with filtering
- **Reports** - Charts and analytics

## \ud83c\udfa8 Dark Theme

Matches your Flutter app:
- Background: #121212 (grey[900])
- Cards: #1E1E1E (grey[850])
- Accent: #667EEA (purple)

## \ud83d\udcbb Deploy to Ubuntu Server

### Option 1: FastAPI Serves Everything (Easiest)

```bash
# Build the web app
cd /Users/travisdewitt/Repos/VendorBoss2.0/vendorboss_web
npm run build

# Copy to server
scp -r dist/* user@your-server:/path/to/vendorboss-api/static/

# Update main.py to serve static files
# Add this to vendorboss-api/main.py:
from fastapi.staticfiles import StaticFiles
app.mount("/", StaticFiles(directory="static", html=True), name="static")

# Restart API
# Now access at http://your-server:8000
```

### Option 2: Nginx (Production)

```bash
# Build
npm run build

# Copy to server
scp -r dist/* user@your-server:/var/www/vendorboss/

# Configure Nginx (see README.md)
```

## \ud83d\udd27 Development

- Edit files in `src/`
- Hot reload enabled
- API proxied to localhost:8000

## \ud83d\udcca Next Features to Add

- Product creation form
- Edit/delete shows
- Record sales form
- Record expenses form
- PDF export for reports
