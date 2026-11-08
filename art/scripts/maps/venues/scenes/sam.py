"""Let's dance! (art/refs/deaths/sam.md): open desert hills at dusk. A sun-baked slope where the two stand, boulders
near and far, the hills rolling up all round, and a broken rocky ridge along the horizon behind the victim (+Z, what
the over-the-shoulder shots look at) curling round to the left; low mesas far off the other way. The sky is the
game's (SkySceneDusk): no walls anywhere.

Scene space: the victim at the origin facing -Z, the killer at (0, 0, -5) facing them.
"""

import math
import random

from maps.venues.scenes import parts
from maps.venues.scenes import plan as P

OX, OZ = P.SAM


def smooth(a, b, x):
    t = min(1.0, max(0.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)


def ground_h(x, z):
    """Near the two: a gentle slope falling to -X; then rolling hills rising to 30-50 studs far off."""
    r = math.hypot(x, z)
    slope = 0.06 * x * (1 - smooth(20, 60, r))
    roll = 1.4 * parts.noise2(x, z, seed=31, octaves=3, scale=38.0) * smooth(8, 30, r)
    hills = smooth(50, 260, r) * (26.0 + 16.0 * parts.noise2(x, z, seed=32, octaves=3, scale=150.0))
    return slope + roll + hills - (0.06 * 0)


def build(s):
    def h(wx, wz):
        return ground_h(wx - OX, wz - OZ)

    def step(wx, wz):
        d = max(abs(wx - OX), abs(wz - OZ))
        return 2.0 if d < 60 else (5.0 if d < 160 else 12.0)

    parts.heightfield(s, "DesertGround", OX - 380, OZ - 380, OX + 380, OZ + 380, step, h)
    r = random.Random(7)
    # boulders: a few big ones close (the stagger passes them), more scattered out over the hills
    near = ((-11, 7, 4.0), (8, -14, 3.0), (-16, -12, 5.0), (-24, 24, 6.5), (28, -26, 4.5), (18, 26, 3.4))
    for k, (x, z, size) in enumerate(near):
        wx, wz = OX + x, OZ + z
        parts.rock(s, "DesertRock", (wx, h(wx, wz), wz), (size * 1.3, size * 0.75, size * 1.05), seed=200 + k,
                   rot=r.uniform(0, 360), rough=0.32, segs=(14, 9), sink=0.22, flat_top=0.12)
        for j in range(3):  # (rubble at its foot)
            a = r.uniform(0, math.tau)
            px, pz = wx + math.cos(a) * size * 1.4, wz + math.sin(a) * size * 1.2
            q = r.uniform(0.3, 0.7)
            parts.rock(s, "DesertRock", (px, h(px, pz), pz), (q * 1.2, q * 0.6, q), seed=900 + k * 3 + j,
                       rot=r.uniform(0, 360), rough=0.3, segs=(8, 5), sink=0.3)
    for k in range(30):
        a = r.uniform(0, math.tau)
        d = r.uniform(60, 260)
        x, z = math.cos(a) * d, math.sin(a) * d
        size = r.uniform(2.5, 9.0) * (1 + d / 260)
        wx, wz = OX + x, OZ + z
        parts.rock(s, "DesertRock", (wx, h(wx, wz), wz), (size * 1.3, size * 0.7, size), seed=300 + k,
                   rot=r.uniform(0, 360), rough=0.3, segs=(10, 6), sink=0.25, flat_top=0.15)
    # the rocky ridge: great broken masses along the horizon behind the victim, curling round to the left (+X)
    for k in range(26):
        a = math.radians(-60 + k * 7.5 + r.uniform(-2, 2))
        d = r.uniform(210, 290)
        x, z = math.sin(a) * d, math.cos(a) * d
        wx, wz = OX + x, OZ + z
        size = r.uniform(26, 46)
        parts.rock(s, "DesertRock", (wx, h(wx, wz) - 4, wz), (size * 1.1, size * r.uniform(0.6, 1.0), size * 0.8),
                   seed=500 + k, rot=r.uniform(0, 360), rough=0.38, segs=(12, 7), sink=0.15, flat_top=0.2)
    # low mesas far off the other way (the side wides see them past the killer)
    for k in range(9):
        a = math.radians(140 + k * 14 + r.uniform(-3, 3))
        d = r.uniform(300, 360)
        x, z = math.sin(a) * d, math.cos(a) * d
        wx, wz = OX + x, OZ + z
        size = r.uniform(30, 50)
        parts.rock(s, "DesertRock", (wx, h(wx, wz) - 3, wz), (size * 1.6, size * 0.55, size), seed=700 + k,
                   rot=r.uniform(0, 360), rough=0.25, segs=(12, 6), sink=0.1, flat_top=0.45)
