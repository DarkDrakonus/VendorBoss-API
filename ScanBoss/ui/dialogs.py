"""
ScanBoss UI Dialogs - Updated for FFTCG (VendorBoss 2.0)
WITH IMAGE PREVIEW
"""
from PyQt6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit,
    QComboBox, QPushButton, QFormLayout, QSpinBox, QTextEdit,
    QScrollArea, QWidget
)
from PyQt6.QtCore import Qt
from PyQt6.QtGui import QPixmap, QImage
from typing import Dict, List, Optional
import cv2
import numpy as np

class FFTCGCardDataDialog(QDialog):
    """
    Dialog for entering FFTCG card data
    NOW WITH IMAGE PREVIEW!
    """
    
    def __init__(self, parent=None, sets: List[Dict] = None, elements: List[str] = None, 
                 rarities: List[str] = None, initial_data: Optional[Dict] = None,
                 card_image: Optional[np.ndarray] = None):
        super().__init__(parent)
        
        self.setWindowTitle("New FFTCG Card")
        self.setMinimumWidth(600)
        self.setMinimumHeight(700)
        
        # Store dropdown data
        self.sets = sets or []
        self.elements = elements or ["Fire", "Ice", "Wind", "Earth", "Lightning", "Water", "Light", "Dark"]
        self.rarities = rarities or ["Common", "Rare", "Hero", "Legend", "Starter", "Promo"]
        self.card_types = ["Forward", "Backup", "Summon", "Monster"]
        
        self.initial_data = initial_data or {}
        self.card_image = card_image
        self.result_data = None
        
        self._setup_ui()
        self._populate_initial_data()
    
    def _setup_ui(self):
        """Setup the dialog UI with image preview"""
        layout = QVBoxLayout(self)
        
        # Scrollable area for long dialogs
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll_widget = QWidget()
        scroll_layout = QVBoxLayout(scroll_widget)
        
        # Title
        title = QLabel("Enter FFTCG Card Information")
        title.setStyleSheet("font-size: 16px; font-weight: bold; margin: 10px;")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        scroll_layout.addWidget(title)
        
        # IMAGE PREVIEW (NEW!)
        if self.card_image is not None:
            preview_label = QLabel("Scanned Card:")
            preview_label.setStyleSheet("font-weight: bold; margin-top: 10px;")
            scroll_layout.addWidget(preview_label)
            
            # Convert numpy array to QPixmap
            self.image_label = QLabel()
            self.image_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
            self._display_image(self.card_image)
            scroll_layout.addWidget(self.image_label)
        
        # Form layout
        form = QFormLayout()
        form.setSpacing(10)
        
        # Card Name (Required)
        self.name_input = QLineEdit()
        self.name_input.setPlaceholderText("e.g., Cloud")
        form.addRow("Card Name *:", self.name_input)
        
        # Set (Required)
        self.set_combo = QComboBox()
        if self.sets:
            for s in self.sets:
                self.set_combo.addItem(f"{s['set_name']} ({s['set_year']})", s['set_id'])
        else:
            self.set_combo.addItem("No sets available", None)
        form.addRow("Set *:", self.set_combo)
        
        # Card Number (Required)
        self.card_number_input = QLineEdit()
        self.card_number_input.setPlaceholderText("e.g., 1-001H")
        form.addRow("Card Number *:", self.card_number_input)
        
        # Element (Required)
        self.element_combo = QComboBox()
        self.element_combo.addItems(self.elements)
        form.addRow("Element *:", self.element_combo)
        
        # Card Type (Required)
        self.type_combo = QComboBox()
        self.type_combo.addItems(self.card_types)
        form.addRow("Card Type *:", self.type_combo)
        
        # Rarity (Required)
        self.rarity_combo = QComboBox()
        self.rarity_combo.addItems(self.rarities)
        form.addRow("Rarity *:", self.rarity_combo)
        
        # Power (Optional - only for Forwards/Monsters)
        self.power_input = QSpinBox()
        self.power_input.setRange(0, 15000)
        self.power_input.setSingleStep(1000)
        self.power_input.setSpecialValueText("N/A")
        form.addRow("Power:", self.power_input)
        
        # Cost (Optional)
        self.cost_input = QSpinBox()
        self.cost_input.setRange(0, 20)
        self.cost_input.setSpecialValueText("N/A")
        form.addRow("Cost:", self.cost_input)
        
        # Job (Optional)
        self.job_input = QLineEdit()
        self.job_input.setPlaceholderText("e.g., SOLDIER")
        form.addRow("Job:", self.job_input)
        
        # Category (Optional)
        self.category_input = QLineEdit()
        self.category_input.setPlaceholderText("e.g., VII")
        form.addRow("Category:", self.category_input)
        
        # Abilities (Optional)
        self.abilities_input = QTextEdit()
        self.abilities_input.setMaximumHeight(80)
        self.abilities_input.setPlaceholderText("Enter card abilities/text...")
        form.addRow("Abilities:", self.abilities_input)
        
        scroll_layout.addLayout(form)
        
        # Info text
        info = QLabel("* Required fields")
        info.setStyleSheet("color: gray; font-size: 11px; margin-top: 10px;")
        scroll_layout.addWidget(info)
        
        scroll.setWidget(scroll_widget)
        layout.addWidget(scroll)
        
        # Buttons (outside scroll area)
        button_layout = QHBoxLayout()
        button_layout.addStretch()
        
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        button_layout.addWidget(cancel_btn)
        
        submit_btn = QPushButton("Submit Card")
        submit_btn.setStyleSheet("""
            QPushButton {
                background-color: #667EEA;
                color: white;
                padding: 8px 20px;
                font-weight: bold;
                border-radius: 4px;
            }
            QPushButton:hover {
                background-color: #5568D3;
            }
        """)
        submit_btn.clicked.connect(self.accept)
        button_layout.addWidget(submit_btn)
        
        layout.addLayout(button_layout)
        
        # Enable type-specific fields
        self.type_combo.currentTextChanged.connect(self._on_type_changed)
        self._on_type_changed(self.type_combo.currentText())
    
    def _display_image(self, image: np.ndarray):
        """Convert numpy image to QPixmap and display"""
        # Convert BGR to RGB
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
        h, w, ch = rgb_image.shape
        bytes_per_line = ch * w
        
        qt_image = QImage(rgb_image.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)
        pixmap = QPixmap.fromImage(qt_image)
        
        # Scale to reasonable size (max 400px wide)
        scaled_pixmap = pixmap.scaled(400, 300, Qt.AspectRatioMode.KeepAspectRatio, 
                                      Qt.TransformationMode.SmoothTransformation)
        
        self.image_label.setPixmap(scaled_pixmap)
        self.image_label.setStyleSheet("""
            border: 2px solid #667EEA;
            border-radius: 8px;
            padding: 10px;
            background-color: #f8f9fa;
        """)
    
    def _on_type_changed(self, card_type: str):
        """Enable/disable power field based on card type"""
        # Power only relevant for Forward and Monster
        has_power = card_type in ["Forward", "Monster"]
        self.power_input.setEnabled(has_power)
    
    def _populate_initial_data(self):
        """Populate fields with initial data if provided"""
        if not self.initial_data:
            return
        
        if 'card_name' in self.initial_data:
            self.name_input.setText(self.initial_data['card_name'])
        
        if 'card_number' in self.initial_data:
            self.card_number_input.setText(self.initial_data['card_number'])
        
        if 'element' in self.initial_data:
            index = self.element_combo.findText(self.initial_data['element'])
            if index >= 0:
                self.element_combo.setCurrentIndex(index)
        
        if 'card_type' in self.initial_data:
            index = self.type_combo.findText(self.initial_data['card_type'])
            if index >= 0:
                self.type_combo.setCurrentIndex(index)
        
        if 'rarity' in self.initial_data:
            index = self.rarity_combo.findText(self.initial_data['rarity'])
            if index >= 0:
                self.rarity_combo.setCurrentIndex(index)
        
        if 'power' in self.initial_data and self.initial_data['power']:
            self.power_input.setValue(self.initial_data['power'])
        
        if 'cost' in self.initial_data and self.initial_data['cost']:
            self.cost_input.setValue(self.initial_data['cost'])
        
        if 'job' in self.initial_data:
            self.job_input.setText(self.initial_data['job'])
        
        if 'category' in self.initial_data:
            self.category_input.setText(self.initial_data['category'])
        
        if 'abilities' in self.initial_data:
            self.abilities_input.setPlainText(self.initial_data['abilities'])
    
    def get_data(self) -> Optional[Dict]:
        """
        Get the entered card data
        Returns None if dialog was cancelled
        """
        if self.result() == QDialog.DialogCode.Rejected:
            return None
        
        # Validate required fields
        if not self.name_input.text().strip():
            return None
        
        if not self.card_number_input.text().strip():
            return None
        
        set_id = self.set_combo.currentData()
        if not set_id:
            return None
        
        # Build card data
        card_data = {
            'card_name': self.name_input.text().strip(),
            'set_id': set_id,
            'card_number': self.card_number_input.text().strip(),
            'element': self.element_combo.currentText(),
            'card_type': self.type_combo.currentText(),
            'rarity': self.rarity_combo.currentText(),
        }
        
        # Add optional fields
        if self.power_input.value() > 0:
            card_data['power'] = self.power_input.value()
        
        if self.cost_input.value() > 0:
            card_data['cost'] = self.cost_input.value()
        
        if self.job_input.text().strip():
            card_data['job'] = self.job_input.text().strip()
        
        if self.category_input.text().strip():
            card_data['category'] = self.category_input.text().strip()
        
        if self.abilities_input.toPlainText().strip():
            card_data['abilities'] = self.abilities_input.toPlainText().strip()
        
        return card_data


class ConfirmMatchDialog(QDialog):
    """
    Dialog to confirm if an identified card match is correct
    NOW WITH IMAGE PREVIEW!
    """
    
    def __init__(self, parent=None, product_info: Dict = None, pricing: Dict = None,
                 card_image: Optional[np.ndarray] = None):
        super().__init__(parent)
        
        self.setWindowTitle("Card Match Found")
        self.setMinimumWidth(500)
        
        self.product_info = product_info or {}
        self.pricing = pricing or {}
        self.card_image = card_image
        self.confirmed = False
        
        self._setup_ui()
    
    def _setup_ui(self):
        """Setup the dialog UI with image preview"""
        layout = QVBoxLayout(self)
        
        # Title
        title = QLabel("✓ Card Identified!")
        title.setStyleSheet("font-size: 18px; font-weight: bold; color: #667EEA; margin: 10px;")
        title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title)
        
        # IMAGE PREVIEW (NEW!)
        if self.card_image is not None:
            self.image_label = QLabel()
            self.image_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
            
            # Convert numpy array to QPixmap
            rgb_image = cv2.cvtColor(self.card_image, cv2.COLOR_BGR2RGB)
            h, w, ch = rgb_image.shape
            bytes_per_line = ch * w
            
            qt_image = QImage(rgb_image.data, w, h, bytes_per_line, QImage.Format.Format_RGB888)
            pixmap = QPixmap.fromImage(qt_image)
            
            # Scale to reasonable size
            scaled_pixmap = pixmap.scaled(350, 250, Qt.AspectRatioMode.KeepAspectRatio,
                                         Qt.TransformationMode.SmoothTransformation)
            
            self.image_label.setPixmap(scaled_pixmap)
            self.image_label.setStyleSheet("""
                border: 2px solid #22C55E;
                border-radius: 8px;
                padding: 10px;
                background-color: #f8f9fa;
                margin: 10px;
            """)
            layout.addWidget(self.image_label)
        
        # Card info
        info_layout = QFormLayout()
        info_layout.setSpacing(8)
        
        # Card Name
        name = self.product_info.get('card_name', 'Unknown')
        name_label = QLabel(name)
        name_label.setStyleSheet("font-weight: bold; font-size: 14px;")
        info_layout.addRow("Card:", name_label)
        
        # Set
        card_set = self.product_info.get('card_set', 'Unknown')
        year = self.product_info.get('card_year', '')
        set_text = f"{card_set} ({year})" if year else card_set
        info_layout.addRow("Set:", QLabel(set_text))
        
        # Card Number
        number = self.product_info.get('card_number', 'N/A')
        info_layout.addRow("Number:", QLabel(number))
        
        # Element
        element = self.product_info.get('element', 'N/A')
        info_layout.addRow("Element:", QLabel(element))
        
        # Rarity
        rarity = self.product_info.get('rarity', 'N/A')
        info_layout.addRow("Rarity:", QLabel(rarity))
        
        layout.addLayout(info_layout)
        
        # Pricing (if available)
        if self.pricing and self.pricing.get('raw_nm_market'):
            raw_pricing = self.pricing['raw_nm_market']
            if raw_pricing.get('average'):
                price_label = QLabel(f"${raw_pricing['average']:.2f}")
                price_label.setStyleSheet("font-size: 16px; font-weight: bold; color: #22C55E;")
                layout.addWidget(QLabel("Market Price:"))
                layout.addWidget(price_label)
        
        # Question
        question = QLabel("\nIs this correct?")
        question.setStyleSheet("font-size: 14px; margin-top: 10px;")
        question.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(question)
        
        # Buttons
        button_layout = QHBoxLayout()
        button_layout.addStretch()
        
        no_btn = QPushButton("No, Wrong Card")
        no_btn.clicked.connect(self.reject)
        button_layout.addWidget(no_btn)
        
        yes_btn = QPushButton("Yes, Correct!")
        yes_btn.setStyleSheet("""
            QPushButton {
                background-color: #22C55E;
                color: white;
                padding: 8px 20px;
                font-weight: bold;
                border-radius: 4px;
            }
            QPushButton:hover {
                background-color: #16A34A;
            }
        """)
        yes_btn.clicked.connect(self._confirm)
        button_layout.addWidget(yes_btn)
        
        layout.addLayout(button_layout)
    
    def _confirm(self):
        """User confirmed match"""
        self.confirmed = True
        self.accept()
    
    def is_confirmed(self) -> bool:
        """Returns True if user confirmed the match"""
        return self.confirmed
