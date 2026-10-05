"""Tokyo's mood and what shelters from its rain: cold mist pooling in the alleys (the river's own mist
is in river.py), crows perched where crows are (on the wires between the power poles, the lantern
posts and the bus shelter), and the invisible cover boxes the client's rain stops under that the
buildings' own roofs do not give: the cherry trees' and plaza trees' crowns (they thin the rain),
the bus shelter's roof. Door canopies and awnings add theirs in buildings.py.

Every crow stands where it is put by hand, from the spots below."""

import math

from maps import geo2d as g2
from maps.venues.tokyo import dressing as D
from maps.venues.tokyo import plan as P
from maps.venues.tokyo.edges import facing

# prop: (size of the cover box, its centre height, how much of the rain it stops)
CROWNS = {
    "TreeSakura": ((9.0, 4.5, 8.5), 10.8, 0.5),
    "Tree": ((6.4, 5.0, 7.0), 9.2, 0.5),
}
SHELTERS = {"BusShelter": ((12.4, 0.6, 4.4), 8.3, 1.0)}

# Alleys and lanes where the mist pools (the streets of plan.STREETS).
MISTY = ("y_a", "y_b", "y_c", "y_cross", "y_dead", "lane_e", "ura")


def covers(s):
    for key, x, y, z, rot, scale, *_ in list(s.props):
        if key in CROWNS:
            size, height, amount = CROWNS[key]
            s.cover((x, y + height * scale, z), (size[0] * scale, size[1], size[2] * scale), 0, amount)  # a crown is round enough
        elif key in SHELTERS:
            size, height, amount = SHELTERS[key]
            s.cover((x, y + height, z), size, rot, amount)


def alley_mist(s):
    """Mist lying along each alley, one box per straight stretch."""
    for name in MISTY:
        pts = P.STREETS[name]["points"]
        width = P.STREETS[name]["road"]
        for a, b in zip(pts, pts[1:]):
            length = math.dist(a, b)
            if length < 6.0:
                continue
            d = ((b[0] - a[0]) / length, (b[1] - a[1]) / length)
            s.emitter("rivermist", ((a[0] + b[0]) / 2, 0.5, (a[1] + b[1]) / 2), g2.rot_of(d),
                      (length, 2.2, width + 1.0))


def crows(s):
    # On the bus shelter's roof: the two ends, their backs to the plaza's wind.
    s.prop("Crow", -93.6, -87.2, 150, 1.0, 8.6)
    s.prop("Crow", -87.2, -86.8, 205, 1.0, 8.6)
    # On the wires of the east street's power line: between the poles, on the lower wire's low point.
    us = [56.0, 88.0, 120.0, 152.0, 186.0, 220.0]
    kerbs = [D.kerb("east", -1, u, 0.9) for u in us]
    for k, side in ((0, 1), (1, -1), (2, 1), (3, 1), (4, -1)):
        (pa, da, into), (pb, _, _) = kerbs[k], kerbs[k + 1]
        mid = ((pa[0] + pb[0]) / 2 + into[0] * 2.0 * side, (pa[1] + pb[1]) / 2 + into[1] * 2.0 * side)
        s.prop("Crow", mid[0], mid[1], facing(da[0], da[1]) + (0 if k % 2 else 180), 1.0, 21.0 - 1.2 - 0.05)
    # On the lantern posts along the south promenade's west end: one on each of two posts.
    for x in (-156.5, -71.5):
        (cx, cz), d = P.river_frame(x)
        n = g2.normal_left(d)
        off = P.PROM_S[0] + 1.0
        s.prop("Crow", cx + n[0] * off, cz + n[1] * off, facing(n[0], n[1]) + 35, 1.0, 10.2)


def build(s):
    crows(s)
    alley_mist(s)
    covers(s)
