"""The UI's textures and icons, drawn with numpy (run with Blender's Python; plain `python` is not installed):

    "C:\\Program Files\\Blender Foundation\\Blender 5.2\\5.2\\python\\bin\\python.exe" art/scripts/ui/textures.py

It writes the textures, the icon atlas, src/shared/UI/Icons.luau and a preview sheet.

Everything is white with alpha (the game tints it). Files go to art/export/textures/<Name>.png and ride
into Roblox on carrier quads in DeathsGambitModels_Core.fbx (build_props.py). The UI works without them
(plain rectangles instead of clipped corners).

The "Notch" shapes are 9-slice images (Rect centre noted next to each): a rectangle with clipped corners.
  UiNotch         panels, cards, toasts: bottom-right corner cut 14 px.        slice 32..224, scale 1
  UiNotchBtn      buttons: top-right corner cut 12 px.                          slice 32..224, scale 1
  UiNotchBtnLine  the 1 px outline of a UiNotchBtn (ghost buttons).             slice 32..224, scale 1
  UiNotchWin      windows: top-right and bottom-left corners cut 18 px.         slice 48..208, scale 0.5
  UiNotchWinLine  the 1 px outline of a UiNotchWin.                             slice 48..208, scale 0.5
Windows are drawn at twice their size (cut 36, outline 2) and shown with SliceScale 0.5.
Tiles: UiScan (scanlines, 3 px period), UiGrain (film grain). UiVignette darkens the screen edges.
Effects for the death and glitch moments: FxShard, FxStatic, FxChalk (a body outline), FxTear.
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


def rgba(lum, alpha):
    lum = np.clip(lum, 0, 1)
    return np.stack([lum, lum, lum, np.clip(alpha, 0, 1)], axis=2)


# Textures ----------------------------------------------------------------------------------------


def cut_polygon(size, margin, cuts):
    """The square [margin, size - margin]^2 with clipped corners; cuts = (top-left, top-right,
    bottom-right, bottom-left) leg lengths in px (0 = square corner), clockwise from the top left."""
    a, b = margin, size - margin
    tl, tr, br, bl = cuts
    pts = []
    pts += [(a, a + tl), (a + tl, a)] if tl else [(a, a)]
    pts += [(b - tr, a), (b, a + tr)] if tr else [(b, a)]
    pts += [(b, b - br), (b - br, b)] if br else [(b, b)]
    pts += [(a + bl, b), (a, b - bl)] if bl else [(a, b)]
    return pts


def notch(size, cuts, ring=0.0):
    """A white clipped-corner rectangle as an RGBA image; with `ring` > 0 only its outline of that width.
    The diagonal of an inset outline moves in by `ring` perpendicular to itself, so its legs shrink."""
    outer = ttf.fill([cut_polygon(size, 0, cuts) + [cut_polygon(size, 0, cuts)[0]]], size, size, ss=6)
    if ring <= 0:
        return rgba(np.ones((size, size)), outer)
    shrink = ring * (2 - math.sqrt(2))
    inner_cuts = tuple(max(c - shrink, 0) if c else 0 for c in cuts)
    poly = cut_polygon(size, ring, inner_cuts)
    inner = ttf.fill([poly + [poly[0]]], size, size, ss=6)
    return rgba(np.ones((size, size)), np.clip(outer - inner, 0, 1))


def scanlines(size=12, period=3):
    """White lines one pixel thick every `period` pixels (tiled over a panel at low opacity)."""
    alpha = np.zeros((size, size))
    alpha[::period, :] = 1.0
    return rgba(np.ones((size, size)), alpha)


def grain(size=256):
    """Film grain that tiles: white specks of random strength."""
    r = np.random.default_rng(31)
    return rgba(np.ones((size, size)), r.random((size, size)) ** 2.2)


def vignette(size=256):
    yy, xx = np.mgrid[0:size, 0:size].astype(float)
    d = np.hypot((xx - size / 2) / (size / 2), (yy - size / 2) / (size / 2))
    return rgba(np.zeros((size, size)), smoothstep(0.45, 1.3, d) * 0.92)


def shard(size=256):
    """A sharp sliver of glass, bright at the tip and fading toward the base (a particle and burst sprite)."""
    pts = [(128, 4), (170, 120), (150, 252), (118, 200), (92, 118)]
    cov = ttf.fill([pts + [pts[0]]], size, size, ss=6)
    yy = np.mgrid[0:size, 0:size][0] / size
    fade = 0.45 + 0.55 * (1 - yy)
    return rgba(np.ones((size, size)), cov * fade)


def static(size=256):
    """TV static that tiles: grey grain with a few brighter horizontal tears (a dissolve and glitch particle)."""
    r = np.random.default_rng(41)
    lum = r.random((size, size)) ** 1.5
    alpha = np.full((size, size), 0.9)
    for _ in range(9):
        y = int(r.integers(0, size))
        h = int(r.integers(1, 4))
        lum[y : y + h, :] = 1.0
        alpha[y : y + h, :] = 1.0
    return rgba(lum, alpha)


def chalk(size=512):
    """A chalk outline of a body lying with arms and legs apart, seen from above (a floor decal)."""
    body = [
        (41, 26), (22, 30), (10, 44), (6, 60), (15, 62), (22, 48), (35, 44), (36, 62), (32, 92), (32, 98),
        (44, 98), (47, 70), (53, 70), (56, 98), (68, 98), (68, 92), (64, 62), (65, 44), (78, 48), (85, 62),
        (94, 60), (90, 44), (78, 30), (59, 26), (41, 26),
    ]  # fmt: skip
    yy, xx = np.mgrid[0:size, 0:size].astype(float) + 0.5
    x, y = xx / size * 100, yy / size * 100
    dist = np.full((size, size), 1e9)
    for (ax, ay), (bx, by) in zip(body, body[1:]):
        vx, vy = bx - ax, by - ay
        t = np.clip(((x - ax) * vx + (y - ay) * vy) / (vx * vx + vy * vy), 0, 1)
        dist = np.minimum(dist, np.hypot(x - (ax + t * vx), y - (ay + t * vy)))
    dist = np.minimum(dist, np.abs(np.hypot(x - 50, y - 13) - 8.5))  # the head
    width = 1.5  # half the stroke in design units
    px = 100 / size
    stroke = smoothstep(width + 2 * px, width - 2 * px, dist)
    rough = noise(size, size, 5, 51) * 0.5 + noise(size, size, 1.6, 52) * 0.5
    gaps = smoothstep(-0.62, -0.5, rough)  # chalk skips here and there
    return rgba(np.ones((size, size)), stroke * gaps * (0.78 + 0.22 * rough))


def tear(w=512, h=64):
    """Horizontal glitch bars of different lengths, for the videotape tear overlay."""
    r = np.random.default_rng(61)
    alpha = np.zeros((h, w))
    for _ in range(8):
        y = int(r.integers(0, h - 8))
        bar = int(r.integers(2, 8))
        x0 = int(r.integers(0, w // 2))
        x1 = int(min(w, x0 + r.integers(w // 6, w)))
        alpha[y : y + bar, x0:x1] = r.uniform(0.55, 1.0)
    for _ in range(14):
        y = int(r.integers(0, h))
        x0 = int(r.integers(0, w - 40))
        alpha[y, x0 : x0 + int(r.integers(30, 200))] = 1.0
    return rgba(np.ones((h, w)), alpha)


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


def clean_icon(cov):
    """Icons keep their drawn, antialiased edge: white with the coverage as alpha."""
    return rgba(np.ones(cov.shape), cov)


def icon_atlas():
    icons = draw_icons()
    atlas = np.zeros((CELL * GRID, CELL * GRID, 4))
    cells = {}
    for i, (name, fn) in enumerate(icons.items()):
        c = Canvas()
        fn(c)
        x, y = (i % GRID) * CELL, (i // GRID) * CELL
        atlas[y : y + CELL, x : x + CELL] = clean_icon(c.cov)
        cells[name] = (x, y)
    return atlas, cells


def write_icons_luau(cells):
    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/ui/textures.py. Do not edit by hand.",
        "-- The line icons in the UiIcons atlas: name -> top-left pixel of its cell.",
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
    """A contact sheet: every texture white-on-dark, as the game tints them."""
    sheet = np.zeros((1500, 1400, 4))
    sheet[..., :3] = np.array([23, 26, 32]) / 255
    sheet[..., 3] = 1

    def put(img, x, y, tint=(0.96, 0.96, 0.97), max_w=300):
        step = max(1, int(math.ceil(img.shape[1] / max_w)))
        img = img[::step, ::step]
        h, w = img.shape[:2]
        region = sheet[y : y + h, x : x + w]
        a = img[: region.shape[0], : region.shape[1], 3:4]
        region[..., :3] = region[..., :3] * (1 - a) + img[: region.shape[0], : region.shape[1], :3] * np.array(tint) * a

    put(textures["UiNotch"], 20, 20)
    put(textures["UiNotchBtn"], 340, 20)
    put(textures["UiNotchBtnLine"], 660, 20)
    put(textures["UiNotchWin"], 20, 340)
    put(textures["UiNotchWinLine"], 340, 340)
    put(np.tile(textures["UiScan"], (20, 20, 1)), 660, 340)
    put(np.tile(textures["UiGrain"], (1, 1, 1)), 980, 340, max_w=256)
    put(textures["FxShard"], 20, 660, max_w=200)
    put(textures["FxStatic"], 240, 660, max_w=200)
    put(textures["FxChalk"], 460, 660, max_w=300)
    put(textures["FxTear"], 780, 660, max_w=400)
    put(icons, 20, 980, max_w=1000)
    os.makedirs(PREVIEWS, exist_ok=True)
    return png.write(os.path.join(PREVIEWS, "ui_textures.png"), sheet)


def main():
    os.makedirs(TEXTURES, exist_ok=True)
    textures = {
        "UiNotch": notch(256, (0, 0, 14, 0)),
        "UiNotchBtn": notch(256, (0, 12, 0, 0)),
        "UiNotchBtnLine": notch(256, (0, 12, 0, 0), ring=1),
        "UiNotchWin": notch(256, (0, 36, 0, 36)),
        "UiNotchWinLine": notch(256, (0, 36, 0, 36), ring=2),
        "UiScan": scanlines(),
        "UiGrain": grain(),
        "UiVignette": vignette(),
        "FxShard": shard(),
        "FxStatic": static(),
        "FxChalk": chalk(),
        "FxTear": tear(),
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
