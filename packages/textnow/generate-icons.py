#!/usr/bin/env python3
"""Generate TextNow Legacy app icons and launch images."""

from PIL import Image, ImageDraw, ImageFont
import os

OUT = os.path.join(os.path.dirname(__file__), "Resources")
os.makedirs(OUT, exist_ok=True)

FONT_BOLD = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
FONT_REG = "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"


def gradient(size, top=(0, 179, 170), bottom=(0, 128, 122)):
    img = Image.new("RGB", (size, size), top)
    draw = ImageDraw.Draw(img)
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(top[0] + (bottom[0] - top[0]) * t)
        g = int(top[1] + (bottom[1] - top[1]) * t)
        b = int(top[2] + (bottom[2] - top[2]) * t)
        draw.line([(0, y), (size, y)], fill=(r, g, b))
    return img


def make_icon(size):
    scale = 4
    s = size * scale
    img = gradient(s)
    draw = ImageDraw.Draw(img)

    # Soft highlight in the upper-left.
    glow = Image.new("L", (s, s), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse([-s * 0.35, -s * 0.45, s * 0.85, s * 0.65], fill=36)
    white = Image.new("RGB", (s, s), (255, 255, 255))
    img = Image.composite(white, img, glow.point(lambda v: int(v * 0.45)))
    draw = ImageDraw.Draw(img)

    # Speech bubble.
    bw, bh = s * 0.64, s * 0.47
    bx, by = (s - bw) / 2, (s - bh) / 2 - s * 0.035
    radius = s * 0.13
    draw.rounded_rectangle([bx, by, bx + bw, by + bh], radius=radius, fill=(255, 255, 255))
    # Tail.
    tail_x = bx + bw * 0.24
    tail_y = by + bh
    draw.polygon([(tail_x, tail_y - 2), (tail_x + s * 0.10, tail_y - 2),
                  (tail_x + s * 0.015, tail_y + s * 0.13)], fill=(255, 255, 255))

    # Three dots.
    dot_r = s * 0.035
    cy = by + bh / 2
    for i in (-1, 0, 1):
        cx = bx + bw / 2 + i * s * 0.10
        draw.ellipse([cx - dot_r, cy - dot_r, cx + dot_r, cy + dot_r], fill=(0, 150, 143))

    return img.resize((size, size), Image.LANCZOS)


def make_launch(width, height, scale=2):
    """scale=2 for @2x, 1 for the 320x480 asset."""
    img = Image.new("RGB", (width, height), (255, 255, 255))
    draw = ImageDraw.Draw(img)

    # Very light teal wash at the top.
    for y in range(height):
        t = y / float(height)
        r = int(255 - (255 - 240) * (1 - t))
        g = int(255 - (255 - 249) * (1 - t))
        b = int(255 - (255 - 248) * (1 - t))
        draw.line([(0, y), (width, y)], fill=(r, g, b))

    icon_size = int(104 * scale)
    icon = make_icon(icon_size if icon_size <= 512 else 512).resize((icon_size, icon_size), Image.LANCZOS)
    ix = (width - icon_size) // 2
    iy = int(height * 0.34)
    img.paste(icon, (ix, iy))

    try:
        title_font = ImageFont.truetype(FONT_BOLD, int(34 * scale))
        sub_font = ImageFont.truetype(FONT_REG, int(14 * scale))
    except Exception:
        title_font = ImageFont.load_default()
        sub_font = ImageFont.load_default()

    title = "TextNow"
    tw = draw.textlength(title, font=title_font)
    draw.text(((width - tw) / 2, iy + icon_size + int(20 * scale)),
              title, font=title_font, fill=(0, 158, 151))
    sub = "LEGACY  ·  for iOS 7"
    sw = draw.textlength(sub, font=sub_font)
    draw.text(((width - sw) / 2, iy + icon_size + int(64 * scale)),
              sub, font=sub_font, fill=(113, 120, 133))

    return img


# SpringBoard / Settings / Spotlight icons.
for base, small in (("AppIcon29x29", 29), ("AppIcon40x40", 40),
                    ("AppIcon57x57", 57), ("AppIcon60x60", 60)):
    make_icon(small).save(os.path.join(OUT, base + ".png"), optimize=True)
    make_icon(small * 2).save(os.path.join(OUT, base + "@2x.png"), optimize=True)

# Launch images for the 3.5" iPhone 4 (320x480 @2x).
make_launch(320, 480, scale=1).save(os.path.join(OUT, "Default.png"), optimize=True)
make_launch(640, 960, scale=2).save(os.path.join(OUT, "Default@2x.png"), optimize=True)

# A larger copy used by the repo page / about screens.
make_icon(512).save(os.path.join(OUT, "AppIcon512.png"), optimize=True)

print("Generated icons in", OUT)
