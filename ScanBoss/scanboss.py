"""
ScanBoss AI - Unified Card Scanner

ONE application with two modes:
- Live Camera: Real-time scanning with webcam
- Batch Folder: Process folder of card photos

Run: python3 scanboss.py
"""

import sys
import cv2
import numpy as np
from datetime import datetime
from pathlib import Path
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QGroupBox, QMessageBox, QSlider, QDialog, 
    QLineEdit, QCheckBox, QFormLayout, QDialogButtonBox, QTabWidget,
    QFileDialog, QTableWidget, QTableWidgetItem, QHeaderView, QProgressBar
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal, QThread
from PyQt6.QtGui import QImage, QPixmap
import requests
from io import BytesIO
from PIL import Image as PILImage

from vgg16_detector import VGG16Detector
from fixed_region_detector import FixedRegionDetector
from magic_api_client import MagicAPIClient


# =============================================================================
# WORKER THREADS
# =============================================================================

class LiveDetectionWorker(QThread):
    """Worker thread for live camera detection"""
    result_ready = pyqtSignal(dict)
    
    def __init__(self, frame, card_detector, vgg16_detector, threshold=0.60, debug=False):
        super().__init__()
        self.frame = frame
        self.card_detector = card_detector
        self.vgg16_detector = vgg16_detector
        self.threshold = threshold
        self.debug = debug
        self.running = True
    
    def run(self):
        if not self.running:
            return
        
        try:
            # Step 1: Detect card region
            card_detection = self.card_detector.detect_card_in_frame(self.frame)
            
            if not card_detection.get('detected', False):
                self.result_ready.emit({'status': 'no_detection'})
                return
            
            card_image = card_detection.get('card_image')
            if card_image is None:
                self.result_ready.emit({'status': 'no_detection'})
                return
            
            # Debug: Save cropped card
            if self.debug:
                timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                debug_path = f"debug_card_{timestamp}.jpg"
                cv2.imwrite(debug_path, card_image)
                print(f"[DEBUG] Saved to {debug_path}")
            
            # Step 2: Identify with VGG16
            result = self.vgg16_detector.detect_card(card_image, confidence_threshold=self.threshold)
            
            if result and self.running:
                result['status'] = 'success'
                self.result_ready.emit(result)
            else:
                self.result_ready.emit({'status': 'no_detection'})
                
        except Exception as e:
            print(f"[ERROR] {e}")
            self.result_ready.emit({'status': 'error', 'error': str(e)})


class BatchScanWorker(QThread):
    """Worker thread for batch folder scanning"""
    progress = pyqtSignal(int, int)
    card_scanned = pyqtSignal(dict)
    finished = pyqtSignal(list)
    
    def __init__(self, image_files, detector):
        super().__init__()
        self.image_files = image_files
        self.detector = detector
        self.running = True
    
    def run(self):
        results = []
        total = len(self.image_files)
        
        for i, img_path in enumerate(self.image_files):
            if not self.running:
                break
            
            try:
                img = cv2.imread(str(img_path))
                if img is None:
                    continue
                
                result = self.detector.detect_card(img, confidence_threshold=0.50)
                
                if result:
                    result['image_path'] = str(img_path)
                    result['filename'] = img_path.name
                    result['status'] = 'detected'
                else:
                    result = {
                        'image_path': str(img_path),
                        'filename': img_path.name,
                        'status': 'failed',
                        'name': 'Detection failed',
                        'confidence': 0.0
                    }
                
                results.append(result)
                self.card_scanned.emit(result)
                self.progress.emit(i + 1, total)
                
            except Exception as e:
                print(f"Error: {e}")
        
        self.finished.emit(results)
    
    def stop(self):
        self.running = False


# =============================================================================
# API SETTINGS DIALOG
# =============================================================================

class APISettingsDialog(QDialog):
    """API Configuration"""
    
    def __init__(self, parent, api_client, api_enabled):
        super().__init__(parent)
        self.setWindowTitle("API Settings")
        self.setModal(True)
        self.setMinimumWidth(400)
        
        layout = QFormLayout()
        
        self.enabled_checkbox = QCheckBox("Enable VendorBoss API")
        self.enabled_checkbox.setChecked(api_enabled)
        layout.addRow("", self.enabled_checkbox)
        
        self.url_input = QLineEdit()
        self.url_input.setText(api_client.base_url)
        self.url_input.setPlaceholderText("http://localhost:8000")
        layout.addRow("API URL:", self.url_input)
        
        self.key_input = QLineEdit()
        self.key_input.setPlaceholderText("Optional API Key")
        self.key_input.setEchoMode(QLineEdit.EchoMode.Password)
        layout.addRow("API Key:", self.key_input)
        
        self.test_btn = QPushButton("🔌 Test Connection")
        self.test_btn.clicked.connect(self.test_connection)
        layout.addRow("", self.test_btn)
        
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addRow(buttons)
        
        self.setLayout(layout)
        self.setStyleSheet("""
            QDialog { background-color: #2b2b2b; color: #fff; }
            QLabel { color: #fff; }
            QLineEdit { background-color: #3c3c3c; color: #fff; border: 1px solid #555; padding: 5px; }
            QCheckBox { color: #fff; }
            QPushButton { background-color: #0066cc; color: white; padding: 8px; }
            QPushButton:hover { background-color: #0088ee; }
        """)
    
    def test_connection(self):
        url = self.url_input.text().strip()
        if not url:
            QMessageBox.warning(self, "Error", "Enter API URL")
            return
        
        try:
            response = requests.get(f"{url}/api/health", timeout=5)
            if response.status_code == 200:
                QMessageBox.information(self, "Success", f"✓ Connected!\n\n{url}")
            else:
                QMessageBox.warning(self, "Failed", f"Status {response.status_code}")
        except Exception as e:
            QMessageBox.warning(self, "Failed", f"Connection error:\n\n{e}")
    
    def get_config(self):
        return {
            'enabled': self.enabled_checkbox.isChecked(),
            'api_url': self.url_input.text().strip(),
            'api_key': self.key_input.text().strip()
        }


# =============================================================================
# MAIN APPLICATION
# =============================================================================

class ScanBoss(QMainWindow):
    """Unified ScanBoss Application"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ScanBoss AI - Card Scanner")
        self.setGeometry(100, 100, 1400, 800)
        
        # Initialize detectors
        try:
            self.card_detector = FixedRegionDetector()
            self.vgg16_detector = VGG16Detector(game="magic")
            print("✓ Detectors loaded")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to load:\n{e}")
            sys.exit(1)
        
        # Initialize API
        self.api_client = MagicAPIClient(base_url="http://localhost:8000")
        self.api_enabled = False
        print("✓ API Client ready (disabled)")
        
        # State
        self.camera = None
        self.guide_roi = None
        self.current_detection = None
        self.detection_worker = None
        self.detection_cooldown = False
        self.confidence_threshold = 0.60
        self.debug_mode = False
        self.auto_scan_enabled = False
        
        # Batch state
        self.image_files = []
        self.scan_results = []
        self.batch_worker = None
        
        # Setup UI
        self.setup_ui()
        
        # Dark theme
        self.setStyleSheet("""
            QMainWindow, QWidget { background-color: #1e1e1e; }
            QLabel { color: #ffffff; }
            QTabWidget::pane { border: 1px solid #444; }
            QTabBar::tab { background: #2b2b2b; color: #fff; padding: 10px; }
            QTabBar::tab:selected { background: #0066cc; }
            QPushButton { background: #0066cc; color: white; padding: 10px; border-radius: 5px; }
            QPushButton:hover { background: #0088ee; }
            QPushButton:disabled { background: #555; color: #888; }
            QTableWidget { background: #2b2b2b; color: #fff; gridline-color: #3c3c3c; }
            QHeaderView::section { background: #3c3c3c; color: #fff; padding: 5px; border: 1px solid #555; }
            QProgressBar { border: 2px solid #555; border-radius: 5px; text-align: center; background: #2b2b2b; color: white; }
            QProgressBar::chunk { background: #00aa00; }
        """)
    
    def setup_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        layout = QVBoxLayout()
        
        # Tabs for different modes
        self.tabs = QTabWidget()
        self.tabs.addTab(self.create_live_tab(), "📹 Live Camera")
        self.tabs.addTab(self.create_batch_tab(), "📁 Batch Folder")
        self.tabs.currentChanged.connect(self.on_tab_changed)
        
        layout.addWidget(self.tabs)
        central_widget.setLayout(layout)
    
    def create_live_tab(self):
        """Live camera scanning interface"""
        widget = QWidget()
        main_layout = QHBoxLayout()
        
        # LEFT: Camera feed
        left_panel = QVBoxLayout()
        
        self.camera_label = QLabel()
        self.camera_label.setMinimumSize(960, 540)
        self.camera_label.setStyleSheet("border: 2px solid #333; background: black;")
        self.camera_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        left_panel.addWidget(self.camera_label)
        
        self.status_label = QLabel("Fill green brackets, then click 'Scan Now'")
        self.status_label.setStyleSheet("color: #00aaff; font-size: 16px; padding: 10px;")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        left_panel.addWidget(self.status_label)
        
        # Scan buttons
        scan_buttons = QHBoxLayout()
        
        self.manual_scan_btn = QPushButton("🔍 Scan Now")
        self.manual_scan_btn.setStyleSheet("background: #00aa00; font-size: 18px; font-weight: bold; padding: 15px;")
        self.manual_scan_btn.clicked.connect(self.manual_scan)
        scan_buttons.addWidget(self.manual_scan_btn, 3)
        
        self.auto_scan_toggle = QPushButton("Enable Auto-Scan")
        self.auto_scan_toggle.setCheckable(True)
        self.auto_scan_toggle.clicked.connect(self.toggle_auto_scan)
        scan_buttons.addWidget(self.auto_scan_toggle, 2)
        
        left_panel.addLayout(scan_buttons)
        
        # Threshold slider
        threshold_layout = QHBoxLayout()
        threshold_layout.addWidget(QLabel("Threshold:"))
        
        self.threshold_slider = QSlider(Qt.Orientation.Horizontal)
        self.threshold_slider.setMinimum(40)
        self.threshold_slider.setMaximum(90)
        self.threshold_slider.setValue(60)
        self.threshold_slider.valueChanged.connect(self.update_threshold)
        threshold_layout.addWidget(self.threshold_slider)
        
        self.threshold_value_label = QLabel("60%")
        threshold_layout.addWidget(self.threshold_value_label)
        
        left_panel.addLayout(threshold_layout)
        
        # API Settings
        self.api_settings_btn = QPushButton("⚙️ API Settings")
        self.api_settings_btn.clicked.connect(self.open_api_settings)
        left_panel.addWidget(self.api_settings_btn)
        
        # Confirm buttons
        button_layout = QHBoxLayout()
        
        self.confirm_btn = QPushButton("✓ Correct Card")
        self.confirm_btn.setEnabled(False)
        self.confirm_btn.setStyleSheet("background: #00aa00; font-size: 16px; padding: 15px;")
        self.confirm_btn.clicked.connect(self.confirm_card)
        button_layout.addWidget(self.confirm_btn)
        
        self.reject_btn = QPushButton("✗ Wrong Card")
        self.reject_btn.setEnabled(False)
        self.reject_btn.setStyleSheet("background: #aa0000; font-size: 16px; padding: 15px;")
        self.reject_btn.clicked.connect(self.reject_card)
        button_layout.addWidget(self.reject_btn)
        
        left_panel.addLayout(button_layout)
        
        # RIGHT: Card details
        right_panel = self.create_card_details_panel()
        
        main_layout.addLayout(left_panel, 2)
        main_layout.addLayout(right_panel, 1)
        
        widget.setLayout(main_layout)
        return widget
    
    def create_batch_tab(self):
        """Batch folder scanning interface"""
        widget = QWidget()
        layout = QVBoxLayout()
        
        # Header
        header = QLabel("📁 Batch Card Scanner")
        header.setStyleSheet("font-size: 24px; font-weight: bold; padding: 10px;")
        layout.addWidget(header)
        
        # Controls
        control_layout = QHBoxLayout()
        
        self.select_folder_btn = QPushButton("📂 Select Folder")
        self.select_folder_btn.clicked.connect(self.select_folder)
        control_layout.addWidget(self.select_folder_btn)
        
        self.start_batch_btn = QPushButton("▶️ Start Scan")
        self.start_batch_btn.clicked.connect(self.start_batch)
        self.start_batch_btn.setEnabled(False)
        control_layout.addWidget(self.start_batch_btn)
        
        self.stop_batch_btn = QPushButton("⏹️ Stop")
        self.stop_batch_btn.clicked.connect(self.stop_batch)
        self.stop_batch_btn.setEnabled(False)
        control_layout.addWidget(self.stop_batch_btn)
        
        self.export_btn = QPushButton("💾 Export CSV")
        self.export_btn.clicked.connect(self.export_results)
        self.export_btn.setEnabled(False)
        control_layout.addWidget(self.export_btn)
        
        control_layout.addStretch()
        layout.addLayout(control_layout)
        
        # Stats
        stats_layout = QHBoxLayout()
        self.folder_label = QLabel("No folder selected")
        self.folder_label.setStyleSheet("color: #aaa;")
        stats_layout.addWidget(self.folder_label)
        stats_layout.addStretch()
        self.batch_stats_label = QLabel("Ready")
        stats_layout.addWidget(self.batch_stats_label)
        layout.addLayout(stats_layout)
        
        # Progress
        self.batch_progress = QProgressBar()
        self.batch_progress.setVisible(False)
        layout.addWidget(self.batch_progress)
        
        # Results table
        self.results_table = QTableWidget()
        self.results_table.setColumnCount(7)
        self.results_table.setHorizontalHeaderLabels([
            "✓", "Filename", "Card Name", "Set", "Confidence", "Price", "Status"
        ])
        
        header = self.results_table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(4, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(5, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(6, QHeaderView.ResizeMode.ResizeToContents)
        
        layout.addWidget(self.results_table)
        
        widget.setLayout(layout)
        return widget
    
    def create_card_details_panel(self):
        """Card details display"""
        layout = QVBoxLayout()
        
        details_group = QGroupBox("Card Details")
        details_layout = QVBoxLayout()
        
        self.card_image_label = QLabel()
        self.card_image_label.setMinimumSize(300, 420)
        self.card_image_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.card_image_label.setStyleSheet("border: 1px solid #444; background: #222;")
        details_layout.addWidget(self.card_image_label)
        
        self.card_name_label = QLabel("No card detected")
        self.card_name_label.setStyleSheet("font-size: 20px; font-weight: bold; padding: 5px;")
        self.card_name_label.setWordWrap(True)
        details_layout.addWidget(self.card_name_label)
        
        self.card_type_label = QLabel("")
        self.card_type_label.setStyleSheet("font-size: 14px; color: #aaa; padding: 5px;")
        self.card_type_label.setWordWrap(True)
        details_layout.addWidget(self.card_type_label)
        
        self.card_set_label = QLabel("")
        self.card_set_label.setStyleSheet("font-size: 14px; color: #aaa; padding: 5px;")
        details_layout.addWidget(self.card_set_label)
        
        self.card_price_label = QLabel("")
        self.card_price_label.setStyleSheet("font-size: 16px; font-weight: bold; color: #00ff00; padding: 5px;")
        details_layout.addWidget(self.card_price_label)
        
        self.confidence_label = QLabel("")
        self.confidence_label.setStyleSheet("font-size: 14px; color: #ffaa00; padding: 5px;")
        details_layout.addWidget(self.confidence_label)
        
        details_layout.addStretch()
        details_group.setLayout(details_layout)
        layout.addWidget(details_group)
        
        return layout
    
    # ========================================================================
    # LIVE CAMERA MODE
    # ========================================================================
    
    def on_tab_changed(self, index):
        """Handle tab changes"""
        if index == 0:  # Live camera
            self.start_camera()
        else:  # Batch
            self.stop_camera()
    
    def start_camera(self):
        """Start camera feed"""
        if self.camera is None:
            self.camera = cv2.VideoCapture(0)
            self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
            self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
            
            self.timer = QTimer()
            self.timer.timeout.connect(self.update_frame)
            self.timer.start(30)
    
    def stop_camera(self):
        """Stop camera feed"""
        if hasattr(self, 'timer'):
            self.timer.stop()
        if self.camera:
            self.camera.release()
            self.camera = None
    
    def update_frame(self):
        """Update camera frame"""
        if not self.camera:
            return
        
        ret, frame = self.camera.read()
        if not ret:
            return
        
        # Draw guide
        frame_with_guide = self._draw_card_guide(frame.copy())
        
        # Display
        rgb_frame = cv2.cvtColor(frame_with_guide, cv2.COLOR_BGR2RGB)
        h, w, ch = rgb_frame.shape
        qt_image = QImage(rgb_frame.data, w, h, ch * w, QImage.Format.Format_RGB888)
        scaled = QPixmap.fromImage(qt_image).scaled(
            self.camera_label.size(),
            Qt.AspectRatioMode.KeepAspectRatio
        )
        self.camera_label.setPixmap(scaled)
        
        # Auto-scan
        if self.auto_scan_enabled:
            if not self.detection_cooldown and (not self.detection_worker or not self.detection_worker.isRunning()):
                self.start_detection(frame)
    
    def _draw_card_guide(self, frame):
        """Draw guide brackets"""
        h, w = frame.shape[:2]
        
        guide_height = int(h * 0.7)
        guide_width = int(guide_height / 1.4)
        
        x1 = (w - guide_width) // 2
        y1 = (h - guide_height) // 2
        x2 = x1 + guide_width
        y2 = y1 + guide_height
        
        bracket_len = 50
        thickness = 3
        color = (0, 255, 0)
        
        # Draw corners
        cv2.line(frame, (x1, y1), (x1 + bracket_len, y1), color, thickness)
        cv2.line(frame, (x1, y1), (x1, y1 + bracket_len), color, thickness)
        cv2.line(frame, (x2, y1), (x2 - bracket_len, y1), color, thickness)
        cv2.line(frame, (x2, y1), (x2, y1 + bracket_len), color, thickness)
        cv2.line(frame, (x1, y2), (x1 + bracket_len, y2), color, thickness)
        cv2.line(frame, (x1, y2), (x1, y2 - bracket_len), color, thickness)
        cv2.line(frame, (x2, y2), (x2 - bracket_len, y2), color, thickness)
        cv2.line(frame, (x2, y2), (x2, y2 - bracket_len), color, thickness)
        
        cv2.putText(frame, "Fill brackets with card", 
                   (x1, y1 - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.8, color, 2)
        
        self.guide_roi = (x1, y1, guide_width, guide_height)
        return frame
    
    def toggle_auto_scan(self, checked):
        """Toggle auto-scan"""
        self.auto_scan_enabled = checked
        self.auto_scan_toggle.setText("Disable Auto-Scan" if checked else "Enable Auto-Scan")
    
    def update_threshold(self, value):
        """Update confidence threshold"""
        self.confidence_threshold = value / 100.0
        self.threshold_value_label.setText(f"{value}%")
    
    def manual_scan(self):
        """Manually trigger scan"""
        if not self.camera:
            return
        
        ret, frame = self.camera.read()
        if ret:
            self.detection_cooldown = False
            self.start_detection(frame)
    
    def start_detection(self, frame):
        """Start detection"""
        self.status_label.setText("🔍 Detecting...")
        
        # Crop to guide
        detection_frame = frame.copy()
        if self.guide_roi:
            x, y, w, h = self.guide_roi
            detection_frame = frame[y:y+h, x:x+w]
        
        self.detection_worker = LiveDetectionWorker(
            detection_frame, 
            self.card_detector,
            self.vgg16_detector,
            self.confidence_threshold,
            debug=self.debug_mode
        )
        self.detection_worker.result_ready.connect(self.on_detection_complete)
        self.detection_worker.start()
        
        self.detection_cooldown = True
        QTimer.singleShot(2000, lambda: setattr(self, 'detection_cooldown', False))
    
    def on_detection_complete(self, result):
        """Handle detection result"""
        status = result.get('status', 'unknown')
        
        if status == 'no_detection':
            self.status_label.setText("No card detected - try again")
            return
        
        if status != 'success':
            return
        
        self.current_detection = result
        self.status_label.setText(f"✓ Detected! ({result['confidence']:.1%})")
        self.display_card_details(result)
        self.confirm_btn.setEnabled(True)
        self.reject_btn.setEnabled(True)
    
    def display_card_details(self, card_info):
        """Display card details"""
        self.card_name_label.setText(card_info.get('name', 'Unknown'))
        
        type_line = card_info.get('type_line', '')
        if card_info.get('power') and card_info.get('toughness'):
            type_line += f" ({card_info['power']}/{card_info['toughness']})"
        self.card_type_label.setText(type_line)
        
        set_name = card_info.get('set_name', '')
        collector_num = card_info.get('collector_number', '')
        self.card_set_label.setText(f"{set_name} #{collector_num}")
        
        prices = card_info.get('prices', {})
        price_text = ""
        if prices.get('usd'):
            price_text += f"${prices['usd']}"
        if prices.get('usd_foil'):
            price_text += f" | Foil: ${prices['usd_foil']}"
        self.card_price_label.setText(f"Price: {price_text}" if price_text else "")
        
        confidence = card_info.get('confidence', 0)
        self.confidence_label.setText(f"AI Confidence: {confidence:.1%}")
        
        # Load image
        if card_info.get('image_url'):
            self.load_card_image(card_info['image_url'])
    
    def load_card_image(self, url):
        """Load card image"""
        try:
            response = requests.get(url, timeout=5)
            img = PILImage.open(BytesIO(response.content)).convert('RGB')
            img_array = np.array(img)
            h, w, ch = img_array.shape
            qt_image = QImage(img_array.data, w, h, ch * w, QImage.Format.Format_RGB888)
            pixmap = QPixmap.fromImage(qt_image).scaled(
                self.card_image_label.size(),
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation
            )
            self.card_image_label.setPixmap(pixmap)
        except:
            pass
    
    def confirm_card(self):
        """User confirms card"""
        if not self.current_detection:
            return
        
        card_name = self.current_detection.get('name', 'Unknown')
        
        if self.api_enabled:
            success = self._send_to_api(self.current_detection)
            if success:
                QMessageBox.information(self, "Success", f"✓ {card_name} added!")
            else:
                QMessageBox.warning(self, "Error", f"Failed to add {card_name}")
        else:
            QMessageBox.information(self, "Detected", f"✓ {card_name}\n\n(API disabled)")
        
        self.reset_detection()
    
    def reject_card(self):
        """User rejects card"""
        QMessageBox.information(self, "Rejected", "Try again with better lighting/angle")
        self.reset_detection()
    
    def reset_detection(self):
        """Reset detection state"""
        self.current_detection = None
        self.confirm_btn.setEnabled(False)
        self.reject_btn.setEnabled(False)
        self.status_label.setText("Ready")
        self.card_name_label.setText("No card detected")
        self.card_type_label.setText("")
        self.card_set_label.setText("")
        self.card_price_label.setText("")
        self.confidence_label.setText("")
        self.card_image_label.clear()
    
    def _send_to_api(self, card_data):
        """Send to API"""
        try:
            api_data = {
                'card_id': card_data.get('card_id'),
                'confidence': card_data.get('confidence'),
                'name': card_data.get('name'),
                'set': card_data.get('set'),
                'set_name': card_data.get('set_name'),
                'collector_number': card_data.get('collector_number'),
                'type_line': card_data.get('type_line'),
                'prices': card_data.get('prices', {}),
                'condition': 'Near Mint',
                'quantity': 1,
                'is_foil': False,
                'scanned_at': datetime.now().isoformat(),
                'scanner_version': 'ScanBoss v1.0'
            }
            
            response = self.api_client.add_scanned_card(api_data)
            return response.get('success', False)
        except:
            return False
    
    # ========================================================================
    # BATCH FOLDER MODE
    # ========================================================================
    
    def select_folder(self):
        """Select folder"""
        folder = QFileDialog.getExistingDirectory(self, "Select Folder", str(Path.home()))
        if not folder:
            return
        
        folder_path = Path(folder)
        image_exts = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
        self.image_files = [f for f in folder_path.iterdir() if f.suffix.lower() in image_exts]
        
        if not self.image_files:
            QMessageBox.warning(self, "No Images", f"No images in {folder}")
            return
        
        self.folder_label.setText(f"📁 {folder_path.name} ({len(self.image_files)} images)")
        self.start_batch_btn.setEnabled(True)
        self.batch_stats_label.setText(f"Ready: {len(self.image_files)} images")
    
    def start_batch(self):
        """Start batch scan"""
        self.scan_results = []
        self.results_table.setRowCount(0)
        
        self.start_batch_btn.setEnabled(False)
        self.select_folder_btn.setEnabled(False)
        self.stop_batch_btn.setEnabled(True)
        self.batch_progress.setVisible(True)
        self.batch_progress.setMaximum(len(self.image_files))
        self.batch_progress.setValue(0)
        
        self.batch_worker = BatchScanWorker(self.image_files, self.vgg16_detector)
        self.batch_worker.progress.connect(self.update_batch_progress)
        self.batch_worker.card_scanned.connect(self.add_batch_result)
        self.batch_worker.finished.connect(self.batch_complete)
        self.batch_worker.start()
    
    def stop_batch(self):
        """Stop batch scan"""
        if self.batch_worker:
            self.batch_worker.stop()
            self.batch_worker.wait()
        self.batch_complete(self.scan_results)
    
    def update_batch_progress(self, current, total):
        """Update progress"""
        self.batch_progress.setValue(current)
        self.batch_stats_label.setText(f"Scanning... {current}/{total}")
    
    def add_batch_result(self, result):
        """Add result row"""
        self.scan_results.append(result)
        
        row = self.results_table.rowCount()
        self.results_table.insertRow(row)
        
        # Checkbox
        checkbox = QCheckBox()
        checkbox.setChecked(result['status'] == 'detected')
        checkbox_widget = QWidget()
        checkbox_layout = QHBoxLayout(checkbox_widget)
        checkbox_layout.addWidget(checkbox)
        checkbox_layout.setAlignment(Qt.AlignmentFlag.AlignCenter)
        checkbox_layout.setContentsMargins(0, 0, 0, 0)
        self.results_table.setCellWidget(row, 0, checkbox_widget)
        
        self.results_table.setItem(row, 1, QTableWidgetItem(result['filename']))
        self.results_table.setItem(row, 2, QTableWidgetItem(result.get('name', 'Unknown')))
        self.results_table.setItem(row, 3, QTableWidgetItem(result.get('set', '-')))
        
        conf = result.get('confidence', 0.0)
        conf_item = QTableWidgetItem(f"{conf:.1%}")
        if conf > 0.80:
            conf_item.setForeground(Qt.GlobalColor.green)
        elif conf > 0.60:
            conf_item.setForeground(Qt.GlobalColor.yellow)
        else:
            conf_item.setForeground(Qt.GlobalColor.red)
        self.results_table.setItem(row, 4, conf_item)
        
        price = result.get('prices', {}).get('usd', 'N/A')
        self.results_table.setItem(row, 5, QTableWidgetItem(f"${price}" if price != 'N/A' else 'N/A'))
        
        status = '✓' if result['status'] == 'detected' else '✗'
        self.results_table.setItem(row, 6, QTableWidgetItem(status))
    
    def batch_complete(self, results):
        """Batch complete"""
        self.scan_results = results
        self.start_batch_btn.setEnabled(True)
        self.select_folder_btn.setEnabled(True)
        self.stop_batch_btn.setEnabled(False)
        self.batch_progress.setVisible(False)
        self.export_btn.setEnabled(True)
        
        detected = sum(1 for r in results if r['status'] == 'detected')
        self.batch_stats_label.setText(f"Complete: {detected}/{len(results)} detected")
    
    def export_results(self):
        """Export to CSV"""
        if not self.scan_results:
            return
        
        filename, _ = QFileDialog.getSaveFileName(
            self,
            "Export Results",
            f"scanboss_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
            "CSV (*.csv)"
        )
        
        if not filename:
            return
        
        try:
            import csv
            with open(filename, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow(['Filename', 'Name', 'Set', 'Confidence', 'Price USD', 'Status'])
                for r in self.scan_results:
                    writer.writerow([
                        r.get('filename', ''),
                        r.get('name', ''),
                        r.get('set', ''),
                        f"{r.get('confidence', 0):.2%}",
                        r.get('prices', {}).get('usd', ''),
                        r.get('status', '')
                    ])
            QMessageBox.information(self, "Exported", f"Saved to:\n{filename}")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Export failed:\n{e}")
    
    # ========================================================================
    # API SETTINGS
    # ========================================================================
    
    def open_api_settings(self):
        """Open API settings"""
        dialog = APISettingsDialog(self, self.api_client, self.api_enabled)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            config = dialog.get_config()
            self.api_enabled = config['enabled']
            if config['api_url']:
                self.api_client.base_url = config['api_url']
            if config['api_key']:
                self.api_client.set_api_key(config['api_key'])
            
            QMessageBox.information(self, "Updated", f"API {'ENABLED' if self.api_enabled else 'DISABLED'}")
    
    def closeEvent(self, event):
        """Cleanup"""
        self.stop_camera()
        event.accept()


def main():
    app = QApplication(sys.argv)
    window = ScanBoss()
    window.show()
    
    # Start on live camera tab
    window.start_camera()
    
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
