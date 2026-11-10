"""Writes src/client/Presentation/SceneDeaths/Costumes.luau: where each scene costume piece (props_scenes.py) sits on the
body part it is worn on, and how big it is (background Blender: it builds each piece, unbaked, to measure it):

    blender -b --factory-startup --python art/scripts/scene_costumes.py

A worn piece (a helmet, a vest, the gauntlet) is built round its body part, so it sits where its middle was built. A
held one is solved on its key pose (emotes.kit.hold): the rifle's grip in the aiming fist with the barrel along the
aim, the spear upright in the soldier's fist. The game scales each model to `size` (its biggest side) and puts its
pivot (the middle of its box) at the part times `at` (SceneDeaths Ctx:wear)."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import bpy  # noqa: E402
import numpy as np  # noqa: E402
from mathutils import Vector  # noqa: E402

import common  # noqa: E402
import modelkit as mk  # noqa: E402
import props  # noqa: E402
import props_scenes as ps  # noqa: E402
from animlib import J  # noqa: E402
from emotes import kit  # noqa: E402

OUT = os.path.join(common.ROOT, "src", "client", "Presentation", "SceneDeaths", "Costumes.luau")
CORE = 35  # the Core import that holds them (maps/export.py VERSION["ModelsCore"])

# The poses the held pieces are solved on (scene_actors.py): the Walrider soldiers' aim, the Iron army's stance.
AIM_R = kit.reach(1, (0.25, 0.75, -1.6), direction=(-0.15, 0.1, -1.0))
SPEAR_R = J((50, 0, 20))
# Dead by selection: the reading hand (scene_actors.PHONE_R)
PHONE_R = kit.reach(1, (0.32, 0.45, -0.95), direction=(-0.12, 0.62, -0.78))


def measure(key):
    """(centre (Blender), size (Roblox x y z)) of a piece as its builder makes it."""
    mk.new_build()
    parts = props.BUILDERS[key]["build"]()[0]
    bpy.context.view_layer.update()
    lo = Vector((1e9, 1e9, 1e9))
    hi = Vector((-1e9, -1e9, -1e9))
    graph = bpy.context.evaluated_depsgraph_get()
    for obj in parts:
        ev = obj.evaluated_get(graph)
        mesh = ev.to_mesh()
        for v in mesh.vertices:
            w = obj.matrix_world @ v.co
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
        ev.to_mesh_clear()
    return (lo + hi) / 2, hi - lo


def rbx(v):
    """Blender (x, y, z) to Roblox axes (the props' export turn: x = -x, y = z, z = y)."""
    return np.array([-v[0], v[2], v[1]], float)


def r3(v):
    return [round(float(x), 3) + 0.0 for x in v]


def steps_text(steps):
    return kit.luau_steps(steps)


def main():
    entries = {}
    sizes = {}
    centres = {}
    for key in ("SceneHelmet", "SceneVest", "SceneRifle", "SceneCyborgHead", "SceneMurasama", "SceneRedBlade",
                "SceneWarlordHelm", "SceneWarlordPlate", "SceneGauntlet", "SceneSpear", "SceneWheelchair",
                "SceneArcReactor", "Smartphone"):
        centre, size = measure(key)
        centres[key] = centre
        sizes[key] = round(max(size), 4)

    def worn(name, key, mount, note):
        entries[name] = dict(model=key, size=sizes[key], mount=mount, at=[{"p": r3(rbx(centres[key]))}], note=note)

    worn("soldierHelmet", "SceneHelmet", "Head", "the Walrider soldiers' helmet")
    worn("soldierVest", "SceneVest", "Torso", "their plate carrier")
    worn("cyborgHead", "SceneCyborgHead", "Head", "the blade's hair and visor")
    worn("warlordHelm", "SceneWarlordHelm", "Head", "the warlord's helm")
    worn("warlordPlate", "SceneWarlordPlate", "Torso", "his chest plate and pauldrons")
    worn("gauntlet", "SceneGauntlet", "Right Arm", "the victim's gauntlet over the right hand")
    worn("arcReactor", "SceneArcReactor", "Torso", "the light in the victim's chest (Core 37; nothing before it)")

    # the blades: the grip in the fist (the arm's end), the blade out ahead of the fist along the hand's front (-Z)
    for name, key, length in (("murasama", "SceneMurasama", 3.4), ("redBlade", "SceneRedBlade", 2.8)):
        grip = rbx(Vector((0.0, -0.3, 0.0)) - centres[key])
        at = np.array([0.0, -1.05, 0.0]) - grip
        tip = rbx(Vector((0.0, -0.62 - 0.06 - length, 0.12)) - centres[key])
        base = rbx(Vector((0.0, -0.62 - 0.06, 0.0)) - centres[key])
        entries[name] = dict(model=key, size=sizes[key], mount="Right Arm", at=[{"p": r3(at)}],
                             tip=r3(tip), base=r3(base), stand=dict(size=[0.12, 0.3, length + 0.6],
                                                                       color=[170, 172, 178]),
                             note="the killer's long blade" if name == "murasama" else "the victim's red sword")

    # the rifle: its pistol grip in the aiming fist, the barrel along the torso's front (-Z), upright
    grip = rbx(Vector((0.0, 0.32, -0.3)) - centres["SceneRifle"])
    fist = kit.fist_at(1, AIM_R)
    entries["rifle"] = dict(model="SceneRifle", size=sizes["SceneRifle"], mount="Right Arm",
                            at=kit.hold("Right Arm", {"rShoulder": AIM_R}, tuple(fist - grip)),
                            muzzle=r3(rbx(Vector((0.0, -1.93, 0.04)) - centres["SceneRifle"])),
                            stand=dict(size=[0.22, 0.34, 2.6], color=[22, 22, 24]), note="their carbine")

    # the spear: upright in the soldier's fist, gripped at its cord
    grip = rbx(Vector((0.0, 0.0, -0.4)) - centres["SceneSpear"])
    fist = kit.fist_at(1, SPEAR_R)
    entries["spear"] = dict(model="SceneSpear", size=sizes["SceneSpear"], mount="Right Arm",
                            at=kit.hold("Right Arm", {"rShoulder": SPEAR_R}, tuple(fist - grip)),
                            stand=dict(size=[0.12, 5.2, 0.12], color=[40, 38, 36]), note="the army's spear")

    # the phone of Dead by selection: upright above the reading fist, its screen (the model's +Y) to the face and
    # tipped up to the eyes, its top (the model's +Z) up: turned 180 about Y, then 65 about X
    fist = kit.fist_at(1, PHONE_R)
    up = np.array([0.0, math.sin(math.radians(65)), -math.cos(math.radians(65))])
    entries["phone"] = dict(model="Smartphone", size=sizes["Smartphone"], mount="Right Arm",
                            at=kit.hold("Right Arm", {"rShoulder": PHONE_R}, tuple(fist + up * 0.3), (65.0, 180.0, 0.0)),
                            stand=dict(size=[0.54, 0.085, 1.04], color=[20, 20, 22]),
                            note="the victim's phone in Dead by selection, held up to read")

    # the stones' sockets on the gauntlet, from its pivot (Roblox axes, at its built size)
    sockets = [r3(rbx(Vector(s) - centres["SceneGauntlet"])) for s in ps.GAUNTLET_SOCKETS]

    lines = [
        "--!strict",
        "-- GENERATED by art/scripts/scene_costumes.py (background Blender) from art/scripts/props_scenes.py. Do not edit",
        "-- by hand: change the pieces or their poses there and run it again.",
        "--",
        "-- The scene deaths' costume pieces (Core models, 2026-11-09): what each extra character wears and carries, on",
        "-- which body part, where (`at`: EmoteProps steps from the part's middle to the model's pivot, the middle of its",
        "-- box) and how big (`size`: its biggest side, studs). A held piece has a `stand`, the plain part shown before the",
        "-- import (CORE); a worn one shows nothing then. Points (`muzzle`, `tip`, `base`, `sockets`) are from the pivot.",
        "",
        "return {",
        f"\tCORE = {CORE},",
    ]
    for name in sorted(entries):
        e = entries[name]
        lines.append(f"\t-- {e['note']}")
        lines.append(f"\t{name} = {{")
        lines.append(f"\t\tmodel = \"{e['model']}\",")
        lines.append(f"\t\tsize = {e['size']},")
        lines.append(f"\t\tmount = \"{e['mount']}\",")
        lines.append(f"\t\tat = {steps_text(e['at'])},")
        for point in ("muzzle", "tip", "base"):
            if point in e:
                lines.append(f"\t\t{point} = {{ {', '.join(f'{v:g}' for v in e[point])} }},")
        if "stand" in e:
            s = e["stand"]
            lines.append(f"\t\tstand = {{ size = {{ {', '.join(f'{v:g}' for v in s['size'])} }}, "
                         f"color = {{ {', '.join(str(v) for v in s['color'])} }} }},")
        lines.append("\t},")
    lines.append("\t-- the gauntlet's six stone sockets (five knuckles, the back of the hand), from its pivot")
    lines.append("\tgauntletSockets = {")
    for s in sockets:
        lines.append(f"\t\t{{ {', '.join(f'{v:g}' for v in s)} }},")
    lines.append("\t},")
    lines.append("\t-- the old man's wheelchair, standing on the floor (a bottom-pivot prop: its pivot at its lowest point)")
    lines.append(f"\twheelchair = {{ model = \"SceneWheelchair\", size = {sizes['SceneWheelchair']} }},")
    lines.append("}")
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    print("[costumes] wrote", OUT)


main()
