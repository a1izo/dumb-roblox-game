"""The cutscene sets: small stages the role cutscenes and the win cutscenes play on, away from every map
(the game builds them once, at Venues.SETS). Nobody walks here; only cutscene cameras see them, so each
set is built for its shots: lit by what is in it (a desk lamp, candles, a wall of monitors), dark where
the camera does not look.

    study       Diavolo's study at night: panelled walls, books, a desk under the tall rainy window
    shrine      the Muertos' candlelit shrine: stone, an altar, a figure above it
    ace         Ace's dark room of monitors, a single armchair facing them
    pantry      the Butler's pantry next door: the tea things, one warm lamp
    locker      the Bureau's locker room: steel lockers, a bench, fluorescent light
    warehouse   the abandoned warehouse of the finale: steel, crates, moonlight through the roof
"""

from maps.venues.sets import ace, locker, shrine, study, warehouse
from maps.venues.sets import plan as P

FORMAT = 2

PLAN_LEVELS = [("floor", 3.0)]

VIEWS = [
    ((0.0, 6.0, 9.0), (0.0, 5.0, -9.0), 20),  # the study towards the window
    ((120.0, 6.0, 12.0), (120.0, 6.0, -14.0), 20),  # the shrine's nave to the altar
    ((236.0, 5.5, 7.0), (240.0, 5.0, -9.0), 20),  # Ace's room to the monitors
    ((258.0, 5.0, 5.0), (256.0, 3.0, -5.0), 20),  # the pantry
    ((360.0, 5.5, 6.0), (360.0, 4.0, -6.0), 20),  # the locker room
    ((520.0, 12.0, 24.0), (520.0, 3.0, 0.0), 22),  # the warehouse floor
]

CHECKS = {"symmetry": None}


def build(s):
    study.build(s)
    shrine.build(s)
    ace.build(s)
    locker.build(s)
    warehouse.build(s)
    s.set_bounds(*P.BOUNDS)
    s.checks = CHECKS
