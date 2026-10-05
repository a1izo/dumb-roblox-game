"""The lobby: the Grey Realm, the never-ending wasteland beyond the world where the Grimoire comes from.
Cracked grey ash running to the horizon under layered cloud, huge twisted columns, mesas and spires standing
out of the fog, and far to the north one colossal blade. Players appear on a ruined terrace over an old
flagstone plaza, facing north; the steles round the plaza carry How to Play, the next case and the boards.
South-west, the Academy's ring of broken pillars holds the practice altars; east, the rift looks down on
Kagegaoka at night; north-west lies the dice rock and the cleft, north-east the needle ledge; south-east a
colossal carcass; and behind the title monolith, up on its mesa, the empty bone throne. A ridge of rock and
needles borders the walkable basin; two old stone causeways cross deep chasms to two plateaus: the Spire
Ascent (west) and the rune courtyard (north-east).

Everything that shows text or does something is built by the game (src/server/Maps/Lobby.luau and
the lobby games) at the anchors this scene exports: the title and tagline, the eight boards, the
spawn, the Academy's signs, its seven drill altars and three effigies, the dice seats, the stone-toss,
the rune tiles, the parkour's checkpoints, the roots and banners that sway. The layout is in plan.py."""

from maps import city
from maps.venues.lobby import dressing, formations, gameplay, islets, landmarks, rift, terrain
from maps.venues.lobby import plan as P

FORMAT = 2

PLAN_LEVELS = [("ground", 30.0)]

MASSING_VIEWS = [
    ((260.0, 240.0, 260.0), (0.0, 0.0, 0.0), 22),
    ((-240.0, 200.0, -260.0), (0.0, 0.0, 0.0), 22),
]
FIGURES = [(0.0, 0.0, 20.0, 0.0)]

# Views for --preview: (camera, target, lens), at a player's height unless noted.
VIEWS = [
    ((0.0, 19.0, 70.0), (-20.0, 60.0, -700.0), 18),  # from the spawn: the first view
    ((0.0, 19.0, 70.0), (0.0, 12.0, -60.0), 18),  # from the spawn: the plaza and the title
    ((-20.0, 6.0, 30.0), (-47.0, 9.0, 4.0), 16),  # How to Play and the west steles
    ((-54.0, 7.0, 58.0), (-80.0, 6.0, 84.0), 16),  # the Academy's gate
    ((-80.0, 7.0, 76.0), (-86.0, 4.0, 100.0), 14),  # inside the ring: the altars and effigies
    ((80.0, 12.0, 22.0), (106.0, -200.0, 22.0), 16),  # down through the rift (from over its lip)
    ((66.0, 7.0, 44.0), (98.0, 0.0, 22.0), 18),  # the rift and the apple tree
    ((-70.0, 6.0, -40.0), (-88.0, 3.0, -54.0), 16),  # the dice rock
    ((-70.0, 7.0, -92.0), (-110.0, 20.0, -140.0), 18),  # the cleft
    ((104.0, 7.0, -48.0), (140.0, 14.0, -80.0), 18),  # the needle ledge and its blade
    ((20.0, 8.0, 90.0), (70.0, 10.0, 110.0), 16),  # under the carcass's ribs
    ((-150.0, 8.0, 0.0), (-300.0, 20.0, 0.0), 20),  # the west causeway to the Spire Ascent
    ((-228.0, 8.0, 14.0), (-228.0, -50.0, -2.0), 20),  # looking down into its chasm
    ((-290.0, 11.0, 0.0), (-326.0, 77.0, -2.0), 20),  # at the foot of the spire
    ((190.0, 14.0, -190.0), (214.0, 11.0, -216.0), 18),  # the rune courtyard
    ((0.0, 300.0, 90.0), (0.0, 0.0, -80.0), 14),  # the basin from above
]

# check_v2's targets: the walk from the spawn to each islet and across the island (seconds); up to 35 s to the
# farthest activity (settled with the user, 2026-10-05). The mirror
# rule is for the gameplay maps; the lobby is an open field to wait in, naturally close to its own
# mirror image, so it is not held to it (settled with the user, 2026-09-29).
CHECKS = {
    "walk": (15.0, 35.0),
    "corners": P.CORNERS,
    "symmetry": None,
}


def preview(s):
    """What the game builds itself, for the previews: its sign panels, the spawn pad (the drill
    altars and effigies are preview props of the scene itself)."""
    anchors = _LAST.get("anchors", {})
    for name, (x, z, rot, w, h) in P.STELES.items():
        a = anchors[name]
        s.box("Screen", (a["x"], a["y"], a["z"]), (w, h, 0.3), rot)
    for key in ("title", "tagline", "academyTitle", "academyLine", "academyGate"):
        a = anchors[key]
        s.box("Screen", (a["x"], a["y"], a["z"]), (a["w"], a["h"], 0.3), a["rot"])
    sx, sz = P.SPAWN
    s.box("RuinFlag", (sx, P.TERRACE[4] + 0.2, sz), (12.0, 0.4, 12.0))


_LAST = {}


def build(s):
    g = city.Ground(s)
    terrain.build(s, g)
    landmarks.build(s, g)
    islets.build(s, g)
    rift.build(s)
    dressing.build(s)
    formations.build(s)
    gameplay.build(s)
    g.finish()
    s.set_bounds(*P.BOUNDS)
    s.checks = CHECKS
    s.far_chunk = (230.0, 1000.0, -120.0)
    _LAST["anchors"] = s.anchors
