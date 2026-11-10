"""The scene deaths' sets (src/client/Presentation/SceneDeaths; the user's verdict of 2026-11-08 on the first sets:
"why are the scenarios so low quality?": they were code-built blocks in a box, so each is modelled here like the
game's other sets). Nobody walks here and no server builds it: a client clones one set's meshes when its scene plays
(SceneDeaths.set), anywhere (a case, the lobby's shop, the debug gallery). Each set sits in its own cell 1000 studs
along X (GROUP keeps every mesh inside one set) and is drawn in its scene's own space: y up, the origin on the floor
where the scene's first actor stands, as the scene module's ctx works.

    patriot     A true patriot: a military cemetery in morning mist, rows of headstones, a big bare oak, bare woods
    blackwall   Blackwall gateway: an underground car park, pillars painted "1", a blue car on a two-level lift
    walrider    Walrider: the asylum lab, the hazard stripe and the steel double door, the white tiled room beyond
    sam         Let's dance!: open desert hills at dusk, boulders, a rocky ridge
    ironman     and I.. am..: a ruined battlefield at dusk, broken walls, rubble, craters, burnt-out shells far off
    selection   Dead by selection: a rooftop at night over a city, under the Milky Way (SkySceneNight)

The two void scenes (requiem, god) and sans' battle screen have no set: their skies are Sky faces (scene_skies.py,
carried here as TEXTURES) and sans' is black.
"""

import math
import os

import common
from maps.venues.scenes import blackwall, ironman, patriot, sam, selection, walrider
from maps.venues.scenes import plan as P

FORMAT = 2
GROUP = P.group
# The clients build it, so its data goes where they can read it (src/shared/Scenes).
DATA_DIR = os.path.join(common.ROOT, "src", "shared")

PLAN_LEVELS = [("floor", 3.0)]
SKY_FACES = ("Ft", "Bk", "Lf", "Rt", "Up", "Dn")
# (and the pictures the scenes show: scene_pictures.py)
TEXTURES = ["SkyScene" + sky + face for sky in P.SKIES for face in SKY_FACES] + ["SelectionChart"]


def _at(where, eye, look, lens):
    ox, oz = where
    return ((eye[0] + ox, eye[1], eye[2] + oz), (look[0] + ox, look[1], look[2] + oz), lens)


def _lens(fov):
    """The Blender lens (36 mm sensor across 16:9) for a Roblox vertical field of view."""
    return 18.0 / (math.tan(math.radians(fov) / 2) * 16 / 9)


VIEWS = [
    # the patriot: the wide from the front-left, the close on the saluter, the headstone, the wide from the right
    _at(P.PATRIOT, (-6.5, 4.2, -13), (0, 3.2, -1), _lens(44)),
    _at(P.PATRIOT, (-1.6, 4.3, -2.4), (0, 4.5, 0), _lens(34)),
    _at(P.PATRIOT, (0.45, 0.9, -1.7), (0, 0.9, -3.8), _lens(40)),
    _at(P.PATRIOT, (8.5, 4.6, -11), (0, 3.2, -1.5), _lens(42)),
    # Blackwall: the hacker's eye
    _at(P.BLACKWALL, (-1.0, 5.2, -9.5), (0.4, 4.2, 0), _lens(58)),
    # Walrider: up at the door; down on the floor looking at the doorway
    _at(P.WALRIDER, (0, 4.8, 6.0), (0, 4.4, -4), _lens(70)),
    _at(P.WALRIDER, (0.9, 0.8, 4.2), (0.2, 1.4, -6), _lens(70)),
    # Sam: over the killer's shoulder; the side wide
    _at(P.SAM, (-3.4, 6.4, -10.5), (0, 3.6, 0), _lens(50)),
    _at(P.SAM, (9, 4.2, -1.5), (0.3, 3.6, -1.5), _lens(48)),
    _at(P.SAM, (4.2, 2.6, 4.4), (0.4, 3.0, 0.8), _lens(46)),
    # Iron Man: the battlefield wide; the low close; the wall
    _at(P.IRONMAN, (9, 4.2, 5), (0, 3.5, -4), _lens(50)),
    _at(P.IRONMAN, (14, 7, 8), (0, 3, -8), _lens(56)),
    _at(P.IRONMAN, (4.6, 3.6, -4.6), (0, 2.8, 0.4), _lens(44)),
    # Dead by selection: over the shoulder to the city; the low angle up at the sky; down from high above; the wide
    _at(P.SELECTION, (1.6, 5.2, 3.4), (-0.4, 4.2, -6), _lens(42)),
    _at(P.SELECTION, (1.2, 1.2, -2.6), (0, 6.5, 0.4), _lens(40)),
    _at(P.SELECTION, (0.5, 24, 1.5), (0, 0, 0), _lens(40)),
    _at(P.SELECTION, (-7.5, 3.2, 8.5), (0, 5.5, -2), _lens(34)),
]

PREVIEW_FIGURES = [
    (P.PATRIOT[0], 0.0, P.PATRIOT[1], 0),
    (P.BLACKWALL[0], 0.0, P.BLACKWALL[1], 180),
    (P.SAM[0], 0.0, P.SAM[1], 0),
    (P.SAM[0], 0.0, P.SAM[1] - 5, 180),
    (P.IRONMAN[0], 0.0, P.IRONMAN[1], 0),
    (P.IRONMAN[0], 0.0, P.IRONMAN[1] - 6.5, 180),
    (P.SELECTION[0], 0.0, P.SELECTION[1], 0),
]

# Each set's preview light: (sky colour, strength, sun energy, sun (pitch, yaw) degrees, sun colour, mist density)
PREVIEW_LIGHT = {
    "patriot": ((0.86, 0.84, 0.78), 1.1, 2.2, (62, -150), (1.0, 0.93, 0.8), 0.018),
    "blackwall": ((0.03, 0.03, 0.03), 0.4, 0.0, (50, 0), (1, 1, 1), 0.0),
    "walrider": ((0.03, 0.035, 0.04), 0.4, 0.0, (50, 0), (1, 1, 1), 0.0),
    "sam": ((0.72, 0.52, 0.32), 1.1, 3.0, (78, -140), (1.0, 0.72, 0.42), 0.006),
    "ironman": ((0.62, 0.36, 0.2), 0.9, 2.5, (82, 20), (1.0, 0.55, 0.28), 0.01),
    "selection": ((0.05, 0.06, 0.1), 1.0, 0.6, (40, 150), (0.7, 0.8, 1.0), 0.0),
}


def PREVIEW_SETUP(eye, world, sun):
    name = P.name_at(eye[0])
    sky, strength, energy, (pitch, yaw), colour, mist = PREVIEW_LIGHT.get(name, PREVIEW_LIGHT["selection"])
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = (*sky, 1)
    bg.inputs["Strength"].default_value = strength
    sun.data.energy = energy
    sun.data.color = colour
    sun.rotation_euler = (math.radians(pitch), 0, math.radians(yaw))
    nodes, links = world.node_tree.nodes, world.node_tree.links
    out = nodes.get("World Output")
    vol = nodes.get("Mist") or nodes.new("ShaderNodeVolumeScatter")
    vol.name = "Mist"
    vol.inputs["Density"].default_value = mist
    vol.inputs["Color"].default_value = (*sky, 1)
    # (Eevee's world volume blacked the whole frame out: the mist is the game's Atmosphere, not previewed)
    for link in list(out.inputs["Volume"].links):
        links.remove(link)


CHECKS = {"symmetry": None}


def build(s):
    patriot.build(s)
    blackwall.build(s)
    walrider.build(s)
    sam.build(s)
    ironman.build(s)
    selection.build(s)
    s.set_bounds(*P.BOUNDS)
    s.checks = CHECKS
