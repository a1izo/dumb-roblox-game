"""The yokocho's and the river's props (set "Tokyo"): red paper lanterns, the strings of lanterns
between the cherry trees, a noren curtain, crates of empties, a yakitori grill, and a moored
pleasure boat. Built to the semi-real standard (propkit); they face -Y."""

import math

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop

WARM_LIGHT = (255, 232, 196)


def _lantern(prefix, x, y, z, r, h, paper, band, ribs=10):
    """A paper lantern at (x, y, z): the ribbed paper body (lathe), black lacquered caps, the
    ribs showing as fine rings."""
    profile = [(0.0, -h / 2), (r * 0.55, -h / 2), (r * 0.86, -h * 0.36), (r, -h * 0.12), (r, h * 0.12),
               (r * 0.86, h * 0.36), (r * 0.55, h / 2), (0.0, h / 2)]
    parts = [mk.lathe(prefix + "Paper", profile, (x, y, z), mat=paper, segments=20)]
    for k in range(1, ribs):
        t = k / ribs
        zz = -h / 2 + h * t
        rr = r * math.sin(math.pi * (0.18 + 0.64 * t)) * 1.005
        parts.append(mk.torus(prefix + "Rib", rr, 0.012, (x, y, z + zz), mat=band, major_segments=20, minor_segments=3))
    parts += [mk.cylinder(prefix + "CapT", r * 0.6, h * 0.08, (x, y, z + h / 2 + h * 0.03), mat=band, verts=16),
              mk.cylinder(prefix + "CapB", r * 0.6, h * 0.08, (x, y, z - h / 2 - h * 0.03), mat=band, verts=16)]
    return parts


@prop("Chochin", pivot="centre", material="Fabric", collide=False, texture=512, set="Tokyo",
      lights=[dict(at=(0, 0, -0.2), kind="point", color=(255, 150, 90), range=12, brightness=0.9)])
def chochin():
    """A red paper lantern hung from its hook: ribbed paper glowing warm, black caps, a tassel,
    居酒屋 brushed on its front."""
    band = pk.metal("CH_Lacquer", (14, 12, 12), (30, 26, 24), rough=0.35, metallic=0.1)
    ink = pk.plastic("CH_Ink", (20, 16, 14))
    parts = []
    glows = _lantern("CH_", 0, 0, 0, 0.52, 1.9, pk.glow("CH_Paper", (230, 60, 40), 2.6), band, ribs=9)
    parts += [g for g in glows if "Rib" in g.name or "Cap" in g.name]
    glows = [g for g in glows if g not in parts]
    parts += [mk.torus("Hook", 0.1, 0.025, (0, 0, 1.22), rot=(90, 0, 0), mat=band, major_segments=10, minor_segments=4),
              mk.tube("Cord", (0, 0, 1.05), (0, 0, 1.15), 0.02, mat=band, verts=4),
              mk.tube("Tassel", (0, 0, -1.02), (0, 0, -1.35), 0.05, mat=pk.plastic("CH_Tassel", (200, 30, 30)), verts=6)]
    parts += pk.label("Word", "居酒屋", 0.3, (0, -0.53, 0.05), ink, rot=(90, 0, 0))
    return parts, glows


@prop("LanternString", pivot="centre", material="Fabric", collide=False, texture=512, set="Tokyo",
      lights=[dict(at=(0, 0, -1.0), kind="point", color=(255, 190, 140), range=14, brightness=0.8)])
def lantern_string():
    """A string of paper lanterns 12 long, sagging between two trees: white and red lanterns in turn
    on a dark cord (the map stretches it to the span)."""
    cord = pk.rubber("LS_Cord")
    band = pk.metal("LS_Band", (20, 18, 18), (36, 32, 30), rough=0.4)
    parts = []
    points = []
    for k in range(17):
        t = k / 16
        points.append((-6.0 + 12.0 * t, 0, -0.9 * 4 * t * (1 - t)))
    for a, b in zip(points, points[1:]):
        parts.append(mk.tube("Cord", a, b, 0.025, mat=cord, verts=4))
    glows = []
    for k in range(7):
        t = (k + 0.5) / 7
        x = -6.0 + 12.0 * t
        z = -0.9 * 4 * t * (1 - t) - 0.55
        paper = pk.glow("LS_White", (250, 240, 220), 2.4) if k % 2 == 0 else pk.glow("LS_Red", (240, 70, 50), 2.4)
        made = _lantern(f"LS{k}_", x, 0, z, 0.24, 0.66, paper, band, ribs=5)
        parts += [p for p in made if "Rib" in p.name or "Cap" in p.name]
        glows += [p for p in made if "Paper" in p.name]
    return parts, glows


@prop("Noren", pivot="centre", material="Fabric", collide=False, texture=512, set="Tokyo")
def noren():
    """A noren split into four panels on its wooden pole, dyed indigo with the bar's name in
    white, hems a little uneven."""
    cloth = mk.noisy("NR_Cloth", srgb(24, 34, 70), srgb(36, 50, 96), scale=18, roughness=0.9)
    pole = mk.wood("NR_Pole", srgb(120, 84, 50), srgb(74, 50, 30))
    white = pk.plastic("NR_White", (240, 238, 230))
    parts = [mk.cylinder("Pole", 0.08, 5.8, (0, 0.05, 1.25), rot=(0, 90, 0), mat=pole, verts=10)]
    for k, word in enumerate(("や", "き", "と", "り")):
        x = -2.1 + k * 1.4
        drop = 2.4 - 0.05 * ((k * 7) % 3)
        parts.append(mk.box("Panel", (1.32, 0.04, drop), (x, 0, 1.2 - drop / 2), mat=cloth, bevel=0.01))
        parts += pk.label("Word", word, 0.6, (x, -0.03, 0.15), white)
    return parts, []


@prop("BeerCrates", pivot="bottom", material="Plastic", collide=True, texture=512, set="Tokyo")
def beer_crates():
    """Two plastic crates of empty bottles stacked by a door, handles cut in their ends."""
    crate = pk.plastic("BC_Crate", (180, 50, 30))
    glass = mk.noisy("BC_Bottle", srgb(70, 40, 12), srgb(110, 66, 24), scale=6, roughness=0.15)
    dark = pk.plastic("BC_Dark", (60, 20, 12))
    parts = []
    for z in (0.0, 1.55):
        parts.append(pk.rounded("Crate", (3.0, 1.9, 1.5), (0, 0, z + 0.75), crate, r=0.06))
        for sx in (-1, 1):
            parts.append(mk.box("Grip", (0.05, 0.8, 0.25), (sx * 1.51, 0, z + 1.15), mat=dark))
        for i in range(4):
            for j in range(2):
                x, y = -1.05 + i * 0.7, -0.45 + j * 0.9
                parts.append(mk.cylinder("Neck", 0.12, 0.35, (x, y, z + 1.6), mat=glass, verts=8))
    return parts, []


@prop("YakitoriGrill", pivot="bottom", material="Metal", collide=True, texture=512, set="Tokyo",
      lights=[dict(at=(0, 0, 4.2), kind="point", color=(255, 140, 60), range=8, brightness=0.7)])
def yakitori_grill():
    """A charcoal grill on a steel stand: glowing coals under a grate of skewers, a tray, a
    tin of sauce and a paper fan."""
    steel = pk.metal("YG_Steel", (70, 70, 74), (100, 100, 104))
    soot = pk.metal("YG_Soot", (22, 20, 20), (40, 36, 34), rough=0.8, metallic=0.2)
    meat = mk.noisy("YG_Meat", srgb(110, 50, 24), srgb(160, 90, 40), scale=30, roughness=0.6)
    wood = mk.wood("YG_Stick", srgb(190, 160, 110), srgb(140, 110, 70))
    parts = [mk.box("Box", (3.8, 1.8, 0.8), (0, 0, 3.4), mat=soot, bevel=0.05),
             mk.box("Shelf", (3.6, 1.6, 0.08), (0, 0, 1.2), mat=steel)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Leg", (0.12, 0.12, 3.0), (sx * 1.7, sy * 0.75, 1.5), mat=steel))
    for k in range(8):
        x = -1.6 + k * 0.45
        parts.append(mk.tube("Skewer", (x, -1.1, 3.88), (x, 0.9, 3.88), 0.02, mat=wood, verts=4))
        for j in range(3):
            parts.append(mk.box("Meat", (0.2, 0.22, 0.16), (x, -0.5 + j * 0.3, 3.95), mat=meat, bevel=0.05))
    parts += [mk.cylinder("Tin", 0.25, 0.5, (1.4, 0.3, 1.5), mat=steel, verts=12),
              mk.box("Fan", (0.7, 0.03, 0.6), (-1.2, 0.2, 1.6), rot=(70, 0, 0), mat=pk.plastic("YG_Fan", (230, 210, 170)))]
    glows = [mk.box("Coals", (3.4, 1.4, 0.15), (0, 0, 3.75), mat=pk.glow("YG_Coals", (255, 110, 40), 4))]
    return parts, glows


@prop("Boat", pivot="bottom", material="Wood", collide=False, texture=1024, set="Tokyo",
      lights=[dict(at=(0, 0, 5.5), kind="point", color=WARM_LIGHT, range=18, brightness=1.0)])
def boat():
    """A yakatabune pleasure boat moored for the night: a long hull, the tatami cabin with shoji
    windows lit from inside, red lanterns along the eaves, the curved roof."""
    hull = pk.paint("BT_Hull", (30, 34, 40), rough=0.4, wear=10)
    trim = pk.paint("BT_Trim", (180, 40, 30), rough=0.4)
    wood = mk.wood("BT_Wood", srgb(140, 98, 60), srgb(84, 56, 34))
    roof = pk.metal("BT_Roof", (40, 38, 36), (60, 56, 52), rough=0.5, metallic=0.2)
    band = pk.metal("BT_Band", (20, 18, 18), (36, 32, 30))
    L, W = 29.0, 7.0
    profile = [(-L / 2, 1.6), (-L / 2 + 3.0, 0.2), (L / 2 - 2.0, 0.2), (L / 2, 1.8), (L / 2, 2.4), (-L / 2 - 0.6, 2.6)]
    parts = [mk.extrude_shape("Hull", profile, W, rot=(90, 0, 90), mat=hull, bevel=0.2),
             mk.box("Deck", (W - 0.4, L - 2.0, 0.2), (0, 0.4, 2.5), mat=wood),
             mk.box("Gunwale", (W + 0.1, L - 1.5, 0.25), (0, 0.4, 2.65), mat=trim),
             mk.box("Cabin", (W - 1.0, L - 9.0, 3.2), (0, 1.5, 4.2), mat=wood, bevel=0.05),
             pk.rounded("Roof", (W + 0.4, L - 7.5, 0.5), (0, 1.5, 6.1), roof, r=0.25)]
    glows = []
    for sx in (-1, 1):
        glows.append(mk.box("Shoji", (0.05, L - 11.0, 2.0), (sx * (W / 2 - 0.48), 1.5, 4.3),
                            mat=pk.glow("BT_Shoji", (255, 226, 170), 2)))
        for k in range(10):
            parts.append(mk.box("Mullion", (0.08, 0.08, 2.0), (sx * (W / 2 - 0.45), -7.0 + k * 1.9, 4.3), mat=wood))
        for k in range(5):
            made = _lantern(f"BT{sx}{k}_", sx * (W / 2 + 0.1), -8.0 + k * 4.0, 5.2, 0.22, 0.6,
                            pk.glow("BT_Lantern", (240, 60, 40), 2.4), band, ribs=4)
            parts += [p for p in made if "Rib" in p.name or "Cap" in p.name]
            glows += [p for p in made if "Paper" in p.name]
    return parts, glows
