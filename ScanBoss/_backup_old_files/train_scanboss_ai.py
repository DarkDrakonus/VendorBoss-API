"""
ScanBoss AI - Model Training Script

Trains a CNN to recognize trading cards using transfer learning.

Usage:
    python train_scanboss_ai.py --game magic --epochs 20
    python train_scanboss_ai.py --game magic --quick-test
"""

import tensorflow as tf
from tensorflow import keras
from tensorflow.keras import layers
from tensorflow.keras.applications import MobileNetV2
from tensorflow.keras.preprocessing.image import ImageDataGenerator
import json
import argparse
from pathlib import Path
from datetime import datetime

# Configuration
SCANBOSS_DIR = Path(__file__).parent
TRAINING_DATA_DIR = SCANBOSS_DIR / "training_data"
MODELS_DIR = SCANBOSS_DIR / "models"
MODELS_DIR.mkdir(exist_ok=True)

IMG_HEIGHT = 560
IMG_WIDTH = 400
BATCH_SIZE = 32


class ScanBossTrainer:
    def __init__(self, game: str):
        self.game = game.lower()
        self.data_dir = TRAINING_DATA_DIR / self.game
        self.model_path = MODELS_DIR / f"scanboss_{self.game}.h5"
        
        if not self.data_dir.exists():
            raise ValueError(f"Training data not found at {self.data_dir}")
        
        self.num_classes = self._count_classes()
        print(f"\n{'='*60}")
        print(f"SCANBOSS AI - {self.game.upper()} TRAINING")
        print(f"{'='*60}")
        print(f"Card types: {self.num_classes:,}")
        print(f"Output: {self.model_path}")
        print(f"{'='*60}\n")
    
    def _count_classes(self):
        total = 0
        for set_dir in self.data_dir.iterdir():
            if set_dir.is_dir():
                total += len(list(set_dir.glob("*.jpg")))
        return total
    
    def prepare_data(self, validation_split=0.2):
        print("Preparing datasets...")
        
        train_datagen = ImageDataGenerator(
            rescale=1./255,
            validation_split=validation_split,
            rotation_range=10,
            width_shift_range=0.05,
            height_shift_range=0.05,
            brightness_range=[0.9, 1.1],
            zoom_range=0.05,
            fill_mode='nearest'
        )
        
        self.train_generator = train_datagen.flow_from_directory(
            self.data_dir,
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
            self.data_dir,
            target_size=(IMG_HEIGHT, IMG_WIDTH),
            batch_size=BATCH_SIZE,
            class_mode='categorical',
            subset='validation',
            shuffle=False
        )
        
        self.class_indices = self.train_generator.class_indices
        
        mapping_file = MODELS_DIR / f"scanboss_{self.game}_classes.json"
        index_to_class = {v: k for k, v in self.class_indices.items()}
        with open(mapping_file, 'w') as f:
            json.dump(index_to_class, f, indent=2)
        
        print(f"✓ Training: {self.train_generator.samples:,}")
        print(f"✓ Validation: {self.val_generator.samples:,}")
        print(f"✓ Classes: {len(self.class_indices):,}\n")
    
    def build_model(self):
        print("Building model...")
        
        base_model = MobileNetV2(
            input_shape=(IMG_HEIGHT, IMG_WIDTH, 3),
            include_top=False,
            weights='imagenet'
        )
        base_model.trainable = False
        
        inputs = keras.Input(shape=(IMG_HEIGHT, IMG_WIDTH, 3))
        x = keras.applications.mobilenet_v2.preprocess_input(inputs)
        x = base_model(x, training=False)
        x = layers.GlobalAveragePooling2D()(x)
        x = layers.Dropout(0.3)(x)
        x = layers.Dense(512, activation='relu')(x)
        x = layers.Dropout(0.3)(x)
        outputs = layers.Dense(self.num_classes, activation='softmax')(x)
        
        self.model = keras.Model(inputs, outputs)
        
        self.model.compile(
            optimizer=keras.optimizers.Adam(learning_rate=0.001),
            loss='categorical_crossentropy',
            metrics=['accuracy', 'top_k_categorical_accuracy']
        )
        
        print(f"✓ Model built: {self.model.count_params():,} parameters\n")
    
    def train(self, epochs=20, quick_test=False):
        if quick_test:
            print("⚡ QUICK TEST - 2 epochs (no validation)\n")
            epochs = 2
        
        print(f"Training for {epochs} epochs...")
        print("This may take hours. Get coffee! ☕\n")
        
        if quick_test:
            # Quick test - no validation, no callbacks
            callbacks = []
            val_data = None
        else:
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
                    verbose=1
                ),
                keras.callbacks.EarlyStopping(
                    monitor='val_loss',
                    patience=5,
                    verbose=1
                )
            ]
            val_data = self.val_generator
        
        start = datetime.now()
        
        self.history = self.model.fit(
            self.train_generator,
            validation_data=val_data,
            epochs=epochs,
            callbacks=callbacks,
            verbose=1
        )
        
        duration = datetime.now() - start
        
        print(f"\n{'='*60}")
        print("TRAINING COMPLETE!")
        print(f"Duration: {duration}")
        print(f"Model saved: {self.model_path}")
        print(f"{'='*60}\n")
    
    def evaluate(self):
        print("Evaluating...")
        results = self.model.evaluate(self.val_generator)
        
        print(f"\n{'='*60}")
        print("RESULTS")
        print(f"{'='*60}")
        print(f"Accuracy: {results[1]*100:.2f}%")
        print(f"Top-5 Accuracy: {results[2]*100:.2f}%")
        print(f"{'='*60}\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--game', required=True, choices=['pokemon', 'magic'])
    parser.add_argument('--epochs', type=int, default=20)
    parser.add_argument('--quick-test', action='store_true')
    args = parser.parse_args()
    
    gpus = tf.config.list_physical_devices('GPU')
    if gpus:
        print(f"\n✓ GPU detected!")
    else:
        print(f"\n⚠ No GPU - training will be slow (4-8 hours)")
    
    trainer = ScanBossTrainer(args.game)
    trainer.prepare_data()
    trainer.build_model()
    trainer.train(epochs=args.epochs, quick_test=args.quick_test)
    trainer.evaluate()
    
    print("🎉 ALL DONE!\n")


if __name__ == '__main__':
    main()
