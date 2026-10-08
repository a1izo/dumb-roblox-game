"""Cutscene face decals (anime-style expressions for the R6 head's front), drawn here and carried into the
game as Tex_Face<Name> (build_props.FACE_TEXTURES). A cutscene's "face" event puts one on an actor's head
for a while (ShotPlayer), over the player's own face.

    python art/scripts/ui/faces.py      -> art/export/textures/Face*.png (512 x 512, transparent)

Drawn at 4x and scaled down, black ink with a little colour (the blush, the mouth's inside, red eyes)."""

import math
import os

from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "export", "textures")
S = 2048  # drawing size (4x)
INK = (18, 14, 16, 255)
MOUTH = (90, 16, 24, 255)
TEETH = (246, 242, 236, 255)
RED = (230, 30, 40, 255)


def W(v):
    return int(v * S / 512)


def eye_arc(d, cx, cy, w, h, up=True, width=26):
    """A closed eye as an arc (^ when up, a smile-curve when not)."""
    box = (W(cx - w), W(cy - h), W(cx + w), W(cy + h))
    d.arc(box, 200 if up else 20, 340 if up else 160, fill=INK, width=W(width / 4))


def narrow_eye(d, cx, cy, w, tilt, lid=14, pupil=True, iris=INK):
    """A narrowed eye: a hard upper lid tilted `tilt` degrees (in to the nose: menace), the pupil under it."""
    t = math.tan(math.radians(tilt))
    top = [(cx - w, cy - t * w), (cx + w, cy + t * w)]
    d.line([(W(x), W(y)) for x, y in top], fill=INK, width=W(lid))
    lower = [(cx - w * 0.8, cy + 16 - t * w * 0.5), (cx + w * 0.8, cy + 16 + t * w * 0.5)]
    d.line([(W(x), W(y)) for x, y in lower], fill=INK, width=W(3))
    if pupil:
        d.ellipse((W(cx - 9), W(cy - 2), W(cx + 9), W(cy + 14)), fill=iris)


def round_eye(d, cx, cy, r, pupil=5, iris=INK):
    d.ellipse((W(cx - r), W(cy - r * 1.15), W(cx + r), W(cy + r * 1.15)), outline=INK, width=W(5))
    d.ellipse((W(cx - pupil), W(cy - pupil), W(cx + pupil), W(cy + pupil)), fill=iris)


def brow(d, x0, y0, x1, y1, width=7):
    d.line([(W(x0), W(y0)), (W(x1), W(y1))], fill=INK, width=W(width))


def grin(d, cx, cy, w, h, teeth=False, open_=0.0):
    """A wide grin: corners up hard. open_ (0..1) opens it into a dark mouth (teeth on top)."""
    if open_ > 0:
        poly = []
        for k in range(21):
            u = k / 20
            x = cx - w + 2 * w * u
            poly.append((x, cy - h * 0.25 * (1 - (2 * u - 1) ** 2) - h * 0.5 * abs(2 * u - 1) ** 3))
        for k in range(21):
            u = 1 - k / 20
            x = cx - w + 2 * w * u
            poly.append((x, cy + h * open_ * (1 - (2 * u - 1) ** 2) - h * 0.5 * abs(2 * u - 1) ** 3))
        d.polygon([(W(x), W(y)) for x, y in poly], fill=MOUTH, outline=INK, width=W(5))
        if teeth:
            top = [(W(x), W(y)) for x, y in poly[:21]]
            d.line(top, fill=TEETH, width=W(9))
            d.line(top, fill=INK, width=W(3))
        return
    pts = []
    for k in range(25):
        u = k / 24
        x = cx - w + 2 * w * u
        y = cy + h * (1 - (2 * u - 1) ** 2) * 0.12 - h * 1.25 * abs(2 * u - 1) ** 4  # flat, the corners up hard
        pts.append((W(x), W(y)))
    d.line(pts, fill=INK, width=W(7), joint="curve")


def canvas():
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def shade(img):
    """The villain's shadow over the eyes: soft at the top and the sides, fading out under the eyes."""
    band = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = band.load()
    for y in range(W(110), W(266)):
        v = min(1.0, (y - W(110)) / W(40), (W(266) - y) / W(70))
        for x in range(0, S, 2):
            side = max(0.0, 1.0 - ((x - S / 2) / (S * 0.36)) ** 2)
            a = int(120 * v * side)
            px[x, y] = (20, 6, 10, a)
            if x + 1 < S:
                px[x + 1, y] = (20, 6, 10, a)
    return Image.alpha_composite(band, img)


def save(img, name, shadow=False):
    """Crops round the features (so they fill the head's face like a Roblox face) and writes the PNG."""
    os.makedirs(OUT, exist_ok=True)
    if shadow:
        img = shade(img)
    k = 1.3
    half = S / k / 2
    cx, cy = W(256), W(272)
    img = img.crop((int(cx - half), int(cy - half), int(cx + half), int(cy + half)))
    img.resize((512, 512), Image.LANCZOS).save(os.path.join(OUT, f"Face{name}.png"))


def main():
    # Grin: the villain's smile. Eyes narrowed and tilted in, a thin wide smile.
    img, d = canvas()
    narrow_eye(d, 186, 230, 44, 14)
    narrow_eye(d, 326, 230, 44, -14)
    brow(d, 140, 186, 226, 206)
    brow(d, 372, 186, 286, 206)
    grin(d, 256, 330, 96, 46)
    save(img, "Grin", shadow=True)

    # Laugh: the head-back laugh. Eyes screwed shut, the mouth wide open with teeth.
    img, d = canvas()
    eye_arc(d, 190, 236, 40, 22, up=True, width=34)
    eye_arc(d, 322, 236, 40, 22, up=True, width=34)
    brow(d, 146, 192, 226, 200)
    brow(d, 366, 192, 286, 200)
    grin(d, 256, 316, 108, 60, teeth=True, open_=1.0)
    save(img, "Laugh")

    # Crazed: one eye wide, one narrowed, the pupils tiny and red, a huge toothy grin.
    img, d = canvas()
    round_eye(d, 186, 226, 40, 6, RED)
    narrow_eye(d, 328, 232, 42, -18, iris=RED)
    brow(d, 140, 168, 226, 182)
    brow(d, 372, 186, 286, 210)
    grin(d, 256, 330, 118, 54, teeth=True, open_=0.55)
    save(img, "Crazed", shadow=True)

    # Shock: wide round eyes with tiny pupils, the brows up, a small open mouth.
    img, d = canvas()
    round_eye(d, 190, 228, 38, 5)
    round_eye(d, 322, 228, 38, 5)
    brow(d, 150, 168, 228, 160)
    brow(d, 362, 168, 284, 160)
    d.ellipse((W(236), W(318), W(276), W(366)), fill=MOUTH, outline=INK, width=W(5))
    save(img, "Shock")

    # Stern: level hard eyes, the brows down, the mouth a short flat line.
    img, d = canvas()
    narrow_eye(d, 188, 232, 40, 6)
    narrow_eye(d, 324, 232, 40, -6)
    brow(d, 146, 194, 228, 204, 8)
    brow(d, 366, 194, 284, 204, 8)
    d.line([(W(226), W(334)), (W(286), W(334))], fill=INK, width=W(6))
    save(img, "Stern", shadow=True)

    # Fear: brows up in the middle, eyes wide, a wavering mouth.
    img, d = canvas()
    round_eye(d, 190, 232, 34, 7)
    round_eye(d, 322, 232, 34, 7)
    brow(d, 148, 186, 222, 166)
    brow(d, 364, 186, 290, 166)
    pts = [(W(206 + 10 * k), W(340 + (6 if k % 2 else -6))) for k in range(11)]
    d.line(pts, fill=INK, width=W(5), joint="curve")
    save(img, "Fear")

    # Devoted: eyes half closed, lit red, a faint calm smile (the Muertos before Diavolo).
    img, d = canvas()
    narrow_eye(d, 188, 236, 40, 0, iris=RED)
    narrow_eye(d, 324, 236, 40, 0, iris=RED)
    grin(d, 256, 334, 54, 16)
    save(img, "Devoted")
    print("faces written to", os.path.abspath(OUT))


if __name__ == "__main__":
    main()
