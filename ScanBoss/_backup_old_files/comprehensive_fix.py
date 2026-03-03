#!/usr/bin/env python3
"""
Major improvements:
1. Multiple fingerprints per card (learning system)
2. Camera autofocus
3. More detailed card fields (brand, number, variant, sport)
"""

print("🔧 Adding fingerprint learning, autofocus, and expanded fields...")

# ============= FIX 1: Update CardDataDialog with more fields =============
print("\n1️⃣ Updating card entry form...")

with open('scanboss_fleet.py', 'r') as f:
    content = f.read()

old_dialog = """class CardDataDialog(QDialog):
    \"\"\"Enhanced dialog with OCR pre-fill\"\"\"
    
    def __init__(self, parent=None, title="New Card Detected", ocr_data=None):
        super().__init__(parent)
        self.setWindowTitle(title)
        self.ocr_data = ocr_data or {}
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout()
        
        # Player name (pre-fill from OCR if available)
        self.player_input = QLineEdit()
        player_hint = self.ocr_data.get('player_name', '')
        if player_hint:
            self.player_input.setText(player_hint)
            self.player_input.setStyleSheet("background-color: #ffffcc; color: #000000;")  # Yellow bg, black text
        self.player_input.setPlaceholderText("e.g., Michael Jordan")
        
        # Card set (pre-fill from OCR if available)
        self.set_input = QLineEdit()
        set_hint = self.ocr_data.get('card_set', '')
        if set_hint:
            self.set_input.setText(set_hint)
            self.set_input.setStyleSheet("background-color: #ffffcc; color: #000000;")
        self.set_input.setPlaceholderText("e.g., Upper Deck Series 1")
        
        # Year (pre-fill from OCR if available)
        self.year_input = QLineEdit()
        year_hint = self.ocr_data.get('card_year')
        if year_hint:
            self.year_input.setText(str(year_hint))
            self.year_input.setStyleSheet("background-color: #ffffcc; color: #000000;")
        self.year_input.setPlaceholderText("e.g., 1997")
        
        layout.addRow("Player Name:", self.player_input)
        layout.addRow("Card Set:", self.set_input)
        layout.addRow("Year:", self.year_input)
        
        # Add hint label if OCR data was used
        if any(self.ocr_data.values()):
            hint = QLabel("💡 Yellow fields = Auto-detected by OCR (please verify)")
            hint.setStyleSheet("color: #666; font-size: 11px; font-style: italic;")
            layout.addRow(hint)
        
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        
        layout.addWidget(buttons)
        self.setLayout(layout)
    
    def get_card_data(self):
        year = self.year_input.text()
        return {
            'player_name': self.player_input.text(),
            'card_set': self.set_input.text(),
            'card_year': int(year) if year.isdigit() else None
        }"""

new_dialog = """class CardDataDialog(QDialog):
    \"\"\"Enhanced dialog with more fields and OCR pre-fill\"\"\"
    
    def __init__(self, parent=None, title="New Card Detected", ocr_data=None):
        super().__init__(parent)
        self.setWindowTitle(title)
        self.setMinimumWidth(400)
        self.ocr_data = ocr_data or {}
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout()
        
        # Sport/League
        self.sport_input = QLineEdit()
        self.sport_input.setPlaceholderText("e.g., Basketball, Baseball, Football")
        
        # Player name (pre-fill from OCR if available)
        self.player_input = QLineEdit()
        player_hint = self.ocr_data.get('player_name', '')
        if player_hint:
            self.player_input.setText(player_hint)
            self.player_input.setStyleSheet("background-color: #ffffcc; color: #000000;")
        self.player_input.setPlaceholderText("e.g., Michael Jordan")
        
        # Brand/Manufacturer
        self.brand_input = QLineEdit()
        self.brand_input.setPlaceholderText("e.g., Topps, Panini, Upper Deck")
        
        # Card set (pre-fill from OCR if available)
        self.set_input = QLineEdit()
        set_hint = self.ocr_data.get('card_set', '')
        if set_hint:
            self.set_input.setText(set_hint)
            self.set_input.setStyleSheet("background-color: #ffffcc; color: #000000;")
        self.set_input.setPlaceholderText("e.g., Chrome, Prizm, Series 1")
        
        # Year (pre-fill from OCR if available)
        self.year_input = QLineEdit()
        year_hint = self.ocr_data.get('card_year')
        if year_hint:
            self.year_input.setText(str(year_hint))
            self.year_input.setStyleSheet("background-color: #ffffcc; color: #000000;")
        self.year_input.setPlaceholderText("e.g., 1997")
        
        # Card Number
        self.number_input = QLineEdit()
        self.number_input.setPlaceholderText("e.g., 123, RC-5, #23")
        
        # Variant/Parallel
        self.variant_input = QLineEdit()
        self.variant_input.setPlaceholderText("e.g., Base, Refractor, Auto, /99")
        
        layout.addRow("Sport/League:", self.sport_input)
        layout.addRow("Player Name:*", self.player_input)
        layout.addRow("Brand:", self.brand_input)
        layout.addRow("Set:*", self.set_input)
        layout.addRow("Year:*", self.year_input)
        layout.addRow("Card Number:", self.number_input)
        layout.addRow("Variant/Parallel:", self.variant_input)
        
        # Add hint label if OCR data was used
        if any(self.ocr_data.values()):
            hint = QLabel("💡 Yellow fields = Auto-detected by OCR (please verify)")
            hint.setStyleSheet("color: #999; font-size: 11px; font-style: italic;")
            layout.addRow(hint)
        
        required_hint = QLabel("* = Required fields")
        required_hint.setStyleSheet("color: #999; font-size: 10px; font-style: italic;")
        layout.addRow(required_hint)
        
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        
        layout.addWidget(buttons)
        self.setLayout(layout)
    
    def get_card_data(self):
        year = self.year_input.text()
        return {
            'sport': self.sport_input.text() or None,
            'player_name': self.player_input.text(),
            'brand': self.brand_input.text() or None,
            'card_set': self.set_input.text(),
            'card_year': int(year) if year.isdigit() else None,
            'card_number': self.number_input.text() or None,
            'variant': self.variant_input.text() or None
        }"""

if old_dialog in content:
    content = content.replace(old_dialog, new_dialog)
    print("✅ Expanded card entry form with 7 fields")

# ============= FIX 2: Add autofocus to camera =============
print("\n2️⃣ Adding camera autofocus...")

old_camera_start = """    def start_camera(self):
        \"\"\"Initialize and start camera\"\"\"
        if self.camera is not None:
            self.camera.release()
        
        self.camera = cv2.VideoCapture(self.camera_index)
        self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)"""

new_camera_start = """    def start_camera(self):
        \"\"\"Initialize and start camera with autofocus\"\"\"
        if self.camera is not None:
            self.camera.release()
        
        self.camera = cv2.VideoCapture(self.camera_index)
        self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, 1280)
        self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 720)
        
        # Enable autofocus if supported
        self.camera.set(cv2.CAP_PROP_AUTOFOCUS, 1)
        
        # Disable auto exposure for more consistent lighting
        # self.camera.set(cv2.CAP_PROP_AUTO_EXPOSURE, 0.25)  # Manual mode
        
        # Optional: Increase sharpness
        # self.camera.set(cv2.CAP_PROP_SHARPNESS, 100)
        
        print(f"Camera {self.camera_index}: Autofocus enabled")"""

if old_camera_start in content:
    content = content.replace(old_camera_start, new_camera_start)
    print("✅ Added autofocus and higher resolution")

# ============= FIX 3: Update display to resize for 1280x720 =============
old_camera_label = """        self.camera_label = QLabel()
        self.camera_label.setMinimumSize(640, 480)
        self.camera_label.setMaximumSize(640, 480)"""

new_camera_label = """        self.camera_label = QLabel()
        self.camera_label.setMinimumSize(800, 600)
        self.camera_label.setMaximumSize(800, 600)"""

if old_camera_label in content:
    content = content.replace(old_camera_label, new_camera_label)
    print("✅ Updated camera preview size for higher resolution")

# ============= FIX 4: Update update_frame to resize properly =============
old_display_code = """                # Convert to QPixmap for display
                rgb_frame = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
                h, w, ch = rgb_frame.shape
                bytes_per_line = ch * w
                qt_image = QImage(rgb_frame.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)
                pixmap = QPixmap.fromImage(qt_image)
                
                self.camera_label.setPixmap(pixmap)"""

new_display_code = """                # Convert to QPixmap for display
                rgb_frame = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
                
                # Resize to fit display (800x600)
                rgb_frame = cv2.resize(rgb_frame, (800, 600))
                
                h, w, ch = rgb_frame.shape
                bytes_per_line = ch * w
                qt_image = QImage(rgb_frame.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)
                pixmap = QPixmap.fromImage(qt_image)
                
                self.camera_label.setPixmap(pixmap)"""

if old_display_code in content:
    content = content.replace(old_display_code, new_display_code)
    print("✅ Fixed display scaling")

with open('scanboss_fleet.py', 'w') as f:
    f.write(content)

# ============= FIX 5: Update local_cache to support multiple fingerprints =============
print("\n3️⃣ Adding multi-fingerprint learning to database...")

with open('local_cache.py', 'r') as f:
    cache_content = f.read()

# Add fingerprints table
old_init_db = """        # Known cards table
        cursor.execute(\"\"\"
            CREATE TABLE IF NOT EXISTS known_cards (
                fingerprint TEXT PRIMARY KEY,
                player_name TEXT,
                card_year INTEGER,
                card_set TEXT,
                confidence REAL,
                synced_at TEXT,
                times_used INTEGER DEFAULT 0
            )
        \"\"\")"""

new_init_db = """        # Known cards table (stores unique card info)
        cursor.execute(\"\"\"
            CREATE TABLE IF NOT EXISTS known_cards (
                card_id INTEGER PRIMARY KEY AUTOINCREMENT,
                sport TEXT,
                player_name TEXT,
                brand TEXT,
                card_set TEXT,
                card_year INTEGER,
                card_number TEXT,
                variant TEXT,
                times_used INTEGER DEFAULT 0,
                created_at TEXT,
                UNIQUE(player_name, card_set, card_year, card_number, variant)
            )
        \"\"\")
        
        # Fingerprints table (multiple fingerprints can map to one card)
        cursor.execute(\"\"\"
            CREATE TABLE IF NOT EXISTS fingerprints (
                fingerprint TEXT PRIMARY KEY,
                card_id INTEGER,
                confidence REAL,
                synced_at TEXT,
                FOREIGN KEY (card_id) REFERENCES known_cards(card_id)
            )
        \"\"\")"""

if old_init_db in cache_content:
    cache_content = cache_content.replace(old_init_db, new_init_db)
    print("✅ Updated database schema for multi-fingerprint learning")

# Update lookup method
old_lookup = """    def lookup(self, fingerprint: str) -> Optional[Dict]:
        \"\"\"
        Look up a fingerprint in local cache
        
        Returns:
            {
                "player_name": "Michael Jordan",
                "card_year": 1997,
                "card_set": "Upper Deck",
                "confidence": 0.95
            } or None if not found
        \"\"\"
        cursor = self.conn.cursor()
        cursor.execute(\"\"\"
            SELECT player_name, card_year, card_set, confidence
            FROM known_cards
            WHERE fingerprint = ?
        \"\"\", (fingerprint,))
        
        result = cursor.fetchone()
        
        if result:
            # Update usage counter
            cursor.execute(\"\"\"
                UPDATE known_cards
                SET times_used = times_used + 1
                WHERE fingerprint = ?
            \"\"\", (fingerprint,))
            self.conn.commit()
            
            return {
                "player_name": result['player_name'],
                "card_year": result['card_year'],
                "card_set": result['card_set'],
                "confidence": result['confidence']
            }
        
        return None"""

new_lookup = """    def lookup(self, fingerprint: str) -> Optional[Dict]:
        \"\"\"
        Look up a fingerprint in local cache
        
        Returns card data if found, None otherwise
        \"\"\"
        cursor = self.conn.cursor()
        cursor.execute(\"\"\"
            SELECT c.sport, c.player_name, c.brand, c.card_set, c.card_year, 
                   c.card_number, c.variant, f.confidence
            FROM fingerprints f
            JOIN known_cards c ON f.card_id = c.card_id
            WHERE f.fingerprint = ?
        \"\"\", (fingerprint,))
        
        result = cursor.fetchone()
        
        if result:
            # Update usage counter
            cursor.execute(\"\"\"
                UPDATE known_cards
                SET times_used = times_used + 1
                WHERE card_id = (SELECT card_id FROM fingerprints WHERE fingerprint = ?)
            \"\"\", (fingerprint,))
            self.conn.commit()
            
            return {
                "sport": result['sport'],
                "player_name": result['player_name'],
                "brand": result['brand'],
                "card_set": result['card_set'],
                "card_year": result['card_year'],
                "card_number": result['card_number'],
                "variant": result['variant'],
                "confidence": result['confidence']
            }
        
        return None"""

if old_lookup in cache_content:
    cache_content = cache_content.replace(old_lookup, new_lookup)
    print("✅ Updated lookup to use fingerprints table")

# Update add_card method
old_add_card = """    def add_card(self, fingerprint: str, card_data: Dict, confidence: float = 1.0):
        \"\"\"Add a single card to cache\"\"\"
        cursor = self.conn.cursor()
        cursor.execute(\"\"\"
            INSERT OR REPLACE INTO known_cards 
            (fingerprint, player_name, card_year, card_set, confidence, synced_at)
            VALUES (?, ?, ?, ?, ?, ?)
        \"\"\", (
            fingerprint,
            card_data.get('player_name'),
            card_data.get('card_year'),
            card_data.get('card_set'),
            confidence,
            datetime.now().isoformat()
        ))
        self.conn.commit()"""

new_add_card = """    def add_card(self, fingerprint: str, card_data: Dict, confidence: float = 1.0):
        \"\"\"Add a card with fingerprint (supports multiple fingerprints per card)\"\"\"
        cursor = self.conn.cursor()
        
        # First, check if this card already exists (by player, set, year, number, variant)
        cursor.execute(\"\"\"
            SELECT card_id FROM known_cards
            WHERE player_name = ? AND card_set = ? AND card_year = ?
              AND (card_number = ? OR (card_number IS NULL AND ? IS NULL))
              AND (variant = ? OR (variant IS NULL AND ? IS NULL))
        \"\"\", (
            card_data.get('player_name'),
            card_data.get('card_set'),
            card_data.get('card_year'),
            card_data.get('card_number'),
            card_data.get('card_number'),
            card_data.get('variant'),
            card_data.get('variant')
        ))
        
        result = cursor.fetchone()
        
        if result:
            # Card exists - just add this fingerprint
            card_id = result['card_id']
            print(f"Card exists (ID {card_id}), adding new fingerprint variant")
        else:
            # New card - create it
            cursor.execute(\"\"\"
                INSERT INTO known_cards 
                (sport, player_name, brand, card_set, card_year, card_number, variant, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
            \"\"\", (
                card_data.get('sport'),
                card_data.get('player_name'),
                card_data.get('brand'),
                card_data.get('card_set'),
                card_data.get('card_year'),
                card_data.get('card_number'),
                card_data.get('variant'),
                datetime.now().isoformat()
            ))
            card_id = cursor.lastrowid
            print(f"New card created (ID {card_id})")
        
        # Add fingerprint
        cursor.execute(\"\"\"
            INSERT OR REPLACE INTO fingerprints
            (fingerprint, card_id, confidence, synced_at)
            VALUES (?, ?, ?, ?)
        \"\"\", (
            fingerprint,
            card_id,
            confidence,
            datetime.now().isoformat()
        ))
        
        self.conn.commit()"""

if old_add_card in cache_content:
    cache_content = cache_content.replace(old_add_card, new_add_card)
    print("✅ Updated add_card to support fingerprint learning")

# Update get_cache_stats
old_stats = """    def get_cache_stats(self) -> Dict:
        \"\"\"Get statistics about local cache\"\"\"
        cursor = self.conn.cursor()
        
        cursor.execute("SELECT COUNT(*) as total FROM known_cards")
        total = cursor.fetchone()['total']"""

new_stats = """    def get_cache_stats(self) -> Dict:
        \"\"\"Get statistics about local cache\"\"\"
        cursor = self.conn.cursor()
        
        cursor.execute("SELECT COUNT(*) as total FROM fingerprints")
        total_fingerprints = cursor.fetchone()['total']
        
        cursor.execute("SELECT COUNT(*) as total FROM known_cards")
        total = cursor.fetchone()['total']"""

if old_stats in cache_content:
    cache_content = cache_content.replace(old_stats, new_stats)

# Update return value of get_cache_stats
old_stats_return = """        return {
            "total_cards": total,
            "average_confidence": round(avg_conf, 3),
            "total_lookups": total_uses,
            "last_sync": last_sync,
            "model_version": version
        }"""

new_stats_return = """        return {
            "total_cards": total,
            "total_fingerprints": total_fingerprints,
            "average_confidence": round(avg_conf, 3),
            "total_lookups": total_uses,
            "last_sync": last_sync,
            "model_version": version
        }"""

if old_stats_return in cache_content:
    cache_content = cache_content.replace(old_stats_return, new_stats_return)

with open('local_cache.py', 'w') as f:
    f.write(cache_content)

print("\n✅ All fixes applied!")
print("\n📋 Summary of changes:")
print("   1. ✅ Expanded card form: Sport, Player, Brand, Set, Year, Number, Variant")
print("   2. ✅ Camera autofocus enabled")
print("   3. ✅ Higher resolution: 1280x720 (should be sharper)")
print("   4. ✅ Multi-fingerprint learning: Same card can have multiple fingerprints")
print("   5. ✅ New database schema with card_id linking")
print("\n🎯 How it works now:")
print("   - Scan card 3 times, enter same info each time")
print("   - System learns all 3 fingerprints map to that card")
print("   - 4th scan with any of those fingerprints = match!")
print("\n⚠️  NOTE: You'll need to delete your cache to use new schema:")
print("   rm ~/.scanboss/card_cache.db")
print("\nTest: python3 scanboss_fleet.py")
