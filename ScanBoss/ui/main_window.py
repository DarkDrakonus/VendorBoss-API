import time
import logging
from typing import Dict, Optional, List
import cv2
import numpy as np
import threading

from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout, QPushButton, 
    QLabel, QTextEdit, QMessageBox, QCheckBox, QFrame, QSlider
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal, QThread, QObject, pyqtSlot
from PyQt6.QtGui import QImage, QPixmap

# Import application components
from api_client import APIClient
from card_detector import CardDetector
from local_cache import LocalCache
from workers import ScanWorker, ModelUpdateWorker
from .dialogs import FFTCGCardDataDialog, ConfirmMatchDialog
from .batch_scan import BatchScanDialog

logger = logging.getLogger(__name__)

class ScanBossApp(QMainWindow):
    """
    ScanBoss Main Window - Updated for VendorBoss 2.0 / FFTCG
    WITH IMAGE PREVIEW AND BATCH SCANNING
    """
    status_update_signal = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.setWindowTitle("ScanBoss - FFTCG Scanner (VendorBoss 2.0)")
        self.setGeometry(100, 100, 950, 750)

        # Initialize components
        self.detector = CardDetector()
        self.api = APIClient()
        self.local_cache = LocalCache()
        
        # Dropdown data caches
        self.sets_cache: List[Dict] = []
        self.elements_cache: List[str] = []
        self.rarities_cache: List[str] = []

        # Camera and scanning state
        self.camera = None
        self.current_frame: Optional[np.ndarray] = None
        self.scanning_active = False
        self.last_scan_time = 0
        self.last_detected_image: Optional[np.ndarray] = None
        self.auto_scan_checkbox = QCheckBox("Auto Scan")
        
        self.setup_ui()
        self.status_update_signal.connect(self.update_status)
        self.start_camera()
        self.run_model_update()
        self.load_dropdown_data()

    def setup_ui(self):
        """Setup the main UI"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QHBoxLayout(central_widget)
        
        # Left panel - Camera view
        left_panel = QFrame()
        left_panel.setFixedWidth(520)
        left_layout = QVBoxLayout(left_panel)
        
        # Camera label
        self.camera_label = QLabel("Initializing Camera...")
        self.camera_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.camera_label.setFixedSize(500, 375)
        self.camera_label.setStyleSheet("background-color: #1a1a1a; color: white;")
        left_layout.addWidget(self.camera_label, alignment=Qt.AlignmentFlag.AlignCenter)
        
        # Camera controls
        controls_frame = QFrame()
        controls_layout = QVBoxLayout(controls_frame)
        
        self.brightness_slider = QSlider(Qt.Orientation.Horizontal)
        self.brightness_slider.setRange(0, 255)
        self.brightness_slider.valueChanged.connect(self.set_brightness)
        controls_layout.addWidget(QLabel("Brightness"))
        controls_layout.addWidget(self.brightness_slider)
        
        self.focus_slider = QSlider(Qt.Orientation.Horizontal)
        self.focus_slider.setRange(0, 255)
        self.focus_slider.valueChanged.connect(self.set_focus)
        controls_layout.addWidget(QLabel("Focus"))
        controls_layout.addWidget(self.focus_slider)
        
        left_layout.addWidget(controls_frame)

        # Scan buttons
        button_layout = QHBoxLayout()
        
        self.scan_button = QPushButton("Manual Scan")
        self.scan_button.setStyleSheet("""
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
        self.scan_button.clicked.connect(self.manual_scan)
        button_layout.addWidget(self.scan_button)
        
        self.auto_scan_checkbox.setStyleSheet("font-size: 13px;")
        button_layout.addWidget(self.auto_scan_checkbox)
        
        left_layout.addLayout(button_layout)
        
        # Batch scan button (NEW!)
        self.batch_button = QPushButton("📦 Batch Scan Mode")
        self.batch_button.setStyleSheet("""
            QPushButton {
                background-color: #F59E0B;
                color: white;
                padding: 10px 20px;
                font-size: 14px;
                font-weight: bold;
                border-radius: 5px;
            }
            QPushButton:hover {
                background-color: #D97706;
            }
        """)
        self.batch_button.clicked.connect(self.launch_batch_mode)
        left_layout.addWidget(self.batch_button)
        
        main_layout.addWidget(left_panel)

        # Right panel - Status and log
        right_panel = QFrame()
        right_layout = QVBoxLayout(right_panel)
        
        self.status_label = QLabel("Initializing...")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.status_label.setStyleSheet("""
            font-size: 16px;
            font-weight: bold;
            padding: 15px;
            background-color: #f0f0f0;
            border-radius: 5px;
        """)
        
        self.results_text = QTextEdit()
        self.results_text.setReadOnly(True)
        self.results_text.setStyleSheet("""
            font-family: 'Courier New', monospace;
            font-size: 12px;
        """)
        
        right_layout.addWidget(QLabel("Status:"))
        right_layout.addWidget(self.status_label)
        right_layout.addWidget(QLabel("Log:"))
        right_layout.addWidget(self.results_text)
        
        main_layout.addWidget(right_panel)

    def start_camera(self):
        """Start camera capture"""
        if self.camera:
            self.camera.release()
        
        self.camera = cv2.VideoCapture(0)
        
        if not self.camera.isOpened():
            self.log_message("Error: Could not open camera.")
            return
        
        # Log camera resolution
        width = int(self.camera.get(cv2.CAP_PROP_FRAME_WIDTH))
        height = int(self.camera.get(cv2.CAP_PROP_FRAME_HEIGHT))
        self.log_message(f"Camera resolution: {width}x{height}")
        
        self.camera_timer = QTimer(self)
        self.camera_timer.timeout.connect(self.update_frame)
        self.camera_timer.start(33)  # ~30 FPS

    def update_frame(self):
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
                500, 375, Qt.AspectRatioMode.KeepAspectRatio
            )
        )

        # Auto-scan if enabled
        if detection_result["detected"] and self.auto_scan_checkbox.isChecked() and not self.scanning_active:
            self.trigger_scan(detection_result.get("region"))

    @pyqtSlot(int)
    def set_brightness(self, value):
        """Set camera brightness"""
        if self.camera:
            self.camera.set(cv2.CAP_PROP_BRIGHTNESS, value)

    @pyqtSlot(int)
    def set_focus(self, value):
        """Set camera focus"""
        if self.camera:
            self.camera.set(cv2.CAP_PROP_FOCUS, value)

    @pyqtSlot(str)
    def update_status(self, message: str):
        """Update status label"""
        self.status_label.setText(message)

    def load_dropdown_data(self):
        """Load FFTCG metadata for dropdowns"""
        def fetch():
            self.log_message("Fetching FFTCG metadata...")
            
            # Get sets
            sets_resp = self.api.get_sets()
            if sets_resp.get('success'):
                self.sets_cache = sets_resp.get('data', {}).get('sets', [])
            
            # Get elements
            elem_resp = self.api.get_elements()
            if elem_resp.get('success'):
                self.elements_cache = elem_resp.get('data', {}).get('elements', [])
            
            # Get rarities
            rar_resp = self.api.get_rarities()
            if rar_resp.get('success'):
                self.rarities_cache = rar_resp.get('data', {}).get('rarities', [])
            
            self.log_message("Metadata loaded.")
        
        threading.Thread(target=fetch, daemon=True).start()

    def run_model_update(self):
        """Run model update in background thread"""
        self.model_update_thread = QThread()
        self.model_worker = ModelUpdateWorker(self.api, self.local_cache)
        self.model_worker.moveToThread(self.model_update_thread)
        
        self.model_update_thread.started.connect(self.model_worker.run)
        self.model_worker.log_message.connect(self.log_message)
        self.model_worker.status_update.connect(self.status_update_signal)
        self.model_worker.finished.connect(lambda: self.status_update_signal.emit("Ready to scan"))
        self.model_worker.finished.connect(self.model_update_thread.quit)
        
        self.model_update_thread.start()

    def manual_scan(self):
        """Manual scan button - detect card first, then scan"""
        if self.scanning_active or self.current_frame is None:
            return
        
        # Detect card in current frame
        detection_result = self.detector.detect_and_draw(self.current_frame.copy())
        
        if detection_result["detected"]:
            # Card found - scan it
            self.trigger_scan(detection_result.get("region"))
        else:
            # No card detected
            self.log_message("No card detected in frame. Position card in detection zone.")
            self.update_status("No card detected")
    
    def trigger_scan(self, card_region: Optional[np.ndarray] = None):
        """Trigger a scan"""
        if self.scanning_active or self.current_frame is None:
            return
        
        # Rate limiting
        if (time.time() - self.last_scan_time) < 3:
            return
        
        scan_frame = card_region if card_region is not None else self.current_frame
        if scan_frame is None:
            return
        
        self.scanning_active = True
        self.last_scan_time = time.time()
        
        # Start scan worker
        self.scan_thread = QThread()
        self.scan_worker = ScanWorker(scan_frame, self.detector, self.api, self.local_cache)
        self.scan_worker.moveToThread(self.scan_thread)
        
        self.scan_thread.started.connect(self.scan_worker.run)
        self.scan_worker.status_update.connect(self.status_update_signal)
        self.scan_worker.finished.connect(self.handle_scan_result)
        self.scan_worker.finished.connect(self.scan_thread.quit)
        
        self.scan_thread.start()

    def handle_scan_result(self, result: Dict):
        """Handle scan result"""
        self.scanning_active = False
        
        status = result.get("status")
        
        if status == "no_card":
            self.update_status("No card detected.")
            return
        
        if status == "error":
            self.log_message(f"ERROR: {result.get('error')}")
            self.update_status("Error occurred.")
            return
        
        self.last_detected_image = result.get("image_region")
        
        if status == "match":
            # Card identified!
            self.show_card_match(
                result.get('card_data', {}),
                result.get('fingerprint_data'),
                result.get('pricing', {}),
                result.get("source", "api").upper()
            )
        elif status == "new_card":
            # New card - prompt for details
            self.prompt_new_card(result.get('fingerprint_data'))

    def show_card_match(self, card_data: Dict, fingerprint_data: Dict, pricing: Dict, source: str):
        """Show card match dialog WITH IMAGE PREVIEW"""
        self.log_message(f"MATCH! ({source})")
        self.log_message(f"  Card: {card_data.get('card_name', 'Unknown')}")
        self.log_message(f"  Set: {card_data.get('card_set', 'Unknown')}")
        self.log_message(f"  Number: {card_data.get('card_number', 'N/A')}")
        
        self.update_status(f"Match: {card_data.get('card_name')}")
        
        # Show confirmation dialog WITH IMAGE
        dialog = ConfirmMatchDialog(
            self, 
            product_info=card_data, 
            pricing=pricing,
            card_image=self.last_detected_image  # UPDATED!
        )
        dialog.exec()
        
        if dialog.is_confirmed():
            # User confirmed - send positive feedback to API
            self.api.confirm_identification(
                fingerprint_data['fingerprint_hash'],
                confirmed=True
            )
            self.log_message("✓ Match confirmed")
        else:
            # User rejected - send negative feedback
            self.api.confirm_identification(
                fingerprint_data['fingerprint_hash'],
                confirmed=False
            )
            # Prompt for correct card
            self.prompt_new_card(fingerprint_data, "Incorrect match - please enter correct card", card_data)

    def prompt_new_card(self, fingerprint_data: Dict, message: str = "New card detected!", existing_data: Optional[Dict] = None):
        """Prompt user to enter new card details WITH IMAGE PREVIEW"""
        self.log_message(message)
        
        # Show entry dialog WITH IMAGE
        dialog = FFTCGCardDataDialog(
            self,
            sets=self.sets_cache,
            elements=self.elements_cache,
            rarities=self.rarities_cache,
            initial_data=existing_data,
            card_image=self.last_detected_image  # UPDATED!
        )
        
        dialog.exec()
        card_data = dialog.get_data()
        
        if not card_data:
            self.log_message("Card entry cancelled.")
            return
        
        # Encode image
        image_bytes = None
        if self.last_detected_image is not None:
            success, encoded_image = cv2.imencode('.jpg', self.last_detected_image)
            if success:
                image_bytes = encoded_image.tobytes()
        
        self.last_detected_image = None
        
        # Submit to API
        self.log_message(f"Submitting: {card_data.get('card_name')}...")
        result = self.api.submit_new_card(fingerprint_data, card_data, image_bytes)
        
        if result.get('success'):
            self.log_message(f"✓ Successfully submitted {card_data.get('card_name')}")
            self.update_status("Card submitted!")
        else:
            self.log_message(f"✗ Submission failed: {result.get('error', 'Unknown')}")
            self.update_status("Submission failed")

    def launch_batch_mode(self):
        """Launch batch scanning mode (NEW!)"""
        self.log_message("Launching batch scan mode...")
        
        # Pause main scanning
        self.scanning_active = False
        
        # Launch batch dialog
        batch_dialog = BatchScanDialog(
            self,
            api=self.api,
            detector=self.detector,
            sets=self.sets_cache,
            elements=self.elements_cache,
            rarities=self.rarities_cache
        )
        
        batch_dialog.exec()
        
        # Get results
        scanned_cards = batch_dialog.get_scanned_cards()
        
        self.log_message(f"✓ Batch complete! Scanned {len(scanned_cards)} cards")
        
        # List scanned cards
        for i, card in enumerate(scanned_cards, 1):
            self.log_message(f"  {i}. {card['name']} ({card['number']})")
        
        # Resume main scanning
        self.scanning_active = False
        self.update_status("Ready to scan")

    def log_message(self, message: str):
        """Log a message to the text area"""
        timestamp = time.strftime("%H:%M:%S")
        self.results_text.append(f"[{timestamp}] {message}")

    def closeEvent(self, event):
        """Handle window close"""
        if self.camera:
            self.camera.release()
        event.accept()
