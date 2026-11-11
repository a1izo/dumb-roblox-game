"""The sets of the six custom deaths remade as scene deaths (2026-11-11; the user's word of 2026-11-10: "remake
absolutely ALL other custom death scenes because their scenarios, camera work, vfx, animation and everything SUCKS").
Each sits in its own cell of the Scenes venue (plan.ORDER) and is drawn in its scene's space: the victim at the
origin facing -Z, y up.

    heart      A broken heart: an old stone bridge over a canal at night in the rain, a lamp at the parapet, the city's
               lit windows along both banks (sky Storm; the rain is the scene's)
    frost      Frozen where they stood: a frozen lake under the stars, snow drifts and bare trees along its shores
               (sky Night; the falling snow is the scene's)
    lightning  Struck by lightning: a bare hilltop in a storm, a lone dead oak, rocks, the hills falling away (sky Storm)
    chip       Choked on a potato chip: a dark study at night, the desk under its lamp, rain on the tall window
    clock      Their time ran out: a colossal clock face lying in a grey void, its numerals and its rim, gears hanging
               in the fog round it (sky Void; the hands are the scene's, they move)
    dark       Taken by the dark: a long hallway of an old house, doors down both sides, a bulb on a cord over the
               victim; the far end lost in black (the bulbs are the scene's: they flicker)
"""

import math
import random

from maps import kit, skyline
from maps.venues.scenes import models, parts
from maps.venues.scenes import plan as P


def at(cell):
    ox, oz = cell

    def W(x, y, z):
        return (ox + x, y, oz + z)

    return W


# A broken heart -----------------------------------------------------------------------------------------------------


def heart(s):
    ox, oz = P.HEART
    W = at(P.HEART)
    # the bridge's deck, worn wet paving, crossing the canal along X; its parapets front and back
    s.box("PaversWet", W(0, -0.5, 2.0), (60.0, 1.0, 9.0))
    for z, face in ((-2.6, -1), (6.6, 1)):
        s.box("RuinStone", W(0, 1.5, z), (60.0, 3.0, 0.9))
        s.box("RuinStone", W(0, 3.15, z), (60.4, 0.3, 1.3))
        for x in range(-28, 29, 7):
            s.box("RuinStone", W(x, 1.6, z), (1.5, 3.2, 1.5))
            s.box("RuinStone", W(x, 3.35, z), (1.8, 0.3, 1.8))
    # the bridge's face over the water: an arch under the victim, the spandrels in dressed stone
    for k in range(13):
        a0, a1 = math.pi * k / 13, math.pi * (k + 1) / 13
        for z in (-3.0, 7.0):
            pts = [W(-math.cos(a0) * 14, -1.0 - 0 * a0, z), W(-math.cos(a1) * 14, -1.0, z),
                   W(-math.cos(a1) * 14, -14 + math.sin(a1) * 11, z), W(-math.cos(a0) * 14, -14 + math.sin(a0) * 11, z)]
            parts.poly(s, "RuinStone", pts, (0, 0, -1 if z < 0 else 1))
    # the canal: dark water far below, its embankment walls, lit windows along both banks
    s.box("PondWater", W(0, -16.0, -60.0), (90.0, 0.2, 120.0))
    s.box("PondWater", W(0, -16.0, 70.0), (90.0, 0.2, 120.0))
    for x in (-24.0, 24.0):
        s.box("BrickDark", W(x, -8.0, -60.0), (2.0, 16.0, 120.0))
        s.box("BrickDark", W(x, -8.0, 70.0), (2.0, 16.0, 120.0))
    rng = random.Random(1201)
    for side in (-1, 1):
        z = -12.0
        while z > -160.0:
            d = rng.uniform(14.0, 22.0)
            poly = [(ox + side * 26, oz + z), (ox + side * 46, oz + z), (ox + side * 46, oz + z - d),
                    (ox + side * 26, oz + z - d)]
            skyline.block(s, poly, rng.randint(4, 8), random.Random(rng.random()), y=-16.0, lit=0.32,
                          styles=("NightBrick", "NightFlats"), detail=1, roof_mat="CityRoof", most=30)
            z -= d + 2.0
    # the lamp at the parapet beside the victim
    s.prop("LampPost", ox + 3.6, oz - 1.6, 0.0)


# Frozen where they stood --------------------------------------------------------------------------------------------


def frost(s):
    ox, oz = P.FROST
    W = at(P.FROST)

    def h(wx, wz):
        x, z = wx - ox, wz - oz
        r = math.hypot(x, z)
        shore = max(0.0, r - 70.0)
        return 0.0 if r < 70 else min(14.0, 0.05 * shore * shore * 0.12 + 1.2 * parts.noise2(x, z, 7, 3, 30))

    def step(wx, wz):
        return 4.0 if max(abs(wx - ox), abs(wz - oz)) < 90 else 10.0

    # the lake's ice, smooth and dark, and the snow on its shores rising round it
    s.box("Ice", W(0, -0.3, 0), (150.0, 0.6, 150.0))
    parts.heightfield(s, "Snow", ox - 240, oz - 240, ox + 240, oz + 240, step,
                      lambda wx, wz: h(wx, wz) if math.hypot(wx - ox, wz - oz) > 68 else -0.6)
    # cracks in the ice: fine pale lines branching out from under the victim's feet
    rng = random.Random(1301)
    for k in range(7):
        a = math.tau * k / 7 + rng.uniform(-0.3, 0.3)
        x, z = 0.6 * math.cos(a), 0.6 * math.sin(a)
        for j in range(6):
            a += rng.uniform(-0.45, 0.45)
            length = rng.uniform(1.2, 2.8)
            nx, nz = x + math.cos(a) * length, z + math.sin(a) * length
            s.box("WhiteTrim", W((x + nx) / 2, 0.012, (z + nz) / 2), (length, 0.02, 0.05),
                  math.degrees(math.atan2(-(nz - z), nx - x)))
            x, z = nx, nz
    # bare trees along the shores, dark against the snow
    for k in range(26):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(76.0, 140.0)
        wx, wz = ox + math.cos(a) * d, oz + math.sin(a) * d
        parts.bare_tree(s, "Bark", wx, wz, h(wx, wz), rng.uniform(18, 30), seed=1300 + k, levels=3,
                        trunk=rng.uniform(0.5, 0.9), spread=rng.uniform(26, 36), sides=6)
    # reeds frozen in the ice near the victim
    for k in range(60):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(5.0, 18.0)
        x, z = math.cos(a) * d, math.sin(a) * d + 6.0
        models.grass_clump(s, ox + x, oz + z, 0.0, seed=1350 + k, blades=6, height=(0.8, 1.8), spread=0.25, dry=0.9)


# Struck by lightning ------------------------------------------------------------------------------------------------


def lightning(s):
    ox, oz = P.LIGHTNING
    W = at(P.LIGHTNING)

    def h(wx, wz):
        x, z = wx - ox, wz - oz
        r = math.hypot(x, z)
        top = -0.012 * r * r if r < 30 else -10.8 - 0.55 * (r - 30)
        return max(-60.0, top + 0.6 * parts.noise2(x, z, 21, 3, 18) * min(1.0, r / 10.0))

    def step(wx, wz):
        d = max(abs(wx - ox), abs(wz - oz))
        return 2.0 if d < 30 else (5.0 if d < 90 else 12.0)

    parts.heightfield(s, "MeadowGrass", ox - 260, oz - 260, ox + 260, oz + 260, step, h)
    # the lone dead oak beside the victim, its roots in the hilltop
    parts.bare_tree(s, "Bark", ox - 5.0, oz - 3.0, h(ox - 5.0, oz - 3.0), 34.0, seed=1401, levels=5, trunk=1.3,
                    spread=34.0, lean=(0.08, 0.04))
    rng = random.Random(1402)
    # rocks breaking through the grass, a few stones of an old wall
    for k in range(18):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(5.0, 34.0)
        x, z = math.cos(a) * d, math.sin(a) * d
        if math.hypot(x, z) < 4.0:
            continue
        models.rock(s, "RockGrey", W(x, h(ox + x, oz + z) - 0.3, z), (rng.uniform(0.8, 2.6), rng.uniform(0.5, 1.6),
                                                                      rng.uniform(0.8, 2.2)), seed=1410 + k)
    for k in range(10):
        x = -14.0 + k * 2.4
        z = 9.0 + 0.4 * math.sin(k)
        s.box("RuinStone", W(x, h(ox + x, oz + z) + 0.5, z), (2.2, 1.0 + 0.5 * (k % 3), 1.0), rng.uniform(-6, 6))
    # grass tufts on the hilltop
    for k in range(240):
        a = rng.uniform(0, math.tau)
        d = 1.5 + abs(rng.gauss(0, 10))
        x, z = math.cos(a) * d, math.sin(a) * d
        models.grass_clump(s, ox + x, oz + z, h(ox + x, oz + z), seed=1450 + k, blades=6, height=(0.4, 1.0),
                           spread=0.3, dry=0.5)


# Choked on a potato chip ------------------------------------------------------------------------------------------


def chip(s):
    ox, oz = P.CHIP
    W = at(P.CHIP)
    hx, h0, h1, ceil = 11.0, -9.0, 9.0, 11.0  # the room: x -11..11, z -9..9
    s.box("WoodFloorDark", W(0, -0.5, 0), (2 * hx, 1.0, h1 - h0))
    kit.ceiling(s, ox - hx, oz + h0, ox + hx, oz + h1, ceil, "CeilingPlasterDark", beams=None)
    for x, face in ((-hx, 1), (hx, -1)):
        s.box("Damask", W(x - face * 0.5, ceil / 2, 0), (1.0, ceil, h1 - h0))
        s.box("WoodPanel", W(x + face * 0.06, 1.8, 0), (0.12, 3.6, h1 - h0))
    s.box("Damask", W(0, ceil / 2, h1 + 0.5), (2 * hx, ceil, 1.0))
    s.box("WoodPanel", W(0, 1.8, h1 - 0.06), (2 * hx, 3.6, 0.12))
    # the window wall behind the camera (-z): a tall window between bookshelves, rain beyond, the city's glow
    s.box("Damask", W(-7.5, ceil / 2, h0 - 0.5), (7.0, ceil, 1.0))
    s.box("Damask", W(7.5, ceil / 2, h0 - 0.5), (7.0, ceil, 1.0))
    s.box("Damask", W(0, 0.9, h0 - 0.5), (8.0, 1.8, 1.0))
    s.box("Damask", W(0, ceil - 0.6, h0 - 0.5), (8.0, 1.2, 1.0))
    s.box("WindowCool", W(0, 5.6, h0 - 0.9), (8.0, 7.6, 0.1))
    s.box("BlackTrim", W(0, 5.6, h0 - 0.75), (0.2, 7.6, 0.2))
    s.box("BlackTrim", W(0, 5.6, h0 - 0.75), (8.0, 0.2, 0.2))
    # the desk under its lamp (the victim stands behind it, the chip bag on it: the scene's), the chair pushed back
    s.prop("Desk", ox, oz - 2.6, 180.0)
    s.prop("OfficeChair", ox + 1.8, oz + 1.8, 200.0)
    s.prop("Bookshelf", ox - hx + 1.2, oz + 4.0, 90.0)
    s.prop("Bookshelf", ox - hx + 1.2, oz - 2.0, 90.0)
    s.prop("Bookshelf", ox + hx - 1.2, oz + 4.0, -90.0)
    s.prop("EvidenceBoard", ox, oz + h1 - 0.3, 0.0, 1.0, 3.0)


# Their time ran out -----------------------------------------------------------------------------------------------


def clock(s):
    ox, oz = P.CLOCK
    W = at(P.CLOCK)
    R = 34.0
    # the face: a great disc of pale stone lying in the void, a brass rim, the minute marks and twelve numerals
    s.lathe("MarbleWhite", W(0, -4.0, 0), [(R + 2.0, 0.0), (R + 2.0, 3.6), (R, 4.0), (0.0, 4.0)], 60)
    s.lathe("Brass", W(0, -0.1, 0), [(R + 2.4, 0.0), (R + 2.4, 0.9), (R + 0.4, 0.9), (R + 0.4, 0.4)], 60,
            caps=(False, False))
    for k in range(60):
        a = math.tau * k / 60
        long = k % 5 == 0
        r0 = R - (3.8 if long else 2.0)
        x, z = math.sin(a) * (r0 + R - 0.8) / 2, -math.cos(a) * (r0 + R - 0.8) / 2
        s.box("BlackTrim", W(x, 0.03, z), (0.5 if long else 0.22, 0.06, (R - 0.8 - r0)), -math.degrees(a))
    for k in range(12):
        a = math.tau * k / 12
        x, z = math.sin(a) * (R - 7.5), -math.cos(a) * (R - 7.5)
        # (a numeral as a cluster of strokes: I, V and X in bars, roughly as the hour's)
        n = k if k else 12
        strokes = {1: "I", 2: "II", 3: "III", 4: "IV", 5: "V", 6: "VI", 7: "VII", 8: "VIII", 9: "IX", 10: "X",
                   11: "XI", 12: "XII"}[n]
        width = 1.1 * len(strokes)
        for j, ch in enumerate(strokes):
            u = -width / 2 + 1.1 * (j + 0.5)
            px, pz = x + math.cos(a) * u, z + math.sin(a) * u
            if ch == "I":
                s.box("BlackTrim", W(px, 0.04, pz), (0.32, 0.08, 3.0), -math.degrees(a))
            else:
                for sgn in (-1, 1):
                    ang = -math.degrees(a) + sgn * (14 if ch == "V" else 30)
                    s.box("BlackTrim", W(px, 0.04, pz), (0.3, 0.08, 3.1), ang)
    # the hub the hands turn on
    s.lathe("Brass", W(0, 0.0, 0), [(1.8, 0.0), (1.8, 0.5), (1.0, 0.8), (0.4, 1.4), (0.0, 1.5)], 24)
    # gears hanging in the fog round it, at all heights
    rng = random.Random(1501)
    for k in range(16):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(48.0, 120.0)
        y = rng.uniform(-30.0, 40.0)
        s.prop("RustGear", ox + math.cos(a) * d, oz + math.sin(a) * d, rng.uniform(0, 360), rng.uniform(3.0, 7.0), y)


# Taken by the dark -------------------------------------------------------------------------------------------------


def dark(s):
    ox, oz = P.DARK
    W = at(P.DARK)
    hx, z0, z1, ceil = 4.5, -40.0, 60.0, 10.0  # the hall: x -4.5..4.5, from z -40 (ahead) to 60 (behind, into black)
    s.box("WoodFloorDark", W(0, -0.5, (z0 + z1) / 2), (2 * hx, 1.0, z1 - z0))
    s.box("CarpetRed", W(0, 0.02, (z0 + z1) / 2), (3.6, 0.04, z1 - z0))
    kit.ceiling(s, ox - hx, oz + z0, ox + hx, oz + z1, ceil, "CeilingPlasterDark", beams=None)
    for side in (-1, 1):
        x = side * hx
        s.box("Wallpaper", W(x + side * 0.5, ceil / 2, (z0 + z1) / 2), (1.0, ceil, z1 - z0))
        s.box("WoodPanel", W(x - side * 0.06, 1.7, (z0 + z1) / 2), (0.12, 3.4, z1 - z0))
        s.box("Wood", W(x - side * 0.12, 3.45, (z0 + z1) / 2), (0.24, 0.16, z1 - z0))
        s.box("Wood", W(x - side * 0.1, 0.25, (z0 + z1) / 2), (0.2, 0.5, z1 - z0))
        # doors down the hall, every 12 studs, shut, dark
        z = z0 + 8.0
        while z < z1 - 6:
            s.box("BlackTrim", W(x - side * 0.08, 3.6, z), (0.16, 7.4, 4.0))
            s.box("WoodFloorDark", W(x - side * 0.12, 3.4, z), (0.12, 6.8, 3.4))
            s.box("Brass", W(x - side * 0.25, 3.2, z + 1.2), (0.12, 0.2, 0.2))
            # a picture frame between the doors
            s.box("BlackTrim", W(x - side * 0.1, 5.6, z + 6.0), (0.12, 2.6, 2.0))
            s.box("PhotoPale", W(x - side * 0.17, 5.6, z + 6.0), (0.04, 2.1, 1.5))
            z += 12.0
    # the far end ahead: a door half open on grey light; behind, the hall runs into black
    s.box("Wallpaper", W(0, ceil / 2, z0 - 0.5), (2 * hx, ceil, 1.0))
    s.box("BlackTrim", W(0, 3.6, z0 + 0.05), (4.2, 7.4, 0.1))
    s.box("PanelCool", W(0.4, 3.4, z0 + 0.1), (2.2, 6.8, 0.05))
    s.box("Abyss", W(0, ceil / 2, z1 + 0.5), (2 * hx, ceil, 1.0))


def build(s):
    heart(s)
    frost(s)
    lightning(s)
    chip(s)
    clock(s)
    dark(s)
