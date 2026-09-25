"""The UI's textures and icons, drawn with numpy (run with plain Python):

    python art/scripts/ui/textures.py      textures + icon atlas + src/shared/UI/Icons.luau + preview

Everything is white or grey with alpha (the game tints it), except the two paper tiles, which
carry their own colour. Files go to art/export/textures/Ui<Name>.png and ride into Roblox on
carrier quads in InkboundModels.fbx (build_props.py). The UI works without them.
"""

import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import png  # noqa: E402
import ttf  # noqa: E402

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
TEXTURES = os.path.join(ROOT, "art", "export", "textures")
PREVIEWS = os.path.join(ROOT, "art", "export", "previews")
ICONS_LUAU = os.path.join(ROOT, "src", "shared", "UI", "Icons.luau")

rng = np.random.default_rng(7)


# Noise ------------------------------------------------------------------------------------------


def tile_noise(size, cells, seed):
    """Smooth noise in -1..1 that tiles: `cells` features across the image."""
    r = np.random.default_rng(seed)
    grid = r.uniform(-1, 1, (cells, cells))
    t = np.arange(size) * cells / size
    i0 = np.floor(t).astype(int)
    f = t - i0
    f = f * f * (3 - 2 * f)
    i1 = (i0 + 1) % cells
    a = grid[i0][:, i0]
    b = grid[i0][:, i1]
    c = grid[i1][:, i0]
    d = grid[i1][:, i1]
    top = a + (b - a) * f[None, :]
    bottom = c + (d - c) * f[None, :]
    return top + (bottom - top) * f[:, None]


def fbm(size, base, octaves, seed):
    out = np.zeros((size, size))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        out += tile_noise(size, base * 2**o, seed + o) * amp
        total += amp
        amp *= 0.5
    return out / total


def noise(h, w, cell, seed):
    """Smooth noise (not tiling) for any shape."""
    r = np.random.default_rng(seed)
    gh, gw = int(h / cell) + 3, int(w / cell) + 3
    grid = r.uniform(-1, 1, (gh, gw))
    ys, xs = np.arange(h) / cell, np.arange(w) / cell
    y0, x0 = np.floor(ys).astype(int), np.floor(xs).astype(int)
    fy, fx = ys - y0, xs - x0
    fy, fx = fy * fy * (3 - 2 * fy), fx * fx * (3 - 2 * fx)
    a, b = grid[y0][:, x0], grid[y0][:, x0 + 1]
    c, d = grid[y0 + 1][:, x0], grid[y0 + 1][:, x0 + 1]
    top = a + (b - a) * fx[None, :]
    bottom = c + (d - c) * fx[None, :]
    return top + (bottom - top) * fy[:, None]


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


def fibers(size, count, length, seed):
    """Thin random strokes that wrap around the edges (paper fibres), 0..1."""
    r = np.random.default_rng(seed)
    out = np.zeros((size, size))
    for _ in range(count):
        x, y = r.uniform(0, size, 2)
        angle = r.uniform(0, math.pi)
        n = int(r.uniform(0.4, 1.0) * length)
        strength = r.uniform(0.3, 1.0)
        for s in range(n):
            px = int(x + math.cos(angle) * s) % size
            py = int(y + math.sin(angle) * s) % size
            out[py, px] = max(out[py, px], strength)
    return out


def rgba(lum, alpha):
    lum = np.clip(lum, 0, 1)
    return np.stack([lum, lum, lum, np.clip(alpha, 0, 1)], axis=2)


# Textures ----------------------------------------------------------------------------------------


def paper(size, base, spread, fiber_tone, seed):
    mottle = fbm(size, 4, 4, seed)
    fib = fibers(size, 2600, 14, seed + 1)
    speck = (tile_noise(size, 128, seed + 2) > 0.93) * 0.5
    img = np.zeros((size, size, 4))
    for c in range(3):
        v = base[c] / 255 + mottle * spread + fib * fiber_tone + speck * fiber_tone * 0.6
        img[..., c] = v
    img[..., 3] = 1
    return np.clip(img, 0, 1)


def black_page():
    return paper(512, (18, 16, 21), 0.018, 0.035, 10)


def parchment():
    img = paper(512, (216, 205, 180), 0.06, -0.08, 20)
    stains = smoothstep(0.35, 0.7, fbm(512, 2, 3, 23))
    for c, tone in enumerate((0.10, 0.12, 0.16)):
        img[..., c] -= stains * tone
    return np.clip(img, 0, 1)


def torn_card(size=256, margin=10):
    """A white card with torn, fibrous edges (for 9-slice; centre 32..224)."""
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    edge = np.minimum(np.minimum(xx, size - 1 - xx), np.minimum(yy, size - 1 - yy))
    wobble = noise(size, size, 9, 31) * 3.0 + noise(size, size, 2.2, 32) * 1.6
    alpha = smoothstep(margin - 1.2, margin + 1.2, edge + wobble)
    fuzz = (noise(size, size, 1.1, 33) > 0.55) & (edge + wobble > margin - 3) & (edge + wobble < margin + 1)
    alpha = np.maximum(alpha, fuzz * 0.6)
    lum = 0.97 + noise(size, size, 6, 34) * 0.03
    return rgba(lum, alpha)


def brush_stroke(w=1024, h=160):
    """A horizontal dry-brush stroke: rough top and bottom, bristle streaks, tapered ends."""
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    u = xx / (w - 1)
    along = np.arange(w) / (w - 1)
    centre = h / 2 + noise(1, w, 180, 41)[0] * 10
    half = (h * 0.4) * np.clip(np.sin(along * math.pi) ** 0.3, 0, 1)
    half = half + noise(1, w, 40, 42)[0] * 4
    top_edge = centre - half + noise(1, w, 5, 43)[0] * 3
    bottom_edge = centre + half + noise(1, w, 5, 44)[0] * 3
    body = smoothstep(-1.5, 1.5, yy - top_edge[None, :]) * smoothstep(-1.5, 1.5, bottom_edge[None, :] - yy)
    streaks = noise(h, 1, 1.3, 45)[:, 0][:, None] * np.ones((1, w))
    dry = smoothstep(0.35, 0.8, streaks + noise(h, w, 60, 46) * 0.6) * smoothstep(0.55, 1.0, u)
    alpha = body * (1 - 0.85 * dry)
    lum = 0.9 + streaks * 0.08
    return rgba(lum, alpha)


def wax_seal(size=256):
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    c = size / 2
    dx, dy = xx - c, yy - c
    r = np.hypot(dx, dy)
    theta = np.arctan2(dy, dx)
    rim = size * 0.44 + np.sin(theta * 7 + 0.6) * 4 + np.sin(theta * 13) * 2.5 + noise(size, size, 10, 51) * 3
    alpha = smoothstep(1.5, -1.5, r - rim)
    # Relief: raised outer lip, sunken ring, flat centre.
    ring_r = size * 0.31
    lip = np.exp(-((r - rim + 8) ** 2) / 30)
    groove = np.exp(-((r - ring_r) ** 2) / 12)
    light = -(dx + dy) / (size * 0.8)  # light from the top left
    lum = 0.62 + lip * 0.25 * (0.6 + light) - groove * 0.25 + noise(size, size, 5, 52) * 0.04
    lum += np.clip(light, -0.3, 0.3) * 0.15
    return rgba(lum, alpha)


def rubber_stamp(w=512, h=192):
    yy, xx = np.mgrid[0:h, 0:w].astype(float)
    edge = np.minimum(np.minimum(xx, w - 1 - xx), np.minimum(yy, h - 1 - yy))
    outer = smoothstep(4, 6, edge) * smoothstep(20, 18, edge)
    inner = smoothstep(26, 28, edge) * smoothstep(32, 30, edge)
    ink = np.maximum(outer, inner)
    grunge = noise(h, w, 3, 61) + noise(h, w, 14, 62) * 0.8
    ink *= 1 - smoothstep(0.55, 0.9, grunge)
    return rgba(np.full((h, w), 1.0), ink)


def scratches(size=512):
    out = np.zeros((size, size))
    r = np.random.default_rng(71)
    for _ in range(90):
        x, y = r.uniform(0, size, 2)
        angle = r.uniform(-0.5, 0.5) + (math.pi / 2 if r.random() < 0.3 else 0)
        length = r.uniform(20, 140)
        strength = r.uniform(0.2, 0.7)
        for s in range(int(length)):
            px = int(x + math.cos(angle) * s) % size
            py = int(y + math.sin(angle) * s + math.sin(s / 9) * 1.5) % size
            out[py, px] = max(out[py, px], strength * (1 - s / length) ** 0.3)
    return rgba(np.ones((size, size)), out)


def ruled(w=64, h=60):
    """One notebook rule at the bottom of a transparent tile (tiled down a page)."""
    img = np.zeros((h, w, 4))
    img[..., :3] = 1
    img[h - 2 :, :, 3] = 0.9
    img[h - 3, :, 3] = 0.25
    return img


def vignette(size=256):
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    d = np.hypot((xx - size / 2) / (size / 2), (yy - size / 2) / (size / 2))
    return rgba(np.zeros((size, size)), smoothstep(0.45, 1.3, d) * 0.92)


# Icons -------------------------------------------------------------------------------------------

CELL = 128
GRID = 8


class Canvas:
    """A 100 x 100 design space drawn into a CELL-sized coverage map (y down)."""

    def __init__(self):
        self.cov = np.zeros((CELL, CELL))
        yy, xx = np.mgrid[0:CELL, 0:CELL].astype(float) + 0.5
        self.x = (xx - 14) / (CELL - 28) * 100
        self.y = (yy - 14) / (CELL - 28) * 100
        self.px = 100 / (CELL - 28)

    def _mix(self, cov, erase=False):
        if erase:
            self.cov = np.minimum(self.cov, 1 - cov)
        else:
            self.cov = np.maximum(self.cov, cov)

    def _seg_dist(self, a, b):
        ax, ay = a
        bx, by = b
        vx, vy = bx - ax, by - ay
        length2 = vx * vx + vy * vy or 1e-9
        t = np.clip(((self.x - ax) * vx + (self.y - ay) * vy) / length2, 0, 1)
        return np.hypot(self.x - (ax + t * vx), self.y - (ay + t * vy))

    def line(self, a, b, w=6, erase=False):
        d = self._seg_dist(a, b)
        self._mix(smoothstep(w / 2 + self.px, w / 2 - self.px, d), erase)

    def poly(self, pts, w=6, closed=False, erase=False):
        seq = list(pts) + ([pts[0]] if closed else [])
        d = np.full(self.x.shape, 1e9)
        for a, b in zip(seq, seq[1:]):
            d = np.minimum(d, self._seg_dist(a, b))
        self._mix(smoothstep(w / 2 + self.px, w / 2 - self.px, d), erase)

    def fill(self, pts, erase=False):
        scale = (CELL - 28) / 100
        shifted = [[(x * scale + 14, y * scale + 14) for x, y in pts + [pts[0]]]]
        self._mix(ttf.fill(shifted, CELL, CELL), erase)

    def circle(self, c, r, w=6, erase=False):
        d = np.abs(np.hypot(self.x - c[0], self.y - c[1]) - r)
        self._mix(smoothstep(w / 2 + self.px, w / 2 - self.px, d), erase)

    def disc(self, c, r, erase=False):
        d = np.hypot(self.x - c[0], self.y - c[1]) - r
        self._mix(smoothstep(self.px, -self.px, d), erase)

    def arc(self, c, r, a0, a1, w=6, erase=False):
        steps = max(8, int(abs(a1 - a0) / 8))
        pts = [
            (c[0] + r * math.cos(math.radians(a0 + (a1 - a0) * i / steps)),
             c[1] + r * math.sin(math.radians(a0 + (a1 - a0) * i / steps)))
            for i in range(steps + 1)
        ]
        self.poly(pts, w, erase=erase)

    def rect(self, x0, y0, x1, y1, w=6, erase=False):
        self.poly([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], w, True, erase)

    def box(self, x0, y0, x1, y1, erase=False):
        self.fill([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], erase)

    def ellipse(self, c, rx, ry, w=None, erase=False):
        pts = [(c[0] + rx * math.cos(a), c[1] + ry * math.sin(a)) for a in np.linspace(0, 2 * math.pi, 48, endpoint=False)]
        if w is None:
            self.fill(pts, erase)
        else:
            self.poly(pts, w, True, erase)


def star(c, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((c[0] + r * math.cos(a), c[1] + r * math.sin(a)))
    return pts


def draw_icons():
    """name -> drawing function. Hand-inked style comes from the inking pass afterwards."""
    icons = {}

    def icon(fn):
        icons[fn.__name__.rstrip("_")] = fn
        return fn

    @icon
    def vote(c):
        c.rect(18, 46, 82, 88, 7)
        c.line((34, 46), (66, 46), 12, erase=True)
        c.poly([(36, 28), (46, 40), (66, 12)], 7)

    @icon
    def task(c):
        c.rect(24, 18, 76, 90, 7)
        c.box(38, 10, 62, 24)
        for y in (44, 58, 72):
            c.line((36, y), (64, y), 5)

    @icon
    def camera(c):
        c.rect(14, 34, 72, 70, 7)
        c.fill([(72, 42), (90, 32), (90, 72), (72, 62)])
        c.circle((36, 52), 9, 6)
        c.line((30, 70), (24, 90), 6)

    @icon
    def fingerprint(c):
        for i, r in enumerate((8, 16, 24, 32, 40)):
            c.arc((50, 58), r, 200 - i * 6, 340 + i * 4, 4.5)
        c.line((50, 58), (50, 70), 4.5)

    @icon
    def phone(c):
        c.rect(32, 10, 68, 90, 7)
        c.line((44, 18), (56, 18), 4)
        c.disc((50, 80), 4)

    @icon
    def forensics(c):
        c.poly([(40, 10), (40, 40), (18, 86), (82, 86), (60, 40), (60, 10)], 7)
        c.line((34, 10), (66, 10), 7)
        c.fill([(28, 66), (72, 66), (80, 84), (20, 84)])

    @icon
    def microscope(c):
        c.box(20, 82, 80, 90)
        c.poly([(34, 82), (34, 70), (50, 56)], 7)
        c.line((44, 18), (64, 58), 12)
        c.line((40, 10), (48, 26), 8)
        c.line((56, 62), (72, 62), 6)

    @icon
    def grimoire(c):
        c.rect(24, 12, 78, 88, 7)
        c.line((34, 12), (34, 88), 7)
        c.line((46, 34), (68, 34), 5)
        c.line((46, 46), (62, 46), 5)
        c.fill([(60, 88), (68, 88), (68, 100), (64, 96), (60, 100)])

    @icon
    def eye(c):
        c.arc((50, 84), 50, 216, 324, 7)
        c.arc((50, 16), 50, 36, 144, 7)
        c.disc((50, 50), 13)
        c.disc((50, 50), 5, erase=True)

    @icon
    def evidence(c):
        c.circle((40, 40), 24, 8)
        c.line((58, 58), (84, 84), 12)

    @icon
    def note(c):
        c.poly([(24, 10), (60, 10), (76, 26), (76, 90), (24, 90)], 7, True)
        c.poly([(60, 10), (60, 26), (76, 26)], 5)
        for y in (44, 58, 72):
            c.line((34, y), (66, y), 5)

    @icon
    def chat(c):
        c.rect(12, 16, 88, 64, 7)
        c.fill([(28, 60), (26, 86), (48, 60)])

    @icon
    def shop(c):
        c.rect(20, 38, 80, 90, 7)
        c.arc((50, 38), 16, 180, 360, 7)

    @icon
    def quests(c):
        c.rect(26, 18, 74, 86, 7)
        c.line((20, 18), (80, 18), 9)
        c.line((20, 86), (80, 86), 9)
        c.poly([(36, 52), (46, 62), (66, 40)], 7)

    @icon
    def profile(c):
        c.circle((50, 34), 16, 7)
        c.arc((50, 92), 32, 200, 340, 7)

    @icon
    def party(c):
        c.circle((36, 36), 12, 6)
        c.arc((36, 84), 24, 200, 340, 6)
        c.circle((66, 30), 12, 6)
        c.arc((66, 78), 24, 210, 330, 6)

    @icon
    def trophy(c):
        c.poly([(28, 14), (28, 40), (50, 60), (72, 40), (72, 14)], 7, True)
        c.arc((24, 28), 10, 90, 270, 5)
        c.arc((76, 28), 10, -90, 90, 5)
        c.line((50, 60), (50, 76), 7)
        c.box(32, 76, 68, 88)

    @icon
    def settings(c):
        c.circle((50, 50), 20, 9)
        for i in range(8):
            a = math.radians(i * 45)
            c.line((50 + 24 * math.cos(a), 50 + 24 * math.sin(a)), (50 + 36 * math.cos(a), 50 + 36 * math.sin(a)), 11)
        c.disc((50, 50), 8, erase=True)

    @icon
    def help_(c):
        c.arc((50, 34), 18, 180, 400, 8)
        c.line((50 + 18 * math.cos(math.radians(40)), 34 + 18 * math.sin(math.radians(40))), (50, 62), 8)
        c.disc((50, 82), 6)

    @icon
    def coin(c):
        c.circle((50, 50), 34, 7)
        c.circle((50, 50), 22, 4)
        c.line((50, 34), (50, 66), 5)

    @icon
    def xp(c):
        c.fill(star((50, 54), 40, 17))

    @icon
    def lock(c):
        c.box(24, 44, 76, 88)
        c.arc((50, 44), 18, 180, 360, 8)
        c.disc((50, 62), 6, erase=True)
        c.line((50, 62), (50, 76), 5, erase=True)

    @icon
    def check(c):
        c.poly([(18, 52), (40, 74), (82, 26)], 12)

    @icon
    def cross(c):
        c.line((22, 22), (78, 78), 12)
        c.line((78, 22), (22, 78), 12)

    @icon
    def clock(c):
        c.circle((50, 50), 36, 7)
        c.line((50, 50), (50, 26), 7)
        c.line((50, 50), (66, 60), 7)

    @icon
    def skull(c):
        c.disc((50, 42), 30)
        c.box(34, 56, 66, 84)
        c.disc((38, 44), 8, erase=True)
        c.disc((62, 44), 8, erase=True)
        c.fill([(50, 54), (45, 64), (55, 64)], erase=True)
        for x in (42, 50, 58):
            c.line((x, 72), (x, 86), 3, erase=True)

    @icon
    def cuffs(c):
        c.circle((30, 62), 16, 7)
        c.circle((70, 62), 16, 7)
        c.poly([(40, 48), (46, 38), (54, 38), (60, 48)], 5)

    @icon
    def candle(c):
        c.box(38, 42, 62, 90)
        c.fill([(50, 8), (60, 26), (56, 36), (44, 36), (40, 26)])
        c.line((50, 36), (50, 44), 3)

    @icon
    def seal(c):
        pts = [(50 + (38 + 3 * math.sin(i * 7 * math.pi / 24)) * math.cos(i * math.pi / 24),
                50 + (38 + 3 * math.sin(i * 7 * math.pi / 24)) * math.sin(i * math.pi / 24)) for i in range(48)]
        c.fill(pts)
        c.circle((50, 50), 24, 4, erase=True)

    @icon
    def ghost(c):
        pts = [(18, 90), (18, 44)]
        pts += [(50 + 32 * math.cos(math.radians(a)), 44 + 32 * math.sin(math.radians(a))) for a in range(180, 361, 15)]
        pts += [(82, 90), (71, 80), (60, 90), (50, 80), (40, 90), (29, 80)]
        c.fill(pts)
        c.ellipse((38, 46), 6, 8, erase=True)
        c.ellipse((62, 46), 6, 8, erase=True)

    @icon
    def play(c):
        c.fill([(28, 16), (28, 84), (84, 50)])

    @icon
    def back(c):
        c.poly([(56, 20), (26, 50), (56, 80)], 10)
        c.line((28, 50), (84, 50), 9)

    @icon
    def menu(c):
        for y in (26, 50, 74):
            c.line((18, y), (82, y), 9)

    @icon
    def hand(c):
        c.fill([(28, 58), (34, 90), (70, 90), (76, 58)])
        for x, top in ((32, 26), (44, 14), (56, 16), (68, 26)):
            c.line((x, 58), (x, top), 10)
        c.line((76, 64), (90, 46), 10)

    @icon
    def agency(c):
        c.poly([(50, 8), (84, 20), (80, 58), (50, 92), (20, 58), (16, 20)], 7, True)
        c.fill(star((50, 48), 18, 8))

    @icon
    def cultist(c):
        c.fill([(50, 6), (80, 40), (86, 94), (14, 94), (20, 40)])
        c.ellipse((50, 50), 13, 17, erase=True)

    @icon
    def butler(c):
        c.fill([(10, 50)] + [(50 + 40 * math.cos(math.radians(a)), 50 + 40 * math.sin(math.radians(a))) for a in range(180, 361, 10)])
        c.line((50, 50), (50, 82), 6)
        c.arc((42, 82), 8, 0, 180, 6)

    @icon
    def key(c):
        c.circle((28, 50), 16, 8)
        c.line((44, 50), (88, 50), 8)
        c.line((72, 50), (72, 66), 7)
        c.line((84, 50), (84, 62), 7)

    @icon
    def bell(c):
        c.fill([(50, 12), (70, 24), (74, 60), (86, 76), (14, 76), (26, 60), (30, 24)])
        c.disc((50, 86), 7)

    @icon
    def heart(c):
        c.disc((34, 38), 18)
        c.disc((66, 38), 18)
        c.fill([(17, 44), (83, 44), (50, 88)])

    @icon
    def podium(c):
        c.box(36, 30, 64, 90)
        c.box(10, 50, 36, 90)
        c.box(64, 62, 90, 90)
        c.line((50, 40), (50, 56), 5, erase=True)

    @icon
    def mail(c):
        c.rect(12, 24, 88, 78, 7)
        c.poly([(14, 26), (50, 54), (86, 26)], 7)

    @icon
    def flag(c):
        c.line((22, 10), (22, 92), 7)
        c.fill([(22, 14), (84, 24), (70, 38), (84, 52), (22, 52)])

    @icon
    def sound(c):
        c.fill([(14, 38), (32, 38), (54, 18), (54, 82), (32, 62), (14, 62)])
        c.arc((54, 50), 16, -50, 50, 6)
        c.arc((54, 50), 30, -50, 50, 6)

    @icon
    def quill(c):
        c.fill([(84, 8), (60, 20), (36, 48), (30, 70), (42, 58), (64, 40)])
        c.line((30, 70), (16, 92), 5)

    @icon
    def hood(c):
        c.fill([(50, 10), (76, 34), (84, 86), (16, 86), (24, 34)])
        c.fill([(50, 30), (64, 46), (60, 70), (40, 70), (36, 46)], erase=True)

    @icon
    def zero(c):
        c.ellipse((50, 50), 26, 38, 10)
        c.line((30, 18), (70, 82), 5)

    @icon
    def dice(c):
        c.rect(16, 16, 84, 84, 7)
        for x, y in ((34, 34), (66, 34), (50, 50), (34, 66), (66, 66)):
            c.disc((x, y), 6)

    @icon
    def streak(c):
        c.fill([(56, 6), (22, 56), (46, 56), (40, 94), (78, 40), (54, 40)])

    @icon
    def rain(c):
        c.arc((36, 44), 16, 150, 300, 7)
        c.arc((60, 36), 22, 200, 360, 7)
        c.line((20, 58), (82, 58), 7)
        c.arc((82, 46), 12, -90, 90, 7)
        for x in (30, 50, 70):
            c.line((x, 70), (x - 6, 88), 5)

    return icons


def ink_icon(cov, seed):
    """Hand-inked edges: a little bleed and a slightly bitten outline."""
    h, w = cov.shape
    wobble = noise(h, w, 3.5, seed) * 0.12 + noise(h, w, 1.5, seed + 1) * 0.06
    alpha = smoothstep(0.35, 0.65, cov + wobble * smoothstep(0.02, 0.5, cov) * smoothstep(0.98, 0.5, cov))
    return rgba(np.full((h, w), 1.0), alpha)


def icon_atlas():
    icons = draw_icons()
    atlas = np.zeros((CELL * GRID, CELL * GRID, 4))
    cells = {}
    for i, (name, fn) in enumerate(icons.items()):
        c = Canvas()
        fn(c)
        x, y = (i % GRID) * CELL, (i // GRID) * CELL
        atlas[y : y + CELL, x : x + CELL] = ink_icon(c.cov, 900 + i)
        cells[name] = (x, y)
    return atlas, cells


def write_icons_luau(cells):
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/ui/textures.py. Do not edit by hand.",
        "-- The hand-inked icons in the UiIcons atlas: name -> top-left pixel of its cell.",
        "",
        "return {",
        '\tatlas = "UiIcons",',
        f"\tcell = {CELL},",
        "\tcells = {",
    ]
    for name, (x, y) in sorted(cells.items()):
        lines.append(f"\t\t{name} = {{ {x}, {y} }},")
    lines += ["\t},", "}"]
    with open(ICONS_LUAU, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return ICONS_LUAU


def preview(textures, icons):
    """A contact sheet: each texture on dark and light, tinted like the game does."""
    sheet = np.zeros((1400, 1400, 4))
    sheet[..., :3] = np.array([30, 28, 34]) / 255
    sheet[..., 3] = 1

    def put(img, x, y, tint=(1, 1, 1), max_w=640):
        h, w = img.shape[:2]
        step = max(1, int(math.ceil(w / max_w)))
        img = img[::step, ::step]
        h, w = img.shape[:2]
        region = sheet[y : y + h, x : x + w]
        a = img[: region.shape[0], : region.shape[1], 3:4]
        region[..., :3] = region[..., :3] * (1 - a) + img[: region.shape[0], : region.shape[1], :3] * np.array(tint) * a

    put(textures["UiPaper"], 20, 20, max_w=300)
    put(textures["UiParchment"], 340, 20, max_w=300)
    put(textures["UiTorn"], 660, 20, (0.85, 0.12, 0.16))
    put(textures["UiSeal"], 940, 20, (0.75, 0.08, 0.1))
    put(textures["UiBrush"], 20, 340, (0.9, 0.9, 0.86))
    put(textures["UiStamp"], 700, 340, (0.85, 0.12, 0.16))
    put(textures["UiScratches"], 1200, 20, max_w=180)
    put(icons, 20, 540, (0.93, 0.9, 0.85), max_w=860)
    os.makedirs(PREVIEWS, exist_ok=True)
    return png.write(os.path.join(PREVIEWS, "ui_textures.png"), sheet)


def main():
    os.makedirs(TEXTURES, exist_ok=True)
    textures = {
        "UiPaper": black_page(),
        "UiParchment": parchment(),
        "UiTorn": torn_card(),
        "UiBrush": brush_stroke(),
        "UiSeal": wax_seal(),
        "UiStamp": rubber_stamp(),
        "UiScratches": scratches(),
        "UiVignette": vignette(),
        "UiRuled": ruled(),
    }
    for name, img in textures.items():
        png.write(os.path.join(TEXTURES, name + ".png"), img)
    atlas, cells = icon_atlas()
    png.write(os.path.join(TEXTURES, "UiIcons.png"), atlas)
    print(f"[ui] {len(textures)} textures, {len(cells)} icons")
    print("[ui]", write_icons_luau(cells))
    print("[ui]", preview(textures, atlas))


if __name__ == "__main__":
    main()
