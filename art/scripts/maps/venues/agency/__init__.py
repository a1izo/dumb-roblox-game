"""Agency HQ: the Agency's 38th and 39th floors of the Kagegaoka Central Tower, at night. 38F is
where the lifts arrive: the lobby under a double-height atrium, the bullpen, the interrogation
suite behind its one-way mirror, the security office. A grand stair climbs the atrium to 39F's
operations deck facing the video wall; round it lie the forensics lab, the evidence lock-up, the
server room, the archive, the canteen and the director's glass office. A fire stair in the core is
the second way between the floors. Out of the glass, Kagegaoka lies 440 studs down.

Built for the map TaskForceHQ: the gameplay spots are placed here with the architecture and
exported with it (src/server/Maps/Scenes/Agency/). The layout is in plan.py.
"""

from maps import catalog, city
from maps.venues.agency import fit, gameplay, lower, outside, shell, upper
from maps.venues.agency import plan as P

FORMAT = 2
MAP_ID = "TaskForceHQ"

# Plan renders: the camera just under each floor's ceiling, looking down.
PLAN_LEVELS = [("38F", 12.6), ("39F", 26.6)]

# Massing renders (--massing): (camera, target, lens); a player-sized figure for scale.
MASSING_VIEWS = [
    ((140.0, 160.0, 160.0), (0.0, 0.0, 0.0), 24),
    ((-160.0, 150.0, -140.0), (0.0, 0.0, 0.0), 24),
]
FIGURES = [(18.0, 0.0, 14.0, 0.0)]

# Night views for --preview: (camera, target, lens), at a player's height.
VIEWS = [
    ((20.0, 5.5, 40.0), (12.0, 18.0, -6.0), 14),  # the lobby from the sign wall, up to the video wall
    ((-10.0, 5.5, 22.0), (-60.0, 4.0, 8.0), 16),  # through the gates into the bullpen
    ((-66.0, 5.5, -52.0), (-80.0, 4.0, -72.0), 16),  # the security office
    ((-54.0, 5.5, -54.0), (-40.0, 5.0, -66.0), 16),  # the observation room, through the mirror
    ((17.0, 19.5, 46.0), (17.0, 20.0, -6.0), 14),  # the operations deck facing the video wall
    ((-70.0, 19.5, -52.0), (-80.0, 17.0, -72.0), 16),  # the forensics lab
    ((40.0, 19.5, -52.0), (80.0, 18.0, -66.0), 16),  # the archive's aisles
    ((66.0, 19.5, 26.0), (100.0, 10.0, 60.0), 16),  # the director's office and the view
    ((0.0, 19.5, 70.0), (-200.0, -300.0, 500.0), 18),  # down to Kagegaoka from the south glass
    ((47.0, 5.5, -10.0), (30.0, 6.0, -24.0), 14),  # the fire stair through its door
    ((60.0, 5.5, 60.0), (100.0, 6.0, 30.0), 16),  # the lounge in the cut corner
    ((0.0, 90.0, 0.0), (0.0, 0.0, 0.1), 12),  # the floor from above (no roof in the preview)
]

# check_v2's targets for this map: the walk (seconds) from each corner of 38F to the opposite
# corner of 39F, the stairs included. Tighter than Tokyo's (30-45 s): two compact floors, so a
# case's 6 to 12 players keep running into each other.
CHECKS = {
    "walk": (18.0, 25.0),
    "corners": [[(-96.0, P.L1, -71.0), (84.0, P.L2, 44.0)], [(96.0, P.L1, -71.0), (-96.0, P.L2, 71.0)],
                [(-96.0, P.L1, 71.0), (96.0, P.L2, -71.0)], [(70.0, P.L1, 50.0), (-96.0, P.L2, -71.0)]],
}


def preview(s):
    """What the game builds itself, for the previews: the station looks, the tip box, the board."""
    cat = catalog.load()
    for st in s_layout(s)["stations"]:
        info = cat.get(st["prop"], {})
        ax, az = info.get("anchor") or (0.0, 0.0)
        dx, dz = fit.turn(st["rot"], -ax, -az)
        s.prop(st["prop"], st["x"] + dx, st["z"] + dz, st["rot"], 1.0, st["y"])


_LAST = {}


def s_layout(s):
    return _LAST.get("layout") or {"stations": []}


def build(s):
    g = city.Ground(s)
    shell.build(s, g)
    lower.build(s, g)
    upper.build(s, g)
    outside.build(s)
    gameplay.build(s)
    g.finish()
    s.set_bounds(*P.BOUNDS)
    s.checks = CHECKS
    s.far_chunk = (150.0, 1400.0)
    _LAST["layout"] = s.layout
