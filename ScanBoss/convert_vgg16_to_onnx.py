"""
Convert VGG16 Model to ONNX Format

This converts the Keras VGG16 model to ONNX format for use in C#.
Run this ONCE to create the .onnx file for the C# application.
"""

import tensorflow as tf
from tensorflow.keras.applications.vgg16 import VGG16
import tf2onnx
import onnx

print("Converting VGG16 to ONNX format...")
print("This will take a few minutes...\n")

# Load VGG16 model (without top classification layers)
print("Loading VGG16 model...")
model = VGG16(weights='imagenet', include_top=False, input_shape=(224, 224, 3))
print("✓ Model loaded\n")

# Convert to ONNX
print("Converting to ONNX...")
spec = (tf.TensorSpec((None, 224, 224, 3), tf.float32, name="input"),)
output_path = "models/vgg16.onnx"

model_proto, _ = tf2onnx.convert.from_keras(
    model,
    input_signature=spec,
    opset=13,
    output_path=output_path
)

print(f"✓ ONNX model saved to: {output_path}\n")

# Verify the model
print("Verifying ONNX model...")
onnx_model = onnx.load(output_path)
onnx.checker.check_model(onnx_model)
print("✓ ONNX model is valid!\n")

print("=" * 60)
print("CONVERSION COMPLETE!")
print("=" * 60)
print(f"\nONNX Model: {output_path}")
print(f"Input:  (batch, 224, 224, 3) - RGB images")
print(f"Output: (batch, 7, 7, 512) - Feature maps")
print(f"\nCopy this file to your C# project's Models/ folder")
print("=" * 60)
