"""Builds the mod's sidebar button icons, icon, poster and Workshop preview.

    python3 scripts/make_art.py

Needs Pillow. Reads from the local Project Zomboid install, writes:
  Contents/mods/TienCustomizableLeftSidebar/42/icon.png       128x128
  Contents/mods/TienCustomizableLeftSidebar/42/poster.png     512x512
  Contents/mods/TienCustomizableLeftSidebar/42/media/ui/Sidebar/<size>/TienCustomizableLeftSidebar_Off|On_<size>.png
                         the Customize button (three rows, the middle one being dragged, and a pencil),
                         drawn here in the style of the game's sidebar icons, 48/64/80/96/128 wide
  preview.png                                                  512x512
"""

import math
import os

from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(HERE)
MOD = os.path.join(REPO, "Contents", "mods", "TienCustomizableLeftSidebar", "42")
UI = os.path.expanduser(
    "~/Library/Application Support/Steam/steamapps/common/ProjectZomboid/"
    "Project Zomboid.app/Contents/Java/media/ui"
)
SIDEBAR = os.path.join(UI, "Sidebar", "128")
EYE_OFF = os.path.join(UI, "foraging", "eyeconOff.png")

SIDEBAR_SIZES = (48, 64, 80, 96, 128)
SS = 4

BG_TOP = (44, 46, 52)
BG_BOTTOM = (14, 15, 18)
ACCENT = (255, 205, 80)


def load(path):
    if not os.path.exists(path):
        raise SystemExit("Missing game image: " + path)
    return Image.open(path).convert("RGBA")


def blend(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def vertical_gradient(size, top, bottom):
    img = Image.new("RGBA", size)
    d = ImageDraw.Draw(img)
    for y in range(size[1]):
        d.line([(0, y), (size[0], y)], fill=blend(top, bottom, y / max(1, size[1] - 1)) + (255,))
    return img


def grow(mask, px):
    """Grows the mask by px with a round pen, so outlines keep round corners on slanted
    shapes (a square MaxFilter leaves stepped, boxy corners)."""
    out = mask.copy()
    steps = max(16, round(px * 2 * math.pi))
    for i in range(steps):
        a = 2 * math.pi * i / steps
        out = ImageChops.lighter(out, ImageChops.offset(mask, round(px * math.cos(a)), round(px * math.sin(a))))
    return out


def solid(size, colour):
    return Image.new("RGBA", size, colour)


def paint(img, mask, fill):
    if isinstance(fill, tuple):
        fill = solid(img.size, fill + (255,))
    img.paste(fill, (0, 0), mask)


def rounded(full, box, radius):
    mask = Image.new("L", full, 0)
    ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
    return mask


def pencil_parts(tip, end, half):
    tx, ty = tip
    ex, ey = end
    length = math.hypot(ex - tx, ey - ty)
    dx, dy = (ex - tx) / length, (ey - ty) / length
    nx, ny = -dy, dx

    def at(t, side):
        return (tx + dx * length * t + nx * half * side, ty + dy * length * t + ny * half * side)

    def band(a, b):
        return [at(a, -1), at(b, -1), at(b, 1), at(a, 1)]

    graphite = [(tx, ty), at(0.07, -0.38), at(0.07, 0.38)]
    wood = [(tx, ty), at(0.2, -1), at(0.2, 1)]
    return {
        "wood": wood,
        "graphite": graphite,
        "body": band(0.2, 0.79),
        "stripe": [at(0.2, -0.18), at(0.79, -0.18), at(0.79, 0.18), at(0.2, 0.18)],
        "ferrule": band(0.79, 0.87),
        "eraser": band(0.87, 1.0),
        "outline": [(tx, ty), at(0.2, -1), at(1.0, -1), at(1.0, 1), at(0.2, 1)],
    }


def sidebar_icon(size, state):
    """Three rows like a list, the middle one pulled out to the right as if dragged, and a
    pencil across them. Grey when off, coloured when on, outlined like the game's sidebar
    icons: a thin white line outside a black one."""
    on = state == "On"
    w, h = size * SS, int(size * 0.75) * SS
    u = h / 100.0
    o = 25 * u
    full = (round(w + 2 * o), round(h + 2 * o))
    stroke = max(SS, round(size * SS / 56))
    img = Image.new("RGBA", full, (0, 0, 0, 0))

    rows = [
        (o + 14 * u, o + 14 * u, o + 78 * u, o + 33 * u, 0),
        (o + 26 * u, o + 41 * u, o + 90 * u, o + 60 * u, 1),
        (o + 14 * u, o + 68 * u, o + 78 * u, o + 87 * u, 0),
    ]
    tip = (o + 78 * u, o + 92 * u)
    end = (o + 124 * u, o + 10 * u)
    half = 9.5 * u
    parts = pencil_parts(tip, end, half)

    pencil_mask = Image.new("L", full, 0)
    ImageDraw.Draw(pencil_mask).polygon(parts["outline"], fill=255)
    row_masks = [rounded(full, (x0, y0, x1, y1), 6 * u) for x0, y0, x1, y1, _ in rows]
    lx0, ly0, _, ly1, _ = rows[1]
    arrow_y = (ly0 + ly1) / 2
    arrow = [(lx0 - 15 * u, arrow_y), (lx0 - 5 * u, arrow_y - 6.5 * u), (lx0 - 5 * u, arrow_y + 6.5 * u)]
    arrow_mask = Image.new("L", full, 0)
    ImageDraw.Draw(arrow_mask).polygon(arrow, fill=255)
    silhouette = ImageChops.lighter(pencil_mask, arrow_mask)
    for m in row_masks:
        silhouette = ImageChops.lighter(silhouette, m)
    paint(img, grow(silhouette, stroke * 2), (255, 255, 255))
    paint(img, grow(silhouette, stroke), (12, 12, 12))

    for (x0, y0, x1, y1, lifted), mask in zip(rows, row_masks):
        if on:
            top, bottom = ((250, 185, 90), (205, 105, 35)) if lifted else ((175, 205, 230), (85, 125, 165))
        else:
            top, bottom = ((228, 228, 228), (150, 150, 150)) if lifted else ((200, 200, 200), (118, 118, 118))
        paint(img, grow(mask, stroke), (12, 12, 12))
        paint(img, mask, vertical_gradient(full, top, bottom))
        d = ImageDraw.Draw(img)
        sq = (y1 - y0) * 0.52
        sy = (y0 + y1) / 2 - sq / 2
        d.rounded_rectangle([x0 + 5 * u, sy, x0 + 5 * u + sq, sy + sq], radius=2 * u, fill=(12, 12, 12, 200))
        line_y = (y0 + y1) / 2
        d.rounded_rectangle([x0 + 8 * u + sq, line_y - 2 * u, x1 - 7 * u, line_y + 2 * u], radius=2 * u,
                            fill=(12, 12, 12, 170))

    paint(img, arrow_mask, (12, 12, 12))
    paint(img, grow(pencil_mask, stroke), (12, 12, 12))
    layers = [
        ("body", ((255, 214, 80), (222, 150, 30)) if on else ((215, 215, 215), (140, 140, 140))),
        ("stripe", ((255, 236, 150), (240, 190, 70)) if on else ((235, 235, 235), (175, 175, 175))),
        ("wood", ((245, 215, 170), (215, 170, 115)) if on else ((225, 225, 225), (170, 170, 170))),
        ("graphite", ((60, 60, 60), (25, 25, 25))),
        ("ferrule", ((225, 225, 230), (140, 140, 150)) if on else ((210, 210, 210), (130, 130, 130))),
        ("eraser", ((245, 140, 160), (200, 80, 110)) if on else ((190, 190, 190), (115, 115, 115))),
    ]
    for name, (top, bottom) in layers:
        mask = Image.new("L", full, 0)
        ImageDraw.Draw(mask).polygon(parts[name], fill=255)
        paint(img, mask, vertical_gradient(full, top, bottom))
    d = ImageDraw.Draw(img)
    ferrule = parts["ferrule"]
    for a, b in ((ferrule[0], ferrule[3]), (ferrule[1], ferrule[2])):
        d.line([a, b], fill=(12, 12, 12, 255), width=max(1, stroke // 2))
    return fit(img, (size, int(size * 0.75)))


def fit(img, size):
    """Scales the drawing down to fit inside the icon with a pixel to spare on every side, centred,
    so no outline is cut off at the canvas edge."""
    box = img.getchannel("A").getbbox()
    art = img.crop(box)
    w, h = size[0] * SS, size[1] * SS
    margin = SS
    scale = min((w - 2 * margin) / art.width, (h - 2 * margin) / art.height)
    art = art.resize((max(1, round(art.width * scale)), max(1, round(art.height * scale))), Image.LANCZOS)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.alpha_composite(art, ((w - art.width) // 2, (h - art.height) // 2))
    return out.resize(size, Image.LANCZOS)


def backdrop(size):
    return vertical_gradient((size, size), BG_TOP, BG_BOTTOM)


def shadow(img, blur, alpha):
    mask = img.getchannel("A").point(lambda a: a * alpha // 255)
    black = Image.new("RGBA", img.size, (0, 0, 0, 0))
    black.putalpha(mask)
    pad = blur * 3
    out = Image.new("RGBA", (img.width + pad * 2, img.height + pad * 2), (0, 0, 0, 0))
    out.alpha_composite(black, (pad, pad))
    return out.filter(ImageFilter.GaussianBlur(blur)), pad


def scaled(img, width):
    return img.resize((width, round(img.height * width / img.width)), Image.LANCZOS)


def faded(img, alpha):
    out = img.copy()
    out.putalpha(img.getchannel("A").point(lambda a: a * alpha // 255))
    return out


def art(size):
    """A sidebar column of the game's own icons: one pulled out to the side on its way to a
    gap lower down, one hidden (faded, with the closed eye), the Customize button at the foot."""
    img = backdrop(size)
    k = size / 512.0
    cell = round(72 * k)
    gap = round(12 * k)
    col_x = round(118 * k)
    top = round(34 * k)
    names = ["Inventory_On", "Heart_Off", None, "Carpentry_Off", "Search_Off", "AnimalZone_Off"]
    slots = []
    y = top
    for name in names:
        slots.append((name, y))
        y += round(cell * 0.75) + gap
    edit_y = y
    panel_h = edit_y + round(cell * 0.75) + round(16 * k) - (top - round(14 * k))
    panel = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(panel).rounded_rectangle(
        [col_x - round(14 * k), top - round(14 * k), col_x + cell + round(14 * k), top - round(14 * k) + panel_h],
        radius=round(12 * k), fill=(0, 0, 0, 120), outline=(110, 110, 110, 200), width=max(1, round(2 * k)))
    img.alpha_composite(panel)

    for name, y in slots:
        if name is None:
            d = ImageDraw.Draw(img)
            h = round(cell * 0.75)
            d.rounded_rectangle([col_x - round(4 * k), y + round(4 * k), col_x + cell + round(4 * k), y + h - round(4 * k)],
                                radius=round(8 * k), outline=ACCENT + (255,), width=max(2, round(3 * k)))
            continue
        icon = scaled(load(os.path.join(SIDEBAR, name + "_128.png")), cell)
        if name == "Search_Off":
            img.alpha_composite(faded(icon, 80), (col_x, y))
            eye = scaled(load(EYE_OFF), round(cell * 0.55))
            img.alpha_composite(eye, (col_x + cell + round(24 * k), y + (icon.height - eye.height) // 2))
        else:
            img.alpha_composite(icon, (col_x, y))
    edit = scaled(sidebar_icon(128, "On"), cell)
    img.alpha_composite(edit, (col_x, edit_y))

    lifted = scaled(load(os.path.join(SIDEBAR, "Map_On_128.png")), round(cell * 1.6))
    lx = round(300 * k)
    ly = round(40 * k)
    sh, pad = shadow(lifted, max(2, round(8 * k)), 170)
    img.alpha_composite(sh, (lx - pad + round(8 * k), ly - pad + round(12 * k)))
    img.alpha_composite(lifted, (lx, ly))

    gap_y = slots[2][1] + round(cell * 0.75) // 2
    start = (lx + lifted.width * 0.3, ly + lifted.height * 0.95)
    stop = (col_x + cell + round(22 * k), gap_y)
    ctrl = (start[0] - 10 * k, stop[1] + 30 * k)
    pts = []
    for i in range(41):
        t = i / 40
        pts.append(((1 - t) ** 2 * start[0] + 2 * (1 - t) * t * ctrl[0] + t * t * stop[0],
                    (1 - t) ** 2 * start[1] + 2 * (1 - t) * t * ctrl[1] + t * t * stop[1]))
    d = ImageDraw.Draw(img)
    width = max(2, round(7 * k))
    d.line(pts, fill=(0, 0, 0, 200), width=width + max(2, round(4 * k)), joint="curve")
    d.line(pts, fill=ACCENT + (255,), width=width, joint="curve")
    ax, ay = pts[-1]
    bx, by = pts[-4]
    ang = math.atan2(ay - by, ax - bx)
    head = 22 * k
    tri = [(ax + math.cos(ang) * head * 0.6, ay + math.sin(ang) * head * 0.6),
           (ax + math.cos(ang + 2.5) * head, ay + math.sin(ang + 2.5) * head),
           (ax + math.cos(ang - 2.5) * head, ay + math.sin(ang - 2.5) * head)]
    d.polygon(tri, fill=ACCENT + (255,), outline=(0, 0, 0, 220))
    return img


def main():
    for size in SIDEBAR_SIZES:
        folder = os.path.join(MOD, "media", "ui", "Sidebar", str(size))
        os.makedirs(folder, exist_ok=True)
        for state in ("Off", "On"):
            sidebar_icon(size, state).save(
                os.path.join(folder, "TienCustomizableLeftSidebar_%s_%d.png" % (state, size)))
    art(128).convert("RGB").save(os.path.join(MOD, "icon.png"))
    poster = art(512).convert("RGB")
    poster.save(os.path.join(MOD, "poster.png"))
    poster.save(os.path.join(REPO, "preview.png"))
    print("Wrote the sidebar icons, icon.png, poster.png and preview.png")


if __name__ == "__main__":
    main()
