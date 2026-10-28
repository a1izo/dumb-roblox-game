"""The cutscene sets: small stages the role cutscenes and the win cutscenes play on, away from every map
(the game builds them once, at Venues.SETS). Nobody walks here; only cutscene cameras see them, so each
set is built for its shots: lit by what is in it (a desk lamp, candles, a wall of monitors), dark where
the camera does not look.

    study       Diavolo's study at night: panelled walls, books, a desk under the tall rainy window
    shrine      the Muertos' candlelit shrine: stone, an altar, a figure above it
    ace         Ace's dark room of monitors, a single armchair facing them
    pantry      the Butler's pantry next door: the tea things, one warm lamp
    locker      the Bureau's locker room: steel lockers, a bench, fluorescent light
    flat        the Muerto's bare flat over the city: a lone desk, red neon through the glass behind it
    warehouse   the abandoned warehouse of the finale: steel, crates, moonlight through the roof

and the win cutscenes' rooms (src/shared/Cinema/WinCuts.luau, each cut's room):

    writer      the Coven's Sealed one: a study at night, the tall window running with rain, books, a globe
    office      the Bureau's Sealed one: a detective's office, the city's light through venetian blinds
    hall        the Bureau's Godhood one: a vast stone hall, the chessboard sunk in its marble floor, the moon
    rooftop     the Coven's Godhood one: a tar roof over the city, a water tank, a radio mast, the stair hut

and each paid one told for the other side (the user, 2026-10-27: every shop win cutscene for both Ace and the Coven):

    archive     The Final Page for the Bureau: the evidence archive at dawn, steel shelving, light through high windows
    steps       New World for the Bureau: a courthouse's portico and steps over a square at sunrise, the press below
    den         Case Closed for the Coven: the detective's study turned over at night, a fire in its stone fireplace
    roofrain    Checkmate for the Coven: an old hotel's roof in the rain over a neon street, its tall red sign
"""

from maps.venues.sets import (ace, archive, den, flat, hall, locker, office, roofrain, rooftop, shrine, steps, study,
                               warehouse, writer)
from maps.venues.sets import plan as P

FORMAT = 2

PLAN_LEVELS = [("floor", 3.0)]

VIEWS = [
    ((0.0, 6.0, 9.0), (0.0, 5.0, -9.0), 20),  # the study towards the window
    ((120.0, 6.0, 12.0), (120.0, 6.0, -14.0), 20),  # the shrine's nave to the altar
    ((236.0, 5.5, 7.0), (240.0, 5.0, -9.0), 20),  # Ace's room to the monitors
    ((258.0, 5.0, 5.0), (256.0, 3.0, -5.0), 20),  # the pantry
    ((360.0, 5.5, 6.0), (360.0, 4.0, -6.0), 20),  # the locker room
    ((360.0, 5.0, 66.0), (360.0, 3.5, 56.0), 20),  # the Muerto's flat, the desk against the window
    ((520.0, 12.0, 24.0), (520.0, 3.0, 0.0), 22),  # the warehouse floor
    ((2.4, 5.8, 70.4), (0.25, 2.9, 67.9), 20),  # the writer's room, over the star's shoulder to the window
    ((118.0, 6.2, 72.6), (120.0, 4.0, 62.0), 20),  # the office, to the evidence board
    ((720.0, 2.2, 17.0), (720.0, 3.4, -1.0), 20),  # the hall from behind the star, down the board
    ((903.2, 2.4, 8.5), (900.0, 3.2, -6.0), 20),  # the rooftop to its edge
    ((243.0, 6.0, 77.0), (240.0, 3.5, 64.0), 20),  # the archive, past the star to the table and the windows
    ((483.0, 5.5, 76.0), (480.0, 2.5, 62.5), 20),  # the den, from behind the armchair to the fire
    ((1100.0, -3.0, -30.0), (1100.0, 6.0, 6.0), 20),  # the steps from the square up to the portico
    ((1302.0, 3.2, 7.0), (1300.0, 0.5, -5.0), 20),  # the rain roof, over the crate to the edge
]

CHECKS = {"symmetry": None}


def build(s):
    study.build(s)
    shrine.build(s)
    ace.build(s)
    locker.build(s)
    flat.build(s)
    warehouse.build(s)
    writer.build(s)
    office.build(s)
    hall.build(s)
    rooftop.build(s)
    archive.build(s)
    den.build(s)
    steps.build(s)
    roofrain.build(s)
    s.set_bounds(*P.BOUNDS)
    s.checks = CHECKS
