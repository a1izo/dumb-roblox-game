"""The apple loading screen's hand (UI/AppleLoading): its contract with the game and its shape, in your sketch's px.
The hand itself is a death god's hand in the spirit of Ryuk's (drawn for this game, not traced from any art), modelled
and rendered in 3D by apple_hand_3d.py (2026-11-06, at your word "make ryuks hand more detailed and high quality
textured and rendered"; the painted hand of 2026-11-05 before it was flat airbrushed grey).

It keeps the first hand's place and movement exactly: the same picture over your sketch (art/refs/ui/apple_sketch.png),
the apple held at the same spot, the thumb's root, hinge and square where they were, so UI/AppleLoading and the apple's
sheets are untouched. Three pictures, so the game closes the thumb smoothly (it turns the thumb's picture about its
root) and the apple lands between them:

    AppleHandBack   the hand without the apple, under it (seen where no apple is: the cup of the palm while it waits)
    AppleHandFront  the hand round the apple, cut away where the apple lies in front of it
    AppleThumb      the thumb alone on a square whose middle is its root, over the apple with the shade it casts

Coordinates are your sketch's px (1681 x 936), laid on the hand's picture (1024 x 736) by H.
"""

import math

import numpy as np

import paint as pt

HAND_BOX = (400, 545, 1010, 983)  # the sketch's px the hand's picture covers (x0, y0, x1, y1)
HAND_SCALE = 1024 / 610
HW, HH = 1024, 736

# Measured on your sketch: the apple in the hand (its middle, half width and half height).
HELD = (845.0, 652.0, 105.0, 91.0)

# The thumb, root to tip, along its middle (the first hand's line from its hinge on, so its square, which reaches to
# its tip, and its hinge stay where they were), and its width there: broad at its root, thin along its bones, swelling
# at its joint. It turns where it leaves the hand's edge, over the hand's own stump of it.
THUMB_AXIS = [(722, 704), (735, 698), (757, 686), (777, 675), (797, 664), (817, 654), (835, 647), (849, 642)]
THUMB_WIDTHS = [38, 33, 27, 24, 28.5, 22, 19.5, 18]
THUMB_JOINT = (799.0, 663.0)  # its knuckle, where its two bones meet
THUMB_PIVOT = (738.0, 694.0)
OPEN_THUMB = -38.0  # degrees the thumb stands up while the hand waits (the game turns it down as the apple lands)


def round_apple(degrees, off):
    """A point round the held apple: `degrees` round from its right (down positive), `off` sketch px out from it."""
    a = math.radians(degrees)
    return (HELD[0] + (HELD[2] + off) * math.cos(a), HELD[1] + (HELD[3] + off) * math.sin(a))


# The four fingers round the apple's right side, back to front (little, ring, middle, index): the knuckle each grows
# from at the hand's end, then its two middle joints and its tip, wrapped round the apple a little further out the
# further back the finger is, so each shows past the one in front; how thick it is at the knuckle, along its bones and
# at its joints; and its claw (length, and how far it hooks in toward the apple, degrees).
FINGERS = [
    {"joints": [(906, 800), round_apple(50, 24), round_apple(28, 30), round_apple(12, 28)], "scale": 0.82,
     "claw": (26, 34)},
    {"joints": [(915, 782), round_apple(40, 12), round_apple(14, 14), round_apple(-4, 8)], "scale": 0.9,
     "claw": (30, 36)},
    {"joints": [(914, 762), round_apple(30, -4), round_apple(2, -6), round_apple(-20, -12)], "scale": 0.96,
     "claw": (33, 38)},
    {"joints": [(900, 744), round_apple(20, -22), round_apple(-14, -26), round_apple(-40, -30)], "scale": 1.0,
     "claw": (36, 40)},
]
# (sketch px across: the knuckle, the bone, the joint, the bone, the joint, the last bone, the tip)
FINGER_WIDTHS = [33, 23.5, 29.5, 21, 25, 18.5, 17]

WRIST =(707.0, 830.0)  # the wrist's middle
ARM_WAY = np.array([145.0, -160.0]) / math.hypot(145.0, -160.0)  # up the forearm toward the hand
# The band round the wrist: where along the forearm it lies (sketch px from the wrist toward the elbow).
BAND = (-14.0, -46.0)
WRIST_BONE = (742.0, 850.0)  # the knob of bone at the wrist's underside

LIGHT = np.array([-0.72, -0.58, -0.38])  # toward the light: up, left and toward us (x right, y down, z away)
LIGHT = LIGHT / np.linalg.norm(LIGHT)


def H(x, y):
    """Sketch px to the hand picture's px."""
    return ((x - HAND_BOX[0]) * HAND_SCALE, (y - HAND_BOX[1]) * HAND_SCALE)


def hgrid():
    """The sketch px at every pixel of the hand's picture (x, y)."""
    ys, xs = pt.grid(HH, HW)
    return xs / HAND_SCALE + HAND_BOX[0], ys / HAND_SCALE + HAND_BOX[1]


def spline(points, n=10):
    """A smooth curve through `points` (Catmull-Rom), n points from each to the next."""
    pts = np.asarray(points, np.float64)
    padded = np.vstack([pts[0] * 2 - pts[1], pts, pts[-1] * 2 - pts[-2]])
    out = []
    for i in range(1, len(padded) - 2):
        p0, p1, p2, p3 = padded[i - 1], padded[i], padded[i + 1], padded[i + 2]
        for t in np.linspace(0, 1, n, endpoint=False):
            out.append(0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t
                              + (3 * p1 - p0 - 3 * p2 + p3) * t * t * t))
    out.append(pts[-1])
    return [tuple(p) for p in out]


def finger_axis(finger):
    """A finger's middle line through its joints, with a point half way along each bone (so the widths swell at the
    joints and run thin between), and the widths there."""
    j = finger["joints"]
    pts = []
    for a, b in zip(j[:-1], j[1:]):
        pts += [a, ((a[0] + b[0]) / 2, (a[1] + b[1]) / 2)]
    pts.append(j[-1])
    return pts, [w * finger["scale"] for w in FINGER_WIDTHS]


def thumb_square():
    """The square the thumb's picture covers: its middle the thumb's root (picture px), its half side."""
    px, py = H(*THUMB_PIVOT)
    reach = 0.0
    for x, y in THUMB_AXIS:
        hx, hy = H(x, y)
        reach = max(reach, math.hypot(hx - px, hy - py))
    half = int(math.ceil(reach + 40 * HAND_SCALE))
    return px, py, half


def thumb_at(square, degrees):
    """The thumb's square turned `degrees` about its middle (screen y down: negative stands it up), bilinear: what the
    game shows."""
    size = square.shape[0]
    c = size / 2
    a = math.radians(-degrees)
    ys, xs = pt.grid(size, size)
    sx = np.clip(c + (xs - c) * math.cos(a) - (ys - c) * math.sin(a) - 0.5, 0, size - 1.001)
    sy = np.clip(c + (xs - c) * math.sin(a) + (ys - c) * math.cos(a) - 0.5, 0, size - 1.001)
    x0, y0 = sx.astype(int), sy.astype(int)
    fx, fy = (sx - x0)[..., None], (sy - y0)[..., None]
    top = square[y0, x0] * (1 - fx) + square[y0, x0 + 1] * fx
    bottom = square[y0 + 1, x0] * (1 - fx) + square[y0 + 1, x0 + 1] * fx
    return (top * (1 - fy) + bottom * fy).astype(np.float32)
