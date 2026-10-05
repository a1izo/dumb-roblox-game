"""The campus's mood and what shelters from its snow: a cold blue-grey ground mist lying low over the
avenue, the forecourt, the pond hollow and the lawns (thinning with height, so the clock tower's top
floats above it), warm light on the clock tower's faces so they glow through it, a black feather now
and then falling through the snow, and the invisible cover boxes the client's snow stops under that
the buildings' roofs do not give: the ginkgos' bare crowns and the pines' (they thin the snow), the
check-in tents, the red gate's roof and the evidence board's kiosk."""

from maps.venues.campus import plan as P

# prop: (size of the cover box, its centre height, how much of the snow it stops)
CROWNS = {
    "GinkgoBare": ((13.0, 9.0, 13.0), 20.0, 0.3),
    "PineYukizuri": ((11.0, 9.0, 10.0), 9.5, 0.55),
    "EventTent": ((10.6, 3.0, 10.6), 9.2, 1.0),
}

# Patches of ground mist: centre (x, z), size across x and z, height of the box's floor (the ground there).
MIST = [
    (-20.0, -12.0, 24.0, 44.0, 0.0),  # the avenue, north half
    (-20.0, 35.0, 24.0, 50.0, 0.0),  # the avenue, south half
    (20.0, 97.0, 56.0, 26.0, 0.0),  # the gate plaza
    (-20.0, -50.0, 90.0, 22.0, 0.0),  # the forecourt
    (-100.0, 4.0, 80.0, 60.0, P.HOLLOW_Y),  # the pond hollow
    (-90.0, 51.0, 110.0, 12.0, 0.0),  # the south path
    (60.0, 28.0, 160.0, 12.0, 0.0),  # the east cross path
    (90.0, -34.0, 110.0, 12.0, 0.0),  # the library's path
    (104.0, -4.0, 80.0, 60.0, 0.0),  # round the tennis court
    (42.0, 60.0, 12.0, 50.0, 0.0),  # the science building's west lane
]

# Where the clock tower's four faces are lit from (just out from each face, at the dial's height).
TOWER_GLOW = [(-20.0, -42.0), (-35.5, -55.0), (-4.5, -55.0)]


def covers(s):
    for key, x, y, z, rot, scale, *_ in list(s.props):
        if key in CROWNS:
            size, height, amount = CROWNS[key]
            s.cover((x, y + height * scale, z), (size[0] * scale, size[1], size[2] * scale), 0, amount)  # a crown is round enough
    # The red gate's roof over the passage, and the kiosk's over the evidence board.
    gx0, gz0, gx1, gz1 = P.GATE
    s.cover(((gx0 + gx1) / 2, 14.5, (gz0 + gz1) / 2), (gx1 - gx0 + 4.0, 3.0, gz1 - gz0 + 5.0), 0, 1.0)
    s.cover((-49.0, 10.0, -44.4), (15.6, 1.4, 2.6), 0, 1.0)


def mist(s):
    for x, z, w, d, y in MIST:
        s.emitter("mist", (x, y + 0.7, z), 0, (w, 2.5, d))


def tower(s):
    """Warm light on the clock tower's faces, so they glow through the mist."""
    for x, z in TOWER_GLOW:
        s.light("point", (x, P.CLOCK_Y, z), (255, 196, 128), 40, 1.3)


def feathers(s):
    # One drift over the forecourt and the tower, one down the avenue (they fall about 15 studs).
    s.emitter("feathers", (-20.0, 16.0, -42.0), 0, (70.0, 2.0, 34.0))
    s.emitter("feathers", (-20.0, 16.0, 40.0), 0, (30.0, 2.0, 90.0))


def build(s):
    mist(s)
    tower(s)
    feathers(s)
    covers(s)
