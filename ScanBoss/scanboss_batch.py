"""
ScanBoss Batch Scanner

Process folders of card images instead of live camera
Perfect for bulk scanning card collections
"""

import sys
from pathlib import Path
from datetime import datetime
from PyQt6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QTableWidget, QTableWidgetItem, QHeaderView,
    QFileDialog, QProgressBar, QMessageBox, QCheckBox, QComboBox,
    QGroupBox
)
from PyQt6.QtCore import Qt, QThread, pyqtSignal
from PyQt6.QtGui import QImage, QPixmap
import cv2
import numpy as np

from vgg16_detector import VGG16Detector
from magic_api_client import MagicAPIClient


class BatchScanWorker(QThread):
    """Worker thread for batch scanning"""
    progress = pyqtSignal(int, int)  # current, total
    card_scanned = pyqtSignal(dict)  # scan result
    finished = pyqtSignal(list)  # all results
    
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
                # Load image
                img = cv2.imread(str(img_path))
                if img is None:
                    print(f"Failed to load: {img_path}")
                    continue
                
                # Detect card
                result = self.detector.detect_card(img, confidence_threshold=0.50)
                
                if result:
                    result['image_path'] = str(img_path)
                    result['filename'] = img_path.name
                    result['status'] = 'detected'
                    results.append(result)
                    self.card_scanned.emit(result)
                else:
                    # No detection
                    failed = {
                        'image_path': str(img_path),
                        'filename': img_path.name,
                        'status': 'failed',
                        'name': 'Detection failed',
                        'confidence': 0.0
                    }
                    results.append(failed)
                    self.card_scanned.emit(failed)
                
                # Update progress
                self.progress.emit(i + 1, total)
                
            except Exception as e:
                print(f"Error processing {img_path}: {e}")
        
        self.finished.emit(results)
    
    def stop(self):
        self.running = False


class BatchScanWindow(QMainWindow):
    """Batch card scanner from folder of images"""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("ScanBoss - Batch Scanner")
        self.setGeometry(100, 100, 1200, 800)
        
        # Initialize detector
        try:
            self.detector = VGG16Detector(game="magic")
            print("✓ VGG16 Detector loaded")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Failed to load detector:\n{e}")
            sys.exit(1)
        
        # Initialize API client
        self.api_client = MagicAPIClient(base_url="http://localhost:8000")
        self.api_enabled = False
        
        # State
        self.image_files = []
        self.scan_results = []
        self.worker = None
        
        # Setup UI
        self.setup_ui()
        
        # Dark theme
        self.setStyleSheet("""
            QMainWindow {
                background-color: #1e1e1e;
            }
            QLabel {
                color: #ffffff;
            }
            QTableWidget {
                background-color: #2b2b2b;
                color: #ffffff;
                gridline-color: #3c3c3c;
            }
            QHeaderView::section {
                background-color: #3c3c3c;
                color: #ffffff;
                padding: 5px;
                border: 1px solid #555;
            }
            QPushButton {
                background-color: #0066cc;
                color: white;
                padding: 10px;
                border-radius: 5px;
                font-size: 14px;
            }
            QPushButton:hover {
                background-color: #0088ee;
            }
            QPushButton:disabled {
                background-color: #555;
                color: #888;
            }
            QProgressBar {
                border: 2px solid #555;
                border-radius: 5px;
                text-align: center;
                background-color: #2b2b2b;
                color: white;
            }
            QProgressBar::chunk {
                background-color: #00aa00;
            }
        """)
    
    def setup_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        
        layout = QVBoxLayout()
        
        # Header
        header = QLabel("📁 Batch Card Scanner")
        header.setStyleSheet("font-size: 24px; font-weight: bold; padding: 10px;")
        layout.addWidget(header)
        
        # Control panel
        control_group = QGroupBox("Controls")
        control_layout = QHBoxLayout()
        
        self.select_folder_btn = QPushButton("📂 Select Folder")
        self.select_folder_btn.clicked.connect(self.select_folder)
        control_layout.addWidget(self.select_folder_btn)
        
        self.start_scan_btn = QPushButton("▶️ Start Scan")
        self.start_scan_btn.clicked.connect(self.start_scan)
        self.start_scan_btn.setEnabled(False)
        control_layout.addWidget(self.start_scan_btn)
        
        self.stop_scan_btn = QPushButton("⏹️ Stop")
        self.stop_scan_btn.clicked.connect(self.stop_scan)
        self.stop_scan_btn.setEnabled(False)
        control_layout.addWidget(self.stop_scan_btn)
        
        self.export_btn = QPushButton("💾 Export Results")
        self.export_btn.clicked.connect(self.export_results)
        self.export_btn.setEnabled(False)
        control_layout.addWidget(self.export_btn)
        
        self.add_to_inventory_btn = QPushButton("✅ Add All to Inventory")
        self.add_to_inventory_btn.clicked.connect(self.add_to_inventory)
        self.add_to_inventory_btn.setEnabled(False)
        control_layout.addWidget(self.add_to_inventory_btn)
        
        control_layout.addStretch()
        control_group.setLayout(control_layout)
        layout.addWidget(control_group)
        
        # Stats
        stats_layout = QHBoxLayout()
        
        self.folder_label = QLabel("No folder selected")
        self.folder_label.setStyleSheet("color: #aaa;")
        stats_layout.addWidget(self.folder_label)
        
        stats_layout.addStretch()
        
        self.stats_label = QLabel("Ready")
        self.stats_label.setStyleSheet("color: #00ff00;")
        stats_layout.addWidget(self.stats_label)
        
        layout.addLayout(stats_layout)
        
        # Progress bar
        self.progress_bar = QProgressBar()
        self.progress_bar.setVisible(False)
        layout.addWidget(self.progress_bar)
        
        # Results table
        self.results_table = QTableWidget()
        self.results_table.setColumnCount(7)
        self.results_table.setHorizontalHeaderLabels([
            "✓", "Filename", "Card Name", "Set", "Confidence", "Price", "Status"
        ])
        
        # Set column widths
        header = self.results_table.horizontalHeader()
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(4, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(5, QHeaderView.ResizeMode.ResizeToContents)
        header.setSectionResizeMode(6, QHeaderView.ResizeMode.ResizeToContents)
        
        layout.addWidget(self.results_table)
        
        central_widget.setLayout(layout)
    
    def select_folder(self):
        """Select folder containing card images"""
        folder = QFileDialog.getExistingDirectory(
            self,
            "Select Folder with Card Images",
            str(Path.home())
        )
        
        if not folder:
            return
        
        folder_path = Path(folder)
        
        # Find image files
        image_extensions = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'}
        self.image_files = [
            f for f in folder_path.iterdir()
            if f.suffix.lower() in image_extensions
        ]
        
        if not self.image_files:
            QMessageBox.warning(
                self,
                "No Images Found",
                f"No images found in:\n{folder}\n\nSupported formats: JPG, PNG, BMP, WEBP"
            )
            return
        
        # Update UI
        self.folder_label.setText(f"📁 {folder_path.name} ({len(self.image_files)} images)")
        self.folder_label.setStyleSheet("color: #fff;")
        self.start_scan_btn.setEnabled(True)
        self.stats_label.setText(f"Ready to scan {len(self.image_files)} images")
        
        print(f"Selected folder: {folder}")
        print(f"Found {len(self.image_files)} images")
    
    def start_scan(self):
        """Start batch scanning"""
        if not self.image_files:
            return
        
        # Clear previous results
        self.scan_results = []
        self.results_table.setRowCount(0)
        
        # Update UI
        self.start_scan_btn.setEnabled(False)
        self.select_folder_btn.setEnabled(False)
        self.stop_scan_btn.setEnabled(True)
        self.progress_bar.setVisible(True)
        self.progress_bar.setMaximum(len(self.image_files))
        self.progress_bar.setValue(0)
        
        # Start worker
        self.worker = BatchScanWorker(self.image_files, self.detector)
        self.worker.progress.connect(self.update_progress)
        self.worker.card_scanned.connect(self.add_result_row)
        self.worker.finished.connect(self.scan_complete)
        self.worker.start()
        
        print(f"Starting batch scan of {len(self.image_files)} images...")
    
    def stop_scan(self):
        """Stop scanning"""
        if self.worker:
            self.worker.stop()
            self.worker.wait()
        
        self.scan_complete(self.scan_results)
    
    def update_progress(self, current, total):
        """Update progress bar"""
        self.progress_bar.setValue(current)
        self.stats_label.setText(f"Scanning... {current}/{total}")
    
    def add_result_row(self, result):
        """Add result to table"""
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
        
        # Filename
        self.results_table.setItem(row, 1, QTableWidgetItem(result['filename']))
        
        # Card name
        name = result.get('name', 'Unknown')
        self.results_table.setItem(row, 2, QTableWidgetItem(name))
        
        # Set
        set_name = result.get('set', '-')
        self.results_table.setItem(row, 3, QTableWidgetItem(set_name))
        
        # Confidence
        confidence = result.get('confidence', 0.0)
        conf_item = QTableWidgetItem(f"{confidence:.1%}")
        if confidence > 0.80:
            conf_item.setForeground(Qt.GlobalColor.green)
        elif confidence > 0.60:
            conf_item.setForeground(Qt.GlobalColor.yellow)
        else:
            conf_item.setForeground(Qt.GlobalColor.red)
        self.results_table.setItem(row, 4, conf_item)
        
        # Price
        price = result.get('prices', {}).get('usd', 'N/A')
        price_text = f"${price}" if price and price != 'N/A' else 'N/A'
        self.results_table.setItem(row, 5, QTableWidgetItem(price_text))
        
        # Status
        status = '✓ Detected' if result['status'] == 'detected' else '✗ Failed'
        status_item = QTableWidgetItem(status)
        if result['status'] == 'detected':
            status_item.setForeground(Qt.GlobalColor.green)
        else:
            status_item.setForeground(Qt.GlobalColor.red)
        self.results_table.setItem(row, 6, status_item)
    
    def scan_complete(self, results):
        """Scanning finished"""
        self.scan_results = results
        
        # Update UI
        self.start_scan_btn.setEnabled(True)
        self.select_folder_btn.setEnabled(True)
        self.stop_scan_btn.setEnabled(False)
        self.progress_bar.setVisible(False)
        self.export_btn.setEnabled(True)
        self.add_to_inventory_btn.setEnabled(True)
        
        # Stats
        detected = sum(1 for r in results if r['status'] == 'detected')
        failed = len(results) - detected
        
        self.stats_label.setText(
            f"✓ Complete: {detected} detected, {failed} failed"
        )
        
        print(f"\nBatch scan complete!")
        print(f"  Detected: {detected}")
        print(f"  Failed: {failed}")
    
    def export_results(self):
        """Export results to CSV"""
        if not self.scan_results:
            return
        
        filename, _ = QFileDialog.getSaveFileName(
            self,
            "Export Results",
            f"scanboss_batch_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv",
            "CSV Files (*.csv)"
        )
        
        if not filename:
            return
        
        try:
            import csv
            
            with open(filename, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow([
                    'Filename', 'Card Name', 'Set', 'Set Name', 'Collector Number',
                    'Type', 'Rarity', 'Confidence', 'Price USD', 'Price Foil', 'Status'
                ])
                
                for result in self.scan_results:
                    writer.writerow([
                        result.get('filename', ''),
                        result.get('name', ''),
                        result.get('set', ''),
                        result.get('set_name', ''),
                        result.get('collector_number', ''),
                        result.get('type_line', ''),
                        result.get('rarity', ''),
                        f"{result.get('confidence', 0):.2%}",
                        result.get('prices', {}).get('usd', ''),
                        result.get('prices', {}).get('usd_foil', ''),
                        result.get('status', '')
                    ])
            
            QMessageBox.information(
                self,
                "Export Complete",
                f"Results exported to:\n{filename}"
            )
            
        except Exception as e:
            QMessageBox.critical(
                self,
                "Export Failed",
                f"Failed to export results:\n{e}"
            )
    
    def add_to_inventory(self):
        """Add checked cards to inventory via API"""
        if not self.api_enabled:
            QMessageBox.information(
                self,
                "API Disabled",
                "API integration is disabled.\n\nResults exported to CSV only."
            )
            return
        
        # Get checked cards
        checked_cards = []
        for row in range(self.results_table.rowCount()):
            checkbox_widget = self.results_table.cellWidget(row, 0)
            checkbox = checkbox_widget.findChild(QCheckBox)
            
            if checkbox and checkbox.isChecked():
                checked_cards.append(self.scan_results[row])
        
        if not checked_cards:
            QMessageBox.warning(
                self,
                "No Cards Selected",
                "Please check the cards you want to add to inventory."
            )
            return
        
        # TODO: Send to API
        QMessageBox.information(
            self,
            "Adding to Inventory",
            f"Adding {len(checked_cards)} cards to inventory..."
        )


def main():
    app = QApplication(sys.argv)
    window = BatchScanWindow()
    window.show()
    sys.exit(app.exec())


if __name__ == '__main__':
    main()
