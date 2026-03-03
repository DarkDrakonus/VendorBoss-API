"""
ScanBoss AI - ROI-Based Training

Trains using defined regions of interest instead of full cards.
Much more effective for cards with similar layouts.

Usage:
    python train_with_roi.py --game magic --epochs 30
    python train_with_roi.py --game magic --quick-test
"""

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from tensorflow.keras.applications import MobileNetV2
import cv2
import numpy as np
import json
from pathlib import Path
import argparse
from datetime import datetime
from tqdm import tqdm

SCANBOSS_DIR = Path(__file__).parent
TRAINING_DATA_DIR = SCANBOSS_DIR / "training_data"
ROI_CONFIG_DIR = SCANBOSS_DIR / "roi_configs"
MODELS_DIR = SCANBOSS_DIR / "models"
MODELS_DIR.mkdir(exist_ok=True)

BATCH_SIZE = 32


class ROIDataGenerator(keras.utils.Sequence):
    """Custom data generator that extracts ROIs from cards"""
    
    def __init__(self, game: str, card_dirs: list, roi_configs: dict, batch_size=32, shuffle=True):
        self.game = game
        self.card_dirs = card_dirs
        self.roi_configs = roi_configs
        self.batch_size = batch_size
        self.shuffle = shuffle
        
        # Create class mappings
        self.class_to_idx = {str(cd.name): idx for idx, cd in enumerate(card_dirs)}
        self.idx_to_class = {v: k for k, v in self.class_to_idx.items()}
        
        self.on_epoch_end()
    
    def __len__(self):
        return int(np.floor(len(self.card_dirs) / self.batch_size))
    
    def __getitem__(self, index):
        # Get batch of card directories
        batch_dirs = self.card_dirs[index * self.batch_size:(index + 1) * self.batch_size]
        
        # Generate data
        X, y = self._generate_batch(batch_dirs)
        
        return X, y
    
    def on_epoch_end(self):
        if self.shuffle:
            np.random.shuffle(self.card_dirs)
    
    def _generate_batch(self, batch_dirs):
        X = []
        y = []
        
        for card_dir in batch_dirs:
            # Get set code from directory name (e.g., "neo-123" -> "neo")
            set_code = card_dir.name.split('-')[0]
            
            # Load card image
            img_path = card_dir / "image.jpg"
            if not img_path.exists():
                continue
            
            img = cv2.imread(str(img_path))
            if img is None:
                continue
            
            # Get ROI config for this set
            roi_config = self.roi_configs.get(set_code)
            if not roi_config:
                # No ROI config - use full image (resized)
                img_resized = cv2.resize(img, (224, 224))
                img_rgb = cv2.cvtColor(img_resized, cv2.COLOR_BGR2RGB)
                X.append(img_rgb / 255.0)
            else:
                # Extract and concatenate ROIs
                combined_img = self._extract_rois(img, roi_config['regions'])
                X.append(combined_img / 255.0)
            
            # Label
            y.append(self.class_to_idx[card_dir.name])
        
        return np.array(X), keras.utils.to_categorical(y, num_classes=len(self.class_to_idx))
    
    def _extract_rois(self, img, regions):
        """Extract ROIs and combine into single image"""
        roi_patches = []
        
        for region in regions:
            # Extract region
            x1, y1 = region['x1'], region['y1']
            x2, y2 = region['x2'], region['y2']
            roi = img[y1:y2, x1:x2]
            
            # Resize to standard size based on label
            if region['label'] == 'art':
                # Art is most important - make it bigger
                roi_resized = cv2.resize(roi, (160, 160))
            elif region['label'] == 'symbol':
                roi_resized = cv2.resize(roi, (48, 48))
            else:  # text, power, etc
                roi_resized = cv2.resize(roi, (64, 64))
            
            roi_patches.append(roi_resized)
        
        # Combine all ROIs into grid
        if len(roi_patches) == 1:
            combined = roi_patches[0]
        else:
            # Create grid layout
            combined = self._create_grid(roi_patches)
        
        # Resize to 224x224 for MobileNetV2
        combined = cv2.resize(combined, (224, 224))
        combined_rgb = cv2.cvtColor(combined, cv2.COLOR_BGR2RGB)
        
        return combined_rgb
    
    def _create_grid(self, patches):
        """Arrange patches in a grid"""
        # Simple: stack vertically then resize
        return np.vstack(patches)


class ROITrainer:
    def __init__(self, game: str):
        self.game = game
        self.data_dir = TRAINING_DATA_DIR / game
        self.model_path = MODELS_DIR / f"scanboss_{game}_roi.h5"
        
        # Load ROI configs
        self.roi_configs = self._load_roi_configs()
        
        # Get all card directories
        self.card_dirs = [d for d in self.data_dir.iterdir() if d.is_dir()]
        self.num_classes = len(self.card_dirs)
        
        print(f"\n{'='*60}")
        print(f"SCANBOSS AI - ROI-BASED TRAINING - {game.upper()}")
        print(f"{'='*60}")
        print(f"Cards: {self.num_classes:,}")
        print(f"ROI configs loaded: {len(self.roi_configs)}")
        for set_code, config in list(self.roi_configs.items())[:5]:
            print(f"  - {set_code}: {len(config['regions'])} regions")
        if len(self.roi_configs) > 5:
            print(f"  ... and {len(self.roi_configs) - 5} more")
        print(f"{'='*60}\n")
    
    def _load_roi_configs(self):
        """Load all ROI configs for this game"""
        configs = {}
        for config_file in ROI_CONFIG_DIR.glob(f"{self.game}_*.json"):
            with open(config_file) as f:
                config = json.load(f)
                set_code = config['set']
                configs[set_code] = config
        return configs
    
    def prepare_data(self, validation_split=0.2):
        print("Preparing datasets...")
        
        # Split into train/val
        np.random.shuffle(self.card_dirs)
        split_idx = int(len(self.card_dirs) * (1 - validation_split))
        
        train_dirs = self.card_dirs[:split_idx]
        val_dirs = self.card_dirs[split_idx:]
        
        self.train_generator = ROIDataGenerator(
            self.game, train_dirs, self.roi_configs,
            batch_size=BATCH_SIZE, shuffle=True
        )
        
        self.val_generator = ROIDataGenerator(
            self.game, val_dirs, self.roi_configs,
            batch_size=BATCH_SIZE, shuffle=False
        )
        
        print(f"✓ Training samples: {len(train_dirs):,}")
        print(f"✓ Validation samples: {len(val_dirs):,}")
        print(f"✓ Classes: {self.num_classes:,}\n")
    
    def build_model(self):
        print("Building model...")
        
        base_model = MobileNetV2(
            input_shape=(224, 224, 3),
            include_top=False,
            weights='imagenet'
        )
        base_model.trainable = False
        
        inputs = keras.Input(shape=(224, 224, 3))
        x = keras.applications.mobilenet_v2.preprocess_input(inputs)
        x = base_model(x, training=False)
        x = layers.GlobalAveragePooling2D()(x)
        x = layers.Dropout(0.5)(x)
        x = layers.Dense(1024, activation='relu')(x)
        x = layers.Dropout(0.5)(x)
        outputs = layers.Dense(self.num_classes, activation='softmax')(x)
        
        self.model = keras.Model(inputs, outputs)
        
        self.model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=0.001),
            loss='categorical_crossentropy',
            metrics=['accuracy', keras.metrics.TopKCategoricalAccuracy(k=5, name='top5_acc')]
        )
        
        print(f"✓ Model built: {self.model.count_params():,} parameters\n")
    
    def train(self, epochs=30, quick_test=False):
        if quick_test:
            print("⚡ QUICK TEST - 5 epochs\n")
            epochs = 5
        
        print(f"Training for {epochs} epochs...")
        print("Using ROI-focused regions! 🎯\n")
        
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
        print("TRAINING COMPLETE!")
        print(f"Duration: {duration}")
        print(f"Model: {self.model_path}")
        print(f"{'='*60}\n")
    
    def evaluate(self):
        print("Evaluating...")
        results = self.model.evaluate(self.val_generator, verbose=1)
        
        print(f"\n{'='*60}")
        print("RESULTS")
        print(f"{'='*60}")
        print(f"Loss: {results[0]:.4f}")
        print(f"Accuracy: {results[1]*100:.2f}%")
        print(f"Top-5 Accuracy: {results[2]*100:.2f}%")
        print(f"{'='*60}\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--game', required=True, choices=['pokemon', 'magic'])
    parser.add_argument('--epochs', type=int, default=30)
    parser.add_argument('--quick-test', action='store_true')
    args = parser.parse_args()
    
    trainer = ROITrainer(args.game)
    
    if len(trainer.roi_configs) == 0:
        print("\n⚠ No ROI configs found!")
        print(f"Run: python define_roi.py --game {args.game} --set <set_code>")
        print(f"Define ROIs for at least a few sets before training.\n")
        return
    
    trainer.prepare_data()
    trainer.build_model()
    trainer.train(epochs=args.epochs, quick_test=args.quick_test)
    trainer.evaluate()
    
    print("🎯 ROI-BASED TRAINING COMPLETE!\n")


if __name__ == '__main__':
    main()
