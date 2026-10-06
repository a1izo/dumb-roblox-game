"""The game's ransom-note wordmark as an image (UiWordmark.png), for the lobby monolith, which the
server builds and which therefore cannot use the client's glyph text. Run with Blender's Python:

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\5.2\\python\\bin\\python.exe" art/scripts/ui/wordmark.py

The letters are laid out by the same rules as Kit.ransom (src/client/UI/Kit/Ransom.luau), so the title in
the lobby menu and the one carved on the monolith are the same arrangement. KEEP THE TWO IN STEP:

  seed        FNV-1a (32 bit) of the text (plus an optional seed string); then xorshift32, rnd() = x / 2^32
  hand wins   redA = floor(rnd() * letters), redB = (redA + 3 + floor(rnd() * max(1, letters - 4))) % letters
              (drawn before the letters, only when `hand` is set; those two letters are red)
  per letter  style k = floor(rnd() * 7), moved to (k + 1) % 7 when it equals the last letter's style;
              rotation = rnd() * 12 - 6 degrees; scale = 0.86 + rnd() * 0.3; dy = round(rnd() * 8 - 4) px at
              size 62 (scaled with the size); upper case when it is the first letter or rnd() < 0.55
              (the second draw happens only for letters after the first); letters in an Aktura (Title) box
              are always lower case, because Aktura's capitals are hard to read
  box         width = (advance + 0.24 em) * scale, height = 1.10 * em * scale, em = size; the glyph sits on a
              baseline 0.06 em + half-leading + ascent below the top; a hard shadow 0.06 em right and down;
              dark boxes also get a light 0.05 em outline; letters are 0.05 em apart, a space is 0.32 em
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import fonts  # noqa: E402
import png  # noqa: E402
import ttf  # noqa: E402

ROOT = fonts.ROOT
TEXTURES = fonts.TEXTURES

TEXT = "Death's Gambit"
WIDTH, HEIGHT = 1320, 270  # the monolith's board at 30 px per stud

WHITE = (244, 245, 247)
G0, G3, G5, G6 = (8, 9, 11), (35, 39, 47), (107, 115, 128), (163, 170, 181)
RED = (225, 17, 43)

# (box colour, letter colour, face, outline) - the same seven as the style board's ransom note.
STYLES = [
    (WHITE, G0, "Title", False),
    (G0, WHITE, "Head", True),
    (G3, WHITE, "Title", True),
    (WHITE, G0, "RnLight", False),
    (G5, G0, "Head", False),
    (G0, WHITE, "Title", True),
    (G6, G0, "RnMedium", False),
]
M = 0xFFFFFFFF


class Rng:
    def __init__(self, text):
        h = 2166136261
        for byte in text.encode("utf-8"):
            h ^= byte
            h = (h * 16777619) & M
        self.x = h or 1

    def next(self):
        x = self.x
        x ^= (x << 13) & M
        x ^= x >> 17
        x ^= (x << 5) & M
        self.x = x
        return x / 4294967296


def lua_round(v):
    return math.floor(v + 0.5)


def layout(text, hand=False, seed=""):
    """The per-letter choices, in order (spaces are None)."""
    rng = Rng(text + seed)
    letters = sum(1 for c in text if c != " ")
    red = set()
    if hand:
        a = math.floor(rng.next() * letters)
        b = (a + 3 + math.floor(rng.next() * max(1, letters - 4))) % letters
        red = {a, b}
    out, last, n = [], -1, 0
    for ch in text:
        if ch == " ":
            out.append(None)
            continue
        k = math.floor(rng.next() * len(STYLES))
        if k == last:
            k = (k + 1) % len(STYLES)
        last = k
        rot = rng.next() * 12 - 6
        scale = 0.86 + rng.next() * 0.3
        dy = lua_round(rng.next() * 8 - 4)
        upper = n == 0 or rng.next() < 0.55
        if STYLES[k][2] == "Title":
            upper = False  # Aktura's capitals are ornate lombardics; its lower case is the readable blackletter
        out.append({"char": ch.upper() if upper else ch.lower(), "style": k, "rot": rot, "scale": scale,
                    "dy": dy, "red": n in red})
        n += 1
    return out


def rotate(img, degrees):
    """Rotates an RGBA image about its centre onto a larger canvas (bilinear, premultiplied)."""
    h, w = img.shape[:2]
    rad = math.radians(degrees)
    c, s = math.cos(rad), math.sin(rad)
    nw, nh = int(math.ceil(abs(w * c) + abs(h * s))) + 2, int(math.ceil(abs(w * s) + abs(h * c))) + 2
    yy, xx = np.mgrid[0:nh, 0:nw].astype(float)
    x, y = xx - nw / 2, yy - nh / 2
    sx, sy = c * x + s * y + w / 2, -s * x + c * y + h / 2
    x0, y0 = np.floor(sx).astype(int), np.floor(sy).astype(int)
    fx, fy = (sx - x0)[..., None], (sy - y0)[..., None]
    pre = img.copy()
    pre[..., :3] *= pre[..., 3:4]

    def tap(ix, iy):
        ok = ((ix >= 0) & (ix < w) & (iy >= 0) & (iy < h))[..., None]
        return np.where(ok, pre[np.clip(iy, 0, h - 1), np.clip(ix, 0, w - 1)], 0.0)

    out = (tap(x0, y0) * (1 - fx) * (1 - fy) + tap(x0 + 1, y0) * fx * (1 - fy)
           + tap(x0, y0 + 1) * (1 - fx) * fy + tap(x0 + 1, y0 + 1) * fx * fy)
    alpha = out[..., 3:4]
    out[..., :3] = np.where(alpha > 1e-6, out[..., :3] / np.maximum(alpha, 1e-6), 0.0)
    return out


def over(dst, src, x, y):
    """Alpha-composites src onto dst with its top-left at (x, y)."""
    h, w = src.shape[:2]
    x0, y0 = max(x, 0), max(y, 0)
    x1, y1 = min(x + w, dst.shape[1]), min(y + h, dst.shape[0])
    if x1 <= x0 or y1 <= y0:
        return
    part = src[y0 - y : y1 - y, x0 - x : x1 - x]
    region = dst[y0:y1, x0:x1]
    a = part[..., 3:4]
    ra = region[..., 3:4]
    out_a = a + ra * (1 - a)
    rgb = np.where(out_a > 1e-6, (part[..., :3] * a + region[..., :3] * ra * (1 - a)) / np.maximum(out_a, 1e-6), 0.0)
    region[..., :3], region[..., 3:4] = rgb, out_a


def letter_box(fnt, spec, size):
    """One ransom letter as a rotated RGBA image (shadow included)."""
    bg, fg, face, outline = STYLES[spec["style"]]
    if spec["red"]:
        bg, fg, outline = RED, WHITE, False
    font = fnt[face]
    s = size * spec["scale"]
    gid = fonts.glyph_for(font["font"], spec["char"], fonts.FACES[face])
    if not gid:
        gid = font["font"].glyph_index("?")
    rgba, adv, info = fonts.render_glyph(font["font"], gid, s, 2)
    pad_x, pad_top = 0.12 * s, 0.06 * s
    box_w, box_h = int(round(adv + 0.24 * s)), int(round(1.10 * s))
    shadow = int(round(0.06 * s)) or 1
    img = np.zeros((box_h + shadow, box_w + shadow, 4))
    img[:box_h, :box_w, :3] = np.array(bg) / 255
    img[:box_h, :box_w, 3] = 1
    # The hard shadow first (underneath), then the box.
    layer = np.zeros_like(img)
    layer[shadow : shadow + box_h, shadow : shadow + box_w, :3] = np.array(G0) / 255
    layer[shadow : shadow + box_h, shadow : shadow + box_w, 3] = 1
    over(layer, img[: box_h + shadow, : box_w + shadow], 0, 0)
    img = layer
    if outline:
        ring = max(1, int(round(0.05 * s)))
        edge = np.ones((box_h, box_w), bool)
        edge[ring:-ring, ring:-ring] = False
        img[:box_h, :box_w, :3][edge] = np.array(G6) / 255
    if rgba is not None:
        ascent, descent = font["ascent"] / font["em"], font["descent"] / font["em"]
        baseline = pad_top + ((1 - (ascent + descent)) / 2 + ascent) * s
        glyph = rgba.copy()
        glyph[..., :3] = np.array(fg) / 255
        over(img, glyph, int(round(pad_x + info["ox"])), int(round(baseline - info["top"])))
    return rotate(img, -spec["rot"])  # CSS rotates clockwise for positive degrees; rotate() turns the other way


def load_fonts():
    out = {}
    for name in ("Title", "Head", "RnLight", "RnMedium"):
        spec = fonts.FACES[name]
        font = ttf.Font(fonts.font_path(spec["source"]))
        scale = 1 / font.units_per_em
        out[name] = {"font": font, "em": 1.0, "ascent": font.ascender * scale, "descent": -font.descender * scale}
    return out


def render(text=TEXT, hand=False, seed="", width=WIDTH, height=HEIGHT):
    fnt = load_fonts()
    specs = layout(text, hand, seed)

    def total_width(size):
        total, first = 0.0, True
        for spec in specs:
            if not first:
                total += 0.05 * size
            first = False
            if spec is None:
                total += 0.32 * size
                continue
            font = fnt[STYLES[spec["style"]][2]]["font"]
            gid = fonts.glyph_for(font, spec["char"], fonts.FACES[STYLES[spec["style"]][2]]) or font.glyph_index("?")
            total += (font.advance(gid) / font.units_per_em + 0.24) * size * spec["scale"]
        return total

    size = 100.0
    size *= min(0.94 * width / total_width(size), 0.72 * height / (1.35 * 1.0))
    canvas = np.zeros((height, width, 4))
    x = (width - total_width(size)) / 2
    mid = height / 2
    first = True
    for spec in specs:
        if not first:
            x += 0.05 * size
        first = False
        if spec is None:
            x += 0.32 * size
            continue
        box = letter_box(fnt, spec, size)
        bh, bw = box.shape[:2]
        font = fnt[STYLES[spec["style"]][2]]["font"]
        gid = fonts.glyph_for(font, spec["char"], fonts.FACES[STYLES[spec["style"]][2]]) or font.glyph_index("?")
        cell = (font.advance(gid) / font.units_per_em + 0.24) * size * spec["scale"]
        cx = x + cell / 2
        cy = mid + spec["dy"] * size / 62
        over(canvas, box, int(round(cx - bw / 2)), int(round(cy - bh / 2)))
        x += cell
    return canvas


def main():
    os.makedirs(TEXTURES, exist_ok=True)
    img = render()
    path = os.path.join(TEXTURES, "UiWordmark.png")
    png.write(path, img)
    hand = render(hand=True)
    os.makedirs(fonts.PREVIEWS, exist_ok=True)
    sheet = np.zeros((HEIGHT * 2 + 30, WIDTH, 4))
    sheet[..., :3] = np.array([23, 26, 32]) / 255
    sheet[..., 3] = 1
    over(sheet, img, 0, 10)
    over(sheet, hand, 0, HEIGHT + 20)
    print("[wordmark]", path)
    print("[wordmark]", png.write(os.path.join(fonts.PREVIEWS, "ui_wordmark.png"), sheet))


if __name__ == "__main__":
    main()
