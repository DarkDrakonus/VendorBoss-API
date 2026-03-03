# VendorBoss App — Test Scenarios
**Version:** 1.0.0  
**Last Updated:** 2026-02-26  
**Tester:** ________________  
**Device(s):** ________________

---

## How to Use This Document
- ✅ = Pass  
- ❌ = Fail  
- ⚠️ = Partial / Needs attention  
- Leave notes in the **Notes** column for anything unexpected

---

## 1. App Launch & Theme

| # | Test | Expected Result | Status | Notes |
|---|------|-----------------|--------|-------|
| 1.1 | Launch the app cold (fully closed) | App opens to Dashboard screen |✅| |
| 1.2 | Check default theme on first launch | App should be in **Dark Mode** by default |✅| |
| 1.3 | Navigate to Settings via gear icon on Dashboard | Settings screen opens |✅| |
| 1.4 | Toggle Dark Mode off in Settings | App switches to Light Mode immediately |✅| |
| 1.5 | Close and relaunch the app | App remembers Light Mode preference |✅| |
| 1.6 | Toggle Dark Mode back on in Settings | App switches back to Dark Mode |✅| |
| 1.7 | Close and relaunch the app | App remembers Dark Mode preference |✅| |

---

## 2. Bottom Navigation

| # | Test | Expected Result | Status | Notes |
|---|------|-----------------|--------|-------|
| 2.1 | Tap **Dashboard** tab | Dashboard screen displays |✅| |
| 2.2 | Tap **Inventory** tab | Inventory screen displays |✅| |
| 2.3 | Tap **Scan** tab | Scan & Lookup screen displays |✅| |
| 2.4 | Tap **Shows** tab | Shows screen displays |✅| |
| 2.5 | Tap **Reports** tab | Reports placeholder screen displays |✅| |
| 2.6 | Navigate to a sub-screen, then tap a bottom nav tab | Returns to correct tab without error |✅| |

---

## 3. Dashboard Screen

| # | Test | Expected Result | Status | Notes |
|---|------|-----------------|--------|-------|
| 3.1 | View Dashboard | Active show banner (Sioux Falls Card Show) is visible in teal/green |✅ | |
| 3.2 | View Dashboard | Today's Performance stats show Sales, Expenses, Net |✅| |
| 3.3 | View Dashboard | Sales = $53.00, Expenses = $127.50, Net = -$74.50 |✅| |
| 3.4 | View Dashboard | Inventory card shows 47 / 200 with progress bar |✅| |
| 3.5 | View Dashboard | Recent Shows list shows 3 shows |✅| |
| 3.6 | Tap **Open** button on active show banner | Navigates to Show Detail screen for Sioux Falls Card Show |✅| |
| 3.7 | Tap **Sioux Falls Card Show** in Recent Shows list | Navigates to Show Detail screen |✅| |
| 3.8 | Tap a past show in Recent Shows list | Navigates to Show Detail screen for that show |✅| |
| 3.9 | Tap gear icon (Settings) | Settings screen opens |✅| |
| 3.10 | Press back from Settings | Returns to Dashboard |✅| |

---

## 4. Inventory Screen

| # | Test | Expected Result | Status | Notes |
|---|------|-----------------|--------|-------|
| 4.1 | View Inventory tab | Shows 6 cards in list |✅| |
| 4.2 | View card list | Each card shows name, game, set, condition, asking price, market price |✅| |
| 4.3 | View card list | Charizard PSA 9 shows graded label |❌| |
| 4.4 | View card list | Cards with quantity > 1 show quantity badge (Pikachu V shows x4) |✅| |
| 4.5 | Type "Charizard" in search bar | List filters to Charizard cards only |✅| |
| 4.6 | Type "pikachu" (lowercase) in search bar | Finds Pikachu V (case insensitive) |✅| |
| 4.7 | Type a name with no match | List shows "No cards found" |✅| |
| 4.8 | Tap the X on the search bar | Clears search, full list returns |❌| |
| 4.9 | Tap **Pokemon** filter chip | List filters to Pokemon cards only |✅| |
| 4.10 | Tap **Magic: The Gathering** filter chip | List filters to Magic cards only (Black Lotus) |✅| |
| 4.11 | Tap **One Piece** filter chip | List filters to One Piece cards only (Roronoa Zoro) |✅| |
| 4.12 | Tap **All** filter chip | Full list returns |✅| |
| 4.13 | Combine search + game filter | e.g. "Charizard" + Pokemon filters correctly |✅| |
| 4.14 | Tap the **+** (add) icon in app bar | No crash (placeholder for now) |✅| |
| 4.15 | Tap the filter icon in app bar | No crash (placeholder for now) |✅| |

---

## 5. Show Detail Screen

| # | Test | Expected Result | Status | Notes |
|---|------|-----------------|--------|-------|
| 5.1 | Open Sioux Falls Card Show | Show Detail screen opens with ACTIVE badge |✅| |
| 5.2 | View Summary tab | Show info (date, venue, location, table, table cost) is displayed |✅| |
| 5.3 | View Summary tab | Sales = $53.00, Expenses = $127.50, Net = -$74.50 |✅| |
| 5.4 | View Summary tab | Transaction count, cards sold, and avg sale are shown |✅| |
| 5.5 | Tap **Sales** tab | Shows 3 sales transactions |✅| |
| 5.6 | View Sales tab | Sale times and payment methods are shown |✅| |
| 5.7 | View Sales tab | Bulk sale (commons bag) shows with different icon |✅| |
| 5.8 | Tap **Expenses** tab | Shows 3 expenses with total bar at top |✅| |
| 5.9 | View Expenses tab | Total = $127.50 displayed in warning color |✅| |
| 5.10 | View Expenses tab | Each expense shows type, description, time, amount |✅| |
| 5.11 | View active show | Floating **New Sale** button is visible |✅| |
| 5.12 | Tap **New Sale** button | Shows snackbar "Sale screen coming soon!" |✅| |
| 5.13 | Open a past show (Midwest TCG Expo) | No ACTIVE badge, no New Sale button |✅| |
| 5.14 | View past show Summary tab | Sales and Expenses show $0 (no mock data for past shows yet) |✅| |
| 5.15 | Press back | Returns to previous screen |✅| |

---

## 6. Shows Screen

| # | Test | Expected Result | Status | Notes |
|---|------|-----------------|--------|-------|
| 6.1 | View Shows tab | Active show section shows Sioux Falls Card Show |✅| |
| 6.2 | View Shows tab | Past Shows section shows 2 past shows |✅| |
| 6.3 | Tap active show card | Navigates to Show Detail screen |✅| |
| 6.4 | Tap a past show card | Navigates to Show Detail screen |✅| |
| 6.5 | Tap **+** icon in app bar | Create New Show bottom sheet slides up |✅| |
| 6.6 | View Create Show sheet | Fields for Name, Date, Venue, Location, Table #, Table Cost |✅| |
| 6.7 | Tap the date field | Date picker opens |✅| |
| 6.8 | Select a date | Date updates in the form |✅| |
| 6.9 | Tap **Create Show** with empty name | Nothing happens (required field) |✅| |
| 6.10 | Fill in Show Name and tap **Create Show** | Sheet closes, snackbar confirms creation |✅| |

---

## 7. Scan & Lookup Screen

| # | Test | Expected Result | Status | Notes |
|---|------|-----------------|--------|-------|
| 7.1 | View Scan tab with no input | Camera icon, instructional text, and Open Camera button are visible |✅| |
| 7.2 | Tap **Open Camera** button | Snackbar shows "Camera scanning coming soon!" |❌| |
| 7.3 | Tap camera icon in app bar | Snackbar shows "Camera scanning coming soon!" |✅| |
| 7.4 | Type "charizard" in search | Results show Charizard card |✅| |
| 7.5 | Type "lightning" in search | Results show Lightning Bolt (Magic) |✅| |
| 7.6 | Type "luffy" in search | Results show Monkey D. Luffy (One Piece) |✅| |
| 7.7 | Type something with no match | Empty results (no crash) |✅| |
| 7.8 | Tap a search result | Card detail panel slides in |✅| |
| 7.9 | View card detail | Name, game, set, card number, rarity, finish displayed |✅| |
| 7.10 | View card detail | Market, Low, Mid, High prices shown |✅| |
| 7.11 | View card detail | Buy Price Calculator section has a toggle switch |✅| |
| 7.12 | Toggle Buy Price Calculator on | Percentage slider and offer price appear |✅| |
| 7.13 | Move the buy percentage slider | Offer price updates in real time |✅| |
| 7.14 | Tap **Buy from Customer** button | Toggles buy calculator on |✅| |
| 7.15 | Tap **Add to Inventory** button | Snackbar shows "Added to inventory! (mock)" |✅| |
| 7.16 | Tap **Back to results** link | Returns to search results list |✅| |
| 7.17 | Tap X on search bar | Clears search and returns to empty state |✅| |

---

## 8. Settings Screen

| # | Test | Expected Result | Status | Notes |
|---|------|-----------------|--------|-------|
| 8.1 | View Settings | Sections: Appearance, Account, Vendor Defaults, App |✅| |
| 8.2 | View Account section | Shows email travis@vendorboss.com |✅| |
| 8.3 | View Account section | Shows Free Plan · 47 / 200 cards with UPGRADE badge |✅| |
| 8.4 | Toggle Dark Mode switch | Theme changes immediately |✅| |
| 8.5 | Tap **Default Buy Percentage** | Dialog opens with slider and current percentage |✅| |
| 8.6 | Move slider in dialog | Percentage label updates in real time |✅| |
| 8.7 | Tap Cancel in dialog | Dialog closes, nothing saved |✅| |
| 8.8 | Tap Save in dialog | Dialog closes (saves when API is connected) |✅| |
| 8.9 | Tap **Sign Out** | Confirmation dialog appears |✅| |
| 8.10 | Tap Cancel in sign out dialog | Dialog closes, stays on Settings |✅| |
| 8.11 | Tap Sign Out in confirmation | Dialog closes (will navigate to login when auth is ready) |✅| |
| 8.12 | Press back | Returns to Dashboard |✅| |

---

## 9. General / Edge Cases

| # | Test | Expected Result | Status | Notes |
|---|------|-----------------|--------|-------|
| 9.1 | Rotate device to landscape | App handles rotation without crashing |✅| |
| 9.2 | Rapidly tap between all bottom nav tabs | No crashes or blank screens |✅| |
| 9.3 | Open Show Detail, press back, open again | No stale data or crashes |✅| |
| 9.4 | Open and close Create Show sheet multiple times | No crashes |✅| |
| 9.5 | Open Buy Calculator on Scan screen, navigate away, return | State resets cleanly |✅| |

---

## Known Placeholders (Not Bugs)
These are intentionally not built yet — do not log as bugs:
- Camera scanning ("coming soon" snackbar is correct behavior)
- Add card to inventory (mock snackbar is correct)
- Reports screen (placeholder is correct)
- Profile and subscription screens (no navigation yet)
- Default markup settings (no navigation yet)
- New Sale button (mock snackbar is correct)
- Past shows have $0 data (no mock data assigned yet)

---

## Bug Log

| # | Screen | Description | Steps to Reproduce | Severity |
|---|--------|-------------|-------------------|----------|
|4.3|Inventory |Charizard (PSA 9) doesn't show and label stating Graded | |Low |
|4.8|Inventory |Pressing X on the search clears entry, but the keyboard also stays active and hide the bottom naviagation bar.  Pressing the back button on the table closed the keyboard||Medium|
|7.2|Scan|Pressing Open Camera does not display snakbar message | |Low|

---

*Generated for VendorBoss v1.0.0 — update this document as new screens are completed*
