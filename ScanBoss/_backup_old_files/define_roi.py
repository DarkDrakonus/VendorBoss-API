"""
ScanBoss AI - Region of Interest (ROI) Definition Tool

Define important regions per set for focused AI training.
Instead of training on full card, train on distinctive regions only.

Usage:
    python define_roi.py --game magic --set neo
    python define_roi.py --game pokemon --set base1
    
Instructions:
    1. Click and drag to define regions
    2. Label each region (art, symbol, text, etc.)
    3. Save ROI config for this set
"""

import cv2
import json
from pathlib import Path
import argparse
import numpy as np

SCANBOSS_DIR = Path(__file__).parent
TRAINING_DATA_DIR = SCANBOSS_DIR / "training_data"
ROI_CONFIG_DIR = SCANBOSS_DIR / "roi_configs"
ROI_CONFIG_DIR.mkdir(exist_ok=True)

class ROIDefiner:
    def __init__(self, game: str, set_code: str):
        self.game = game
        self.set_code = set_code
        self.roi_file = ROI_CONFIG_DIR / f"{game}_{set_code}.json"
        
        # Find sample card from this set
        set_dir = TRAINING_DATA_DIR / game / f"{set_code}-*"
        sample_dirs = list(Path(TRAINING_DATA_DIR / game).glob(f"{set_code}-*"))
        
        if not sample_dirs:
            raise ValueError(f"No cards found for {game}/{set_code}")
        
        # Load first card as sample
        sample_card = sample_dirs[0] / "image.jpg"
        self.image = cv2.imread(str(sample_card))
        self.display_image = self.image.copy()
        
        # ROI storage
        self.rois = []
        self.current_roi = None
        self.drawing = False
        self.start_point = None
        
        print(f"\n{'='*60}")
        print(f"ROI DEFINITION TOOL - {game.upper()} / {set_code}")
        print(f"{'='*60}")
        print(f"Sample card: {sample_card.name}")
        print(f"\nInstructions:")
        print(f"  1. Click and drag to draw rectangle")
        print(f"  2. Press 'a' to label as ART region")
        print(f"  3. Press 's' to label as SYMBOL region")
        print(f"  4. Press 't' to label as TEXT region")
        print(f"  5. Press 'p' to label as POWER region")
        print(f"  6. Press 'u' to undo last region")
        print(f"  7. Press 'SPACE' to save and exit")
        print(f"  8. Press 'ESC' to exit without saving")
        print(f"{'='*60}\n")
    
    def mouse_callback(self, event, x, y, flags, param):
        if event == cv2.EVENT_LBUTTONDOWN:
            self.drawing = True
            self.start_point = (x, y)
        
        elif event == cv2.EVENT_MOUSEMOVE:
            if self.drawing:
                temp_image = self.display_image.copy()
                cv2.rectangle(temp_image, self.start_point, (x, y), (0, 255, 0), 2)
                cv2.imshow('Define ROI', temp_image)
        
        elif event == cv2.EVENT_LBUTTONUP:
            self.drawing = False
            self.current_roi = {
                'x1': min(self.start_point[0], x),
                'y1': min(self.start_point[1], y),
                'x2': max(self.start_point[0], x),
                'y2': max(self.start_point[1], y),
                'label': None
            }
            
            print(f"\nROI drawn: ({self.current_roi['x1']}, {self.current_roi['y1']}) to "
                  f"({self.current_roi['x2']}, {self.current_roi['y2']})")
            print(f"Press a key to label: [a]rt, [s]ymbol, [t]ext, [p]ower")
    
    def add_roi(self, label: str):
        if self.current_roi:
            self.current_roi['label'] = label
            self.rois.append(self.current_roi)
            
            # Draw labeled ROI
            color = {
                'art': (0, 255, 0),      # Green
                'symbol': (255, 0, 0),    # Blue
                'text': (0, 255, 255),    # Yellow
                'power': (255, 0, 255)    # Magenta
            }.get(label, (128, 128, 128))
            
            cv2.rectangle(
                self.display_image,
                (self.current_roi['x1'], self.current_roi['y1']),
                (self.current_roi['x2'], self.current_roi['y2']),
                color, 2
            )
            
            # Add label text
            cv2.putText(
                self.display_image,
                label.upper(),
                (self.current_roi['x1'], self.current_roi['y1'] - 5),
                cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2
            )
            
            print(f"✓ Added {label} region")
            print(f"  Total regions: {len(self.rois)}")
            
            self.current_roi = None
            cv2.imshow('Define ROI', self.display_image)
    
    def undo_last(self):
        if self.rois:
            removed = self.rois.pop()
            print(f"✗ Removed {removed['label']} region")
            
            # Redraw all ROIs
            self.display_image = self.image.copy()
            for roi in self.rois:
                color = {
                    'art': (0, 255, 0),
                    'symbol': (255, 0, 0),
                    'text': (0, 255, 255),
                    'power': (255, 0, 255)
                }.get(roi['label'], (128, 128, 128))
                
                cv2.rectangle(
                    self.display_image,
                    (roi['x1'], roi['y1']),
                    (roi['x2'], roi['y2']),
                    color, 2
                )
                cv2.putText(
                    self.display_image,
                    roi['label'].upper(),
                    (roi['x1'], roi['y1'] - 5),
                    cv2.FONT_HERSHEY_SIMPLEX, 0.5, color, 2
                )
            
            cv2.imshow('Define ROI', self.display_image)
    
    def save_config(self):
        config = {
            'game': self.game,
            'set': self.set_code,
            'image_size': {
                'width': self.image.shape[1],
                'height': self.image.shape[0]
            },
            'regions': self.rois
        }
        
        with open(self.roi_file, 'w') as f:
            json.dump(config, f, indent=2)
        
        print(f"\n{'='*60}")
        print(f"ROI CONFIG SAVED")
        print(f"{'='*60}")
        print(f"File: {self.roi_file}")
        print(f"Regions: {len(self.rois)}")
        for roi in self.rois:
            print(f"  - {roi['label']}: "
                  f"({roi['x2']-roi['x1']}×{roi['y2']-roi['y1']} pixels)")
        print(f"{'='*60}\n")
    
    def run(self):
        cv2.namedWindow('Define ROI')
        cv2.setMouseCallback('Define ROI', self.mouse_callback)
        cv2.imshow('Define ROI', self.display_image)
        
        while True:
            key = cv2.waitKey(1) & 0xFF
            
            if key == ord('a'):  # Art
                self.add_roi('art')
            elif key == ord('s'):  # Symbol
                self.add_roi('symbol')
            elif key == ord('t'):  # Text
                self.add_roi('text')
            elif key == ord('p'):  # Power
                self.add_roi('power')
            elif key == ord('u'):  # Undo
                self.undo_last()
            elif key == ord(' '):  # Save
                if self.rois:
                    self.save_config()
                    break
                else:
                    print("⚠ No regions defined! Draw at least one region.")
            elif key == 27:  # ESC
                print("\n✗ Cancelled without saving")
                break
        
        cv2.destroyAllWindows()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--game', required=True, choices=['pokemon', 'magic', 'fftcg'])
    parser.add_argument('--set', required=True, help='Set code (e.g., neo, base1, 1)')
    args = parser.parse_args()
    
    definer = ROIDefiner(args.game, args.set)
    definer.run()


if __name__ == '__main__':
    main()
