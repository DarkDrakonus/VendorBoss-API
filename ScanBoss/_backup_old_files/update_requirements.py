#!/usr/bin/env python3
"""Add pyzbar to requirements.txt for barcode scanning"""

print("📦 Updating requirements.txt...")

with open('requirements.txt', 'r') as f:
    requirements = f.read()

if 'pyzbar' not in requirements:
    with open('requirements.txt', 'a') as f:
        f.write('pyzbar\n')
    print("✅ Added pyzbar to requirements.txt")
else:
    print("✓ pyzbar already in requirements.txt")

print("\n📋 Install with:")
print("   pip install -r requirements.txt")
print("   brew install zbar  # macOS only - needed for pyzbar")
