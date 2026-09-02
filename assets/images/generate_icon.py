#!/usr/bin/env python3
"""Generate a simple UsizoAI app icon (1024x1024 PNG).

Requirements: pip install Pillow

Usage: python generate_icon.py

Outputs: assets/images/app_icon.png
"""

from PIL import Image, ImageDraw
import math
import os

SIZE = 1024
CENTER = SIZE // 2
RADIUS = SIZE // 2 - 40
OUTPUT = os.path.join(os.path.dirname(__file__), 'app_icon.png')


def create_icon():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── Background circle (teal) ──────────────────────────────────
    draw.ellipse(
        [CENTER - RADIUS, CENTER - RADIUS, CENTER + RADIUS, CENTER + RADIUS],
        fill=(8, 127, 112, 255),  # #087f70
    )

    # ── White cross ───────────────────────────────────────────────
    arm_width = int(SIZE * 0.18)
    arm_length = int(SIZE * 0.52)
    corner = int(arm_width * 0.3)

    # Vertical arm
    v_rect = [
        CENTER - arm_width // 2,
        CENTER - arm_length // 2,
        CENTER + arm_width // 2,
        CENTER + arm_length // 2,
    ]
    draw.rounded_rectangle(v_rect, radius=corner, fill=(255, 255, 255, 255))

    # Horizontal arm
    h_rect = [
        CENTER - arm_length // 2,
        CENTER - arm_width // 2,
        CENTER + arm_length // 2,
        CENTER + arm_width // 2,
    ]
    draw.rounded_rectangle(h_rect, radius=corner, fill=(255, 255, 255, 255))

    # ── Small leaf accent (top-right) ─────────────────────────────
    leaf_cx = int(CENTER + RADIUS * 0.35)
    leaf_cy = int(CENTER - RADIUS * 0.35)
    leaf_size = int(SIZE * 0.14)

    leaf_points = [
        (leaf_cx, leaf_cy - leaf_size),
        (leaf_cx + leaf_size, leaf_cy - leaf_size // 3),
        (leaf_cx + leaf_size // 3, leaf_cy + leaf_size),
        (leaf_cx - leaf_size // 3, leaf_cy + leaf_size // 3),
    ]
    draw.polygon(leaf_points, fill=(168, 230, 207, 255))  # #a8e6cf

    # ── Save ──────────────────────────────────────────────────────
    img.save(OUTPUT, 'PNG')
    print(f'Icon saved to {OUTPUT}')


if __name__ == '__main__':
    create_icon()
