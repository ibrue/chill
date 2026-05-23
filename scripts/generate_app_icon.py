#!/usr/bin/env python3
"""Generate Chill app icon PNGs at all macOS slot sizes.

Renders a 4-blade fan in white on the Chill gradient (ice blue → mint)
inside a rounded-rect tile, then resamples to every required size.
"""
import os
import math
from PIL import Image, ImageDraw, ImageFilter

OUT = os.path.join(os.path.dirname(__file__), "..", "Chill",
                   "Assets.xcassets", "AppIcon.appiconset")

# Brand colors (match Chill/UI/Brand.swift)
PRIMARY = (102, 199, 242, 255)   # ice blue   0.40, 0.78, 0.95
SECONDARY = (158, 230, 217, 255)  # mint       0.62, 0.90, 0.85

MASTER = 1024  # render at 1024, downsample for every slot

# Required (size, scale, filename) tuples
SLOTS = [
    (16, 1, "icon_16x16.png"),
    (16, 2, "icon_16x16@2x.png"),
    (32, 1, "icon_32x32.png"),
    (32, 2, "icon_32x32@2x.png"),
    (128, 1, "icon_128x128.png"),
    (128, 2, "icon_128x128@2x.png"),
    (256, 1, "icon_256x256.png"),
    (256, 2, "icon_256x256@2x.png"),
    (512, 1, "icon_512x512.png"),
    (512, 2, "icon_512x512@2x.png"),
]


def make_gradient(size: int) -> Image.Image:
    """Diagonal gradient from PRIMARY (top-left) to SECONDARY (bottom-right)."""
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            # Projection onto the diagonal: 0 at top-left → 1 at bottom-right
            t = (x + y) / (2 * (size - 1))
            r = int(PRIMARY[0] * (1 - t) + SECONDARY[0] * t)
            g = int(PRIMARY[1] * (1 - t) + SECONDARY[1] * t)
            b = int(PRIMARY[2] * (1 - t) + SECONDARY[2] * t)
            px[x, y] = (r, g, b, 255)
    return img


def rounded_mask(size: int, radius: int) -> Image.Image:
    """Solid white rounded-rect alpha mask."""
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, size - 1, size - 1), radius=radius, fill=255)
    return mask


def make_blade(blade_w: int, blade_h: int) -> Image.Image:
    """A single fan blade: white teardrop on transparent canvas.

    The blade's narrow tip is at the top-center of the canvas; the wide
    end is at the bottom. We oversize the canvas so rotation doesn't clip.
    """
    img = Image.new("RGBA", (blade_w, blade_h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Teardrop = ellipse skewed toward bottom.
    # Use a polygon approximation for a swept-blade look.
    cx = blade_w / 2
    points = []
    n = 64
    for i in range(n + 1):
        t = i / n
        # Width tapers from 0 at top to full at ~70% then back narrow at bottom
        # Profile: parabolic with peak slightly past midpoint
        profile = math.sin(t * math.pi) ** 0.85
        # Slight sweep so the blade curves like a real fan blade
        sweep = math.sin(t * math.pi) * blade_w * 0.18
        y = t * blade_h
        x_left = cx - profile * blade_w * 0.45 + sweep
        points.append((x_left, y))
    for i in range(n, -1, -1):
        t = i / n
        profile = math.sin(t * math.pi) ** 0.85
        sweep = math.sin(t * math.pi) * blade_w * 0.18
        y = t * blade_h
        x_right = cx + profile * blade_w * 0.45 + sweep
        points.append((x_right, y))
    d.polygon(points, fill=(255, 255, 255, 255))
    return img


def render_master() -> Image.Image:
    size = MASTER

    # 1) Gradient tile, rounded.
    grad = make_gradient(size)
    mask = rounded_mask(size, radius=int(size * 0.225))
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    tile.paste(grad, (0, 0), mask)

    # Soft drop shadow inside the tile for depth.
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    sd.rounded_rectangle(
        (0, int(size * 0.04), size - 1, size - 1),
        radius=int(size * 0.225),
        fill=(0, 0, 0, 60),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(radius=size * 0.012))
    composed = Image.alpha_composite(shadow, tile)

    # 2) Fan blades.
    blade_w = int(size * 0.36)
    blade_h = int(size * 0.40)
    blade = make_blade(blade_w, blade_h)

    cx = cy = size // 2
    for angle in (0, 90, 180, 270):
        # Rotate around bottom-center of blade so the tip ends up at icon center.
        rot = blade.rotate(angle, resample=Image.BICUBIC, expand=True)
        rw, rh = rot.size
        # Original blade has tip at top-center → after rotation, work out tip pos.
        # Easier: build a canvas with the blade placed so tip is at center,
        # then rotate the whole canvas.
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        canvas.paste(blade, (cx - blade_w // 2, cy - blade_h), blade)
        rotated_canvas = canvas.rotate(
            angle, resample=Image.BICUBIC, center=(cx, cy)
        )
        composed = Image.alpha_composite(composed, rotated_canvas)

    # 3) Center hub.
    hub_r = int(size * 0.085)
    hub = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    hd = ImageDraw.Draw(hub)
    hd.ellipse(
        (cx - hub_r, cy - hub_r, cx + hub_r, cy + hub_r),
        fill=(255, 255, 255, 255),
    )
    # Inner accent dot
    inner = int(hub_r * 0.35)
    hd.ellipse(
        (cx - inner, cy - inner, cx + inner, cy + inner),
        fill=PRIMARY,
    )
    composed = Image.alpha_composite(composed, hub)

    return composed


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    master = render_master()
    master_path = os.path.join(os.path.dirname(__file__), "_master_1024.png")
    master.save(master_path)
    print(f"Wrote master {master_path}")

    for pt_size, scale, fname in SLOTS:
        px = pt_size * scale
        resized = master.resize((px, px), Image.LANCZOS)
        path = os.path.join(OUT, fname)
        resized.save(path)
        print(f"Wrote {fname} ({px}x{px})")


if __name__ == "__main__":
    main()
