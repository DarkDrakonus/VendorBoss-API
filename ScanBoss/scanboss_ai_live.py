"""
ScanBoss AI - Live Detection Mode

Real-time card detection with VGG16 + detailed card info display
"""

import sys
import cv2
import numpy as np
from datetime import datetime
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QTextEdit, QGroupBox, QGridLayout, QMessageBox,
    QSlider, QDialog, QLineEdit, QCheckBox, QFormLayout, QDialogButtonBox
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal, QThread
from PyQt6.QtGui import QImage, QPixmap, QFont
import requests
from io import BytesIO
from PIL import Image as PILImage

from vgg16_detector import VGG16Detector
from fixed_region_detector import FixedRegionDetector
from magic_api_client import MagicAPIClient


class DetectionWorker(QThread):
    """Worker thread for real-time card detection"""
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
        """Detect card in background"""
        if not self.running:
            return
        
        try:
            # Step 1: Detect card region in frame
            card_detection = self.card_detector.detect_card_in_frame(self.frame)
            
            if not card_detection.get('detected', False):
                self.result_ready.emit({'status': 'no_detection'})
                return
            
            # Get the cropped card image
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
            
            # Step 2: Identify card using VGG16
            result = self.vgg16_detector.detect_card(card_image, confidence_threshold=self.threshold)
            
            if result and self.running:
                result['status'] = 'success'
                self.result_ready.emit(result)
            else:
                self.result_ready.emit({'status': 'no_detection'})
                
        except Exception as e:
            print(f"[ERROR] {e}")
            self.result_ready.emit({'status': 'error', 'error': str(e)})


class APISettingsDialog(QDialog):
    """API Configuration Dialog"""
    
    def __init__(self, parent, api_client, api_enabled):
        super().__init__(parent)
        self.setWindowTitle("API Settings")
        self.setModal(True)
        self.setMinimumWidth(400)
        
        layout = QFormLayout()
        
        # Enable/Disable API
        self.enabled_checkbox = QCheckBox("Enable VendorBoss API Integration")
        self.enabled_checkbox.setChecked(api_enabled)
        layout.addRow("", self.enabled_checkbox)
        
        # API URL
        self.url_input = QLineEdit()
        self.url_input.setText(api_client.base_url)
        self.url_input.setPlaceholderText("http://localhost:8000")
        layout.addRow("API URL:", self.url_input)
        
        # API Key (optional)
        self.key_input = QLineEdit()
        self.key_input.setPlaceholderText("Optional API Key")
        self.key_input.setEchoMode(QLineEdit.EchoMode.Password)
        layout.addRow("API Key:", self.key_input)
        
        # Test Connection button
        self.test_btn = QPushButton("🔌 Test Connection")
        self.test_btn.clicked.connect(self.test_connection)
        layout.addRow("", self.test_btn)
        
        # Buttons
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        layout.addRow(buttons)
        
        self.setLayout(layout)
        
        # Style
        self.setStyleSheet("""
            QDialog {
                background-color: #2b2b2b;
                color: #ffffff;
            }
            QLabel {
                color: #ffffff;
            }
            QLineEdit {
                background-color: #3c3c3c;
                color: #ffffff;
                border: 1px solid #555;
                padding: 5px;
                border-radius: 3px;
            }
            QCheckBox {
                color: #ffffff;
            }
            QPushButton {
                background-color: #0066cc;
                color: white;
                padding: 8px;
                border-radius: 3px;
            }
            QPushButton:hover {
                background-color: #0088ee;
            }
        """)
    
    def test_connection(self):
        """Test API connection"""
        url = self.url_input.text().strip()
        
        if not url:
            QMessageBox.warning(self, "Error", "Please enter API URL")
            return
        
        try:
            # Try to connect
            response = requests.get(f"{url}/api/health", timeout=5)
            
            if response.status_code == 200:
                QMessageBox.information(
                    self,
                    "Success",
                    f"✓ Connected to VendorBoss API\n\nURL: {url}"
                )
            else:
                QMessageBox.warning(
                    self,
                    "Connection Failed",
                    f"Server responded with status {response.status_code}"
                )
        except Exception as e:
            QMessageBox.warning(
                self,
                "Connection Failed",
                f"Could not connect to API:\n\n{str(e)}\n\nMake sure the server is running."
            )
    
    def get_config(self):
        """Get configuration from dialog"""
        return {
            'enabled': self.enabled_checkbox.isChecked(),
            'api_url': self.url_input.text().strip(),
            'api_key': self.key_input.text().strip()
        }


class ScanBossAI(QMainWindow):
    """ScanBoss AI - Live Detection with Card Details"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ScanBoss AI - Live Detection")
        self.setGeometry(100, 100, 1400, 800)
        
        # Initialize detectors
        try:
            self.card_detector = FixedRegionDetector()  # Use guide region
            self.vgg16_detector = VGG16Detector(game="magic")  # Identify card
            print("✓ Fixed Region Detector loaded")
            print("✓ VGG16 Detector loaded")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to load detectors:\n{e}")
            sys.exit(1)
        
        # Initialize API client
        self.api_client = MagicAPIClient(
            base_url="http://localhost:8000",
            # api_key="your-api-key-here"  # Add when ready
        )
        self.api_enabled = False  # Enable after configuration
        print("✓ API Client initialized (disabled)")
        
        # Camera
        self.camera = cv2.VideoCapture(0)
        self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, 1920)
        self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 1080)
        
        # State
        self.current_detection = None
        self.detection_worker = None
        self.detection_cooldown = False
        self.confidence_threshold = 0.60  # Default threshold
        self.debug_mode = False  # Disable debug - no more spam!
        self.auto_scan_enabled = False  # Don't auto-scan until user enables
        self.guide_roi = None  # Will be set by _draw_card_guide
        
        # Setup UI
        self.setup_ui()
        
        # Start camera feed
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_frame)
        self.timer.start(30)  # 30ms = ~33 FPS
        
        # Instructions
        self.status_label.setText("Fill green brackets with card, then click 'Scan Now'")
        self.status_label.setStyleSheet("color: #00aaff; font-size: 16px; padding: 10px;")
    
    def setup_ui(self):
        """Setup user interface"""
        
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        main_layout = QHBoxLayout()
        
        # LEFT: Camera feed
        left_panel = QVBoxLayout()
        
        # Camera display
        self.camera_label = QLabel()
        self.camera_label.setMinimumSize(960, 540)
        self.camera_label.setStyleSheet("border: 2px solid #333; background: black;")
        self.camera_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        left_panel.addWidget(self.camera_label)
        
        # Status label
        self.status_label = QLabel("Ready to scan...")
        self.status_label.setStyleSheet("color: #00ff00; font-size: 16px; padding: 10px;")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        left_panel.addWidget(self.status_label)
        
        # Scan buttons
        scan_buttons_layout = QHBoxLayout()
        
        self.manual_scan_btn = QPushButton("🔍 Scan Now")
        self.manual_scan_btn.setStyleSheet("""
            QPushButton {
                background: #00aa00;
                color: white;
                font-size: 18px;
                font-weight: bold;
                padding: 15px;
                border-radius: 5px;
            }
            QPushButton:hover {
                background: #00cc00;
            }
        """)
        self.manual_scan_btn.clicked.connect(self.manual_scan)
        
        self.auto_scan_toggle = QPushButton("Enable Auto-Scan")
        self.auto_scan_toggle.setCheckable(True)
        self.auto_scan_toggle.setStyleSheet("""
            QPushButton {
                background: #666;
                color: white;
                font-size: 14px;
                padding: 15px;
                border-radius: 5px;
            }
            QPushButton:checked {
                background: #0066cc;
            }
            QPushButton:hover {
                background: #888;
            }
            QPushButton:checked:hover {
                background: #0088ee;
            }
        """)
        self.auto_scan_toggle.clicked.connect(self.toggle_auto_scan)
        
        scan_buttons_layout.addWidget(self.manual_scan_btn, 3)
        scan_buttons_layout.addWidget(self.auto_scan_toggle, 2)
        left_panel.addLayout(scan_buttons_layout)
        
        # Threshold slider
        threshold_layout = QHBoxLayout()
        threshold_label = QLabel("Detection Threshold:")
        threshold_label.setStyleSheet("color: #ccc; font-size: 12px;")
        
        self.threshold_slider = QSlider(Qt.Orientation.Horizontal)
        self.threshold_slider.setMinimum(40)
        self.threshold_slider.setMaximum(90)
        self.threshold_slider.setValue(60)
        self.threshold_slider.setTickPosition(QSlider.TickPosition.TicksBelow)
        self.threshold_slider.setTickInterval(10)
        self.threshold_slider.valueChanged.connect(self.update_threshold)
        
        self.threshold_value_label = QLabel("60%")
        self.threshold_value_label.setStyleSheet("color: #fff; font-size: 12px; font-weight: bold;")
        
        threshold_layout.addWidget(threshold_label)
        threshold_layout.addWidget(self.threshold_slider)
        threshold_layout.addWidget(self.threshold_value_label)
        
        left_panel.addLayout(threshold_layout)
        
        # API Settings button
        self.api_settings_btn = QPushButton("⚙️ API Settings")
        self.api_settings_btn.setStyleSheet("""
            QPushButton {
                background: #444;
                color: white;
                font-size: 12px;
                padding: 8px;
                border-radius: 5px;
            }
            QPushButton:hover {
                background: #666;
            }
        """)
        self.api_settings_btn.clicked.connect(self.open_api_settings)
        left_panel.addWidget(self.api_settings_btn)
        
        # Control buttons
        button_layout = QHBoxLayout()
        
        self.confirm_btn = QPushButton("✓ Correct Card")
        self.confirm_btn.setEnabled(False)
        self.confirm_btn.setStyleSheet("""
            QPushButton {
                background: #00aa00;
                color: white;
                font-size: 16px;
                padding: 15px;
                border-radius: 5px;
            }
            QPushButton:hover {
                background: #00cc00;
            }
            QPushButton:disabled {
                background: #555;
            }
        """)
        self.confirm_btn.clicked.connect(self.confirm_card)
        
        self.reject_btn = QPushButton("✗ Wrong Card")
        self.reject_btn.setEnabled(False)
        self.reject_btn.setStyleSheet("""
            QPushButton {
                background: #aa0000;
                color: white;
                font-size: 16px;
                padding: 15px;
                border-radius: 5px;
            }
            QPushButton:hover {
                background: #cc0000;
            }
            QPushButton:disabled {
                background: #555;
            }
        """)
        self.reject_btn.clicked.connect(self.reject_card)
        
        button_layout.addWidget(self.confirm_btn)
        button_layout.addWidget(self.reject_btn)
        
        left_panel.addLayout(button_layout)
        
        # RIGHT: Card details
        right_panel = QVBoxLayout()
        
        # Card details group
        details_group = QGroupBox("Card Details")
        details_group.setStyleSheet("""
            QGroupBox {
                font-size: 18px;
                font-weight: bold;
                border: 2px solid #666;
                border-radius: 5px;
                margin-top: 10px;
                padding-top: 10px;
            }
            QGroupBox::title {
                subcontrol-origin: margin;
                left: 10px;
                padding: 0 5px;
            }
        """)
        details_layout = QVBoxLayout()
        
        # Card image
        self.card_image_label = QLabel()
        self.card_image_label.setMinimumSize(300, 420)
        self.card_image_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.card_image_label.setStyleSheet("border: 1px solid #444; background: #222;")
        details_layout.addWidget(self.card_image_label)
        
        # Card info
        self.card_name_label = QLabel("No card detected")
        self.card_name_label.setStyleSheet("font-size: 20px; font-weight: bold; color: #fff; padding: 5px;")
        self.card_name_label.setWordWrap(True)
        details_layout.addWidget(self.card_name_label)
        
        self.card_type_label = QLabel("")
        self.card_type_label.setStyleSheet("font-size: 14px; color: #aaa; padding: 5px;")
        self.card_type_label.setWordWrap(True)
        details_layout.addWidget(self.card_type_label)
        
        self.card_set_label = QLabel("")
        self.card_set_label.setStyleSheet("font-size: 14px; color: #aaa; padding: 5px;")
        details_layout.addWidget(self.card_set_label)
        
        self.card_mana_label = QLabel("")
        self.card_mana_label.setStyleSheet("font-size: 14px; color: #aaa; padding: 5px;")
        details_layout.addWidget(self.card_mana_label)
        
        self.card_rarity_label = QLabel("")
        self.card_rarity_label.setStyleSheet("font-size: 14px; color: #aaa; padding: 5px;")
        details_layout.addWidget(self.card_rarity_label)
        
        self.card_price_label = QLabel("")
        self.card_price_label.setStyleSheet("font-size: 16px; font-weight: bold; color: #00ff00; padding: 5px;")
        details_layout.addWidget(self.card_price_label)
        
        self.confidence_label = QLabel("")
        self.confidence_label.setStyleSheet("font-size: 14px; color: #ffaa00; padding: 5px;")
        details_layout.addWidget(self.confidence_label)
        
        details_layout.addStretch()
        
        details_group.setLayout(details_layout)
        right_panel.addWidget(details_group)
        
        # Add panels to main layout
        main_layout.addLayout(left_panel, 2)
        main_layout.addLayout(right_panel, 1)
        
        central_widget.setLayout(main_layout)
        
        # Dark theme
        self.setStyleSheet("""
            QMainWindow {
                background-color: #1e1e1e;
            }
            QLabel {
                color: #ffffff;
            }
            QGroupBox {
                color: #ffffff;
            }
        """)
    
    def update_frame(self):
        """Update camera frame and trigger detection"""
        
        ret, frame = self.camera.read()
        if not ret:
            return
        
        # Add visual guide overlay
        frame_with_guide = self._draw_card_guide(frame.copy())
        
        # Display frame
        rgb_frame = cv2.cvtColor(frame_with_guide, cv2.COLOR_BGR2RGB)
        h, w, ch = rgb_frame.shape
        bytes_per_line = ch * w
        qt_image = QImage(rgb_frame.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)
        scaled_pixmap = QPixmap.fromImage(qt_image).scaled(
            self.camera_label.size(),
            Qt.AspectRatioMode.KeepAspectRatio
        )
        self.camera_label.setPixmap(scaled_pixmap)
        
        # Only auto-detect if enabled
        if self.auto_scan_enabled:
            if not self.detection_cooldown and (not self.detection_worker or not self.detection_worker.isRunning()):
                self.start_detection(frame)
    
    def start_detection(self, frame):
        """Start detection in background thread"""
        
        self.status_label.setText("🔍 Detecting...")
        self.status_label.setStyleSheet("color: #ffaa00; font-size: 16px; padding: 10px;")
        
        # Crop to guide region if available
        detection_frame = frame.copy()
        if self.guide_roi:
            x, y, w, h = self.guide_roi
            detection_frame = frame[y:y+h, x:x+w]
        
        self.detection_worker = DetectionWorker(
            detection_frame, 
            self.card_detector,
            self.vgg16_detector,
            self.confidence_threshold,
            debug=self.debug_mode
        )
        self.detection_worker.result_ready.connect(self.on_detection_complete)
        self.detection_worker.start()
        
        # Cooldown to avoid too frequent detections
        self.detection_cooldown = True
        QTimer.singleShot(2000, lambda: setattr(self, 'detection_cooldown', False))
    
    def toggle_auto_scan(self, checked):
        """Toggle auto-scan mode"""
        self.auto_scan_enabled = checked
        if checked:
            self.auto_scan_toggle.setText("Disable Auto-Scan")
            self.status_label.setText("Auto-scan ON - fill brackets with card")
            self.status_label.setStyleSheet("color: #00ff00; font-size: 16px; padding: 10px;")
            print("Auto-scan ENABLED")
        else:
            self.auto_scan_toggle.setText("Enable Auto-Scan")
            self.status_label.setText("Fill green brackets, then click 'Scan Now'")
            self.status_label.setStyleSheet("color: #00aaff; font-size: 16px; padding: 10px;")
            print("Auto-scan DISABLED")
    
    def update_threshold(self, value):
        """Update confidence threshold"""
        self.confidence_threshold = value / 100.0
        self.threshold_value_label.setText(f"{value}%")
        print(f"Threshold updated to: {self.confidence_threshold:.2f}")
    
    def manual_scan(self):
        """Manually trigger scan"""
        ret, frame = self.camera.read()
        if ret:
            self.detection_cooldown = False
            self.start_detection(frame)
    
    def on_detection_complete(self, result):
        """Handle detection result"""
        
        status = result.get('status', 'unknown')
        
        if status == 'no_detection':
            self.status_label.setText("No card detected - adjust position/lighting")
            self.status_label.setStyleSheet("color: #ff5500; font-size: 16px; padding: 10px;")
            return
        
        if status == 'error':
            self.status_label.setText(f"Error: {result.get('error', 'Unknown')}")
            self.status_label.setStyleSheet("color: #ff0000; font-size: 16px; padding: 10px;")
            return
        
        if status != 'success':
            return
        
        self.current_detection = result
        
        # Update UI
        self.status_label.setText(f"✓ Card detected! ({result['confidence']:.1%} confidence)")
        self.status_label.setStyleSheet("color: #00ff00; font-size: 16px; padding: 10px;")
        
        # Display card details
        self.display_card_details(result)
        
        # Enable buttons
        self.confirm_btn.setEnabled(True)
        self.reject_btn.setEnabled(True)
    
    def display_card_details(self, card_info):
        """Display detailed card information"""
        
        # Card name
        self.card_name_label.setText(card_info.get('name', 'Unknown'))
        
        # Type line
        type_line = card_info.get('type_line', '')
        if card_info.get('power') and card_info.get('toughness'):
            type_line += f" ({card_info['power']}/{card_info['toughness']})"
        self.card_type_label.setText(type_line)
        
        # Set info
        set_name = card_info.get('set_name', '')
        collector_num = card_info.get('collector_number', '')
        rarity = card_info.get('rarity', '')
        self.card_set_label.setText(f"{set_name} #{collector_num}")
        self.card_rarity_label.setText(f"Rarity: {rarity}")
        
        # Mana cost
        mana_cost = card_info.get('mana_cost', '')
        if mana_cost:
            self.card_mana_label.setText(f"Mana Cost: {mana_cost}")
        else:
            self.card_mana_label.setText("")
        
        # Price
        prices = card_info.get('prices', {})
        usd = prices.get('usd')
        usd_foil = prices.get('usd_foil')
        
        price_text = ""
        if usd:
            price_text += f"${usd}"
        if usd_foil:
            if price_text:
                price_text += f" | Foil: ${usd_foil}"
            else:
                price_text += f"Foil: ${usd_foil}"
        
        if price_text:
            self.card_price_label.setText(f"Price: {price_text}")
        else:
            self.card_price_label.setText("")
        
        # Confidence
        confidence = card_info.get('confidence', 0)
        confidence_color = "#00ff00" if confidence > 0.85 else "#ffaa00" if confidence > 0.70 else "#ff5500"
        self.confidence_label.setText(f"AI Confidence: {confidence:.1%}")
        self.confidence_label.setStyleSheet(f"font-size: 14px; color: {confidence_color}; padding: 5px;")
        
        # Load card image
        image_url = card_info.get('image_url')
        if image_url:
            self.load_card_image(image_url)
    
    def load_card_image(self, url):
        """Load card image from URL"""
        
        try:
            response = requests.get(url, timeout=5)
            response.raise_for_status()
            
            img = PILImage.open(BytesIO(response.content))
            img = img.convert('RGB')
            
            # Convert to QPixmap
            img_array = np.array(img)
            h, w, ch = img_array.shape
            bytes_per_line = ch * w
            qt_image = QImage(img_array.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)
            pixmap = QPixmap.fromImage(qt_image)
            
            # Scale to fit
            scaled_pixmap = pixmap.scaled(
                self.card_image_label.size(),
                Qt.AspectRatioMode.KeepAspectRatio,
                Qt.TransformationMode.SmoothTransformation
            )
            
            self.card_image_label.setPixmap(scaled_pixmap)
            
        except Exception as e:
            print(f"Error loading card image: {e}")
    
    def confirm_card(self):
        """User confirms card is correct"""
        
        if not self.current_detection:
            return
        
        card_name = self.current_detection.get('name', 'Unknown')
        
        # Send to API if enabled
        if self.api_enabled:
            success = self._send_to_api(self.current_detection)
            
            if success:
                QMessageBox.information(
                    self,
                    "Card Added",
                    f"✓ {card_name} added to inventory!"
                )
            else:
                QMessageBox.warning(
                    self,
                    "API Error",
                    f"Card detected but failed to add to inventory.\n\nCard: {card_name}\n\nCheck API connection."
                )
        else:
            # API disabled - just confirm detection
            QMessageBox.information(
                self,
                "Card Detected",
                f"✓ {card_name}\n\n(API disabled - not added to inventory)"
            )
        
        # TODO: Save scan to training dataset for custom AI
        
        self.reset_detection()
    
    def reject_card(self):
        """User rejects detection"""
        
        QMessageBox.information(
            self,
            "Detection Rejected",
            "Try repositioning the card or adjusting lighting."
        )
        
        self.reset_detection()
    
    def _draw_card_guide(self, frame):
        """Draw visual guide showing where to place card"""
        
        h, w = frame.shape[:2]
        
        # Calculate guide rectangle (centered, card-sized)
        # Card aspect ratio: 2.5" x 3.5" = 1:1.4
        guide_height = int(h * 0.7)  # 70% of frame height
        guide_width = int(guide_height / 1.4)  # Maintain card aspect ratio
        
        # Center it
        x1 = (w - guide_width) // 2
        y1 = (h - guide_height) // 2
        x2 = x1 + guide_width
        y2 = y1 + guide_height
        
        # Draw corner brackets (looks professional)
        bracket_len = 50
        thickness = 3
        color = (0, 255, 0)  # Green
        
        # Top-left corner
        cv2.line(frame, (x1, y1), (x1 + bracket_len, y1), color, thickness)
        cv2.line(frame, (x1, y1), (x1, y1 + bracket_len), color, thickness)
        
        # Top-right corner
        cv2.line(frame, (x2, y1), (x2 - bracket_len, y1), color, thickness)
        cv2.line(frame, (x2, y1), (x2, y1 + bracket_len), color, thickness)
        
        # Bottom-left corner
        cv2.line(frame, (x1, y2), (x1 + bracket_len, y2), color, thickness)
        cv2.line(frame, (x1, y2), (x1, y2 - bracket_len), color, thickness)
        
        # Bottom-right corner
        cv2.line(frame, (x2, y2), (x2 - bracket_len, y2), color, thickness)
        cv2.line(frame, (x2, y2), (x2, y2 - bracket_len), color, thickness)
        
        # Add instruction text
        cv2.putText(frame, "Fill brackets with card - corners aligned", 
                   (x1, y1 - 20), cv2.FONT_HERSHEY_SIMPLEX, 
                   0.8, color, 2)
        
        # Add size reference
        cv2.putText(frame, "Card should fill 80-90% of this area",
                   (x1, y2 + 40), cv2.FONT_HERSHEY_SIMPLEX,
                   0.7, (255, 255, 0), 2)
        
        # Store guide dimensions for detector to use
        self.guide_roi = (x1, y1, guide_width, guide_height)
        
        return frame
    
    def _send_to_api(self, card_data: dict) -> bool:
        """Send confirmed card to VendorBoss API"""
        
        try:
            # Prepare card data for API
            api_data = {
                # Detection info
                'card_id': card_data.get('card_id'),
                'confidence': card_data.get('confidence'),
                
                # Card details from Scryfall
                'name': card_data.get('name'),
                'set': card_data.get('set'),
                'set_name': card_data.get('set_name'),
                'collector_number': card_data.get('collector_number'),
                'type_line': card_data.get('type_line'),
                'mana_cost': card_data.get('mana_cost'),
                'rarity': card_data.get('rarity'),
                'image_url': card_data.get('image_url'),
                'prices': card_data.get('prices', {}),
                'oracle_text': card_data.get('oracle_text'),
                'power': card_data.get('power'),
                'toughness': card_data.get('toughness'),
                'scryfall_uri': card_data.get('scryfall_uri'),
                
                # Default user input (can be customized later)
                'condition': 'Near Mint',
                'quantity': 1,
                'is_foil': False,
                
                # Metadata
                'scanned_at': datetime.now().isoformat(),
                'scanner_version': 'ScanBoss AI v1.0'
            }
            
            # Send to API
            print(f"Sending to API: {api_data['name']}")
            response = self.api_client.add_scanned_card(api_data)
            
            if response.get('success'):
                print(f"✓ API Success: {response.get('data')}")
                return True
            else:
                print(f"✗ API Error: {response.get('error')}")
                return False
                
        except Exception as e:
            print(f"[ERROR] Failed to send to API: {e}")
            return False
    
    def open_api_settings(self):
        """Open API configuration dialog"""
        dialog = APISettingsDialog(self, self.api_client, self.api_enabled)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            # Apply settings
            config = dialog.get_config()
            self.api_enabled = config['enabled']
            
            if config['api_url']:
                self.api_client.base_url = config['api_url']
            
            if config['api_key']:
                self.api_client.set_api_key(config['api_key'])
            
            # Update status
            status = "ENABLED" if self.api_enabled else "DISABLED"
            print(f"API {status}: {self.api_client.base_url}")
            
            QMessageBox.information(
                self,
                "Settings Updated",
                f"API {status}\n\nURL: {self.api_client.base_url}"
            )
    
    def reset_detection(self):
        """Reset detection state"""
        
        self.current_detection = None
        self.confirm_btn.setEnabled(False)
        self.reject_btn.setEnabled(False)
        self.status_label.setText("Ready to scan...")
        self.status_label.setStyleSheet("color: #00ff00; font-size: 16px; padding: 10px;")
        
        # Clear card details
        self.card_name_label.setText("No card detected")
        self.card_type_label.setText("")
        self.card_set_label.setText("")
        self.card_mana_label.setText("")
        self.card_rarity_label.setText("")
        self.card_price_label.setText("")
        self.confidence_label.setText("")
        self.card_image_label.clear()
    
    def closeEvent(self, event):
        """Cleanup on close"""
        self.timer.stop()
        if self.detection_worker and self.detection_worker.isRunning():
            self.detection_worker.running = False
            self.detection_worker.wait()
        self.camera.release()
        event.accept()


def main():
    app = QApplication(sys.argv)
    window = ScanBossAI()
    window.show()
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
