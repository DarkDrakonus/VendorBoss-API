"""
ScanBoss AI - Custom Model Training

Trains custom AI on REAL scans collected from users.
This model will surpass VGG16 by learning:
- Odd angles
- Damage patterns
- Lighting variations
- Real-world scanning conditions

Usage:
    python train_custom_ai.py --game magic --epochs 30
    python train_custom_ai.py --game magic --pilot  # Quick test
"""

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.preprocessing.image import ImageDataGenerator
from pathlib import Path
import json
import argparse
from datetime import datetime

SCANBOSS_DIR = Path(__file__).parent
REAL_SCANS_DIR = SCANBOSS_DIR / "real_scans"
MODELS_DIR = SCANBOSS_DIR / "models"

IMG_HEIGHT = 224
IMG_WIDTH = 224
BATCH_SIZE = 32


class CustomAITrainer:
    """Train custom model on real scans"""
    
    def __init__(self, game: str):
        self.game = game
        self.scans_dir = REAL_SCANS_DIR / game
        self.model_path = MODELS_DIR / f"scanboss_custom_{game}.h5"
        
        # Check data
        if not self.scans_dir.exists():
            raise ValueError(f"No real scans found at {self.scans_dir}")
        
        # Count available data
        self._analyze_dataset()
    
    def _analyze_dataset(self):
        """Analyze collected scans"""
        print(f"\n{'='*60}")
        print(f"CUSTOM AI TRAINING - {self.game.upper()}")
        print(f"{'='*60}\n")
        
        print("Analyzing real scan dataset...")
        
        card_counts = {}
        total_scans = 0
        
        for card_dir in self.scans_dir.iterdir():
            if card_dir.is_dir() and card_dir.name != "metadata.json":
                scans = list(card_dir.glob("*.jpg"))
                if len(scans) > 0:
                    card_counts[card_dir.name] = len(scans)
                    total_scans += len(scans)
        
        self.num_classes = len(card_counts)
        self.total_scans = total_scans
        
        # Statistics
        cards_with_5plus = sum(1 for c in card_counts.values() if c >= 5)
        cards_with_10plus = sum(1 for c in card_counts.values() if c >= 10)
        avg_scans = total_scans / self.num_classes if self.num_classes > 0 else 0
        
        print(f"\n📊 DATASET STATISTICS:")
        print(f"   Total scans: {total_scans:,}")
        print(f"   Unique cards: {self.num_classes:,}")
        print(f"   Avg scans per card: {avg_scans:.1f}")
        print(f"   Cards with 5+ scans: {cards_with_5plus}")
        print(f"   Cards with 10+ scans: {cards_with_10plus}")
        
        # Check if ready
        if self.num_classes < 50:
            print(f"\n⚠️ WARNING: Only {self.num_classes} unique cards")
            print(f"   Recommended: 100+ cards for pilot, 1000+ for production")
            print(f"   Current status: INSUFFICIENT DATA")
            return False
        
        elif self.num_classes < 100:
            print(f"\n⚡ PILOT MODE: {self.num_classes} cards available")
            print(f"   Good for testing, not production-ready")
            return True
        
        else:
            print(f"\n✅ PRODUCTION READY: {self.num_classes} cards")
            return True
    
    def prepare_data(self, validation_split=0.2):
        """Prepare training data"""
        print("\nPreparing datasets...")
        
        # Heavy augmentation since we have limited real scans
        train_datagen = ImageDataGenerator(
            rescale=1./255,
            validation_split=validation_split,
            rotation_range=20,           # Cards can be rotated
            width_shift_range=0.1,
            height_shift_range=0.1,
            shear_range=0.1,             # Perspective distortion
            zoom_range=0.2,
            brightness_range=[0.7, 1.3], # Lighting variations
            horizontal_flip=False,        # Don't flip cards
            fill_mode='nearest'
        )
        
        self.train_generator = train_datagen.flow_from_directory(
            self.scans_dir,
            target_size=(IMG_HEIGHT, IMG_WIDTH),
            batch_size=BATCH_SIZE,
            class_mode='categorical',
            subset='training',
            shuffle=True
        )
        
        val_datagen = ImageDataGenerator(
            rescale=1./255,
            validation_split=validation_split
        )
        
        self.val_generator = val_datagen.flow_from_directory(
            self.scans_dir,
            target_size=(IMG_HEIGHT, IMG_WIDTH),
            batch_size=BATCH_SIZE,
            class_mode='categorical',
            subset='validation',
            shuffle=False
        )
        
        print(f"✓ Training: {self.train_generator.samples:,} scans")
        print(f"✓ Validation: {self.val_generator.samples:,} scans")
        print(f"✓ Classes: {len(self.train_generator.class_indices):,} cards\n")
        
        # Save class mappings
        self._save_class_mappings()
    
    def _save_class_mappings(self):
        """Save class mappings"""
        index_to_class = {v: k for k, v in self.train_generator.class_indices.items()}
        mapping_file = MODELS_DIR / f"scanboss_custom_{self.game}_classes.json"
        
        with open(mapping_file, 'w') as f:
            json.dump(index_to_class, f, indent=2)
        
        print(f"✓ Class mappings saved\n")
    
    def build_model(self):
        """Build custom model"""
        print("Building custom model...")
        
        # Use MobileNetV2 as base (transfer learning)
        base_model = MobileNetV2(
            input_shape=(IMG_HEIGHT, IMG_WIDTH, 3),
            include_top=False,
            weights='imagenet'
        )
        
        # Fine-tune last layers for our specific task
        base_model.trainable = True
        for layer in base_model.layers[:-20]:
            layer.trainable = False
        
        # Custom top
        inputs = keras.Input(shape=(IMG_HEIGHT, IMG_WIDTH, 3))
        x = keras.applications.mobilenet_v2.preprocess_input(inputs)
        x = base_model(x, training=True)
        x = layers.GlobalAveragePooling2D()(x)
        x = layers.Dropout(0.5)(x)
        x = layers.Dense(1024, activation='relu')(x)
        x = layers.Dropout(0.5)(x)
        x = layers.Dense(512, activation='relu')(x)
        x = layers.Dropout(0.3)(x)
        outputs = layers.Dense(self.num_classes, activation='softmax')(x)
        
        self.model = keras.Model(inputs, outputs)
        
        self.model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=0.0001),
            loss='categorical_crossentropy',
            metrics=['accuracy', keras.metrics.TopKCategoricalAccuracy(k=5)]
        )
        
        print(f"✓ Custom model built: {self.model.count_params():,} parameters\n")
    
    def train(self, epochs=30, pilot_mode=False):
        """Train custom model"""
        
        if pilot_mode:
            print("⚡ PILOT MODE - Quick training (10 epochs)\n")
            epochs = 10
        
        print(f"Training for {epochs} epochs...")
        print("This model learns from YOUR real scans! 🎯\n")
        
        callbacks = [
            keras.callbacks.ModelCheckpoint(
                self.model_path,
                monitor='val_accuracy',
                save_best_only=True,
                verbose=1
            ),
            keras.callbacks.ReduceLROnPlateau(
                monitor='val_loss',
                factor=0.5,
                patience=3,
                verbose=1,
                min_lr=0.00001
            ),
            keras.callbacks.EarlyStopping(
                monitor='val_loss',
                patience=7,
                verbose=1,
                restore_best_weights=True
            ),
            keras.callbacks.CSVLogger(
                MODELS_DIR / f"custom_training_log_{self.game}.csv"
            )
        ]
        
        start = datetime.now()
        
        self.history = self.model.fit(
            self.train_generator,
            validation_data=self.val_generator,
            epochs=epochs,
            callbacks=callbacks,
            verbose=1
        )
        
        duration = datetime.now() - start
        
        print(f"\n{'='*60}")
        print("CUSTOM AI TRAINING COMPLETE!")
        print(f"{'='*60}")
        print(f"Duration: {duration}")
        print(f"Model: {self.model_path}")
        print(f"{'='*60}\n")
    
    def evaluate(self):
        """Evaluate model"""
        print("Evaluating custom model...")
        results = self.model.evaluate(self.val_generator, verbose=1)
        
        print(f"\n{'='*60}")
        print("CUSTOM MODEL PERFORMANCE")
        print(f"{'='*60}")
        print(f"Accuracy: {results[1]*100:.2f}%")
        print(f"Top-5 Accuracy: {results[2]*100:.2f}%")
        print(f"{'='*60}\n")
        
        # Compare to VGG16 baseline
        print("This custom model should outperform VGG16 for:")
        print("  ✓ Odd angles")
        print("  ✓ Poor lighting")
        print("  ✓ Damaged cards")
        print("  ✓ Cards in sleeves")
        print("  ✓ Real-world scanning conditions")
        print()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--game', required=True, choices=['pokemon', 'magic'])
    parser.add_argument('--epochs', type=int, default=30)
    parser.add_argument('--pilot', action='store_true', help='Quick pilot training')
    args = parser.parse_args()
    
    trainer = CustomAITrainer(args.game)
    
    if trainer.num_classes < 50:
        print("\n❌ INSUFFICIENT DATA")
        print(f"   Current: {trainer.num_classes} cards")
        print(f"   Minimum: 50 cards for pilot")
        print(f"\nKeep using scanboss_hybrid.py to collect more scans!")
        return
    
    trainer.prepare_data()
    trainer.build_model()
    trainer.train(epochs=args.epochs, pilot_mode=args.pilot)
    trainer.evaluate()
    
    print("\n" + "="*60)
    print("CUSTOM AI READY! 🎉")
    print("="*60)
    print(f"\nNext time you run scanboss_hybrid.py, it will use:")
    print(f"  {trainer.model_path}")
    print(f"\nYour custom AI trained on {trainer.total_scans:,} real scans!")
    print("="*60 + "\n")


if __name__ == '__main__':
    main()
