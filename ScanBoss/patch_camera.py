#!/usr/bin/env python3
"""
Quick Fix for Camera Issues
Run this to patch scanboss_fleet.py
"""

import sys

print("🔧 Patching scanboss_fleet.py for better camera detection...\n")

try:
    # Read the file
    with open('scanboss_fleet.py', 'r') as f:
        content = f.read()
    
    # Fix 1: Change camera range from 5 to 3
    old_range = "for i in range(5):"
    new_range = "for i in range(3):  # Mac cameras are typically 0-2"
    
    if old_range in content:
        content = content.replace(old_range, new_range)
        print("✅ Fixed camera detection range (5 → 3)")
    else:
        print("⚠️ Camera range already patched or different format")
    
    # Fix 2: Add camera validation
    old_check = """            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                self.camera_combo.addItem(f"Camera {i}", i)
                cap.release()"""
    
    new_check = """            cap = cv2.VideoCapture(i)
            if cap.isOpened():
                # Verify we can actually read frames
                ret, _ = cap.read()
                if ret:
                    self.camera_combo.addItem(f"Camera {i}", i)
                cap.release()"""
    
    if old_check in content:
        content = content.replace(old_check, new_check)
        print("✅ Added frame reading validation")
    else:
        print("⚠️ Camera validation already patched or different format")
    
    # Write back
    with open('scanboss_fleet.py', 'w') as f:
        f.write(content)
    
    print("\n✅ Patch complete! Try running again:")
    print("   python3 scanboss_fleet.py")
    
except FileNotFoundError:
    print("❌ Error: scanboss_fleet.py not found")
    print("   Make sure you're in the ScanBoss directory")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
