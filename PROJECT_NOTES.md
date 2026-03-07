# VendorBoss 2.0 — Project Notes

_Last updated: 2026-03-06. Keep this file updated after every session._

---

## Infrastructure

| Item | Value |
|------|-------|
| Repo | `/Users/travisdewitt/Repos/VendorBoss2.0/` |
| Backend server (local) | `192.168.1.37:8001` |
| Backend server (public) | `69.9.234.136` |
| Database | PostgreSQL `localhost:5432`, db: `vendorboss`, user: `vendorboss_user` |
| CI/CD | GitHub Actions with self-hosted runner on Ubuntu server |
| Flutter app | `vendorboss_app/` |
| FastAPI backend | `vendorboss-api/` |

---

## Backend API Modules (all deployed)

| Module | Prefix | Notes |
|--------|--------|-------|
| auth | `/api/auth/` | login, register, me, me/password |
| inventory | `/inventory/` | CRUD, enriched card details |
| shows | `/shows/` | CRUD, close show |
| sales | `/sales/` | record, void |
| expenses | `/expenses/` | CRUD |
| reports | `/reports/` | show-roi, financial-summary, top-performers, inventory-health, channel-performance |
| cards | `/cards/` | search, get by product_id |
| scan | `/scan/` | AI vision via Claude API |

**Critical URL rule:** List/create endpoints use trailing slash (`/inventory/`).
Item-level endpoints (`/inventory/{id}`) must NOT use `ApiConfig.inventory` as prefix
— hardcode the path (`/inventory/$id`) to avoid double-slash 404s.

---

## Database Schema

- `categories` table (29 rows) — integer PKs, replaced legacy `sports` table
- `brands` table (24 rows) — integer PKs
- `products` table — links to `tcg_details` or `card_details`
- `tcg_details` — TCG card catalog (card_name, card_number, set_id, rarity, etc.)
- `card_details` — Sports card catalog (player, team, year, etc.)
- `inventory` — user inventory (product_id FK, quantity, prices, condition, notes)
- `price_history` — market price tracking per product

**Card identity lives in the catalog tables, NOT inventory.**
Editing inventory cannot change card name/set/game — those require delete + re-add.

---

## Flutter App — Screens Status

| Screen | Status | Notes |
|--------|--------|-------|
| Login / Sign Up | ✅ Live | business_name field, password complexity (10 chars, upper/lower/digit/special) |
| Dashboard | ✅ Live | real data from getMe, getShows, getSales, getExpenses |
| Inventory | ✅ Live | paginated, search, game filter chips |
| Card Detail | ✅ Live | reads `_item` in local state, updates on edit save |
| Add/Edit Card | ✅ Live | catalog search widget, save/delete wired to API |
| Shows | ✅ Live | active/past separation |
| Show Detail | ✅ Live | Summary/Sales/Expenses tabs, Close Show |
| Sale Screen | ✅ Live | records transactions to API |
| Add Expense | ✅ Live | create/edit/delete, tap-to-edit on show detail |
| Settings | ✅ Live | real user data, edit profile, change password |
| Scan / Card Recognition | ⚠️ Partial | camera + AI wired, productId not returned from backend yet |
| Listing Management | ❌ Not started | UI placeholder exists in Card Detail |
| Reports (all 7) | ❌ Mock data | framework built, not wired to API |

---

## Flutter App — Known Issues / Functional Gaps

- **General Sales** — no entry point for sales not tied to a show
- **Bulk sale mode** — records against first item instead of proper bulk line items
- **Sale screen search** — doesn't show quantity available or filter sold-out items
- **Void sale** — endpoint exists (`DELETE /sales/{id}`), no UI to trigger it
- **Scan flow** — `ScannedCardData` model missing `productId` field; backend `/cards/identify` needs to return `product_id` when card is recognised
- **Card search game field** — search results return empty `game` string (set_id used as subtitle instead); needs enrichment from product/category join
- **Subscription management** — upgrade flow not built
- **Default buy % / markup settings** — not persisted
- **Platform connections** — TCGPlayer, eBay, Whatnot, Mercari UI exists but no OAuth

---

## Flutter App — Key Architecture Notes

### Auth
- `AuthService` — token storage, 30-day Remember Me tokens
- `ApiService` — singleton, all HTTP calls, `_headers` injects Bearer token
- Email stored lowercase at register/login

### Models
- `InventoryItem.fromApiJson()` — maps API response to model
- `_toDouble()` helper handles PostgreSQL Decimal→String casting
- `Sale`, `Expense`, `Show` all have `fromApiJson()` constructors

### Navigation pattern for edit screens
```dart
Navigator.push<dynamic>(context, ...).then((result) {
  if (result == 'deleted') Navigator.pop(context);
  else if (result is InventoryItem) setState(() => _item = result);
});
```

### Card search response shape
```json
{
  "tcg_cards":    [{ "product_id", "card_name", "card_number", "set_id", ... }],
  "sports_cards": [{ "product_id", "player", "team", "year", "card_number", ... }],
  "total_tcg": 0,
  "total_sports": 0
}
```

---

## Supported Card Categories (29)

**TCG:** Pokemon, Magic, One Piece, FFTCG, Yu-Gi-Oh!, Dragon Ball Super,
Disney Lorcana, Flesh and Blood, Digimon, Star Wars Unlimited,
Weiss Schwarz, Cardfight!! Vanguard

**Sports:** Baseball, Basketball, Football, Hockey, Soccer, Golf,
Boxing/MMA, Wrestling, Multi-Sport

**Non-Sport:** Marvel, DC Comics, Star Wars, WWE, Garbage Pail Kids,
Topps Chrome, Vintage Non-Sport, Anime Cards

---

## Branding

- Logo: Clean solid-color three-card fan with VB monogram
- Style: Bold/energetic, professional, clean/minimal
- Files: `vendorboss_banner.png`, `vendorboss_icon_1024.png`

---

## Remaining Work (Priority Order)

### Immediate (blocking)
1. **Scan flow productId** — backend `/cards/identify` must return `product_id`; update `ScannedCardData` model and `_openScanner()` to set `_selectedProductId`

### High priority
2. **Reports API wiring** — 7 screens all have framework, need real data
3. **General Sales entry point** — FAB or menu item for sales outside shows
4. **Sale screen improvements** — show quantity, filter sold-out items

### Medium priority
5. **Listing Management screen** — populate `_listings` in Card Detail
6. **Card search game enrichment** — join product→category to return game name
7. **Void sale UI** — button on sale line items

### Future
8. Platform OAuth (TCGPlayer, eBay, Whatnot, Mercari)
9. Subscription management / upgrade flow
10. Bulk add from CSV
11. Custom product creation (cards not in catalog)
12. Default buy % and markup persistence
