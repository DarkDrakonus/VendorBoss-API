# VendorBoss 2.0 — Project Notes

_Last updated: 2026-03-07. Keep this file updated after every session._

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

## ScanBoss

### Vision
ScanBoss is a separate product line that extends VendorBoss into hardware-assisted card scanning and sorting. It shares the same backend API and user account as VendorBoss — vendors log into ScanBoss with their VendorBoss credentials and all data syncs automatically.

ScanBoss is intentionally a separate app/program (not integrated into VendorBoss) to keep VendorBoss lean and to allow ScanBoss to run on desktop as well as mobile.

### Product Tiers

| Product | Description |
|---------|-------------|
| **ScanBoss S** (Small/Portable) | Lightweight briefcase form factor for vendors at shows |
| **ScanBoss Desktop** | Software-only version for home/hobbyist use with a webcam |
| **ScanBoss Pro** | Future large-format commercial version for card shops with high volume |

### ScanBoss S — Hardware Design

A portable briefcase that:
- Folds open to reveal **6 configurable sorting bins**
- Has a **vacuum arm** that physically routes cards to the correct bin
- Has a **device dock** at the top that accepts the vendor's phone or tablet
- Has an **internal power supply** that powers the sorter AND charges the docked device
- Connects to the docked device via **USB-C** for communication and control

**Adapter System:**
Because phones and tablets have different form factors and charging ports, ScanBoss S uses a swappable adapter in the dock. Each adapter:
- Positions the device so the camera is always in the exact spot
- Connects to the device's native charging port (Lightning, USB-C, etc.)
- Has a standard USB-C output that plugs into the sorter

This means the sorter hardware never changes — vendors just buy a new adapter if they upgrade their device.

**Communication chain:**
```
Phone/Tablet camera → VendorBoss/ScanBoss app → API (AI identification)
                                                        ↓
                                              Sort decision returned
                                                        ↓
Phone/Tablet → USB-C adapter → Sorter USB-C → Microcontroller → Vacuum arm
```

### Sort Profiles
Before each session the vendor configures what each of the 6 bins represents. Profiles are saved and reusable. Examples:

- **By game:** Bin 1=Pokémon, Bin 2=Magic, Bin 3=Baseball, Bin 4=One Piece, Bin 5=Other TCG, Bin 6=Unknown
- **By value:** Bin 1=<$1, Bin 2=$1–$5, Bin 3=$5–$25, Bin 4=$25–$100, Bin 5=$100+, Bin 6=Needs Review
- **By set:** Sort within a single game by set or era
- **Custom/mixed:** e.g. High-value Pokémon, Bulk Pokémon, Magic rares, Magic bulk, Sports, Junk

Any card the AI cannot confidently identify routes to the **Unknown/Needs Review** bin automatically.

### Session Modes
The same hardware supports multiple workflows — vendor picks a mode at the start of each session:

| Mode | Use Case |
|------|----------|
| **Inventory Intake** | Scan new stock, bulk-add to inventory with pricing |
| **Buying a Collection** | Scan cards being purchased, get instant market prices, sort by value |
| **Collection Appraisal** | Scan a customer's collection, get total estimated value |
| **Show Prep** | Scan what you're bringing to a show, verify against inventory |
| **Inventory Audit** | End-of-show reconciliation — scan remaining cards vs what sold |
| **Point of Sale** | Scan single cards at the table, pull asking price, record sale |

### API Integration
ScanBoss hits the same VendorBoss backend. Relevant endpoints:
- `/scan/` — AI vision via Claude API (already exists)
- `/inventory/` — bulk-add scanned cards
- `/sales/` — record sales from scan sessions
- `/cards/` — card search and lookup

Sort profiles will need new endpoints:
- `GET/POST /scan-profiles/` — save and load sort profiles
- `POST /scan-sessions/` — start a session, batch-commit results

### ScanBoss Desktop
Software-only version for home users:
- Uses a webcam instead of phone camera
- No sorting hardware — just identification and batch inventory add
- Built with Flutter Desktop (cross-platform: Mac, Windows, Linux)
- Same API, same credentials as VendorBoss mobile

### Business Model
- VendorBoss app (free/subscription) acts as the sales funnel
- ScanBoss S is the premium hardware upsell for serious vendors
- Adapters are low-cost accessories sold per device type
- ScanBoss Desktop is a software subscription or one-time purchase
- ScanBoss Pro (future) targets card shops and high-volume buyers

### Development Status
- ❌ ScanBoss app — not started
- ❌ Sort profile API endpoints — not started
- ❌ Hardware design/prototyping — concept stage
- ❌ Microcontroller firmware — not started
- ⚠️ `/scan/` API endpoint — exists but `product_id` not returned yet (blocking for all scan flows)

---

## Web App (vendorboss_web)

Started by Travis using Amazon Q. React + Vite + Tailwind stack.
Location: `/Users/travisdewitt/Repos/VendorBoss2.0/vendorboss_web/`

| File | Notes |
|------|-------|
| `src/api.js` | API client (mirrors Flutter ApiService) |
| `src/pages/Login.jsx` | Auth |
| `src/pages/Dashboard.jsx` | Dashboard |
| `src/pages/Inventory.jsx` | Inventory list |
| `src/pages/Shows.jsx` | Shows |
| `src/pages/Sales.jsx` | Sales |
| `src/pages/Expenses.jsx` | Expenses |
| `src/pages/Reports.jsx` | Reports |
| `src/pages/Placeholder.jsx` | Placeholder for unbuilt screens |
| `src/components/Layout.jsx` | Shared nav/layout wrapper |

Status: early stage, needs review to determine what's wired vs placeholder.

---

## Remaining Work (Priority Order)

### Immediate (blocking)
1. **Scan flow productId** — backend `/cards/identify` must return `product_id`; update `ScannedCardData` model and `_openScanner()` to set `_selectedProductId`

### High priority
2. **Reports API wiring** ✅ DONE — all 7 screens wired to real API; mock data fully removed
   - `financial_summary_report.dart` — was already wired
   - `show_roi_report.dart` — was already wired
   - `top_performers_report.dart` ✅ now wired (`/reports/top-performers` enhanced with card_name, game)
   - `inventory_health_report.dart` ✅ now wired (`/reports/inventory-health` enhanced with item detail + price drift)
   - `channel_performance_report.dart` ✅ now wired (`/reports/channel-performance`; shows payment methods)
   - `bulk_effectiveness_report.dart` ✅ now wired (new `/reports/bulk-sales` endpoint; detects bulk by notes)
3. **General Sales entry point** ✅ DONE — dashboard has `_GeneralSalesCard` with "New Sale" button; FAB uses active show or general
4. **Sale screen improvements** ✅ DONE — filters sold-out items (quantity > 0), shows qty in search results

### Medium priority
5. **Listing Management screen** — populate `_listings` in Card Detail
6. **Card search game enrichment** — join product→category to return game name
7. **Void sale UI** — button on sale line items

### Future — Platform & Monetization
8. Platform OAuth (TCGPlayer, eBay, Whatnot, Mercari)
9. Subscription management / upgrade flow
10. Bulk add from CSV
11. Custom product creation (cards not in catalog)
12. Default buy % and markup persistence

---

## Future Features (Planned — Not Started)

### Connection Marketplace

**Overview:**
A section within VendorBoss where vendors can connect their account to third-party platforms and data services. Similar to how apps like Shopify handle integrations — a grid of available connections, each with a connect/disconnect toggle and OAuth or API key flow. Some connections enable inventory syncing (push listings to selling platforms), others enable price data (pull market prices into VendorBoss).

**Two categories of connection:**
1. **Selling Platforms** — sync inventory and receive orders from external marketplaces
2. **Price Data APIs** — pull real-time and historical pricing to inform buy/sell decisions

---

#### Selling Platform Connections

| Platform | Status | Notes |
|----------|--------|-------|
| **TCGPlayer** | ❌ No access | API no longer offered to third-party developers |
| **CardTrader** | ✅ Available | JWT token auth via developer dashboard. Supports inventory create/update/delete, marketplace listings, webhooks. Other tools (TCG Sync, SortSwift) already integrate with it successfully. |
| **Card Kingdom** | ⚠️ Investigate | No clear public seller API for cardkingdom.com. Price data accessible via MTGJSON. Needs direct outreach to confirm seller integration availability. |
| **CardSphere** | ⚠️ Investigate | Price data available via MTGJSON but no confirmed seller/inventory API found. Needs research. |
| **Mana Pool** | ✅ Available | Has published API docs at `manapool.com/api/docs/v1`. MTG-specific marketplace. Shopify sync app already exists suggesting API is active and accessible. |
| **eBay** | ✅ Available | Well-established Sell API. Covers both sports cards and TCG. Requires OAuth. Supports listing creation, order management, and sold order history. |
| **COMC** | ❌ No access | API not available |
| **CollX** | ❌ No access | API not offered |

**What selling platform integration enables:**
- Push VendorBoss inventory listings to connected platforms automatically
- Pull sold orders back into VendorBoss to update inventory and record sales
- Centralized multi-platform inventory management without manual re-entry
- Channel performance report becomes truly useful with real sold data per platform

---

#### Price Data Connections

| Service | Coverage | Notes |
|---------|----------|-------|
| **Card Hedge AI** | Sports cards + TCG | Pulls real-time prices and historical sales from eBay, Heritage Auctions, and Fanatics. 40M+ weekly sales tracked, 2M+ cards, API plans start at $49/month. Supports fuzzy matching, graded prices (PSA, BGS, CGC), ML-ready data formats. Developer API at `ai.cardhedger.com`. Strong candidate for VendorBoss's primary price data source. |
| **MTGJSON** | MTG only (price data) | Free, open data. Includes CardKingdom, CardSphere, CardTrader, and TCGPlayer buy/sell prices. Good for MTG price reference even if direct API access to those platforms isn't available. |

**What price data integration enables:**
- Real-time market prices shown in inventory and on the scan screen
- Buy calculator uses live data instead of manually entered values
- Price drift report becomes genuinely useful (tracks changes over time)
- Inventory health report can flag cards where vendor is underwater vs current market
- Automatically suggests asking prices when adding new inventory

---

**VendorBoss UI concept:**
```
Settings → Connections

┌─────────────────────────────────────┐
│ Selling Platforms                   │
│                                     │
│ [CardTrader]    ● Connected  Manage │
│ [Mana Pool]     ○ Connect           │
│ [eBay]          ○ Connect           │
│ [TCGPlayer]     ✗ Unavailable       │
│                                     │
│ Price Data                          │
│                                     │
│ [Card Hedge AI] ○ Connect           │
│ [MTGJSON]       ● Active (free)     │
└─────────────────────────────────────┘
```

**Development Status:** ❌ Not started — OAuth flows and API integrations not built. CardTrader, Mana Pool, and Card Hedge AI are the highest-priority connections to build first.

---

### Card DNA — Individual Card Tracking & Barcode System

**Overview:**
Every individual card that a vendor wants to track gets a unique GUID assigned to it in VendorBoss. That GUID is converted to a barcode and printed on a small thermal sticker that the vendor applies to the card sleeve, top loader, or case. From that point forward, that specific physical card has a permanent, scannable identity that follows it through every transaction — regardless of how many times it changes hands.

This is essentially a **VIN number for individual trading cards.**

**How It Works:**
1. Vendor selects a card in their inventory and chooses "Generate Card ID"
2. VendorBoss generates a GUID for that specific physical copy
3. GUID is converted to a barcode (Code 128 or QR code — TBD)
4. Vendor prints the sticker on a small thermal label printer
5. Sticker goes on the card's sleeve/holder
6. Every time that card is bought or sold through VendorBoss, the transaction is appended to that card's history
7. Any VendorBoss user who scans the barcode can see the card's full transaction history and instantly add it to their own inventory with all historical data attached

**What Data Travels With Each Card:**
- Card identity (product_id, name, set, condition at each transaction)
- Purchase price at each transfer
- Sale price at each transfer
- Profit/loss at each transfer
- Date of each transaction
- How long each owner held it
- Condition changes over time (if noted)

**The Viral / Acquisition Mechanic:**
When a buyer receives a stickered card, they have a reason to sign up for VendorBoss to scan it and see the history. The physical sticker becomes a word-of-mouth acquisition channel. Vendors who sticker their cards are also invested in the ecosystem — those stickers only work in VendorBoss.

**The Proprietary Pricing Data Play:**
This is the long-term strategic value. As more cards accumulate transaction histories:
- VendorBoss builds its own real-world pricing dataset from actual vendor-to-vendor transactions
- Unlike eBay or TCGPlayer data (which reflects retail/auction prices), this is dealer-to-dealer pricing
- For cards with enough history, VendorBoss can provide its own market analysis — average sale price over time, price trend, typical hold duration, etc.
- Example: 5 Connor Bedard rookie cards each bought/sold 10 times = 50 real transactions with rich context. Average them and you have statistically meaningful data on that card's real-world market behavior that no competitor has.
- Over time this becomes a **proprietary data moat** that gets more valuable the more vendors use the platform

**Hardware Integration:**
Works with any small thermal label printer. Popular options to recommend/support:
- Dymo LabelWriter series
- Brother QL series
- Phomemo / Munbyn pocket printers (popular with card vendors already)

VendorBoss generates the label-ready output; vendor prints from any compatible device.

**ScanBoss Integration:**
The ScanBoss S barcode scanner could scan these stickers as part of a session:
- Scan a stickered card → instantly pull up full history + current owner's inventory record
- In Point of Sale mode: scan sticker → price auto-populated → record sale → history updated
- In Buying mode: scan sticker → see what previous owners paid → make informed offer

**New Database Concepts Required:**
- `card_instances` table — one row per stickered physical card
  - `instance_id` (GUID, the barcode value)
  - `product_id` (FK to catalog)
  - `created_by` (vendor who first stickered it)
  - `created_at`
- `card_instance_history` table — one row per transaction involving a stickered card
  - `instance_id` (FK)
  - `transaction_type` (purchase / sale)
  - `price`
  - `condition`
  - `owner_id` (vendor)
  - `transaction_date`
  - `notes`

**New API Endpoints Required:**
- `POST /card-instances/` — generate a new GUID for a card, return barcode data
- `GET /card-instances/{guid}` — public or authenticated lookup of a card's full history
- `GET /card-instances/{guid}/label` — return label-ready barcode image for printing
- `POST /card-instances/{guid}/transfer` — record a new transaction on a tracked card

**New UI Required:**
- "Generate Card ID" button on Card Detail screen
- Print label flow (select printer size/format, preview, print)
- Card History view — timeline of all transactions for a stickered card
- Barcode scanner integration on Scan screen to look up stickered cards
- Market analysis view for cards with enough history (price trend chart)

**VendorBoss Market Data (Long-Term):**
Once enough transaction history accumulates, VendorBoss can surface:
- Average sale price by card (dealer-to-dealer, not retail)
- Price trend over time (appreciation / depreciation)
- Average hold time before resale
- Liquidity score (how quickly does this card typically sell)
- Condition drift (do cards in this set tend to degrade condition over time)

This data could eventually become a premium feature, a published price guide, or a data product sold to other platforms.

**Development Status:** ❌ Not started — concept stage. Thermal printer integration and GUID/barcode generation are the first pieces to prototype.

---

### Show Discovery & Customer Card Search ("ShowFloor")

**Overview:**
Transforms VendorBoss from a vendor-only tool into a two-sided platform. A customer at a card show scans a QR code at the entrance, lands on a live search page for that show, and can find which vendor has the card they're looking for and at what price — no app download, no login required.

This feature should only be built after VendorBoss has meaningful market penetration. It only delivers value when enough vendors at a given show are using it.

**The Three Stakeholders:**

| Stakeholder | Role |
|-------------|------|
| **Event Organizer** | Registers the show in VendorBoss, assigns table numbers to vendors, generates QR code for entrance |
| **Vendor** | Joins a show from the global events database, opts in to making their inventory searchable, inventory updates automatically as sales are recorded |
| **Customer** | Scans QR code at entrance, searches for specific cards, gets directed to the right table with price |

**How It Works:**
1. VendorBoss maintains a global `events` database of known card shows (organizer-submitted and VendorBoss-maintained)
2. Event organizer registers their show, gets a unique QR code, assigns table numbers to vendors
3. Vendors find their show via search instead of creating it manually — they join the existing event
4. Vendors opt in to customer-facing inventory visibility (default off, encouraged on)
5. Customer scans QR at entrance → lands on public show search page (no login)
6. Customer searches "Black Lotus" → sees which vendors have it, at what price, and at which table
7. Inventory accuracy is maintained automatically since VendorBoss updates inventory on every recorded sale

**Vendor Opt-In Rationale:**
Some vendors may worry about customers only visiting their table for one card. The counter-argument is strong — a customer searching for a specific card is a warm lead walking directly to that table, and often buys more once they're there. Most vendors will opt in once they understand this.

**New Database Concepts Required:**
- `events` table — global show database (name, date, location, organizer, recurring flag, venue)
- `event_vendors` — junction table (event_id, vendor_id, table_number, table_name, opt_in_searchable)
- `event_organizers` — new user type distinct from vendors
- QR codes that resolve to a public, unauthenticated show search URL scoped to a specific event

**New API Endpoints Required:**
- `GET /events/` — public list of upcoming shows (searchable by location/date)
- `GET /events/{id}` — show detail + vendor list
- `GET /events/{id}/search?q=` — public unauthenticated card search scoped to show (only opted-in vendors)
- `POST /events/` — organizer creates a show
- `POST /events/{id}/vendors` — vendor joins a show
- `GET /events/{id}/qr` — generate QR code for show entrance

**New User Type — Event Organizer:**
Organizers need their own dashboard to:
- Register and manage their shows
- Invite/manage vendor list and table assignments
- Generate and download QR codes
- View show analytics (how many customers used the search, most searched cards, etc.)

**Public Customer Experience:**
- No app download required
- No account required
- Accessed entirely via QR code → mobile web browser
- Search returns: card name, condition, price, vendor name, table number
- Simple, fast, read-only

**Inventory Accuracy:**
Not a significant technical problem — VendorBoss already updates inventory in real time on every recorded sale. The only edge case is a vendor who completes a cash sale without logging it immediately. This is a vendor behavior issue, not a software issue. Could add a "flag as potentially sold" mechanic if needed later.

**Development Status:** ❌ Not started — planned for after VendorBoss has firm market foothold

---

## Competitor Analysis

_Track competitors here to inform product decisions and identify gaps/opportunities._

---

### SortSwift (sortswift.com)

**Target customer:** Established card shops (LGS — Local Game Stores) with physical locations and online stores. High-volume operations.

**What they offer:**

| Module | Details |
|--------|---------|
| Inventory | Chaos sorting (mixed piles), location tracking, bulk lots |
| POS | Zero commission checkout |
| Buylist | Customer-facing portal, automated pricing, multi-language |
| Autopricing | 23-step drag-and-drop pricing engine, per-platform configs, daily auto-update |
| Syncing | Shopify, eBay, CardTrader, Mana Pool (full sync); TCGPlayer (Chrome extension semi-sync) |
| Card Scanning | AI recognition, 26+ TCGs, 99.9% claimed accuracy, web + mobile + document scanner |
| Kiosk | In-store self-service browsing terminal for customers |
| Mobile App | Free, 500 scans/month, in-person trading, collection management |
| Reporting | Sales reports, price trend analytics |
| Consignment | Coming soon |

**Hardware:**
- **Super Sorter** — 29-bin automated sorting machine, ~3,000 cards/hour, handles sleeved/raw/toploaded cards. Built with MTech Cave. Raspberry Pi-based, uses Ricoh document scanner. Large, stationary machine — not portable.
- **Simple Sifter** — Raspberry Pi appliance supporting up to 4 Fujitsu scanners in parallel. Desktop scanning station.

**Pricing:**
- **Free tier** — 2,500 inventory items, 500 AI scans/month, CSV suite, TCGPlayer semi-sync
- **Autopricing** — from $15.99/month (per game, scales up)
- **Bundles** — modular, up to ~40% savings vs à la carte (exact prices behind signup)
- **Super Sorter** — $199/month subscription, unlimited basic sorts (separate from software)
- No transaction/commission fees on any plan

**Card coverage:** TCG-focused (26+ games). Sports cards only via PriceCharting add-on — not native.

**Integrations:** Shopify, eBay, CardTrader, Mana Pool, TCGPlayer. Square, WooCommerce, Walmart coming soon.

**220+ stores** currently on the platform.

---

**Where VendorBoss is differentiated from SortSwift:**

| Area | SortSwift | VendorBoss |
|------|-----------|------------|
| Target customer | Card shops / LGS | Individual vendors at shows |
| Show tracking | ❌ None | ✅ Core feature (P&L per show) |
| Expense tracking | ❌ None | ✅ Core feature |
| Sports cards | ⚠️ Add-on only | ✅ Native support |
| Portable hardware | ❌ Stationary only | ✅ ScanBoss S (briefcase form factor) |
| Customer show search | ❌ None | 🗓️ Planned (ShowFloor) |
| Pricing | Subscription per module | TBD |
| Free tier | ✅ Yes | TBD |

**Key insight:** SortSwift owns the card shop / LGS market. VendorBoss owns the traveling vendor / show market. These are largely different customers with different needs. Direct competition is limited in the short term, but SortSwift could expand into the show vendor space as they grow.

**Watch for:** Their patent-pending Super Sorter hardware — if they release a portable version, that directly competes with ScanBoss S.

---

## Future Roadmap & Design Ideas

_Captured observations, architectural improvements, and feature ideas for future sessions._
_Not prioritized — use this as a backlog to pull from._

### Backend / Data Model

- **`is_bulk` column on `inventory_transactions`** — bulk detection currently relies on `'bulk'` appearing in `notes`, which is fragile. Add a proper boolean `is_bulk` column. Bulk sales recorded via the Bulk Sale toggle in the sale screen should set this flag. Avoids notes being repurposed for filtering.
- **General sales in reports** — Show ROI report matches sales by `show_name`; any sale with `show_id = NULL` is silently excluded from all show-level reports. Need a "General Sales" row in the ROI report and financial breakdown.
- **COGS per month in financial summary** — the monthly chart calculates `net = revenue - expenses` but does not subtract COGS on a per-month basis. Net profit looks inflated relative to what Schedule C would show. Fix: join `inventory_transactions` → `inventory.purchase_price` per month.
- **Orphaned inventory items** — if a product has no `tcg_details` or `card_details` row, `fromApiJson` falls back to `card_name: 'Unknown Card'`. Need an audit query and/or a catalog cleanup tool to identify and fix these.
- **Price history tracking** — `price_history` table exists but nothing writes to it. Could auto-log market price changes from scan confirmations or manual edits to power the Price Drift report over time rather than just a point-in-time snapshot.
- **Transaction soft-delete / void flag** — voiding a sale currently hard-deletes the record. Consider a `voided_at` timestamp and `void_reason` text column so voided sales still appear in reports as negative line items.

### Reports

- **General Sales in Show ROI** — add a synthetic "General Sales" entry at the bottom of the Show ROI report for transactions with no show_id
- **Monthly COGS breakout** — add COGS line to the monthly financial chart so gross profit vs net profit are both visible
- **YTD vs prior year comparison** — financial summary currently only shows one year; add a year picker and prior-year comparison column
- **Expense category breakdown** — the Expenses tab on Financial Summary currently just shows the total and lists category names. Wire to a real `/reports/expense-breakdown` endpoint that sums by `expense_type`
- **Top performers: set-level rollup** — currently ranks individual inventory items; add a "By Set" view that rolls up all copies of the same product_id into one row
- **Inventory health: restock recommendations** — if a card sold quickly (< 7 days) and at high margin, surface it as a "buy more" candidate in the health report
- **Bulk sales: per-show trend line** — the Bulk Effectiveness report has by-show cards but no trend chart showing bulk % over time show-by-show. Add a mini sparkline similar to the Show ROI trend chart.

### Sale Screen

- **Oversell guard** — if order quantity exceeds `available_quantity`, show a warning or cap the stepper. Currently no check exists.
- **Sale screen: show current market price vs asking price delta** — already shows discount %, but could add a "below cost" warning if `salePrice < purchasePrice`
- **Quick price suggestions** — when adding a card to the order, pre-suggest: market price, asking price, minimum price as tap targets instead of always opening the edit dialog
- **Payment split** — some transactions are split (e.g. partial cash + partial trade). Current model assumes a single payment method per line item.

### Inventory

- **Bulk import from CSV** — let vendor upload a spreadsheet of cards to add in one shot. Map columns to `InventoryCreate` fields. Good for migrating from a spreadsheet workflow.
- **Storage location browser** — filter inventory by `storage_location` / `box_number`. Useful at shows when looking for a specific box.
- **Print price tags / labels** — generate a printable sheet of price stickers (card name, condition, asking price) from a filtered inventory selection.
- **Batch price update** — select multiple cards and apply a % markup/markdown across all asking prices at once.
- **Featured items toggle** — `featured` boolean exists in the schema and UI model but nothing surfaces it. Could be used to mark cards for a display case or showcase at shows.

### Scan

- **Scan flow productId** _(blocking, already in priority list)_ — `/cards/identify` needs to return `product_id` when a card is matched
- **Scan-to-sale shortcut** — after scanning a card that's already in inventory, offer a "Sell" button directly on the recognition result screen without going through the full Add/Edit flow
- **Scan bulk mode** — rapid-fire scan multiple cards in sequence, confirm/reject each quickly, add all to inventory in one batch save
- **Scan confidence threshold UI** — the AI returns a confidence score; show it to the vendor so they know when to trust the match vs verify manually

### Card Catalog

- **Card search game enrichment** _(already in medium priority)_ — search results return empty `game` string; needs a product→category join
- **Custom product creation** — vendor can create a card not in the catalog (custom set, promo, misprint, etc.) and add it to inventory with a manual product record
- **Catalog image quality** — some `image_url` values are missing or return 404s. Add a fallback placeholder and/or a background job to validate image URLs
- **Set completion tracker** — for collectors, show how many cards from a given set the vendor has vs total cards in the set

### Channel / Marketplace Integration

- **TCGPlayer OAuth** — pull actual sold listings and fees directly from the TCGPlayer seller API; reconcile with VendorBoss sales records
- **eBay OAuth** — same; eBay Sell API for sold order history and final value fees
- **Whatnot OAuth** — Whatnot seller API for show auction results
- **Mercari** — REST API exists but requires approval; lower priority
- **Channel performance report v2** — once real marketplace data is available, replace the payment-method breakdown with true per-platform revenue, fee, and net margin data

### Web App (vendorboss_web)

- **Full audit needed** — Amazon Q scaffold exists but status of each page is unknown; need to go through each page and determine wired vs placeholder
- **Feature parity with mobile** — Dashboard, Inventory CRUD, Shows, Sale entry, Reports should all work on the web app
- **Inventory management focus** — web may be more suited to bulk inventory management (CSV import, batch price updates) than mobile; lean into that
- **Report export** — web is a better surface than mobile for exporting CSVs, PDFs, and Schedule C exports
- **Responsive design** — Tailwind stack; should work on tablet/desktop layouts

### UX / Polish

- **Onboarding flow** — new users see an empty dashboard with no guidance. Add a checklist-style onboarding (add first card → create first show → record first sale)
- **Offline mode / optimistic UI** — API calls block the UI; consider optimistic updates for sale recording and inventory edits so the app feels faster on slow connections
- **Push notifications** — price drop alerts when market price falls below purchase price ("You're underwater on 3 cards")
- **Dark/light mode toggle** — app is dark-only right now; some users may prefer light mode
- **iPad layout** — current Flutter app is phone-optimized; an iPad split-view layout would be useful at shows (inventory list on left, sale screen on right)
- **Haptic feedback** — add subtle haptics on sale completion, scan match, delete actions
- **Accessibility** — screen reader labels missing on most custom widgets; worth an audit pass before public launch
