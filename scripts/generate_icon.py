#!/usr/bin/env python3
"""Generate a 1024x1024 app icon for Babushka.

Usage:
    python3 scripts/generate_icon.py [output_path]

Default output: Babushka/Assets.xcassets/AppIcon.appiconset/icon.png
"""

import math
import os
import subprocess
import sys

VENV_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".venv")


def _get_site_packages():
    """Return the site-packages path for the current Python inside the venv."""
    if sys.platform == "win32":
        return os.path.join(VENV_DIR, "Lib", "site-packages")
    lib_dir = os.path.join(VENV_DIR, "lib")
    py_dirs = [d for d in os.listdir(lib_dir) if d.startswith("python")] if os.path.isdir(lib_dir) else []
    if not py_dirs:
        raise RuntimeError(f"No python directory found in {lib_dir}")
    return os.path.join(lib_dir, py_dirs[0], "site-packages")


def _create_venv():
    """Create (or recreate) the venv and install Pillow."""
    import shutil

    if os.path.isdir(VENV_DIR):
        shutil.rmtree(VENV_DIR)
    print(f"Creating venv at {VENV_DIR}...")
    subprocess.check_call([sys.executable, "-m", "venv", VENV_DIR])
    pip = os.path.join(VENV_DIR, "bin", "pip")
    req = os.path.join(os.path.dirname(os.path.abspath(__file__)), "requirements.txt")
    subprocess.check_call([pip, "install", "-r", req])


def ensure_pillow():
    """Create a venv and install Pillow if needed, then activate it."""
    if not os.path.isdir(VENV_DIR):
        _create_venv()

    site_packages = _get_site_packages()
    if site_packages not in sys.path:
        sys.path.insert(0, site_packages)

    try:
        import PIL._imaging  # noqa: F401
    except (ImportError, ModuleNotFoundError):
        # Stale venv (wrong Python version) — recreate it
        _create_venv()
        site_packages = _get_site_packages()
        if site_packages not in sys.path:
            sys.path.insert(0, site_packages)


ensure_pillow()

from PIL import Image, ImageDraw  # noqa: E402

SIZE = 1024
DEFAULT_OUTPUT = os.path.join(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
    "Babushka",
    "Assets.xcassets",
    "AppIcon.appiconset",
    "icon.png",
)


def lerp_color(c1, c2, t):
    """Linearly interpolate between two RGB colors."""
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_gradient(draw, size, top_color, bottom_color):
    """Draw a vertical gradient background."""
    for y in range(size):
        color = lerp_color(top_color, bottom_color, y / size)
        draw.line([(0, y), (size, y)], fill=color)


def draw_doll_layer(draw, cx, cy, width, height, head_radius, color, outline_color):
    """Draw one matryoshka doll layer (body + head)."""
    # Body — rounded rectangle
    body_top = cy - height // 2 + head_radius
    body_bottom = cy + height // 2
    draw.rounded_rectangle(
        [cx - width // 2, body_top, cx + width // 2, body_bottom],
        radius=width // 3,
        fill=color,
        outline=outline_color,
        width=3,
    )
    # Head — circle
    head_cy = body_top
    draw.ellipse(
        [cx - head_radius, head_cy - head_radius, cx + head_radius, head_cy + head_radius],
        fill=color,
        outline=outline_color,
        width=3,
    )


def draw_face(draw, cx, cy, head_radius):
    """Draw a simple face circle on the innermost doll."""
    face_r = int(head_radius * 0.6)
    draw.ellipse(
        [cx - face_r, cy - face_r, cx + face_r, cy + face_r],
        fill=(255, 228, 196),
        outline=(200, 160, 120),
        width=2,
    )


def draw_magnifying_glass(draw, cx, cy, radius, thickness):
    """Draw a magnifying glass suggesting inspection."""
    # Glass circle
    draw.ellipse(
        [cx - radius, cy - radius, cx + radius, cy + radius],
        fill=None,
        outline=(255, 255, 255, 220),
        width=thickness,
    )
    # Inner tint — light translucent fill so the glass looks clear
    inner_r = radius - thickness
    draw.ellipse(
        [cx - inner_r, cy - inner_r, cx + inner_r, cy + inner_r],
        fill=(255, 255, 255, 100),
    )
    # Handle
    handle_angle = math.radians(45)
    hx1 = cx + int(radius * math.cos(handle_angle))
    hy1 = cy + int(radius * math.sin(handle_angle))
    handle_len = int(radius * 0.8)
    hx2 = hx1 + int(handle_len * math.cos(handle_angle))
    hy2 = hy1 + int(handle_len * math.sin(handle_angle))
    draw.line([(hx1, hy1), (hx2, hy2)], fill=(255, 255, 255, 220), width=thickness + 2)
    # Rounded handle end
    draw.ellipse(
        [hx2 - thickness // 2 - 1, hy2 - thickness // 2 - 1,
         hx2 + thickness // 2 + 1, hy2 + thickness // 2 + 1],
        fill=(255, 255, 255, 220),
    )


def generate_icon(output_path):
    """Generate the Babushka app icon."""
    img = Image.new("RGBA", (SIZE, SIZE))
    draw = ImageDraw.Draw(img)

    # Gradient background — deep purple
    draw_gradient(draw, SIZE, top_color=(60, 20, 90), bottom_color=(25, 5, 45))

    cx, cy = SIZE // 2, SIZE // 2 + 20

    # Six nested doll layers (outer to inner) — purple gradient from light to deep
    num_layers = 6
    max_width, max_height, max_head_r = 460, 540, 120
    scale_step = 0.13  # each layer shrinks by this fraction
    layers = []
    for i in range(num_layers):
        t = i / (num_layers - 1)  # 0.0 (outermost) to 1.0 (innermost)
        s = 1.0 - i * scale_step
        w = int(max_width * s)
        h = int(max_height * s)
        hr = int(max_head_r * s)
        # Purple gradient: light lavender (outer) → deep violet (inner)
        r = int(200 - t * 120)
        g = int(160 - t * 130)
        b = int(255 - t * 60)
        fill = (r, g, b, 210)
        outline = (max(r - 40, 0), max(g - 30, 0), max(b - 20, 0))
        layers.append((w, h, hr, fill, outline))

    for width, height, head_r, fill, outline in layers:
        draw_doll_layer(draw, cx, cy, width, height, head_r, fill, outline)


    # Magnifying glass in the lower-right — the "inspector" motif
    mag_cx = cx + 200
    mag_cy = cy + 180
    draw_magnifying_glass(draw, mag_cx, mag_cy, radius=90, thickness=10)

    # Flatten to RGB
    final = Image.new("RGB", (SIZE, SIZE))
    final.paste(img, mask=img.split()[3])

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    final.save(output_path, "PNG")
    print(f"Generated {SIZE}x{SIZE} app icon: {output_path}")


if __name__ == "__main__":
    output = sys.argv[1] if len(sys.argv) > 1 else DEFAULT_OUTPUT
    generate_icon(output)
