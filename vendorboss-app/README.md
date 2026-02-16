# VendorBoss App 2.0

Consumer-facing web application for card identification and inventory management.

## 🚀 Quick Start

```bash
cd vendorboss-app

# Install dependencies
npm install

# Run development server
npm run dev
```

Then open: **http://localhost:3000**

## 📱 Features

### Current (v2.0.0):
- ✅ Image upload / camera capture
- ✅ Card identification via API
- ✅ Display card details and pricing
- ✅ Confirmation feedback (correct/incorrect)
- ✅ Mobile-responsive design

### Coming Soon:
- [ ] Real fingerprint generation from images
- [ ] Inventory management
- [ ] Show/expense tracking
- [ ] User authentication
- [ ] Offline mode

## 🔧 How It Works

1. **Upload/Capture** - Take a photo or upload an image of a card
2. **Identify** - App generates fingerprint and calls `/api/fingerprints/identify`
3. **Review** - See card details, set, rarity, and market pricing
4. **Confirm** - Tell the system if identification was correct (improves accuracy)

## ⚠️ Current Limitations

**Fingerprint Generation Not Implemented:**
- The app currently uses **mock fingerprint data** for testing
- Real implementation requires C++ OpenCV library
- This will be Phase 2 after API is proven

**Testing Without Real Data:**
You can test the UI flow, but identification won't work until:
1. Real cards are added to the database
2. Fingerprints are generated and stored
3. C++ fingerprint generator is built

## 🎯 API Integration

The app connects to your local API at `http://localhost:8000`

Make sure your API is running:
```bash
cd ../vendorboss-api
uvicorn main:app --reload
```

### Endpoints Used:
- `POST /api/fingerprints/identify` - Identify a card
- `POST /api/fingerprints/confirm` - Confirm/reject identification

## 📦 Tech Stack

- **React 18** - UI framework
- **Vite** - Build tool and dev server
- **CSS** - Styling (no framework needed for this size)

## 🔮 Future Enhancements

- **React Native version** for native mobile apps
- **PWA** for installable web app
- **WebAssembly** for client-side fingerprint generation
- **Inventory management** dashboard
- **Barcode scanning** for quick lookups
- **Price alerts** and market tracking

## 🐛 Troubleshooting

**CORS errors?**
- Make sure API has CORS enabled for `http://localhost:3000`
- Check `main.py` in vendorboss-api

**Can't connect to API?**
- Verify API is running on port 8000
- Check browser console for errors

**Images not uploading?**
- Camera access requires HTTPS in production
- For local dev, HTTP is fine

---

**Status:** Working UI, mock data only. Waiting for C++ fingerprint generator.
