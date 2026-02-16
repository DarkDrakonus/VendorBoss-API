#!/usr/bin/env python3
"""
ScanBoss - PyQt6 Version
Professional AI Card Scanner with modern UI
"""

import sys
import cv2
import numpy as np
from datetime import datetime
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QTextEdit, QLineEdit, QDialog, QFormLayout,
    QDialogButtonBox, QComboBox, QMessageBox
)
from PyQt6.QtCore import Qt, QTimer, pyqtSignal, QThread
from PyQt6.QtGui import QImage, QPixmap, QPalette, QColor

from card_detector import CardDetector
from api_client import APIClient


class ScanWorker(QThread):
    """Worker thread for card scanning to prevent UI freezing"""
    finished = pyqtSignal(dict)
    
    def __init__(self, frame, detector, api):
        super().__init__()
        self.frame = frame
        self.detector = detector
        self.api = api
    
    def run(self):
        """Process frame in background thread"""
        try:
            result = self.detector.detect_card_in_frame(self.frame)
            
            if result.get('detected', False):
                fingerprint = result['fingerprint']
                api_result = self.api.scan_fingerprint(fingerprint)
                
                if api_result['success']:
                    data = api_result['data']
                    if data.get('found'):
                        self.finished.emit({
                            'status': 'match',
                            'product': data.get('product', {}),
                            'fingerprint': fingerprint
                        })
                    else:
                        self.finished.emit({
                            'status': 'new_card',
                            'fingerprint': fingerprint
                        })
                else:
                    self.finished.emit({
                        'status': 'error',
                        'error': api_result['error']
                    })
            else:
                self.finished.emit({'status': 'no_card'})
        except Exception as e:
            self.finished.emit({'status': 'error', 'error': str(e)})


class LoginDialog(QDialog):
    """Login dialog for VendorBoss API"""
    
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Login to VendorBoss")
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout()
        
        self.email_input = QLineEdit()
        self.email_input.setPlaceholderText("your@email.com")
        
        self.password_input = QLineEdit()
        self.password_input.setEchoMode(QLineEdit.EchoMode.Password)
        self.password_input.setPlaceholderText("Password")
        
        layout.addRow("Email:", self.email_input)
        layout.addRow("Password:", self.password_input)
        
        buttons = QDialogButtonBox(
            QDialogButtonBox.StandardButton.Ok | QDialogButtonBox.StandardButton.Cancel
        )
        buttons.accepted.connect(self.accept)
        buttons.rejected.connect(self.reject)
        
        layout.addWidget(buttons)
        self.setLayout(layout)
    
    def get_credentials(self):
        return self.email_input.text(), self.password_input.text()


class CardDataDialog(QDialog):
    """Dialog for entering new card data"""
    
    def __init__(self, parent=None, title="New Card Detected"):
        super().__init__(parent)
        self.setWindowTitle(title)
        self.setup_ui()
    
    def setup_ui(self):
        layout = QFormLayout()
        
        self.player_input = QLineEdit()
        self.player_input.setPlaceholderText("e.g., Michael Jordan")
        
        self.set_input = QLineEdit()
        self.set_input.setPlaceholderText("e.g., Upper Deck Series 1")
        
        self.year_input = QLineEdit()
        self.year_input.setPlaceholderText("e.g., 1997")
        
        layout.addRow("Player Name:", self.player_input)
        layout.addRow("Card Set:", self.set_input)
        layout.addRow("Year:", self.year_input)
        
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
        }


class ScanBossApp(QMainWindow):
    """Main application window"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ScanBoss - AI Card Scanner")
        self.setMinimumSize(900, 700)
        
        # Initialize components
        self.detector = CardDetector()
        self.api = APIClient()
        self.camera = None
        self.camera_index = 0
        self.scanning = False
        self.auto_scan = False
        self.current_frame = None
        self.scan_worker = None
        
        # Setup UI
        self.setup_ui()
        
        # Setup camera timer
        self.timer = QTimer()
        self.timer.timeout.connect(self.update_frame)
        
        # Start camera
        self.start_camera()
    
    def setup_ui(self):
        """Create the user interface"""
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        main_layout = QVBoxLayout()
        central_widget.setLayout(main_layout)
        
        # Title
        title = QLabel("ScanBoss - AI Card Scanner")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title.setStyleSheet("font-size: 24px; font-weight: bold; padding: 10px;")
        main_layout.addWidget(title)
        
        # Camera selection
        camera_layout = QHBoxLayout()
        camera_label = QLabel("Camera:")
        self.camera_combo = QComboBox()
        self.detect_cameras()
        self.camera_combo.currentIndexChanged.connect(self.change_camera)
        camera_layout.addWidget(camera_label)
        camera_layout.addWidget(self.camera_combo)
        camera_layout.addStretch()
        main_layout.addLayout(camera_layout)
        
        # Camera preview
        self.camera_label = QLabel()
        self.camera_label.setMinimumSize(640, 480)
        self.camera_label.setMaximumSize(640, 480)
        self.camera_label.setStyleSheet("border: 2px solid #333; background-color: black;")
        self.camera_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.camera_label.setText("Camera Preview")
        
        preview_container = QHBoxLayout()
        preview_container.addStretch()
        preview_container.addWidget(self.camera_label)
        preview_container.addStretch()
        main_layout.addLayout(preview_container)
        
        # Control buttons
        button_layout = QHBoxLayout()
        
        self.scan_button = QPushButton("Scan Card")
        self.scan_button.setMinimumHeight(40)
        self.scan_button.clicked.connect(self.scan_card)
        
        self.auto_button = QPushButton("Auto Scan: OFF")
        self.auto_button.setMinimumHeight(40)
        self.auto_button.clicked.connect(self.toggle_auto_scan)
        
        self.login_button = QPushButton("Login")
        self.login_button.setMinimumHeight(40)
        self.login_button.clicked.connect(self.login)
        
        button_layout.addWidget(self.scan_button)
        button_layout.addWidget(self.auto_button)
        button_layout.addWidget(self.login_button)
        main_layout.addLayout(button_layout)
        
        # Status label
        self.status_label = QLabel("Ready to scan")
        self.status_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.status_label.setStyleSheet("padding: 5px; font-weight: bold;")
        main_layout.addWidget(self.status_label)
        
        # Results text area
        results_label = QLabel("Scan Results:")
        main_layout.addWidget(results_label)
        
        self.results_text = QTextEdit()
        self.results_text.setReadOnly(True)
        self.results_text.setMaximumHeight(150)
        main_layout.addWidget(self.results_text)
        
        # Apply modern styling
        self.apply_styling()
    
    def apply_styling(self):
        """Apply modern color scheme"""
        self.setStyleSheet("""
            QMainWindow {
                background-color: #f5f5f5;
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
                background-color: #cccccc;
            }
            QTextEdit {
                border: 1px solid #ddd;
                border-radius: 4px;
                padding: 5px;
                font-family: monospace;
            }
            QComboBox {
                padding: 5px;
                border: 1px solid #ddd;
                border-radius: 4px;
            }
        """)
    
    def detect_cameras(self):
        """Detect available cameras"""
        self.camera_combo.clear()
        for i in range(5):
            cap = cv2.VideoCapture(i)
            if cap.isOpened():
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
        """Initialize and start camera"""
        if self.camera is not None:
            self.camera.release()
        
        self.camera = cv2.VideoCapture(self.camera_index)
        self.camera.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
        self.camera.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
        
        if self.camera.isOpened():
            self.timer.start(33)  # ~30 FPS
            self.log_result("Camera started successfully")
        else:
            self.log_result("ERROR: Failed to start camera")
    
    def update_frame(self):
        """Update camera preview"""
        if self.camera and self.camera.isOpened():
            ret, frame = self.camera.read()
            if ret:
                self.current_frame = frame.copy()
                
                # Draw detection zone (ENLARGED for easier card placement)
                display_frame = frame.copy()
                h, w = display_frame.shape[:2]
                center_x, center_y = w // 2, h // 2
                zone_w, zone_h = 350, 490  # Increased from 200x280
                
                cv2.rectangle(display_frame,
                            (center_x - zone_w//2, center_y - zone_h//2),
                            (center_x + zone_w//2, center_y + zone_h//2),
                            (0, 255, 0), 2)
                
                # Convert to QPixmap for display
                rgb_frame = cv2.cvtColor(display_frame, cv2.COLOR_BGR2RGB)
                h, w, ch = rgb_frame.shape
                bytes_per_line = ch * w
                qt_image = QImage(rgb_frame.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)
                pixmap = QPixmap.fromImage(qt_image)
                
                self.camera_label.setPixmap(pixmap)
                
                # Auto scan if enabled
                if self.auto_scan and not self.scanning:
                    self.scan_card()
    
    def scan_card(self):
        """Trigger card scan"""
        if self.scanning or self.current_frame is None:
            return
        
        self.scanning = True
        self.scan_button.setEnabled(False)
        self.status_label.setText("Scanning...")
        self.log_result("Processing frame...")
        
        # Create and start worker thread
        self.scan_worker = ScanWorker(self.current_frame, self.detector, self.api)
        self.scan_worker.finished.connect(self.handle_scan_result)
        self.scan_worker.start()
    
    def handle_scan_result(self, result):
        """Handle scan result from worker thread"""
        status = result.get('status')
        
        if status == 'match':
            product = result['product']
            player = product.get('player_name', 'Unknown')
            card_set = product.get('card_set', 'Unknown')
            year = product.get('card_year', 'Unknown')
            
            message = f"MATCH FOUND!\nPlayer: {player}\nSet: {card_set}\nYear: {year}"
            self.log_result(message)
            self.status_label.setText("Card matched!")
            
            # Ask for confirmation
            reply = QMessageBox.question(
                self, 'Card Match',
                f"{message}\n\nIs this correct?",
                QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No
            )
            
            if reply == QMessageBox.StandardButton.No:
                self.prompt_new_card(result['fingerprint'], "Incorrect match")
        
        elif status == 'new_card':
            self.log_result("New card detected!")
            self.prompt_new_card(result['fingerprint'])
        
        elif status == 'no_card':
            self.log_result("No card detected")
            self.status_label.setText("No card detected")
        
        elif status == 'error':
            self.log_result(f"Error: {result.get('error', 'Unknown error')}")
            self.status_label.setText("Scan error")
        
        self.scanning = False
        self.scan_button.setEnabled(True)
        if not self.auto_scan:
            self.status_label.setText("Ready to scan")
    
    def prompt_new_card(self, fingerprint, reason="New card detected"):
        """Show dialog to enter new card data"""
        dialog = CardDataDialog(self, reason)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            card_data = dialog.get_card_data()
            card_data['fingerprint'] = fingerprint
            
            # Send to API
            result = self.api.create_product(card_data)
            if result['success']:
                player = card_data['player_name']
                card_set = card_data['card_set']
                self.log_result(f"✓ Card added: {player} - {card_set}")
                self.status_label.setText("Card added to database!")
            else:
                self.log_result(f"✗ Failed to add card: {result['error']}")
    
    def toggle_auto_scan(self):
        """Toggle auto scanning mode"""
        self.auto_scan = not self.auto_scan
        self.auto_button.setText(f"Auto Scan: {'ON' if self.auto_scan else 'OFF'}")
        self.status_label.setText("Auto scan enabled" if self.auto_scan else "Auto scan disabled")
    
    def login(self):
        """Show login dialog"""
        dialog = LoginDialog(self)
        if dialog.exec() == QDialog.DialogCode.Accepted:
            email, password = dialog.get_credentials()
            result = self.api.login(email, password)
            
            if result['success']:
                self.log_result("✓ Login successful!")
                self.login_button.setText("Logged In")
                self.login_button.setEnabled(False)
                self.login_button.setStyleSheet("background-color: #2196F3;")
            else:
                QMessageBox.critical(self, "Login Failed", result['error'])
    
    def log_result(self, message):
        """Log message to results area"""
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.results_text.append(f"[{timestamp}] {message}")
    
    def closeEvent(self, event):
        """Cleanup on close"""
        if self.camera:
            self.camera.release()
        event.accept()


def main():
    app = QApplication(sys.argv)
    
    # Set application style
    app.setStyle('Fusion')
    
    # Create and show window
    window = ScanBossApp()
    window.show()
    
    sys.exit(app.exec())


if __name__ == "__main__":
    main()
