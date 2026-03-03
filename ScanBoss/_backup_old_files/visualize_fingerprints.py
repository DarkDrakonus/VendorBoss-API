"""
Visual Fingerprint Comparison Tool
Shows cards with their fingerprint components visually
"""
import cv2
import numpy as np
import os
import json
from card_detector import CardDetector
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
import matplotlib.patches as mpatches

def visualize_fingerprints():
    """Create visual comparison of fingerprints"""
    
    print("=" * 70)
    print("Visual Fingerprint Comparison")
    print("=" * 70)
    print()
    
    # Initialize detector
    detector = CardDetector()
    
    # Get all images from Scans folder
    scans_dir = "Scans"
    if not os.path.exists(scans_dir):
        print(f"❌ Error: {scans_dir} folder not found!")
        return
    
    image_files = sorted([f for f in os.listdir(scans_dir) if f.endswith(('.jpg', '.jpeg', '.png'))])
    
    if not image_files:
        print(f"❌ No images found in {scans_dir}/")
        return
    
    print(f"Found {len(image_files)} card images")
    print("Generating fingerprints and visualizations...")
    print()
    
    # Process each image
    results = []
    
    for image_file in image_files:
        image_path = os.path.join(scans_dir, image_file)
        image = cv2.imread(image_path)
        
        if image is None:
            continue
        
        # Resize to detection size
        resized = cv2.resize(image, (detector.detection_width, detector.detection_height))
        
        # Generate fingerprint
        fingerprint_data = detector._generate_14_component_fingerprint(resized)
        
        if fingerprint_data:
            results.append({
                'filename': image_file,
                'image': resized,
                'fingerprint': fingerprint_data
            })
    
    if not results:
        print("❌ No fingerprints generated!")
        return
    
    # Create visualization
    print(f"Creating visualizations for {len(results)} cards...")
    
    # Figure 1: Grid of all cards with fingerprints
    create_card_grid(results)
    
    # Figure 2: Detailed component visualization for first card
    if results:
        create_component_breakdown(results[0])
    
    # Figure 3: Comparison of similar cards (if we have FL versions)
    create_comparison_view(results)
    
    # Figure 4: 3x3 Quadrant visualization
    if results:
        create_quadrant_visualization(results[0])
    
    print("\n✓ Visualizations created!")
    print("\nClose the matplotlib windows to continue...")
    plt.show()


def create_card_grid(results):
    """Create a grid showing all cards with their fingerprints"""
    
    num_cards = len(results)
    cols = min(3, num_cards)
    rows = (num_cards + cols - 1) // cols
    
    fig, axes = plt.subplots(rows, cols, figsize=(cols * 5, rows * 6))
    fig.suptitle('VendorBoss 2.0 - Card Fingerprints', fontsize=16, fontweight='bold')
    
    # Flatten axes for easier iteration
    if num_cards == 1:
        axes = [axes]
    else:
        axes = axes.flatten() if rows > 1 else [axes] if cols == 1 else axes
    
    for i, result in enumerate(results):
        ax = axes[i]
        
        # Convert BGR to RGB
        image_rgb = cv2.cvtColor(result['image'], cv2.COLOR_BGR2RGB)
        
        # Display image
        ax.imshow(image_rgb)
        ax.axis('off')
        
        # Title with filename
        filename = result['filename'].replace('_eg', '').replace('.jpg', '')
        ax.set_title(filename, fontsize=12, fontweight='bold')
        
        # Add fingerprint info as text
        fp_hash = result['fingerprint']['fingerprint_hash']
        
        # Truncate hash for display
        hash_display = f"{fp_hash[:16]}...\n...{fp_hash[-16:]}"
        
        ax.text(0.5, -0.05, hash_display,
               transform=ax.transAxes,
               ha='center', va='top',
               fontsize=8, family='monospace',
               bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5))
    
    # Hide empty subplots
    for i in range(num_cards, len(axes)):
        axes[i].axis('off')
    
    plt.tight_layout()


def create_component_breakdown(result):
    """Show detailed component breakdown for a single card"""
    
    fig, axes = plt.subplots(2, 3, figsize=(15, 10))
    fig.suptitle(f"Component Breakdown: {result['filename']}", fontsize=16, fontweight='bold')
    
    image = result['image']
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    components = result['fingerprint']['components']
    
    h, w = image.shape[:2]
    
    # 1. Original card
    ax = axes[0, 0]
    ax.imshow(image_rgb)
    ax.set_title('Original Card', fontweight='bold')
    ax.axis('off')
    
    # 2. Border regions
    ax = axes[0, 1]
    ax.imshow(image_rgb)
    border_width = 20
    rect_top = Rectangle((0, 0), w, border_width, linewidth=2, edgecolor='red', facecolor='red', alpha=0.3)
    rect_bottom = Rectangle((0, h-border_width), w, border_width, linewidth=2, edgecolor='red', facecolor='red', alpha=0.3)
    rect_left = Rectangle((0, 0), border_width, h, linewidth=2, edgecolor='red', facecolor='red', alpha=0.3)
    rect_right = Rectangle((w-border_width, 0), border_width, h, linewidth=2, edgecolor='red', facecolor='red', alpha=0.3)
    ax.add_patch(rect_top)
    ax.add_patch(rect_bottom)
    ax.add_patch(rect_left)
    ax.add_patch(rect_right)
    ax.set_title(f"Border\n{components['border']}", fontweight='bold', fontsize=10)
    ax.axis('off')
    
    # 3. Name region
    ax = axes[0, 2]
    ax.imshow(image_rgb)
    name_h = int(h * 0.2)
    rect = Rectangle((0, 0), w, name_h, linewidth=2, edgecolor='blue', facecolor='blue', alpha=0.3)
    ax.add_patch(rect)
    ax.set_title(f"Name Region\n{components['name_region']}", fontweight='bold', fontsize=10)
    ax.axis('off')
    
    # 4. Color zones
    ax = axes[1, 0]
    ax.imshow(image_rgb)
    # Draw 5 zones
    zones = [
        (int(h*0.4), int(h*0.6), int(w*0.4), int(w*0.6)),  # Center
        (0, int(h*0.3), 0, int(w*0.3)),                     # Top-left
        (0, int(h*0.3), int(w*0.7), w),                     # Top-right
        (int(h*0.7), h, 0, int(w*0.3)),                     # Bottom-left
        (int(h*0.7), h, int(w*0.7), w),                     # Bottom-right
    ]
    colors = ['yellow', 'cyan', 'magenta', 'lime', 'orange']
    for (y1, y2, x1, x2), color in zip(zones, colors):
        rect = Rectangle((x1, y1), x2-x1, y2-y1, linewidth=2, edgecolor=color, facecolor=color, alpha=0.2)
        ax.add_patch(rect)
    ax.set_title(f"Color Zones\n{components['color_zones']}", fontweight='bold', fontsize=10)
    ax.axis('off')
    
    # 5. Texture (edge detection)
    ax = axes[1, 1]
    gray = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
    edges = cv2.Canny(gray, 50, 150)
    ax.imshow(edges, cmap='gray')
    ax.set_title(f"Texture/Edges\n{components['texture']}", fontweight='bold', fontsize=10)
    ax.axis('off')
    
    # 6. Component summary
    ax = axes[1, 2]
    ax.axis('off')
    
    # Display all components
    comp_text = "All Components:\n\n"
    comp_text += f"border:      {components['border']}\n"
    comp_text += f"name_region: {components['name_region']}\n"
    comp_text += f"color_zones: {components['color_zones']}\n"
    comp_text += f"texture:     {components['texture']}\n"
    comp_text += f"layout:      {components['layout']}\n"
    comp_text += "\n3x3 Quadrants:\n"
    for row in range(3):
        for col in range(3):
            key = f'quadrant_{row}_{col}'
            comp_text += f"{key}: {components[key]}\n"
    
    ax.text(0.1, 0.9, comp_text, transform=ax.transAxes,
           fontsize=8, family='monospace', verticalalignment='top',
           bbox=dict(boxstyle='round', facecolor='lightblue', alpha=0.7))
    
    plt.tight_layout()


def create_comparison_view(results):
    """Compare similar cards (e.g., normal vs FL versions)"""
    
    # Find pairs of similar cards (same number, different suffix)
    pairs = []
    processed = set()
    
    for i, result1 in enumerate(results):
        if i in processed:
            continue
        
        name1 = result1['filename'].replace('_FL', '').replace('_eg.jpg', '')
        
        for j, result2 in enumerate(results):
            if i >= j or j in processed:
                continue
            
            name2 = result2['filename'].replace('_FL', '').replace('_eg.jpg', '')
            
            if name1 == name2:
                pairs.append((result1, result2))
                processed.add(i)
                processed.add(j)
                break
    
    if not pairs:
        print("  No similar card pairs found for comparison")
        return
    
    # Create comparison figure
    fig, axes = plt.subplots(len(pairs), 2, figsize=(10, len(pairs) * 5))
    fig.suptitle('Card Variant Comparison', fontsize=16, fontweight='bold')
    
    if len(pairs) == 1:
        axes = axes.reshape(1, -1)
    
    for i, (card1, card2) in enumerate(pairs):
        # Card 1
        ax = axes[i, 0]
        image1_rgb = cv2.cvtColor(card1['image'], cv2.COLOR_BGR2RGB)
        ax.imshow(image1_rgb)
        ax.set_title(card1['filename'], fontweight='bold')
        ax.axis('off')
        
        hash1 = card1['fingerprint']['fingerprint_hash']
        ax.text(0.5, -0.05, f"{hash1[:32]}...",
               transform=ax.transAxes, ha='center', va='top',
               fontsize=8, family='monospace',
               bbox=dict(boxstyle='round', facecolor='lightgreen', alpha=0.5))
        
        # Card 2
        ax = axes[i, 1]
        image2_rgb = cv2.cvtColor(card2['image'], cv2.COLOR_BGR2RGB)
        ax.imshow(image2_rgb)
        ax.set_title(card2['filename'], fontweight='bold')
        ax.axis('off')
        
        hash2 = card2['fingerprint']['fingerprint_hash']
        ax.text(0.5, -0.05, f"{hash2[:32]}...",
               transform=ax.transAxes, ha='center', va='top',
               fontsize=8, family='monospace',
               bbox=dict(boxstyle='round', facecolor='lightcoral', alpha=0.5))
        
        # Compare fingerprints
        if hash1 == hash2:
            match_text = "⚠️ SAME FINGERPRINT (Unexpected!)"
            color = 'red'
        else:
            match_text = "✓ DIFFERENT FINGERPRINTS (Expected)"
            color = 'green'
        
        # Count matching components
        comp1 = card1['fingerprint']['components']
        comp2 = card2['fingerprint']['components']
        matching = sum(1 for k in comp1 if comp1[k] == comp2[k])
        
        match_text += f"\nMatching components: {matching}/14"
        
        fig.text(0.5, 1.0 - (i + 0.5) / len(pairs), match_text,
                ha='center', va='center', fontsize=12, fontweight='bold',
                color=color, bbox=dict(boxstyle='round', facecolor='yellow', alpha=0.3))
    
    plt.tight_layout()


def create_quadrant_visualization(result):
    """Visualize the 3x3 quadrant breakdown"""
    
    fig, axes = plt.subplots(3, 3, figsize=(12, 12))
    fig.suptitle(f"3x3 Quadrant Breakdown: {result['filename']}", fontsize=16, fontweight='bold')
    
    image = result['image']
    image_rgb = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)
    components = result['fingerprint']['components']
    
    h, w = image.shape[:2]
    
    for row in range(3):
        for col in range(3):
            ax = axes[row, col]
            
            # Calculate quadrant bounds
            y1 = int(h * row / 3)
            y2 = int(h * (row + 1) / 3)
            x1 = int(w * col / 3)
            x2 = int(w * (col + 1) / 3)
            
            # Extract quadrant
            quadrant = image_rgb[y1:y2, x1:x2]
            
            # Display
            ax.imshow(quadrant)
            
            # Title with component hash
            key = f'quadrant_{row}_{col}'
            ax.set_title(f"{key}\n{components[key]}", fontsize=9, fontweight='bold')
            ax.axis('off')
            
            # Add border to show position
            for spine in ax.spines.values():
                spine.set_edgecolor('red')
                spine.set_linewidth(2)
    
    plt.tight_layout()


if __name__ == "__main__":
    visualize_fingerprints()
