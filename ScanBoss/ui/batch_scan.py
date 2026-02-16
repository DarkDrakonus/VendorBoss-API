"""
Batch Scanning Mode for ScanBoss
Rapid card entry with auto-detection
"""
import time
import cv2
import numpy as np
from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QPushButton, QLabel,
    QProgressBar, QListWidget, QTextEdit
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal
from PyQt6.QtGui import QPixmap, QImage
from typing import List, Dict

from card_detector import CardDetector
from api_client import APIClient
from ui.dialogs import FFTCGCardDataDialog, ConfirmMatchDialog

class BatchScanDialog(QDialog):
    """
    Batch scanning mode for rapid card entry
    """
    
    def __init__(self, parent=None, api: APIClient = None, detector: CardDetector = None,
                 sets: List = None, elements: List = None, rarities: List = None):
        super().__init__(parent)
        
        self.setWindowTitle("Batch Scanning Mode")
        self.setGeometry(100, 100, 1000, 700)
        
        self.api = api
        self.detector = detector or CardDetector()
        self.sets = sets or []
        self.elements = elements or []
        self.rarities = rarities or []
        
        # Camera
        self.camera = None
        self.current_frame = None
        
        # Scanning state
        self.scanning_active = True
        self.auto_capture = False
        self.last_capture_time = 0
        self.capture_cooldown = 2.0  # seconds
        
        # Batch tracking
        self.cards_scanned = []
        self.current_card_image = None
        
        self._setup_ui()
        self._start_camera()
    
    def _setup_ui(self):
        """Setup batch scanning UI"""
        layout = QHBoxLayout(self)
        
        # Left panel - Camera view
        left_panel = QVBoxLayout()
        
        # Camera label
        self.camera_label = QLabel("Initializing camera...")
        self.camera_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.camera_label.setFixedSize(640, 480)
        self.camera_label.setStyleSheet("background-color: #1a1a1a; color: white;")
        left_panel.addWidget(self.camera_label)
        
        # Status label
        self.status_label = QLabel("Ready - Place card and press SPACE or click Capture")
        self.status_label.setStyleSheet("""
            font-size: 14px;
            font-weight: bold;
            padding: 10px;
            background-color: #f0f0f0;
            border-radius: 5px;
        """)
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        left_panel.addWidget(self.status_label)
        
        # Control buttons
        button_layout = QHBoxLayout()
        
        self.capture_btn = QPushButton("📷 Capture (Space)")
        self.capture_btn.setStyleSheet("""
            QPushButton {
                background-color: #667EEA;
                color: white;
                padding: 10px 20px;
                font-size: 14px;
                font-weight: bold;
                border-radius: 5px;
            }
            QPushButton:hover {
                background-color: #5568D3;
            }
        """)
        self.capture_btn.clicked.connect(self._manual_capture)
        button_layout.addWidget(self.capture_btn)
        
        self.auto_btn = QPushButton("🤖 Auto-Capture: OFF")
        self.auto_btn.setCheckable(True)
        self.auto_btn.clicked.connect(self._toggle_auto_capture)
        button_layout.addWidget(self.auto_btn)
        
        left_panel.addLayout(button_layout)
        
        layout.addLayout(left_panel, stretch=2)
        
        # Right panel - Progress and list
        right_panel = QVBoxLayout()
        
        # Title
        title = QLabel("Batch Progress")
        title.setStyleSheet("font-size: 16px; font-weight: bold;")
        right_panel.addWidget(title)
        
        # Progress bar
        self.progress_bar = QProgressBar()
        self.progress_bar.setValue(0)
        right_panel.addWidget(self.progress_bar)
        
        # Count label
        self.count_label = QLabel("Cards Scanned: 0")
        self.count_label.setStyleSheet("font-size: 14px; font-weight: bold;")
        right_panel.addWidget(self.count_label)
        
        # Scanned cards list
        list_label = QLabel("Scanned Cards:")
        right_panel.addWidget(list_label)
        
        self.cards_list = QListWidget()
        right_panel.addWidget(self.cards_list)
        
        # Log
        log_label = QLabel("Log:")
        right_panel.addWidget(log_label)
        
        self.log_text = QTextEdit()
        self.log_text.setReadOnly(True)
        self.log_text.setMaximumHeight(150)
        right_panel.addWidget(self.log_text)
        
        # Done button
        done_btn = QPushButton("✓ Finish Batch")
        done_btn.setStyleSheet("""
            QPushButton {
                background-color: #22C55E;
                color: white;
                padding: 10px 20px;
                font-weight: bold;
                border-radius: 5px;
            }
            QPushButton:hover {
                background-color: #16A34A;
            }
        """)
        done_btn.clicked.connect(self.accept)
        right_panel.addWidget(done_btn)
        
        layout.addLayout(right_panel, stretch=1)
    
    def _start_camera(self):
        """Start camera capture"""
        self.camera = cv2.VideoCapture(0)
        
        if not self.camera.isOpened():
            self.log("❌ Could not open camera")
            return
        
        self.camera_timer = QTimer(self)
        self.camera_timer.timeout.connect(self._update_frame)
        self.camera_timer.start(33)  # ~30 FPS
        
        self.log("✓ Camera started")
    
    def _update_frame(self):
        """Update camera frame"""
        if not self.camera:
            return
        
        ret, frame = self.camera.read()
        if not ret:
            return
        
        self.current_frame = frame
        
        # Detect and draw
        detection_result = self.detector.detect_and_draw(frame.copy())
        display_frame = detection_result["frame"]
        
        # Convert to Qt format
        rgb_image = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
        h, w, ch = rgb_image.shape
        qt_image = QImage(rgb_image.data, w, h, ch * w, QImage.Format.Format_RGB888)
        self.camera_label.setPixmap(
            QPixmap.fromImage(qt_image).scaled(
                640, 480, Qt.AspectRatioMode.KeepAspectRatio
            )
        )
        
        # Auto-capture if enabled and card detected
        if self.auto_capture and detection_result["detected"]:
            current_time = time.time()
            if (current_time - self.last_capture_time) > self.capture_cooldown:
                self._capture_card(detection_result.get("region"))
    
    def _manual_capture(self):
        """Manual capture button clicked"""
        if self.current_frame is not None:
            # Detect card first
            detection = self.detector.detect_card_in_frame(self.current_frame)
            
            if detection and detection.get('detected'):
                self._capture_card(detection['region'])
            else:
                self.status_label.setText("❌ No card detected - adjust position")
                self.status_label.setStyleSheet("""
                    font-size: 14px;
                    font-weight: bold;
                    padding: 10px;
                    background-color: #FEE2E2;
                    color: #991B1B;
                    border-radius: 5px;
                """)
    
    def _toggle_auto_capture(self, checked: bool):
        """Toggle auto-capture mode"""
        self.auto_capture = checked
        if checked:
            self.auto_btn.setText("🤖 Auto-Capture: ON")
            self.auto_btn.setStyleSheet("background-color: #22C55E; color: white;")
            self.log("✓ Auto-capture enabled")
        else:
            self.auto_btn.setText("🤖 Auto-Capture: OFF")
            self.auto_btn.setStyleSheet("")
            self.log("Auto-capture disabled")
    
    def _capture_card(self, card_region: np.ndarray):
        """Capture and process card"""
        self.last_capture_time = time.time()
        self.current_card_image = card_region
        
        self.status_label.setText("📸 Card captured! Identifying...")
        self.status_label.setStyleSheet("""
            font-size: 14px;
            font-weight: bold;
            padding: 10px;
            background-color: #DBEAFE;
            color: #1E40AF;
            border-radius: 5px;
        """)
        
        # Generate fingerprint
        fingerprint_data = self.detector._generate_14_component_fingerprint(card_region)
        
        if not fingerprint_data:
            self.log("❌ Failed to generate fingerprint")
            return
        
        # Try to identify
        result = self.api.identify_card(fingerprint_data)
        
        if result.get('success') and result.get('data', {}).get('found'):
            # Card identified!
            self._handle_identified_card(result['data'], fingerprint_data)
        else:
            # New card
            self._handle_new_card(fingerprint_data)
    
    def _handle_identified_card(self, data: Dict, fingerprint_data: Dict):
        """Handle identified card"""
        product = data.get('product', {})
        pricing = data.get('pricing', {})
        
        self.log(f"✓ Identified: {product.get('card_name', 'Unknown')}")
        
        # Show confirmation dialog
        dialog = ConfirmMatchDialog(
            self,
            product_info=product,
            pricing=pricing,
            card_image=self.current_card_image
        )
        
        dialog.exec()
        
        if dialog.is_confirmed():
            # User confirmed
            self.api.confirm_identification(
                fingerprint_data['fingerprint_hash'],
                confirmed=True
            )
            
            self._add_to_batch(product.get('card_name', 'Unknown'), product.get('card_number', 'N/A'))
            self.status_label.setText("✓ Card confirmed! Ready for next card")
            self.status_label.setStyleSheet("""
                font-size: 14px;
                font-weight: bold;
                padding: 10px;
                background-color: #D1FAE5;
                color: #065F46;
                border-radius: 5px;
            """)
        else:
            # User rejected - treat as new card
            self.api.confirm_identification(
                fingerprint_data['fingerprint_hash'],
                confirmed=False
            )
            self._handle_new_card(fingerprint_data, existing_data=product)
    
    def _handle_new_card(self, fingerprint_data: Dict, existing_data: Dict = None):
        """Handle new card entry"""
        self.log("📝 New card - please enter details")
        
        # Show entry dialog
        dialog = FFTCGCardDataDialog(
            self,
            sets=self.sets,
            elements=self.elements,
            rarities=self.rarities,
            initial_data=existing_data,
            card_image=self.current_card_image
        )
        
        dialog.exec()
        card_data = dialog.get_data()
        
        if not card_data:
            self.log("⚠️  Card entry cancelled")
            self.status_label.setText("Ready for next card")
            return
        
        # Encode image
        image_bytes = None
        if self.current_card_image is not None:
            success, encoded_image = cv2.imencode('.jpg', self.current_card_image)
            if success:
                image_bytes = encoded_image.tobytes()
        
        # Submit to API
        result = self.api.submit_new_card(fingerprint_data, card_data, image_bytes)
        
        if result.get('success'):
            self.log(f"✓ Successfully added: {card_data.get('card_name')}")
            self._add_to_batch(card_data.get('card_name'), card_data.get('card_number'))
            self.status_label.setText("✓ Card added! Ready for next card")
            self.status_label.setStyleSheet("""
                font-size: 14px;
                font-weight: bold;
                padding: 10px;
                background-color: #D1FAE5;
                color: #065F46;
                border-radius: 5px;
            """)
        else:
            self.log(f"❌ Failed to add card: {result.get('error')}")
    
    def _add_to_batch(self, card_name: str, card_number: str):
        """Add card to batch list"""
        self.cards_scanned.append({'name': card_name, 'number': card_number})
        
        # Update list
        self.cards_list.addItem(f"{len(self.cards_scanned)}. {card_name} ({card_number})")
        
        # Update count
        self.count_label.setText(f"Cards Scanned: {len(self.cards_scanned)}")
        
        # Update progress (if target set)
        # For now just show count
    
    def log(self, message: str):
        """Add message to log"""
        timestamp = time.strftime("%H:%M:%S")
        self.log_text.append(f"[{timestamp}] {message}")
    
    def keyPressEvent(self, event):
        """Handle keyboard shortcuts"""
        if event.key() == Qt.Key.Key_Space:
            self._manual_capture()
        elif event.key() == Qt.Key.Key_Escape:
            self.accept()
        else:
            super().keyPressEvent(event)
    
    def closeEvent(self, event):
        """Handle window close"""
        if self.camera:
            self.camera.release()
        event.accept()
    
    def get_scanned_cards(self) -> List[Dict]:
        """Get list of scanned cards"""
        return self.cards_scanned
