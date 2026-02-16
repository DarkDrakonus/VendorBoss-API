#!/usr/bin/env python3
"""
ScanBoss - Fleet Learning Version (Fully Automatic)
Crowd-sourced card scanner - No login required!
Auto-syncs every 24 hours in the background
"""

import sys
import cv2
import numpy as np
from datetime import datetime
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QTextEdit, QLineEdit, QDialog, QFormLayout,
    QDialogButtonBox, QComboBox, QMessageBox, QProgressDialog
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal, QThread
from PyQt6.QtGui import QImage, QPixmap

from card_detector import CardDetector
from api_client import APIClient
from local_cache import LocalCardCache, CacheSyncManager


class ScanWorker(QThread):
    """Worker thread for card scanning with fleet learning"""
    finished = pyqtSignal(dict)
    
    def __init__(self, frame, detector, api, cache):
        super().__init__()
        self.frame = frame
        self.detector = detector
        self.api = api
        self.cache = cache
    
    def run(self):
        """Process frame with local cache + API fallback"""
        try:
            result = self.detector.detect_card_in_frame(self.frame)
            
            if result.get('detected', False):
                fingerprint = result['fingerprint']
                ocr_data = result.get('ocr_data', {})
                
                # STEP 1: Check local cache first (instant, offline)
                cached = self.cache.lookup(fingerprint)
                if cached:
                    self.finished.emit({
                        'status': 'match',
                        'source': 'cache',
                        'product': cached,
                        'fingerprint': fingerprint,
                        'ocr_data': ocr_data
                    })
                    return
                
                # STEP 2: Check API (uses V2 learning endpoints)
                api_result = self.api.check_fingerprint_v2(fingerprint)
                
                if api_result['success'] and api_result['known']:
                    # Cache the result locally
                    self.cache.add_card(
                        fingerprint, 
                        api_result['card_data'],
                        api_result['confidence']
                    )
                    
                    self.finished.emit({
                        'status': 'match',
                        'source': 'api',
                        'product': api_result['card_data'],
                        'fingerprint': fingerprint,
                        'confidence': api_result['confidence'],
                        'ocr_data': ocr_data
                    })
                else:
                    # New card - needs user input
                    self.finished.emit({
                        'status': 'new_card',
                        'fingerprint': fingerprint,
                        'ocr_data': ocr_data
                    })
            else:
                self.finished.emit({'status': 'no_card'})
                
        except Exception as e:
            import traceback
            traceback.print_exc()
            self.finished.emit({'status': 'error', 'error': str(e)})


class SyncWorker(QThread):
    """Worker thread for syncing with API"""
    finished = pyqtSignal(dict)
    progress = pyqtSignal(str)
    
    def __init__(self, sync_manager):
        super().__init__()
        self.sync_manager = sync_manager
    
    def run(self):
        """Perform sync"""
        try:
            self.progress.emit("Checking for updates...")
            result = self.sync_manager.sync(force=False)
            self.finished.emit(result)
        except Exception as e:
            self.finished.emit({'success': False, 'error': str(e)})


class ProductDataDialog(QDialog):
    """Dialog for entering pack/box product data"""
    
    def __init__(self, parent=None, barcode=None):
        super().__init__(parent)
        self.setWindowTitle("Add Product")
        self.setMinimumWidth(400)
        self.barcode = barcode
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout()
        
        # Show detected barcode
        if self.barcode:
            barcode_label = QLabel(f"Barcode: {self.barcode}")
            barcode_label.setStyleSheet("font-weight: bold; color: #4CAF50;")
            layout.addRow(barcode_label)
        
        # Product Type (Box, Pack, etc.)
        self.type_input = QComboBox()
        self.type_input.addItems(["Pack", "Box", "Blaster Box", "Hobby Box", "Retail Box", "Hanger Box"])
        
        # Brand
        self.brand_input = QLineEdit()
        self.brand_input.setPlaceholderText("e.g., Topps, Panini, Upper Deck")
        
        # Sport
        self.sport_input = QLineEdit()
        self.sport_input.setPlaceholderText("e.g., Basketball, Baseball, Football")
        
        # Set Name
        self.set_input = QLineEdit()
        self.set_input.setPlaceholderText("e.g., Chrome, Prizm, Series 1")
        
        # Year
        self.year_input = QLineEdit()
        self.year_input.setPlaceholderText("e.g., 2024")
        
        # Retail Price (optional)
        self.price_input = QLineEdit()
        self.price_input.setPlaceholderText("e.g., 4.99")
        
        # Cards per pack/box (optional)
        self.cards_input = QLineEdit()
        self.cards_input.setPlaceholderText("e.g., 10 cards per pack")
        
        layout.addRow("Product Type:*", self.type_input)
        layout.addRow("Brand:*", self.brand_input)
        layout.addRow("Sport:", self.sport_input)
        layout.addRow("Set Name:*", self.set_input)
        layout.addRow("Year:*", self.year_input)
        layout.addRow("Retail Price ($):", self.price_input)
        layout.addRow("Cards/Packs:", self.cards_input)
        
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
    
    def get_product_data(self):
        year = self.year_input.text()
        price = self.price_input.text()
        cards = self.cards_input.text()
        
        # Determine if it's a pack or box
        product_type = self.type_input.currentText()
        is_box = "box" in product_type.lower()
        
        return {
            'product_type': product_type,
            'brand': self.brand_input.text(),
            'sport': self.sport_input.text() or None,
            'set_name': self.set_input.text(),
            'year': int(year) if year.isdigit() else None,
            'retail_price': float(price) if price.replace('.', '').isdigit() else None,
            'cards_per_pack': int(cards) if cards.isdigit() else None,
            'packs_per_box': int(cards) if is_box and cards.isdigit() else None
        }


class CardDataDialog(QDialog):
    """Enhanced dialog with more fields and OCR pre-fill"""
    
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
        variant = self.variant_input.text()
        
        return {
            # Required fields (matching API ProductBase)
            'sport': self.sport_input.text() or 'Unknown',
            'player_name': self.player_input.text(),
            'card_year': int(year) if year.isdigit() else None,
            'card_set': self.set_input.text(),
            
            # Optional fields
            'card_number': self.number_input.text() or None,
            
            # Variant fields (API uses is_parallel + parallel_name)
            'is_parallel': bool(variant),
            'parallel_name': variant if variant else None,
            
            # Boolean flags
            'is_rookie': False,  # Could add checkbox for this
            'is_auto': False,    # Could add checkbox for this
            'is_relic': False,   # Could add checkbox for this
            'is_refractor': False,  # Could add checkbox for this
            'serial_numbered': False,
            
            # Additional fields if needed
            'team': None,
            'position': None,
            'barcode': None
        }


class ScanBossApp(QMainWindow):
    """Main application - Fully automatic syncing"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ScanBoss - Anonymous Card Scanner")
        self.setMinimumSize(900, 720)
        
        # Initialize components (no authentication)
        self.detector = CardDetector()
        self.api = APIClient()  # Anonymous API client
        self.cache = LocalCardCache()
        self.sync_manager = CacheSyncManager(self.cache, self.api)
        
        self.camera = None
        self.camera_index = 0
        self.scanning = False
        self.auto_scan = False
        self.current_frame = None
        self.scan_worker = None
        self.sync_worker = None  # Track sync worker
        self.recent_cards = []  # Track recently added cards (with full data for editing)
        self.scan_mode = "CARD"  # CARD or BARCODE mode
        
        # Setup UI
        self.setup_ui()
        
        # Setup camera timer
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_frame)
        
        # Setup automatic sync timer (check every hour, sync if 24h elapsed)
        self.sync_timer = QTimer()
        self.sync_timer.timeout.connect(self.check_and_sync)
        self.sync_timer.start(3600000)  # Check every 1 hour (3600000 ms)
        
        # Start camera
        self.start_camera()
        
        # Show cache stats
        self.show_cache_stats()
        
        # Start in fullscreen
        self.showMaximized()
    
    def setup_ui(self):
        """Create the user interface"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        # Main horizontal layout: camera area | recent cards panel
        main_layout = QHBoxLayout()
        central_widget.setLayout(main_layout)
        
        # Left side: camera and controls
        left_layout = QVBoxLayout()
        main_layout.addLayout(left_layout, stretch=3)
        
        # Right side: recent cards panel
        right_layout = QVBoxLayout()
        main_layout.addLayout(right_layout, stretch=1)
        
        # Title with subtitle
        title = QLabel("ScanBoss")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title.setStyleSheet("font-size: 28px; font-weight: bold; padding: 5px;")
        left_layout.addWidget(title)
        
        subtitle = QLabel("Anonymous Crowd-Sourced Card Scanner 📸")
        subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)
        subtitle.setStyleSheet("font-size: 13px; color: #999; padding: 0px;")
        left_layout.addWidget(subtitle)
        
        # Mode indicator
        self.mode_label = QLabel("📸 CARD SCANNING MODE")
        self.mode_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.mode_label.setStyleSheet("font-size: 14px; font-weight: bold; color: #4CAF50; padding: 5px; background-color: #2d2d2d; border-radius: 4px;")
        left_layout.addWidget(self.mode_label)
        
        # Cache status bar with sync indicator
        self.cache_label = QLabel("Local Cache: Loading...")
        self.cache_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.cache_label.setStyleSheet("font-size: 11px; color: #999; padding: 5px;")
        left_layout.addWidget(self.cache_label)
        
        # Camera selection
        camera_layout = QHBoxLayout()
        camera_label = QLabel("Camera:")
        self.camera_combo = QComboBox()
        self.detect_cameras()
        self.camera_combo.currentIndexChanged.connect(self.change_camera)
        camera_layout.addWidget(camera_label)
        camera_layout.addWidget(self.camera_combo)
        camera_layout.addStretch()
        left_layout.addLayout(camera_layout)
        
        # Camera preview
        self.camera_label = QLabel()
        self.camera_label.setMinimumSize(800, 600)
        self.camera_label.setMaximumSize(800, 600)
        self.camera_label.setStyleSheet("border: 2px solid #333; background-color: black;")
        self.camera_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.camera_label.setText("Camera Preview")
        
        preview_container = QHBoxLayout()
        preview_container.addStretch()
        preview_container.addWidget(self.camera_label)
        preview_container.addStretch()
        left_layout.addLayout(preview_container)
        
        # Control buttons
        button_layout = QHBoxLayout()
        
        self.scan_button = QPushButton("Scan Card")
        self.scan_button.setMinimumHeight(40)
        self.scan_button.clicked.connect(self.scan_card)
        
        self.auto_button = QPushButton("Auto Scan: OFF")
        self.auto_button.setMinimumHeight(40)
        self.auto_button.clicked.connect(self.toggle_auto_scan)
        
        self.mode_switch_button = QPushButton("📦 Add Product (Barcode Mode)")
        self.mode_switch_button.setMinimumHeight(40)
        self.mode_switch_button.setStyleSheet("""
            QPushButton {
                background-color: #2196F3;
                color: white;
            }
            QPushButton:hover {
                background-color: #1976D2;
            }
        """)
        self.mode_switch_button.clicked.connect(self.switch_mode)
        
        button_layout.addWidget(self.scan_button)
        button_layout.addWidget(self.auto_button)
        button_layout.addWidget(self.mode_switch_button)
        left_layout.addLayout(button_layout)
        
        # Status label
        self.status_label = QLabel("Ready to scan - No login required! 🎉")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.status_label.setStyleSheet("padding: 5px; font-weight: bold;")
        left_layout.addWidget(self.status_label)
        
        # Results text area
        results_label = QLabel("Scan Results:")
        left_layout.addWidget(results_label)
        
        self.results_text = QTextEdit()
        self.results_text.setReadOnly(True)
        self.results_text.setMaximumHeight(100)
        left_layout.addWidget(self.results_text)
        
        # Right panel: Recent cards
        recent_label = QLabel("Recently Added Cards")
        recent_label.setStyleSheet("font-size: 16px; font-weight: bold; padding: 10px;")
        right_layout.addWidget(recent_label)
        
        # Recent cards list (using QListWidget for click support)
        from PyQt6.QtWidgets import QListWidget, QListWidgetItem
        self.recent_cards_list = QListWidget()
        self.recent_cards_list.setStyleSheet("""
            QListWidget {
                background-color: #2d2d2d;
                color: #e0e0e0;
                border: 1px solid #444;
                border-radius: 4px;
                padding: 5px;
                font-family: monospace;
                font-size: 11px;
            }
            QListWidget::item {
                padding: 8px;
                border-bottom: 1px solid #3a3a3a;
            }
            QListWidget::item:hover {
                background-color: #3a3a3a;
            }
            QListWidget::item:selected {
                background-color: #4CAF50;
            }
        """)
        self.recent_cards_list.itemClicked.connect(self.edit_recent_card)
        right_layout.addWidget(self.recent_cards_list)
        
        # Apply modern styling
        self.apply_styling()
    
    def apply_styling(self):
        """Apply dark theme"""
        self.setStyleSheet("""
            QMainWindow {
                background-color: #1a1a1a;
            }
            QWidget {
                background-color: #1a1a1a;
                color: #e0e0e0;
            }
            QLabel {
                color: #e0e0e0;
            }
            QPushButton {
                background-color: #4CAF50;
                color: white;
                border: none;
                padding: 8px 16px;
                font-size: 14px;
                border-radius: 4px;
            }
            QPushButton:hover {
                background-color: #45a049;
            }
            QPushButton:pressed {
                background-color: #3d8b40;
            }
            QPushButton:disabled {
                background-color: #333333;
                color: #666666;
            }
            QTextEdit {
                background-color: #2d2d2d;
                color: #e0e0e0;
                border: 1px solid #444;
                border-radius: 4px;
                padding: 5px;
                font-family: monospace;
            }
            QComboBox {
                background-color: #2d2d2d;
                color: #e0e0e0;
                padding: 5px;
                border: 1px solid #444;
                border-radius: 4px;
            }
            QComboBox:drop-down {
                border: none;
            }
            QComboBox QAbstractItemView {
                background-color: #2d2d2d;
                color: #e0e0e0;
                selection-background-color: #4CAF50;
            }
        """)
    
    def show_cache_stats(self):
        """Display local cache statistics"""
        stats = self.cache.get_cache_stats()
        last_sync = stats['last_sync']
        
        # Format last sync time
        if last_sync:
            try:
                sync_time = datetime.fromisoformat(last_sync)
                time_ago = self._time_ago(sync_time)
                sync_text = f"synced {time_ago}"
            except:
                sync_text = "sync status unknown"
        else:
            sync_text = "never synced"
        
        self.cache_label.setText(
            f"📦 {stats['total_cards']:,} known cards | "
            f"v{stats['model_version']} | "
            f"{sync_text} | 🔄 auto-sync every 24h"
        )
    
    def _time_ago(self, dt: datetime) -> str:
        """Convert datetime to human-readable time ago"""
        delta = datetime.now() - dt
        hours = delta.total_seconds() / 3600
        
        if hours < 1:
            minutes = int(delta.total_seconds() / 60)
            return f"{minutes}m ago"
        elif hours < 24:
            return f"{int(hours)}h ago"
        else:
            days = int(hours / 24)
            return f"{days}d ago"
    
    def detect_cameras(self):
        """Detect available cameras"""
        self.camera_combo.clear()
        for i in range(3):  # Mac cameras are typically 0-2
            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                # Verify we can actually read frames
                ret, _ = cap.read()
                if ret:
                    self.camera_combo.addItem(f"Camera {i}", i)
                cap.release()
        
        if self.camera_combo.count() == 0:
            self.camera_combo.addItem("No cameras found", -1)
    
    def change_camera(self, index):
        """Switch to different camera"""
        if index >= 0:
            camera_index = self.camera_combo.currentData()
            if camera_index is not None and camera_index >= 0:
                self.camera_index = camera_index
                self.start_camera()
    
    def start_camera(self):
        """Initialize and start camera with autofocus"""
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
        
        print(f"Camera {self.camera_index}: Autofocus enabled")
        
        if self.camera.isOpened():
            self.timer.start(33)  # ~30 FPS
            self.log_result("✓ Camera started")
            
            # Auto-sync on startup (background, after 2 seconds)
            QTimer.singleShot(2000, self.background_sync)
        else:
            self.log_result("✗ Failed to start camera")
    
    def update_frame(self):
        """Update camera preview"""
        if self.camera and self.camera.isOpened():
            ret, frame = self.camera.read()
            if ret:
                self.current_frame = frame.copy()
                
                # Draw detection zone
                display_frame = frame.copy()
                h, w = display_frame.shape[:2]
                center_x, center_y = w // 2, h // 2
                zone_w, zone_h = 350, 490
                
                cv2.rectangle(display_frame,
                            (center_x - zone_w//2, center_y - zone_h//2),
                            (center_x + zone_w//2, center_y + zone_h//2),
                            (0, 255, 0), 2)
                
                # Convert to QPixmap for display
                rgb_frame = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
                
                # Resize to fit display (800x600)
                rgb_frame = cv2.resize(rgb_frame, (800, 600))
                
                h, w, ch = rgb_frame.shape
                bytes_per_line = ch * w
                qt_image = QImage(rgb_frame.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)
                pixmap = QPixmap.fromImage(qt_image)
                
                self.camera_label.setPixmap(pixmap)
                
                # Auto scan if enabled
                if self.auto_scan and not self.scanning:
                    self.scan_card()
    
    def switch_mode(self):
        """Toggle between CARD and BARCODE modes"""
        if self.scan_mode == "CARD":
            # Switch to BARCODE mode
            self.scan_mode = "BARCODE"
            self.mode_label.setText("📦 BARCODE SCANNER MODE")
            self.mode_label.setStyleSheet("font-size: 14px; font-weight: bold; color: #2196F3; padding: 5px; background-color: #2d2d2d; border-radius: 4px;")
            self.scan_button.setText("Scan Barcode")
            self.mode_switch_button.setText("📸 Add Card (Card Mode)")
            self.mode_switch_button.setStyleSheet("""
                QPushButton {
                    background-color: #4CAF50;
                    color: white;
                }
                QPushButton:hover {
                    background-color: #45a049;
                }
            """)
            self.log_result("Switched to BARCODE mode - Scan packs/boxes")
        else:
            # Switch to CARD mode
            self.scan_mode = "CARD"
            self.mode_label.setText("📸 CARD SCANNING MODE")
            self.mode_label.setStyleSheet("font-size: 14px; font-weight: bold; color: #4CAF50; padding: 5px; background-color: #2d2d2d; border-radius: 4px;")
            self.scan_button.setText("Scan Card")
            self.mode_switch_button.setText("📦 Add Product (Barcode Mode)")
            self.mode_switch_button.setStyleSheet("""
                QPushButton {
                    background-color: #2196F3;
                    color: white;
                }
                QPushButton:hover {
                    background-color: #1976D2;
                }
            """)
            self.log_result("Switched to CARD mode - Scan individual cards")
    
    def scan_card(self):
        """Trigger scan (card or barcode depending on mode)"""
        if self.scanning or self.current_frame is None:
            return
        
        if self.scan_mode == "CARD":
            # Card scanning mode
            self.scanning = True
            self.scan_button.setEnabled(False)
            self.status_label.setText("Scanning card...")
            self.log_result("Processing frame for card...")
            
            # Create and start worker thread
            self.scan_worker = ScanWorker(self.current_frame, self.detector, self.api, self.cache)
            self.scan_worker.finished.connect(self.handle_scan_result)
            self.scan_worker.start()
        else:
            # Barcode scanning mode
            self.scanning = True
            self.scan_button.setEnabled(False)
            self.status_label.setText("Scanning barcode...")
            self.log_result("Looking for barcode...")
            
            # Try to detect barcode
            barcode = self.detect_barcode(self.current_frame)
            if barcode:
                self.log_result(f"✓ Barcode detected: {barcode}")
                self.prompt_product_entry(barcode)
            else:
                self.log_result("✗ No barcode detected")
                self.status_label.setText("No barcode found - try again")
            
            self.scanning = False
            self.scan_button.setEnabled(True)
    
    def handle_scan_result(self, result):
        """Handle scan result from worker thread"""
        status = result.get('status')
        
        if status == 'match':
            product = result['product']
            source = result.get('source', 'unknown')
            player = product.get('player_name', 'Unknown')
            card_set = product.get('card_set', 'Unknown')
            year = product.get('card_year', 'Unknown')
            confidence = result.get('confidence', 1.0)
            
            source_icon = "💾" if source == 'cache' else "🌐"
            message = f"{source_icon} MATCH!\nPlayer: {player}\nSet: {card_set}\nYear: {year}"
            if confidence < 1.0:
                message += f"\nConfidence: {int(confidence*100)}%"
            
            self.log_result(f"✓ {player} ({year})")
            self.status_label.setText(f"Card matched!")
            
            # Ask for confirmation
            reply = QMessageBox.question(
                self, 'Card Match',
                f"{message}\n\nIs this correct?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            
            if reply == QMessageBox.StandardButton.No:
                ocr_data = result.get('ocr_data', {})
                self.prompt_new_card(result['fingerprint'], "Incorrect match", ocr_data)
        
        elif status == 'new_card':
            self.log_result("📝 New card detected!")
            ocr_data = result.get('ocr_data', {})
            
            # Log OCR findings
            if ocr_data.get('player_name'):
                self.log_result(f"  OCR: {ocr_data['player_name']}")
            
            self.prompt_new_card(result['fingerprint'], ocr_data=ocr_data)
        
        elif status == 'no_card':
            self.log_result("No card detected")
            self.status_label.setText("No card detected")
        
        elif status == 'error':
            self.log_result(f"✗ Error: {result.get('error', 'Unknown')}")
            self.status_label.setText("Scan error")
        
        self.scanning = False
        self.scan_button.setEnabled(True)
        if not self.auto_scan:
            self.status_label.setText("Ready to scan")
    
    def detect_barcode(self, frame):
        """Detect barcode in frame using pyzbar"""
        try:
            from pyzbar import pyzbar
            import cv2
            
            # Convert to grayscale for better detection
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            
            # Detect barcodes
            barcodes = pyzbar.decode(gray)
            
            if barcodes:
                # Return first barcode found
                barcode_data = barcodes[0].data.decode('utf-8')
                return barcode_data
            
            return None
            
        except ImportError:
            self.log_result("⚠️  pyzbar not installed. Install with: pip install pyzbar")
            self.log_result("⚠️  Also need: brew install zbar (on macOS)")
            return None
        except Exception as e:
            self.log_result(f"Barcode detection error: {e}")
            return None
    
    def prompt_product_entry(self, barcode):
        """Show dialog to enter product (pack/box) data"""
        dialog = ProductDataDialog(self, barcode=barcode)
        
        if dialog.exec() == QDialog.DialogCode.Accepted:
            product_data = dialog.get_product_data()
            
            # Add barcode
            product_data['barcode'] = barcode
            
            # Submit to API
            result = self.api.create_product(product_data)
            
            if result['success']:
                self.log_result(f"✓ Product added: {product_data['product_type']} - {product_data.get('brand')} {product_data.get('card_set')}")
                self.status_label.setText("Product added! 📦")
            else:
                self.log_result(f"✗ Failed to add product: {result.get('error')}")
                QMessageBox.warning(self, "Error", f"Failed to add product: {result.get('error')}")
    
    def prompt_new_card(self, fingerprint, reason="New card detected", ocr_data=None):
        """Show dialog to enter new card data"""
        dialog = CardDataDialog(self, reason, ocr_data)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            card_data = dialog.get_card_data()
            
            # Submit to API (anonymous submission)
            result = self.api.submit_fingerprint(fingerprint, card_data)
            
            if result['success']:
                player = card_data['player_name']
                card_set = card_data['card_set']
                year = card_data.get('card_year', '?')
                self.log_result(f"✓ Added: {player}")
                self.status_label.setText("Thanks for contributing! 🎉")
                
                # Add to local cache too
                self.cache.add_card(fingerprint, card_data, confidence=0.5)
                self.show_cache_stats()
                
                # Add to recent cards display
                self.add_recent_card(player, card_set, year, fingerprint)
            else:
                self.log_result(f"✗ Submit failed: {result.get('error')}")
    
    def toggle_auto_scan(self):
        """Toggle auto scanning mode"""
        self.auto_scan = not self.auto_scan
        self.auto_button.setText(f"Auto Scan: {'ON' if self.auto_scan else 'OFF'}")
        status = "Auto scan enabled" if self.auto_scan else "Auto scan disabled"
        self.status_label.setText(status)
        self.log_result(status)
    
    def check_and_sync(self):
        """Automatic background sync check (runs every hour)"""
        self.log_result("🔄 Checking for updates...")
        
        # Don't start new sync if one is running
        if self.sync_worker and self.sync_worker.isRunning():
            self.log_result("⏳ Sync already in progress")
            return
        
        self.sync_worker = SyncWorker(self.sync_manager)
        self.sync_worker.finished.connect(self.handle_auto_sync_result)
        self.sync_worker.start()
    
    def background_sync(self):
        """Perform background sync on startup"""
        self.log_result("🔄 Syncing with community database...")
        
        self.sync_worker = SyncWorker(self.sync_manager)
        self.sync_worker.finished.connect(self.handle_sync_result)
        self.sync_worker.start()
    
    def handle_sync_result(self, result):
        """Handle initial sync completion"""
        if result.get('success'):
            if result.get('up_to_date'):
                self.log_result("✓ Up to date")
            elif result.get('skipped'):
                self.log_result("✓ Recently synced")
            else:
                cards = result.get('cards_updated', 0)
                version = result.get('new_version', '?')
                self.log_result(f"✓ Downloaded {cards:,} cards (v{version})")
            
            self.show_cache_stats()
        else:
            error = result.get('error', 'Unknown error')
            self.log_result(f"✗ Sync failed: {error}")
    
    def handle_auto_sync_result(self, result):
        """Handle automatic background sync (silent unless there are updates)"""
        if result.get('success'):
            if not result.get('up_to_date') and not result.get('skipped'):
                cards = result.get('cards_updated', 0)
                version = result.get('new_version', '?')
                self.log_result(f"✓ Auto-update: {cards:,} new cards (v{version})")
                self.show_cache_stats()
            # Otherwise stay silent - no need to log "up to date" every hour
        else:
            # Only log sync failures
            error = result.get('error', 'Unknown error')
            self.log_result(f"✗ Auto-sync failed: {error}")
    
    def log_result(self, message):
        """Log message to results area"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.results_text.append(f"[{timestamp}] {message}")
    
    def add_recent_card(self, player, card_set, year, fingerprint):
        """Add card to recent cards panel"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        card_info = {
            'player': player,
            'set': card_set,
            'year': year,
            'fingerprint': fingerprint,  # Store full fingerprint for editing
            'fingerprint_short': fingerprint[:12],
            'time': timestamp
        }
        
        # Add to beginning of list
        self.recent_cards.insert(0, card_info)
        
        # Keep only last 20 cards
        if len(self.recent_cards) > 20:
            self.recent_cards = self.recent_cards[:20]
        
        # Update display
        self.update_recent_cards_display()
    
    def update_recent_cards_display(self):
        """Update the recent cards panel"""
        from PyQt6.QtWidgets import QListWidgetItem
        
        self.recent_cards_list.clear()
        
        if not self.recent_cards:
            item = QListWidgetItem("No cards added yet.\n\nScan and add cards to see them here!")
            item.setData(1, None)  # No card data
            self.recent_cards_list.addItem(item)
            return
        
        for i, card in enumerate(self.recent_cards):
            display_text = f"{card['player']}\n"
            display_text += f"{card['set']} ({card['year']})\n"
            display_text += f"FP: {card['fingerprint_short']}... | {card['time']}"
            
            item = QListWidgetItem(display_text)
            item.setData(1, i)  # Store index for editing
            self.recent_cards_list.addItem(item)
    
    def edit_recent_card(self, item):
        """Edit a card from recent cards list"""
        card_index = item.data(1)
        
        if card_index is None:
            return  # Clicked on "no cards" message
        
        card = self.recent_cards[card_index]
        
        # Show edit dialog with current values
        dialog = CardDataDialog(
            self, 
            title=f"Edit Card: {card['player']}",
            ocr_data={}
        )
        
        # Pre-fill with current values
        dialog.player_input.setText(card['player'])
        dialog.set_input.setText(card['set'])
        dialog.year_input.setText(str(card['year']) if card['year'] else '')
        
        if dialog.exec() == QDialog.DialogCode.Accepted:
            new_data = dialog.get_card_data()
            
            # Update API
            result = self.api.submit_fingerprint(card['fingerprint'], new_data)
            
            if result['success']:
                # Update local cache
                self.cache.add_card(card['fingerprint'], new_data, confidence=0.5)
                
                # Update recent cards list
                card['player'] = new_data['player_name']
                card['set'] = new_data['card_set']
                card['year'] = new_data.get('card_year')
                
                self.update_recent_cards_display()
                self.log_result(f"✓ Updated: {new_data['player_name']}")
                self.status_label.setText("Card updated!")
            else:
                self.log_result(f"✗ Update failed: {result.get('error')}")
                QMessageBox.warning(self, "Update Failed", f"Failed to update card: {result.get('error')}")
    
    def closeEvent(self, event):
        """Cleanup on close"""
        print("🛑 Shutting down ScanBoss...")
        
        # Stop timers first
        self.timer.stop()
        self.sync_timer.stop()
        
        # Wait for scan worker if running
        if self.scan_worker and self.scan_worker.isRunning():
            print("⏳ Waiting for scan to complete...")
            self.scan_worker.wait(2000)  # Wait max 2 seconds
        
        # Wait for sync worker if running
        if self.sync_worker and self.sync_worker.isRunning():
            print("⏳ Waiting for sync to complete...")
            self.sync_worker.wait(3000)  # Wait max 3 seconds
        
        # Release camera
        if self.camera:
            self.camera.release()
        
        # Close cache
        self.cache.close()
        
        print("✅ Cleanup complete")
        event.accept()


def main():
    app = QApplication(sys.argv)
    app.setStyle('Fusion')
    
    window = ScanBossApp()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
