"""The meeting room: the Agency's war room, where every case's survivors meet round one table under
one hard light, and Zero speaks from the screen. 60 x 60 studs, 18 high (the same room as before,
rebuilt): walnut panelling under oxblood damask, a chevron parquet with a round red carpet, a
coffered ceiling with the spotlight in its rose and a brass halo, the Specters' mezzanine round
the walls, the case wall of photographs and red string round the evidence board, bookcases, the
sideboard and a clock just past midnight, and through half-open blinds the city at night far
below, rain on the glass.

The game builds the screen, the board, the standing places and the Specters' spots at the anchors
this scene exports (src/server/Maps/MeetingRoom.luau). The numbers are in plan.py."""

from maps.venues.meeting import furnish, outside, room
from maps.venues.meeting import plan as P

FORMAT = 2

PLAN_LEVELS = [("floor", 11.0), ("mezzanine", 17.0)]

MASSING_VIEWS = [((70.0, 60.0, 70.0), (0.0, 6.0, 0.0), 24)]
FIGURES = [(0.0, 0.0, 17.0, 180.0)]

VIEWS = [
    ((24.0, 13.0, 25.0), (-6.0, 3.0, -6.0), 18),  # over the table from the mezzanine's corner
    ((0.0, 5.5, 25.0), (0.0, 8.0, -29.0), 20),  # Zero's screen from the south standing places
    ((-25.0, 14.0, -23.0), (8.0, 2.0, 8.0), 18),  # the room from the north-west
    ((-10.0, 5.5, 0.0), (29.0, 7.0, 0.0), 18),  # the case wall and the board
    ((10.0, 5.5, 0.0), (-29.0, 6.0, 0.0), 18),  # the west wall: bookcases, sideboard, clock
    ((0.0, 6.5, 20.0), (0.0, 0.0, 400.0), 18),  # out through the blinds
]

CHECKS = {
    "walk": (2.0, 10.0),
    "corners": [[(-26.0, 0.0, -24.0), (26.0, 0.0, 24.0)], [(-24.0, 0.0, 24.0), (24.0, 0.0, -24.0)]],
    # A square room round a round table is its own mirror image on purpose.
    "symmetry": None,
}


def preview(s):
    """What the game builds itself, for the previews: the screen and the board."""
    x, y, z, rot, w, h = P.SCREEN
    s.box("Screen", (x, y, z), (w, h, 0.3), rot)
    x, y, z, rot, w, h = P.BOARD
    s.prop("EvidenceBoard", x - 0.2, z, rot, min(w / 12.0, h / 7.0), y)


def build(s):
    room.build(s)
    furnish.build(s)
    outside.build(s)
    s.set_bounds(*P.BOUNDS)
    s.checks = CHECKS
    s.far_chunk = (90.0, 1000.0, -60.0)
