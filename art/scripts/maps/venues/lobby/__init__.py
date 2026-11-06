"""The lobby: the Grey Realm, the death gods' realm the Grimoire comes from, remade from nothing on 2026-11-04 to the
user's two reference videos. A flat grey plain under one blinding glow low in the north, dark walls of cloud east and
west, jagged pale shards on the skyline. Players appear on a ledge of billowing rock in the south, facing north over
the bowl (a great stone basin sunk in the plain where everyone gathers: the candle stones of who is ready round a dish
of skulls, the five tableaux round its rim) to the bone throne high on its rock against the glow. North-east, the rift
down to the human world, the stone notebook hanging over it; east, the colossal carcass with the name duel under its
ribs; south-west, the grotto with the Academy inside, lit by cage lanterns; north-west, the chess game, two colossal
tusks, the great arch; heaps of junk about. Over two causeways: the Chain Heap (the Spire Ascent climbs round a
colossal chain hanging out of the sky, west) and a garden of pale shards (north-east). The lobby's games are the
three the user kept on 2026-11-05: the dive into the rift, the Spire Ascent and the name duel.

Everything that shows text or does something is built by the game (src/server/Maps/Lobby.luau and the lobby games)
at the anchors this scene exports: the Most Wins board, the spawn, the Academy's gate sign, its seven drill altars and
three puppets, the candles, the tableaux' figures, the figure on the throne, the duel, the rift and its landing, the
parkour's checkpoints, the roots that sway. The layout is in plan.py."""

from maps import city
from maps.venues.lobby import dressing, formations, gameplay, ground, islets, landmarks, rift, rocks, terrain
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
    ((0.0, 15.0, 108.0), (0.0, 40.0, -900.0), 18),  # from the spawn: the first view, over the bowl to the glow
    ((0.0, 15.0, 108.0), (0.0, 4.0, -40.0), 18),  # from the spawn: the bowl and the throne
    ((-26.0, 6.0, 46.0), (0.0, -1.0, 16.0), 16),  # into the bowl from its rim
    ((0.0, 5.0, -30.0), (0.0, 14.0, -66.0), 16),  # the throne on its rock, the plaque, Most Wins
    ((-50.0, 7.0, 30.0), (-104.0, 8.0, 52.0), 16),  # the grotto's mouth
    ((-96.0, 6.0, 46.0), (-112.0, 6.0, 62.0), 14),  # inside the grotto: the altars and the puppets
    ((60.0, 9.0, -20.0), (90.0, -10.0, -44.0), 18),  # the rift and the notebook
    ((96.0, 7.0, 34.0), (122.0, 8.0, 38.0), 16),  # under the carcass's ribs: the duel
    ((-40.0, 7.0, -20.0), (-62.0, 3.0, -40.0), 16),  # the chess game
    ((-60.0, 8.0, -84.0), (-76.0, 18.0, -104.0), 18),  # the tusks
    ((-150.0, 8.0, 0.0), (-326.0, 60.0, -2.0), 20),  # the west causeway to the Chain Heap
    ((-290.0, 11.0, 0.0), (-326.0, 80.0, -2.0), 20),  # at the foot of the great chain
    ((190.0, 14.0, -190.0), (214.0, 11.0, -216.0), 18),  # the shard garden
    ((0.0, 300.0, 110.0), (0.0, 0.0, -40.0), 14),  # the basin from above
]

# check_v2's targets: the walk from the spawn to each islet and across the island (seconds); up to 35 s to the
# farthest activity (settled with the user, 2026-10-05). The mirror
# rule is for the gameplay maps; the lobby is an open field to wait in, naturally close to its own
# mirror image, so it is not held to it (settled with the user, 2026-09-29).
# Ceiling pools stop at their own floor at export (lightbook.stop_pools), on every map since 2026-11-06.
STOP_POOLS = True

CHECKS = {
    "walk": (15.0, 35.0),
    "corners": P.CORNERS,
    "symmetry": None,
    # Nobody is dealt a case's spawn here: everyone arrives at the spawn ring (check_v2's spawn spread is for the maps).
    "spawns": None,
    # Everywhere a game is played can be walked to from the spawn: the bowl's candles, the tableaux, the throne's
    # plaque and the wins slab, the duel, the Academy's altars and puppets (inside the grotto) and the foot of the
    # climb (on its plateau).
    "reach": ["spawn", "ready*", "tableau*", "throneplaque", "wins", "duel*", "drill*", "dummy*", "pkStart"],
    # The carcass's skull rests on its jaw, settled into the ash (landmarks.carcass); the gears lie half buried in the
    # junk (landmarks.junk, islets.chain_heap); the dish of skulls and the drips hang where they are meant to: all on
    # purpose.
    "finds_ok": ["sunk GiantSkull in the floor or the map", "sunk RustGear in the floor or the map",
                 # (hanging on purpose: the climb's gear decks, the cage lanterns on their chains, the great chain out of
                 # the sky, the gears standing on their edges in the junk)
                 "float GearPlatform", "float HangingCage", "float GreatChain", "float RustGear"],
}


def preview(s):
    """What the game builds itself, for the previews: its sign panels, the spawn pad (the drill
    altars and effigies are preview props of the scene itself)."""
    anchors = _LAST.get("anchors", {})
    for name, (x, z, rot, w, h, by) in P.STELES.items():
        a = anchors[name]
        s.box("Screen", (a["x"], a["y"], a["z"]), (w, h, 0.3), rot)
    for key in ("academyGate",):
        a = anchors[key]
        s.box("Screen", (a["x"], a["y"], a["z"]), (a["w"], a["h"], 0.3), a["rot"])
    sx, sz = P.SPAWN
    s.box("RuinFlag", (sx, P.LEDGE[4] + 0.2, sz), (12.0, 0.4, 12.0))


_LAST = {}


def build(s):
    rocks.FEET.clear()
    g = city.Ground(s)
    terrain.build(s, g)
    landmarks.build(s, g)
    islets.build(s, g)
    rift.build(s)
    dressing.build(s)
    formations.build(s)
    gameplay.build(s)
    ground.build(s)
    g.finish()
    s.set_bounds(*P.BOUNDS)
    s.checks = CHECKS
    s.far_chunk = (230.0, 1000.0, -120.0)
    _LAST["anchors"] = s.anchors
