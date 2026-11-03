"""The shared furniture made again (Core set): what the game itself still names (emotes, win cuts, the shop, the cutscene sets) and what one
map still stands on, now that each map has its own of the rest (props_mapown.py). The keys, footprints and seat heights are the old ones.

- Chair: a walnut ladder back dining chair (Tokyo's rooms, the sitting emotes, the win rooms).
- OfficeChair: a mesh back task chair on a five star base (the Bureau's bullpen).
- Bookshelf: a library stack in dark oak, its books in runs with their bay plate (the University's library, 95 of them, so it is lighter
  than the old one).
- FilingCabinet: a four drawer steel file."""

import math
import random

from mathutils import Vector

import modelkit as mk
import propkit as pk
import stationkit as sk
from common import srgb
from props import prop
from props_mapown import _axis, bar, card_frame, cushion, lattice, loop, spline, turned
from props_world import LEATHER_RED, dark_wood


@prop("Chair", pivot="bottom", material="Wood", collide=True, texture=256, exact=True)
def chair():
    """A walnut dining chair: tapered square front legs, back posts that rake above the seat, three steam-bent ladder rails, side and front
    stretchers, a drop-in seat in dark red hide with its piping."""
    wood = dark_wood("WChair_Wood")
    hide = mk.noisy("WChair_Leather", *LEATHER_RED, scale=10, roughness=0.5)
    pipe = mk.flat("WChairPipe_Leather", srgb(40, 16, 14), 0.5)
    top = 1.745
    parts = [cushion("Seat", (1.64, 1.56, 0.2), (0, -0.02, top - 0.1), hide, e=0.42, segments=14, rings=7),
             bar("Piping", loop(1.54, 1.46, top - 0.16, c=0.14, y=-0.02), 0.014, pipe, sides=3)]
    for x, y, r in ((-0.81, -0.74, 0), (0.81, -0.74, 0)):
        parts.append(mk.cylinder("FrontLeg", 0.066, 1.56, (x, y, 0.78), rot=(0, 0, 45), mat=wood, verts=4, radius2=0.11))
    for side in (-1, 1):
        x = side * 0.81
        parts.append(sk.wedge("BackPost", [(0.68, 0.0), (0.82, 0.0), (0.82, 1.5), (0.9, 3.86), (0.78, 3.86), (0.68, 1.5)], 0.13, x, wood, bevel=0.012))
        parts.append(mk.box("SideRail", (0.08, 1.4, 0.24), (x, 0.0, 1.42), mat=wood, bevel=0.01, segments=1))
        parts.append(mk.box("SideStretcher", (0.06, 1.4, 0.08), (x, 0.0, 0.62), mat=wood))
    parts += [mk.box("FrontRail", (1.56, 0.08, 0.24), (0, -0.74, 1.42), mat=wood, bevel=0.01, segments=1),
              mk.box("BackRail", (1.56, 0.08, 0.24), (0, 0.74, 1.42), mat=wood, bevel=0.01, segments=1),
              mk.box("FrontStretcher", (1.56, 0.06, 0.08), (0, -0.74, 0.44), mat=wood),
              mk.box("BackStretcher", (1.56, 0.06, 0.08), (0, 0.74, 0.44), mat=wood)]
    for k, z in enumerate((2.3, 2.9, 3.5)):
        y = 0.76 + (z - 1.5) / 2.36 * 0.08
        rail = spline([(-0.79, y, z), (-0.4, y + 0.06, z), (0.0, y + 0.08, z), (0.4, y + 0.06, z), (0.79, y, z)], 2)
        parts.append(bar("LadderRail", rail, 0.05 if k < 2 else 0.065, wood, sides=5))
    return parts, []


@prop("OfficeChair", pivot="bottom", material="Leather", collide=True, texture=512, exact=True, normal=128)
def office_chair():
    """A task chair: a five star nylon base on twin castors, the gas lift and its tilt lever, a padded seat with a waterfall edge, a plastic frame
    holding a black mesh back and its lumbar pad on a curved steel spine, height adjustable arms with soft pads."""
    fabric = mk.noisy("OChair_Cloth", srgb(20, 20, 24), srgb(44, 44, 50), roughness=0.85, kind="wool")
    nylon = mk.noisy("OChair_Plastic", srgb(14, 14, 16), srgb(34, 34, 38), roughness=0.4)
    mesh = lattice("OChair_Mesh", (10, 10, 12), (46, 46, 52), 0.07, _axis("X"), _axis("Z"), share=0.5, roughness=0.8, square=True)
    steel = pk.metal("OChair_Steel", (60, 60, 66), (110, 110, 118), rough=0.3, metallic=1.0)
    chrome = pk.chrome("OChair_Chrome")
    pad = mk.noisy("OChair_Leather", srgb(16, 16, 18), srgb(38, 38, 42), roughness=0.5)
    tyre = pk.rubber("OChair_Tyre")
    seat_top = 1.72
    parts = [mk.cylinder("GasLift", 0.055, 0.6, (0, 0, 0.94), mat=chrome, verts=10),
             mk.cylinder("Sleeve", 0.1, 0.56, (0, 0, 0.52), mat=nylon, verts=10, radius2=0.085),
             pk.rounded("Tilt", (0.7, 0.86, 0.14), (0, 0.02, 1.3), steel, r=0.04),
             bar("TiltLever", spline([(0.3, 0.1, 1.3), (0.7, 0.14, 1.28), (1.02, 0.1, 1.26)], 2), 0.022, steel, sides=4),
             mk.sphere("LeverKnob", 0.05, (1.02, 0.1, 1.26), scale=(1.6, 1, 1), mat=nylon, segments=6, rings=4),
             cushion("SeatPad", (1.86, 1.78, 0.3), (0, -0.04, seat_top - 0.15), fabric, e=0.36, segments=16, rings=8),
             cushion("SeatShell", (1.8, 1.72, 0.12), (0, -0.02, seat_top - 0.32), nylon, e=0.4, segments=12, rings=6)]
    for k in range(5):
        a = math.radians(90 + k * 72)
        c, s = math.cos(a), math.sin(a)
        arm = spline([(0.06 * c, 0.06 * s, 0.34), (0.5 * c, 0.5 * s, 0.32), (0.86 * c, 0.86 * s, 0.26)], 2)
        parts.append(bar("StarArm", arm, [0.1, 0.095, 0.085, 0.07, 0.055], nylon))
        for side in (-1, 1):
            parts.append(mk.soften(mk.cylinder("CastorWheel", 0.13, 0.05, (0.92 * c - side * 0.05 * s, 0.92 * s + side * 0.05 * c, 0.13), rot=(90, 0, math.degrees(a)), mat=tyre,
                                               verts=10)))
        parts.append(mk.sphere("CastorHood", 0.09, (0.92 * c, 0.92 * s, 0.17), mat=nylon, segments=8, rings=4))
    # The back: a plastic hoop round a mesh, on a curved spine.
    bz, bh = 2.72, 1.9
    rake = -9
    frame = bar("BackFrame", [(x, 0, z - bz) for x, y, z in [(p[0], p[1], p[1] + bz) for p in loop(1.56, bh, 0, c=0.34, steps=4)]], 0.05, nylon)
    frame.location = (0, 0.82, bz)
    frame.rotation_euler = (math.radians(rake), 0, 0)
    screen = mk.box("BackMesh", (1.48, 0.016, bh - 0.08), (0, 0.82, bz), rot=(rake, 0, 0), mat=mesh)
    lumbar = cushion("Lumbar", (1.2, 0.08, 0.44), (0, 0.72, 2.26), pad, e=0.45, segments=10, rings=5)
    lumbar.rotation_euler = (math.radians(rake), 0, 0)
    spine = spline([(0, 0.3, 1.34), (0, 0.84, 1.4), (0, 1.0, 1.82), (0, 0.96, 2.5), (0, 0.92, 2.9)], 2)
    parts += [frame, screen, lumbar, bar("Spine", spine, [0.09, 0.09, 0.085, 0.08, 0.075, 0.07, 0.06, 0.055, 0.05], steel)]
    # The arms.
    for side in (-1, 1):
        x = side * 1.0
        parts += [bar("ArmStrut", spline([(side * 0.5, 0.06, 1.3), (side * 0.86, 0.06, 1.32), (x, 0.06, 1.5)], 2), 0.05, steel),
                  pk.rounded("ArmSleeve", (0.12, 0.2, 0.6), (x, 0.06, 1.72), nylon, r=0.03),
                  mk.box("ArmStem", (0.08, 0.14, 0.4), (x, 0.06, 2.1), mat=steel),
                  mk.box("ArmButton", (0.02, 0.08, 0.1), (x + side * 0.066, 0.06, 1.86), mat=steel),
                  cushion("ArmPad", (0.26, 0.92, 0.1), (x, -0.04, 2.3), pad, e=0.5, segments=10, rings=5)]
    return parts, []


@prop("Bookshelf", pivot="bottom", material="Wood", collide=True, texture=1024)
def bookshelf():
    """A library stack in dark oak: a plinth, a moulded cornice, a boarded back, six shelves on their pegs with a brass label holder on each,
    leather and cloth volumes in runs of a height, a few leaning, the odd gilt band, the bay's number plate on the top rail."""
    wood = dark_wood("Shelf_Wood")
    edge = mk.wood("Shelf_Oak", srgb(92, 62, 38), srgb(56, 36, 22), roughness=0.45)
    brass = pk.metal("Shelf_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    card = mk.noisy("Shelf_Label", srgb(206, 196, 170), srgb(232, 224, 200), roughness=0.9)
    gilt = pk.metal("ShelfGilt_Gold", (160, 126, 62), (210, 176, 100), rough=0.4, metallic=1.0)
    tones = [(110, 20, 26), (30, 44, 80), (170, 140, 80), (34, 60, 38), (60, 40, 30), (20, 20, 24), (140, 130, 118), (92, 58, 34), (74, 26, 40)]
    books = [mk.noisy(f"Shelf_Book{i}", srgb(*c), srgb(*[min(255, int(v * 1.4)) for v in c]), scale=30, roughness=0.6) for i, c in enumerate(tones)]
    w, h, d = 3.2, 8.1, 1.8
    parts = [mk.box("Back", (w - 0.2, 0.08, h - 0.5), (0, d / 2 - 0.08, 4.1), mat=wood),
             mk.box("Plinth", (w, d - 0.04, 0.32), (0, 0, 0.16), mat=edge, bevel=0.02, segments=1),
             mk.box("CorniceLow", (w - 0.06, d - 0.04, 0.1), (0, 0, 7.86), mat=edge, bevel=0.02, segments=1),
             pk.rounded("Cornice", (w, d, 0.2), (0, 0, 8.0), edge, r=0.03)]
    for x in (-w / 2 + 0.08, w / 2 - 0.08):
        parts.append(mk.box("Side", (0.14, d - 0.1, 7.6), (x, 0, 4.1), mat=wood, bevel=0.015, segments=1))
        parts.append(mk.box("Stile", (0.18, 0.06, 7.5), (x, -d / 2 + 0.05, 4.1), mat=edge))
    rng = random.Random(11)
    levels = [0.36 + k * 1.24 for k in range(6)]
    for level, z in enumerate(levels):
        parts.append(mk.box("Board", (w - 0.26, d - 0.16, 0.08), (0, 0, z), mat=edge))
        parts.append(mk.box("Lip", (w - 0.26, 0.03, 0.12), (0, -d / 2 + 0.09, z), mat=wood))
        parts += card_frame("Holder", 0, -d / 2 + 0.075, z - 0.005, brass, card, w=0.4, h=0.11)
        x = -w / 2 + 0.2
        end = w / 2 - 0.2
        run_tall = rng.uniform(0.86, 1.02)
        run_left = 0
        tone = rng.choice(books)
        while x < end - 0.08:
            if run_left == 0:  # (a set: the same height and binding for a few volumes)
                run_left = rng.randrange(3, 8)
                run_tall = rng.uniform(0.8, 1.06)
                tone = rng.choice(books)
                thick = rng.uniform(0.13, 0.2)
            run_left -= 1
            if rng.random() < 0.06:  # (a gap, the neighbour leaning into it)
                x += thick * 0.9
                parts.append(mk.box("Book", (thick, 1.2, run_tall), (x - thick * 0.3, -0.12, z + 0.04 + run_tall / 2), rot=(0, 9, 0), mat=tone))
                x += thick + 0.01
                continue
            tall = run_tall + rng.uniform(-0.02, 0.02)
            parts.append(mk.box("Book", (thick, 1.2, tall), (x + thick / 2, -0.12, z + 0.04 + tall / 2), mat=tone))
            if run_left % 2 == 0:
                parts.append(mk.box("Band", (thick * 0.9, 0.006, 0.05), (x + thick / 2, -0.724, z + 0.04 + tall * 0.78), mat=gilt))
            x += thick + 0.008
    parts += [mk.box("BayPlate", (0.6, 0.016, 0.16), (0, -d / 2 - 0.004, 7.8), mat=brass, bevel=0.004)]
    return parts, []


@prop("FilingCabinet", pivot="bottom", material="Metal", collide=True, texture=512)
def filing_cabinet():
    """A four drawer steel file in olive grey: a welded case on a recessed kick, each drawer with a chrome pull, thumb catch and card holder, a lock
    at the top corner, the paint worn at its edges."""
    body = pk.metal("File_Steel", (70, 76, 72), (100, 106, 100), rough=0.46, metallic=0.55)
    bright = pk.metal("File_Chrome", (126, 130, 134), (176, 180, 184), rough=0.3, metallic=1.0)
    dark = pk.metal("File_Iron", (18, 18, 20), (40, 40, 44), rough=0.5, metallic=0.6)
    card = mk.noisy("File_Label", srgb(206, 196, 170), srgb(232, 224, 200), roughness=0.9)
    typed = mk.flat("File_Print", srgb(30, 30, 34), 0.8)
    front = -1.0
    parts = [mk.box("Case", (2.4, 2.06, 4.76), (0, 0.07, 2.62), mat=body, bevel=0.03, segments=1),
             mk.box("Kick", (2.26, 1.9, 0.24), (0, 0.08, 0.12), mat=dark)]
    tall = 1.14
    for k in range(4):
        z = 0.3 + tall * (k + 0.5)
        parts.append(pk.rounded("Drawer", (2.24, 0.06, tall - 0.06), (0, front - 0.03, z), body, r=0.02))
        parts.append(mk.box("PullLip", (0.86, 0.06, 0.06), (0, front - 0.09, z + 0.1), mat=bright, bevel=0.015, segments=1))
        parts.append(mk.box("PullBack", (0.86, 0.03, 0.14), (0, front - 0.07, z + 0.06), mat=dark))
        parts.append(mk.box("Catch", (0.12, 0.05, 0.1), (0, front - 0.095, z + 0.0), mat=bright, bevel=0.012, segments=1))
        parts += card_frame("Label", 0, front - 0.06, z + 0.34, bright, card, w=0.62, h=0.2)
        parts.append(mk.box("Typed", (0.34, 0.005, 0.04), (0, front - 0.073, z + 0.34), mat=typed))
    parts.append(mk.cylinder("Lock", 0.055, 0.03, (0.94, front - 0.07, 4.76), rot=(90, 0, 0), mat=bright, verts=10))
    return parts, []
