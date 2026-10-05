"""The Agency's mood: the tower stands over a sea of cloud (the city's lights showing through it far
below the windows), dust motes hang in the light of the tall rooms, a faint cold haze lies in the
atrium, and now and then a tired fitting flickers (the client does that for the lights marked
flicker in lower.py and upper.py, rarely, and never in a way that touches a letter's visibility: it
is a local light going dark for half a second).

Nothing here is solid and nothing needs the rain's cover: the tower is all inside."""

from maps.venues.agency import plan as P

# Dust motes: (centre x, y, z), size.
DUST = [
    ((17.0, 14.0, 19.0), (40.0, 26.0, 28.0)),  # the atrium over the lobby
    ((-58.0, 7.0, 8.0), (56.0, 10.0, 60.0)),  # the bullpen
    ((17.0, P.L2 + 7.0, 40.0), (60.0, 12.0, 40.0)),  # the operations deck
    ((20.0, 7.0, 58.0), (56.0, 10.0, 28.0)),  # the lounge
]


def cloud_sea(s):
    """A huge flat bank of cloud well below the glass, between the windows and the city."""
    s.emitter("cloudsea", (0.0, -165.0, 0.0), 0, (900.0, 50.0, 800.0))


def atrium_haze(s):
    s.emitter("mist", (17.0, 0.7, 19.0), 0, (38.0, 2.0, 28.0))


def dust(s):
    for centre, size in DUST:
        s.emitter("dust", centre, 0, size)


def build(s):
    cloud_sea(s)
    atrium_haze(s)
    dust(s)
