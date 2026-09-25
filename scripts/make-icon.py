#!/usr/bin/env python3
"""Draws Assets/AppIcon.png (1024×1024) — requires Pillow (pip install pillow).

The build script turns the PNG into AppIcon.icns; re-run this only to change the design.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersampling factor for smooth edges
SIZE = 1024 * S


def lerp(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def rounded_mask(box, radius):
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))

# Background squircle on Apple's macOS icon grid (824 pt body, 100 pt margin).
margin, body = 100 * S, 824 * S
box = (margin, margin, margin + body, margin + body)
top, bottom = (99, 102, 241), (168, 85, 247)  # indigo → violet
gradient = Image.new("RGBA", (SIZE, SIZE))
draw = ImageDraw.Draw(gradient)
for y in range(margin, margin + body):
    t = (y - margin) / body
    draw.line([(0, y), (SIZE, y)], fill=lerp(top, bottom, t) + (255,))
# Soft light from the top left.
glow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse((margin - 200 * S, margin - 300 * S, margin + 600 * S, margin + 400 * S), fill=(255, 255, 255, 60))
gradient = Image.alpha_composite(gradient, glow.filter(ImageFilter.GaussianBlur(120 * S)))
icon.paste(gradient, (0, 0), rounded_mask(box, 185 * S))

# Paper card with shadow, slightly rotated.
card_w, card_h = 470 * S, 560 * S
card = Image.new("RGBA", (card_w + 200 * S, card_h + 200 * S), (0, 0, 0, 0))
ox, oy = 100 * S, 100 * S
shadow = Image.new("RGBA", card.size, (0, 0, 0, 0))
ImageDraw.Draw(shadow).rounded_rectangle((ox, oy + 24 * S, ox + card_w, oy + card_h + 24 * S), radius=56 * S, fill=(40, 20, 90, 110))
card = Image.alpha_composite(card, shadow.filter(ImageFilter.GaussianBlur(30 * S)))
cd = ImageDraw.Draw(card)
cd.rounded_rectangle((ox, oy, ox + card_w, oy + card_h), radius=56 * S, fill=(255, 255, 255, 255))

# Title bar and text lines, one of them highlighted.
left = ox + 70 * S
cd.rounded_rectangle((left, oy + 80 * S, left + 250 * S, oy + 122 * S), radius=21 * S, fill=(79, 70, 229, 255))
line_y = oy + 190 * S
widths = [330, 290, 330, 210, 300]
for i, w in enumerate(widths):
    y = line_y + i * 68 * S
    if i == 2:
        # Highlighter stroke with slightly ragged, wider ends.
        cd.rounded_rectangle((left - 22 * S, y - 26 * S, left + w * S + 30 * S, y + 50 * S), radius=10 * S, fill=(253, 224, 71, 255))
    color = (203, 213, 225, 255) if i != 2 else (87, 83, 78, 255)
    cd.rounded_rectangle((left, y, left + w * S, y + 24 * S), radius=12 * S, fill=color)

card = card.rotate(-6, resample=Image.BICUBIC, expand=False)
cx = (SIZE - card.width) // 2 + 10 * S
cy = (SIZE - card.height) // 2 + 6 * S
icon.alpha_composite(card, (cx, cy))

out = Path(__file__).resolve().parent.parent / "Assets" / "AppIcon.png"
icon.resize((1024, 1024), Image.LANCZOS).save(out)
print(f"wrote {out}")
