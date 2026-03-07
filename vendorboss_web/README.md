# VendorBoss Web Dashboard

Web interface for VendorBoss TCG vendor management system with dark theme matching the mobile app.

## Features

✅ **Complete Feature Set:**
- Login/Register with authentication
- Dashboard with sales, expenses, and profit overview
- Inventory management with search
- Show management with create/view/track functionality
- Sales tracking with show filtering
- Expense tracking with show filtering
- Reports & Analytics with charts (Recharts)

🎨 **Dark Theme:**
- Matches Flutter app dark mode
- Grey[900] background (#121212)
- Grey[850] cards (#1E1E1E)
- Purple accent (#667EEA)
- Optimized for big screen viewing

## Setup

### 1. Install Dependencies

```bash
cd /Users/travisdewitt/Repos/VendorBoss2.0/vendorboss_web
npm install
```

### 2. Start Development Server

```bash
npm run dev
```

The app will run on **http://localhost:3000**

API requests are automatically proxied to **http://localhost:8000**

### 3. Build for Production

```bash
npm run build
```

This creates a `dist/` folder with static files.

## Deployment Options

### Option A: Serve from FastAPI (Recommended)

1. Build the React app:
```bash
npm run build
```

2. Update FastAPI to serve static files:
```python
# In vendorboss-api/main.py
from fastapi.staticfiles import StaticFiles

app.mount("/", StaticFiles(directory="../vendorboss_web/dist", html=True), name="static")
```

3. Access at http://your-server:8000

### Option B: Nginx (Production)

1. Build the app
2. Copy `dist/` to `/var/www/vendorboss`
3. Configure Nginx:

```nginx
server {
    listen 80;
    server_name vendorboss.local;

    root /var/www/vendorboss;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /api {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Tech Stack

- **React 18** - UI framework
- **Vite** - Build tool
- **TailwindCSS** - Styling with custom dark theme
- **React Router** - Navigation
- **Recharts** - Charts and analytics

## Project Structure

```
vendorboss_web/
├── src/
│   ├── pages/
│   │   ├── Login.jsx          # Authentication
│   │   ├── Dashboard.jsx      # Main overview
│   │   ├── Inventory.jsx      # Card inventory
│   │   ├── Shows.jsx          # Show management
│   │   ├── Sales.jsx          # Sales tracking
│   │   ├── Expenses.jsx       # Expense tracking
│   │   └── Reports.jsx        # Analytics & charts
│   ├── components/
│   │   └── Layout.jsx         # Navigation layout
│   ├── api.js                 # API service
│   ├── App.jsx                # Router setup
│   ├── main.jsx               # Entry point
│   └── index.css              # TailwindCSS
├── package.json
├── vite.config.js
└── tailwind.config.js
```

## API Integration

The web app uses the same API endpoints as the mobile app:

- `POST /api/auth/login` - Login
- `POST /api/auth/register` - Register
- `GET /api/auth/me` - Get user profile
- `GET /api/inventory` - List inventory
- `GET /api/shows` - List shows
- `GET /api/shows/{id}` - Show summary
- `POST /api/shows` - Create show
- `GET /api/sales` - List sales
- `GET /api/expenses` - List expenses
- `GET /api/reports/show-roi` - Show ROI report
- `GET /api/reports/financial-summary` - Financial summary

## Development Notes

- Token stored in `localStorage`
- Auto-redirects to login on 401
- Dark theme by default
- Responsive design (mobile-friendly)
- All API calls go through `/api` proxy

## Next Steps

- [ ] Add product creation UI
- [ ] Implement edit/delete for shows
- [ ] Add sale recording form
- [ ] Add expense recording form
- [ ] Export reports to PDF
- [ ] Add user settings page

---

**Built with ❤️ for VendorBoss 2.0**
