#!/usr/bin/env python3
"""
Quick Camera Test - Find which cameras work
"""
import cv2

print("🔍 Scanning for cameras...\n")

working_cameras = []

for i in range(3):  # Only test 0-2
    print(f"Testing camera {i}...")
    try:
        cap = cv2.VideoCapture(i)
        if cap.isOpened():
            ret, frame = cap.read()
            if ret and frame is not None:
                h, w = frame.shape[:2]
                print(f"  ✅ Camera {i} works! Resolution: {w}x{h}")
                working_cameras.append(i)
            else:
                print(f"  ❌ Camera {i} opened but can't read frames")
            cap.release()
        else:
            print(f"  ❌ Camera {i} failed to open")
    except Exception as e:
        print(f"  ❌ Camera {i} error: {e}")

print("\n" + "="*50)
if working_cameras:
    print(f"✅ Found {len(working_cameras)} working camera(s): {working_cameras}")
    print(f"\nRecommended camera index: {working_cameras[0]}")
else:
    print("❌ No working cameras found!")
    print("\nTroubleshooting:")
    print("1. Check System Settings > Privacy & Security > Camera")
    print("2. Grant camera permission to Terminal/Python")
    print("3. Close other apps using the camera")
    print("4. Try: sudo killall VDCAssistant")
print("="*50)
