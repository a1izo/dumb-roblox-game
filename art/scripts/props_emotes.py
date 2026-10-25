"""The things the emote pack's emotes hold or set down (Core set; see props.py, 2026-10-14): Pre-Dawn
Bonk's club, Blindfold Lift's blindfold, Two-Finger Grip's phone, Chip and Pen's chip, Strawberry on
Top's slice of cake and its strawberry, Dice Tower's die, Chocolate Snap's bar, Forty Seconds' watch,
Mushroom Stroll's stick, Match Point's racket and ball, The Smiling Lord's cane, Cuffed Together's cuff, and
the radio on the Potato Chip's desk. The game scales each to the size it needs
(src/shared/Anim/EmoteProps.luau), so the sizes here are only the shapes' proportions. Small and plain,
like the shop's props, so their textures stay small."""

import math

from mathutils import Matrix

import modelkit as mk
import propkit as pk
from common import srgb
import props
from props import prop


@prop("Bat", pivot="centre", material="Wood", collide=False, texture=256)
def bat():
    """A plain wooden club, thick at the end and bound with dark cloth at the grip: Pre-Dawn Bonk's (the
    striker of a slit drum)."""
    wood = mk.noisy("Bt_Wood", srgb(118, 84, 52), srgb(170, 128, 84), roughness=0.6, kind="wood")
    grip = mk.flat("Bt_Cloth", srgb(40, 34, 30), 0.9)
    profile = [(0.0, -1.3), (0.07, -1.3), (0.08, -1.26), (0.07, -1.2), (0.075, -0.6), (0.11, 0.0), (0.16, 0.7),
               (0.18, 1.15), (0.15, 1.28), (0.0, 1.32)]
    return [mk.lathe("Club", profile, mat=wood, segments=16),
            mk.cylinder("Grip", 0.085, 0.5, (0, 0, -0.95), mat=grip, verts=16)], []


@prop("Blindfold", pivot="centre", material="Fabric", collide=False, texture=256)
def blindfold():
    """A band of black cloth tied round the head, the knot and its two loose ends at the back: Blindfold
    Lift's. Round Z (the head's up), the front facing -Y."""
    cloth = mk.noisy("Bf_Cloth", srgb(12, 12, 14), srgb(34, 34, 38), roughness=0.85, kind="cloth")
    band = [(0.64, -0.16), (0.69, -0.16), (0.69, 0.16), (0.64, 0.16), (0.64, -0.16)]
    parts = [mk.lathe("Band", band, mat=cloth, segments=28),
             mk.sphere("Knot", 0.1, (0, 0.72, 0.02), scale=(1.2, 0.8, 1.0), mat=cloth, segments=10, rings=6)]
    for side in (-1, 1):
        parts.append(mk.box("Tail", (0.12, 0.03, 0.42), (0.07 * side, 0.74, -0.2), rot=(-14, 0, 12 * side), mat=cloth,
                            bevel=0.01))
    return parts, []


@prop("Phone", pivot="centre", material="SmoothPlastic", collide=False, texture=256)
def phone():
    """An old black mobile, a bar with a small grey screen and a keypad: Two-Finger Grip's, held by a corner
    between two fingertips."""
    body = mk.noisy("Ph_Plastic", srgb(16, 16, 18), srgb(40, 40, 44), roughness=0.4, kind="plastic")
    screen = mk.flat("Ph_Screen", srgb(120, 130, 122), 0.2, kind="plastic")
    keys = mk.flat("Ph_Button", srgb(70, 70, 76), 0.5)
    parts = [pk.rounded("Body", (0.5, 0.12, 1.05), (0, 0, 0), body, r=0.05),
             mk.box("Screen", (0.36, 0.012, 0.34), (0, -0.064, 0.24), mat=screen)]
    for row in range(4):
        for col in range(3):
            parts.append(mk.box("Key", (0.09, 0.02, 0.06), (-0.12 + 0.12 * col, -0.064, -0.08 - 0.1 * row), mat=keys,
                                bevel=0.008))
    return parts, []


@prop("Chip", pivot="centre", material="SmoothPlastic", collide=False, texture=256)
def chip():
    """One potato chip, golden and curled like a saddle: Chip and Pen's."""
    potato = mk.noisy("Cp_Plastic", srgb(196, 150, 60), srgb(236, 196, 104), roughness=0.5, kind="plastic")
    grid = []
    for j in range(9):
        row = []
        for i in range(9):
            u, v = i / 8 * 2 - 1, j / 8 * 2 - 1
            x = 0.42 * u * math.sqrt(max(0.0, 1 - v * v / 2))
            y = 0.36 * v * math.sqrt(max(0.0, 1 - u * u / 2))
            row.append((x, y, 0.5 * (x * x - y * y)))
        grid.append(row)
    return [mk.sheet("Crisp", grid, potato, apart=0.012)], []


@prop("CakeSlice", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def cake_slice():
    """A slice of strawberry shortcake on a small white plate: Strawberry on Top's (the strawberry on top is
    a prop of its own, picked off it)."""
    plate = mk.flat("Ck_Plastic", srgb(236, 234, 228), 0.3)
    sponge = mk.noisy("Ck_Sponge", srgb(214, 172, 96), srgb(240, 206, 140), roughness=0.9, kind="matte")
    cream = mk.noisy("Ck_Cream", srgb(236, 230, 214), srgb(250, 248, 242), roughness=0.7, kind="matte")
    jam = mk.flat("Ck_Jam", srgb(170, 30, 40), 0.4)
    wedge = [(-0.38, 0.0), (0.38, -0.24), (0.38, 0.24)]
    parts = [mk.cylinder("Plate", 0.6, 0.05, (0, 0, 0.025), mat=plate, verts=24, bevel=0.012)]
    for mat, z, h in ((sponge, 0.05, 0.16), (cream, 0.21, 0.05), (jam, 0.26, 0.03), (sponge, 0.29, 0.14), (cream, 0.43, 0.07)):
        parts.append(mk.extrude_shape("Layer", wedge, h, loc=(0, 0, z + h / 2), mat=mat))
    parts.append(mk.sphere("Dollop", 0.07, (0.24, 0.0, 0.53), scale=(1, 1, 0.7), mat=cream, segments=10, rings=6))
    return parts, []


@prop("Strawberry", pivot="centre", material="SmoothPlastic", collide=False, texture=256)
def strawberry():
    """A ripe strawberry with its green cap: on top of Strawberry on Top's cake, then picked and eaten."""
    flesh = mk.noisy("Sb_Plastic", srgb(150, 18, 26), srgb(210, 40, 44), roughness=0.35, kind="plastic")
    leaf = mk.flat("Sb_Leaf", srgb(54, 110, 40), 0.6)
    profile = [(0.0, -0.22), (0.07, -0.19), (0.14, -0.08), (0.17, 0.04), (0.14, 0.13), (0.06, 0.17), (0.0, 0.17)]
    star = []
    for k in range(10):
        a = math.pi * k / 5
        r = 0.16 if k % 2 == 0 else 0.07
        star.append((r * math.cos(a), r * math.sin(a)))
    # (rounded, with a faint seeded grain: held up to the camera)
    berry = mk.lathe("Berry", profile, mat=flesh, segments=24)
    mk.subdivide(berry, 1)
    mk.displace_noise(berry, strength=0.006, scale=0.03, name="SbSeeds")
    return [berry,
            mk.extrude_shape("Cap", star, 0.02, loc=(0, 0, 0.175), mat=leaf),
            mk.tube("Stalk", (0, 0, 0.18), (0.02, 0, 0.26), 0.015, 0.012, mat=leaf, verts=6)], []


@prop("Die", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def die():
    """A white die with black pips, its edges rounded: Dice Tower's (stacked)."""
    bone = mk.noisy("Di_Plastic", srgb(226, 222, 212), srgb(246, 244, 238), roughness=0.35, kind="plastic")
    ink = mk.flat("Di_Pip", srgb(18, 18, 20), 0.4, kind="plastic")
    s = 0.4
    parts = [pk.rounded("Cube", (s, s, s), (0, 0, s / 2), bone, r=0.05)]
    d = 0.1
    patterns = {
        1: [(0, 0)],
        2: [(-d, -d), (d, d)],
        3: [(-d, -d), (0, 0), (d, d)],
        4: [(-d, -d), (-d, d), (d, -d), (d, d)],
        5: [(-d, -d), (-d, d), (0, 0), (d, -d), (d, d)],
        6: [(-d, -d), (-d, 0), (-d, d), (d, -d), (d, 0), (d, d)],
    }
    # (face normal, its number): opposite faces add up to seven
    faces = (((0, 0, 1), 1), ((0, 0, -1), 6), ((1, 0, 0), 3), ((-1, 0, 0), 4), ((0, -1, 0), 2), ((0, 1, 0), 5))
    for (nx, ny, nz), number in faces:
        for a, b in patterns[number]:
            if nz:
                at = (a, b, s / 2 + nz * s / 2)
            elif nx:
                at = (nx * s / 2, a, s / 2 + b)
            else:
                at = (a, ny * s / 2, s / 2 + b)
            flat = (0.35 if nx else 1.0, 0.35 if ny else 1.0, 0.35 if nz else 1.0)
            parts.append(mk.sphere("Pip", 0.035, at, scale=flat, mat=ink, segments=8, rings=4))
    return parts, []


@prop("ChocolateBar", pivot="centre", material="SmoothPlastic", collide=False, texture=256)
def chocolate_bar():
    """A bar of dark chocolate in a deep red wrapper, the paper and foil torn back from its top to show the
    squares: Chocolate Snap's."""
    choc = mk.noisy("Cb_Plastic", srgb(46, 26, 16), srgb(80, 48, 30), roughness=0.4, kind="plastic")
    paper = mk.flat("Cb_Paper", srgb(110, 20, 28), 0.7)
    foil = mk.flat("Cb_Foil", srgb(190, 190, 196), 0.25, metallic=1.0)
    parts = [mk.box("Wrapper", (0.46, 0.12, 0.72), (0, 0, -0.16), mat=paper, bevel=0.01),
             mk.box("Foil", (0.47, 0.13, 0.08), (0, 0, 0.22), rot=(0, 4, 0), mat=foil, bevel=0.01)]
    for col in (-0.105, 0.105):
        for row, z in enumerate((0.33, 0.5)):
            parts.append(pk.rounded("Square", (0.19, 0.09, 0.15), (col, 0, z), choc, r=0.02))
    return parts, []


def _square_band(tag, inner, outer, half_height, mat):
    """A band round Z with a square inside `inner` studs from the middle to each flat side, open through the
    middle: an R6 arm is a square 1 stud across, so a round strap lets its corners through. Four flat sides (a
    lathe would cap the hole and round the shading)."""
    t = outer - inner
    mid = (inner + outer) / 2
    h = half_height * 2
    return [mk.box(tag + "Front", (outer * 2, t, h), (0, -mid, 0), mat=mat, bevel=0.01),
            mk.box(tag + "Back", (outer * 2, t, h), (0, mid, 0), mat=mat, bevel=0.01),
            mk.box(tag + "Left", (t, inner * 2, h), (-mid, 0, 0), mat=mat, bevel=0.01),
            mk.box(tag + "Right", (t, inner * 2, h), (mid, 0, 0), mat=mat, bevel=0.01)]


@prop("Wristwatch", pivot="centre", material="Metal", collide=False, texture=256)
def wristwatch():
    """A plain steel watch on a black leather strap, round the left wrist: Forty Seconds'. The strap goes
    round Z (along the arm) and lies flat on the arm's four sides (2026-10-17: it was round, and the square arm's
    corners came through it); the face looks out at -Y."""
    steel = mk.noisy("Ww_Steel", srgb(120, 122, 128), srgb(186, 188, 194), roughness=0.25, metallic=1.0)
    strap = mk.noisy("Ww_Leather", srgb(14, 14, 16), srgb(36, 34, 34), roughness=0.6, kind="leather")
    dial = mk.flat("Ww_Face", srgb(232, 228, 218), 0.3, kind="plastic")
    hands = mk.flat("Ww_Iron", srgb(20, 20, 22), 0.4, metallic=0.8)
    parts = [*_square_band("Strap", 0.53, 0.58, 0.1, strap),
             mk.cylinder("Case", 0.22, 0.09, (0, -0.625, 0), rot=(90, 0, 0), mat=steel, verts=20, bevel=0.015),
             mk.cylinder("Dial", 0.185, 0.01, (0, -0.675, 0), rot=(90, 0, 0), mat=dial, verts=20),
             mk.box("Hour", (0.02, 0.006, 0.1), (0.0, -0.682, 0.04), mat=hands),
             mk.box("Minute", (0.015, 0.006, 0.15), (0.05, -0.682, -0.03), rot=(0, 40, 0), mat=hands)]
    return parts, []


@prop("Cuff", pivot="centre", material="Metal", collide=False, texture=256)
def cuff():
    """One steel handcuff closed round an R6 wrist: Cuffed Together's, one on each of the two chained wrists,
    the chain hung from the ring on its outer side. A square band round Z (the arm), the lock at -Y, the ring at
    +X (in the game, the arm's outside for a left wrist: turned round for a right one)."""
    steel = mk.noisy("Cf_Steel", srgb(88, 90, 96), srgb(170, 172, 178), scale=25, roughness=0.25, metallic=1.0)
    parts = [*_square_band("Band", 0.53, 0.6, 0.11, steel),
             mk.box("Lock", (0.36, 0.08, 0.2), (0, -0.64, 0), mat=steel, bevel=0.02),
             mk.box("Hinge", (0.12, 0.1, 0.22), (0, 0.64, 0), mat=steel, bevel=0.02),
             mk.torus("Ring", 0.07, 0.022, (0.68, 0, 0), rot=(90, 0, 0), mat=steel, major_segments=14,
                      minor_segments=6)]
    return parts, []


@prop("WalkingStick", pivot="centre", material="Wood", collide=False, texture=256)
def walking_stick():
    """A crooked branch for a walking stick, with a small red-capped mushroom tied near its top: Mushroom
    Stroll's, carried over the shoulder."""
    bark = mk.noisy("Ws_Bark", srgb(70, 52, 38), srgb(112, 88, 64), roughness=0.8, kind="bark")
    cap = mk.noisy("Ws_Cap", srgb(150, 24, 26), srgb(196, 44, 40), roughness=0.5, kind="plastic")
    pale = mk.flat("Ws_Stalk", srgb(226, 218, 200), 0.7)
    spots = mk.flat("Ws_Spot", srgb(240, 236, 226), 0.6)
    bends = [(0, 0, -2.0), (0.06, 0, -0.7), (-0.05, 0, 0.6), (0.08, 0, 1.9)]
    parts = []
    for (a, b), r in zip(zip(bends, bends[1:]), (0.11, 0.1, 0.09)):
        parts.append(mk.tube("Stick", a, b, r, r * 0.92, mat=bark, verts=8))
    parts.append(mk.tube("Twig", (0.0, 0, 0.2), (0.22, 0.02, 0.5), 0.03, 0.015, mat=bark, verts=6))
    parts.append(mk.tube("Mushroom", (0.1, 0, 1.5), (0.26, 0, 1.76), 0.05, 0.045, mat=pale, verts=8))
    parts.append(mk.sphere("Cap", 0.24, (0.3, 0, 1.82), scale=(1, 1, 0.55), mat=cap, segments=14, rings=7))
    for k in range(5):
        a = 2 * math.pi * k / 5
        parts.append(mk.sphere("Spot", 0.035, (0.3 + 0.13 * math.cos(a), 0.13 * math.sin(a), 1.9), mat=spots,
                               segments=6, rings=4))
    return parts, []


@prop("Cane", pivot="centre", material="SmoothPlastic", collide=False, texture=256)
def cane():
    """A gentleman's cane, black lacquer with a silver knob and tip: The Smiling Lord's."""
    lacquer = mk.noisy("Cn_Plastic", srgb(12, 12, 14), srgb(34, 34, 38), roughness=0.25, kind="plastic")
    silver = mk.noisy("Cn_Steel", srgb(150, 152, 158), srgb(206, 208, 214), roughness=0.2, metallic=1.0)
    return [mk.tube("Shaft", (0, 0, -1.1), (0, 0, 1.02), 0.05, 0.055, mat=lacquer, verts=12),
            mk.sphere("Knob", 0.11, (0, 0, 1.1), scale=(1, 1, 0.85), mat=silver, segments=14, rings=8),
            mk.cylinder("Collar", 0.07, 0.08, (0, 0, 0.98), mat=silver, verts=12),
            mk.cylinder("Tip", 0.055, 0.1, (0, 0, -1.12), mat=silver, verts=12)], []


@prop("Racket", pivot="centre", material="Wood", collide=False, texture=256)
def racket():
    """An old wooden tennis racket with gut strings and a leather grip: Match Point's (each player holds one).
    Along Z, the strings in the XZ plane."""
    wood = mk.noisy("Rk_Wood", srgb(150, 110, 70), srgb(196, 154, 106), roughness=0.5, kind="wood")
    gut = mk.flat("Rk_String", srgb(230, 222, 196), 0.6)
    grip = mk.noisy("Rk_Leather", srgb(40, 28, 22), srgb(70, 52, 40), roughness=0.7, kind="leather")
    width, height, centre = 0.4, 0.52, 0.62
    frame = mk.torus("Frame", 0.5, 0.045, mat=wood, major_segments=32, minor_segments=6)
    # (made round Z: stood up into the XZ plane, stretched to an oval and lifted, in the mesh itself)
    frame.data.transform(Matrix.Translation((0, 0, centre)) @ Matrix.Diagonal((width / 0.5, 1.0, height / 0.5, 1.0))
                         @ Matrix.Rotation(math.radians(90), 4, "X"))
    parts = [frame]
    for k in range(-3, 4):
        x = k * 0.1
        half = height * math.sqrt(max(0.0, 1 - (x / width) ** 2))
        parts.append(mk.box("String", (0.012, 0.012, 2 * half), (x, 0, centre), mat=gut))
    for k in range(-4, 5):
        z = k * 0.1
        half = width * math.sqrt(max(0.0, 1 - (z / height) ** 2))
        parts.append(mk.box("String", (2 * half, 0.012, 0.012), (0, 0, centre + z), mat=gut))
    for side in (-1, 1):
        parts.append(mk.tube("Throat", (0.16 * side, 0, centre - height + 0.04), (0.03 * side, 0, -0.02), 0.04, 0.035,
                             mat=wood, verts=8))
    # (the handle long enough for a whole fist and a bit below it: 1.3 studs)
    parts.append(pk.rounded("Handle", (0.13, 0.12, 1.3), (0, 0, -0.675), grip, r=0.03))
    parts.append(pk.rounded("Butt", (0.16, 0.15, 0.06), (0, 0, -1.34), wood, r=0.02))
    return parts, []


@prop("TennisBall", pivot="centre", material="Fabric", collide=False, texture=256)
def tennis_ball():
    """A tennis ball, yellow-green felt with its pale seam: Match Point's."""
    felt = mk.noisy("Tb_Felt", srgb(196, 214, 60), srgb(222, 236, 96), roughness=0.95, kind="cloth")
    seam = mk.flat("Tb_Rubber", srgb(236, 236, 226), 0.6)
    parts = [mk.sphere("Ball", 0.3, mat=felt, segments=20, rings=12)]
    a, b = 0.7, 0.3
    points = []
    for i in range(33):
        t = 2 * math.pi * i / 32
        x = a * math.cos(t) + b * math.cos(3 * t)
        y = a * math.sin(t) - b * math.sin(3 * t)
        z = 2 * math.sqrt(a * b) * math.sin(2 * t)
        n = math.sqrt(x * x + y * y + z * z)
        points.append((0.302 * x / n, 0.302 * y / n, 0.302 * z / n))
    for p, q in zip(points, points[1:]):
        parts.append(mk.tube("Seam", p, q, 0.012, 0.012, mat=seam, verts=5))
    return parts, []


@prop("Radio", pivot="bottom", material="SmoothPlastic", collide=False, texture=256)
def radio():
    """A small silver portable radio of the 2000s, a round speaker on the left of its black face, the tuning dial
    and two knobs on the right, a carrying handle and a telescopic aerial: on Light's desk in Diavolo's Potato
    Chip (on the right; the notebook and the bag of crisps on the left). The face looks out at -Y."""
    body = mk.noisy("Rd_Body", srgb(132, 134, 140), srgb(188, 190, 196), scale=12, roughness=0.35, metallic=0.55,
                    kind="plastic")
    face = mk.flat("Rd_Face", srgb(22, 22, 25), 0.5, kind="plastic")
    grille = mk.banded("Rd_Grille", srgb(46, 46, 50), srgb(12, 12, 14), frequency=70, axis="Z", roughness=0.7)
    chrome = mk.flat("Rd_Chrome", srgb(196, 198, 204), 0.2, metallic=1.0)
    needle = mk.flat("Rd_Needle", srgb(190, 30, 30), 0.4)
    dial = mk.emissive("Rd_Dial", srgb(255, 196, 120), 1.6)
    parts = [
        pk.rounded("Body", (1.4, 0.5, 0.85), (0, 0, 0.425), body, r=0.07),
        mk.box("Face", (1.3, 0.02, 0.66), (0, -0.252, 0.4), mat=face, bevel=0.01),
        mk.cylinder("Speaker", 0.25, 0.02, (-0.33, -0.266, 0.4), rot=(90, 0, 0), mat=grille, verts=28),
        mk.torus("SpeakerRim", 0.255, 0.018, (-0.33, -0.268, 0.4), rot=(90, 0, 0), mat=chrome, major_segments=28,
                 minor_segments=5),
        mk.box("Needle", (0.014, 0.008, 0.13), (0.24, -0.27, 0.56), mat=needle),
        mk.cylinder("Knob", 0.075, 0.07, (0.18, -0.29, 0.24), rot=(90, 0, 0), mat=chrome, verts=16, bevel=0.01),
        mk.cylinder("Knob", 0.075, 0.07, (0.46, -0.29, 0.24), rot=(90, 0, 0), mat=chrome, verts=16, bevel=0.01),
        mk.tube("Handle", (-0.5, 0.0, 0.84), (-0.46, 0.0, 1.06), 0.035, 0.035, mat=face, verts=8),
        mk.tube("Handle", (-0.46, 0.0, 1.06), (0.46, 0.0, 1.06), 0.035, 0.035, mat=face, verts=8),
        mk.tube("Handle", (0.46, 0.0, 1.06), (0.5, 0.0, 0.84), 0.035, 0.035, mat=face, verts=8),
        mk.tube("Aerial", (0.6, 0.12, 0.84), (0.98, 0.22, 1.9), 0.022, 0.012, mat=chrome, verts=6),
        mk.sphere("AerialTip", 0.03, (0.98, 0.22, 1.9), mat=chrome, segments=8, rings=5),
    ]
    for x in (-0.55, 0.55):
        parts.append(mk.box("Foot", (0.2, 0.36, 0.04), (x, 0, -0.0), mat=face, bevel=0.01))
    return parts, [mk.box("Dial", (0.52, 0.012, 0.16), (0.31, -0.264, 0.56), mat=dial)]


# The signature props (the shop overhaul's B6, the owner's Q33: 2026-10-21) --------------------------------------

def _bend_brim(obj, inner, outer, front=0.0, sides=0.0):
    """Bends a lathed brim (the vertices between radius `inner` and `outer`): `front` studs down at the front edge
    (-Y), `sides` studs up at the sides (X), easing in from the crown."""
    for v in obj.data.vertices:
        x, y = v.co.x, v.co.y
        r = math.hypot(x, y)
        if r <= inner or r < 1e-6:
            continue
        u = min(1.0, (r - inner) / (outer - inner))
        v.co.z += u * u * (sides * (x / r) ** 2 - front * max(0.0, -y / r) ** 1.5)


@prop("Fedora", pivot="centre", material="Fabric", collide=False, texture=256)
def fedora():
    """A white felt fedora with a black band, its brim snapped down at the front: Impossible Lean's (Smooth
    Criminal). Round Z (the head's up), the front facing -Y; it sits on the head, the head inside the crown."""
    felt = mk.noisy("Fd_Felt", srgb(222, 220, 214), srgb(246, 244, 238), roughness=0.85, kind="cloth")
    band = mk.noisy("Fd_Band", srgb(10, 10, 12), srgb(30, 30, 34), roughness=0.5, kind="cloth")
    hat = mk.lathe("Hat", [(0.0, 0.02), (0.96, 0.0), (1.0, 0.035), (0.97, 0.07), (0.69, 0.085), (0.68, 0.3),
                           (0.65, 0.58), (0.58, 0.76), (0.36, 0.8), (0.18, 0.7), (0.0, 0.69)], mat=felt, segments=40)
    _bend_brim(hat, 0.7, 1.0, front=0.1, sides=0.06)
    ribbon = mk.lathe("Band", [(0.688, 0.09), (0.702, 0.09), (0.692, 0.26), (0.678, 0.26), (0.688, 0.09)], mat=band,
                      segments=40)
    bow = mk.box("Bow", (0.05, 0.16, 0.13), (0.702, 0.12, 0.175), mat=band, bevel=0.015)
    return [hat, ribbon, bow], []


@prop("TopHat", pivot="centre", material="Fabric", collide=False, texture=256)
def top_hat():
    """A tall black silk top hat, flared a little at the top, a dull satin band, the brim curled up at the sides:
    The Smiling Lord's. Round Z, the front facing -Y; the head inside the crown."""
    silk = mk.noisy("Th_Silk", srgb(14, 14, 16), srgb(34, 34, 38), roughness=0.35, kind="cloth")
    satin = mk.noisy("Th_Satin", srgb(30, 30, 34), srgb(50, 50, 56), roughness=0.55, kind="cloth")
    hat = mk.lathe("Hat", [(0.0, 0.02), (0.9, 0.0), (0.94, 0.04), (0.9, 0.075), (0.66, 0.09), (0.645, 0.2),
                           (0.655, 0.7), (0.685, 1.05), (0.665, 1.08), (0.0, 1.08)], mat=silk, segments=40)
    _bend_brim(hat, 0.67, 0.94, sides=0.09)
    ribbon = mk.lathe("Band", [(0.652, 0.1), (0.664, 0.1), (0.662, 0.3), (0.65, 0.3), (0.652, 0.1)], mat=satin,
                      segments=40)
    return [hat, ribbon], []


@prop("Tailcoat", pivot="centre", material="Fabric", collide=False, texture=256)
def tailcoat():
    """The tails of a black evening coat, hung from the waist at the back to the backs of the knees and split up
    the middle, cut away at the outer corners, with two buttons at the waist: The Smiling Lord's. Behind a torso:
    the front faces -Y, so the tails are seen from +Y."""
    wool = mk.noisy("Tc_Wool", srgb(12, 12, 14), srgb(30, 30, 34), roughness=0.8, kind="cloth")
    button = mk.flat("Tc_Button", srgb(20, 20, 22), 0.3)
    parts = [mk.box("Waist", (1.94, 0.08, 0.22), (0, 0, -0.11), mat=wool, bevel=0.02)]
    for side in (-1, 1):
        shape = [(side * x, y) for x, y in ((0.05, 0.0), (0.92, 0.0), (0.8, -1.2), (0.5, -2.05), (0.3, -2.1),
                                           (0.1, -1.6), (0.05, -0.8))]
        if side < 0:
            shape.reverse()
        parts.append(mk.extrude_shape("Tail", shape, 0.07, (0, 0, 0), rot=(94, 0, 3 * side), mat=wool, bevel=0.015))
        parts.append(mk.sphere("Button", 0.05, (0.24 * side, 0.06, -0.12), mat=button, segments=10, rings=6))
    return parts, []


@prop("Cravat", pivot="centre", material="Fabric", collide=False, texture=256)
def cravat():
    """A white silk cravat at the throat, a soft knot with two folds falling over the shirt front and a small gold
    pin: The Smiling Lord's. The front faces -Y."""
    silk = mk.noisy("Cr_Silk", srgb(232, 230, 224), srgb(250, 250, 246), roughness=0.4, kind="cloth")
    gold = mk.noisy("Cr_Gold", srgb(170, 130, 50), srgb(222, 184, 96), roughness=0.3, metallic=1.0)
    parts = [mk.sphere("Knot", 0.13, (0, 0, 0.12), scale=(1.35, 0.7, 1.0), mat=silk, segments=14, rings=8)]
    for side in (-1, 1):
        parts.append(mk.box("Fold", (0.2, 0.06, 0.36), (0.06 * side, 0.02, -0.1), rot=(0, 9 * side, 0), mat=silk,
                            bevel=0.03))
    parts.append(mk.sphere("Pin", 0.035, (0, -0.07, 0.0), mat=gold, segments=8, rings=6))
    return parts, []


@prop("Glove", pivot="centre", material="Fabric", collide=False, texture=256)
def glove():
    """A white cotton evening glove over the end of an R6 arm (its fist), with a turned-back cuff and two small
    pearl buttons: The Smiling Lord's, one on each hand. Along Z (the arm's length), the cuff at the top."""
    cotton = mk.noisy("Gl_Cotton", srgb(232, 230, 224), srgb(248, 248, 244), roughness=0.85, kind="cloth")
    pearl = mk.flat("Gl_Pearl", srgb(236, 232, 222), 0.3)
    return [pk.rounded("Hand", (1.04, 1.04, 0.56), (0, 0, 0), cotton, r=0.06),
            pk.rounded("Cuff", (1.1, 1.1, 0.13), (0, 0, 0.31), cotton, r=0.04),
            mk.sphere("Button", 0.035, (0.2, -0.56, 0.3), mat=pearl, segments=8, rings=6),
            mk.sphere("Button", 0.035, (0.32, -0.56, 0.3), mat=pearl, segments=8, rings=6)], []


# The emote wheel's revolver ------------------------------------------------------------------------------------------

# The wheel (UI/Wheel, the owner's pick 2 of 2026-10-21: a snub barrel and a bird's-head grip) shows this in a
# ViewportFrame round its eight chambers: the cylinder seen from the front, the gun's frame laid round it as on the
# review page (the barrel out to the right, the hammer's spur over the top left, the grip down to the bottom left).
# Studs here are the wheel's pixels / 100: the cylinder 1.69 across its radius, the chambers' middles 1.24 out, each
# chamber 0.36 round, so the wheel's plates (66 px) sit in their mouths. The front faces -Y; the cylinder is a piece
# of its own ("Cylinder") that the wheel turns about its hinge, the middle of its front face. (The owner, 2026-10-24:
# the flat drawing "looks really low quality"; the cylinder spins a little as the wheel opens.)
WHEEL_R = 1.69
WHEEL_CHAMBERS = 8
WHEEL_RING = 1.24
WHEEL_BORE = 0.36
WHEEL_FRONT = -0.55  # the cylinder's front face (y); its back is at +0.55


def _carve(obj, cutters):
    """obj less every cutter (exact booleans, applied); the cutters go."""
    import bpy

    for cutter in cutters:
        mod = obj.modifiers.new("Carve", "BOOLEAN")
        mod.operation = "DIFFERENCE"
        mod.solver = "EXACT"
        mod.object = cutter
        cutter.hide_render = True
        cutter.hide_viewport = True
    depsgraph = bpy.context.evaluated_depsgraph_get()
    mesh = bpy.data.meshes.new_from_object(obj.evaluated_get(depsgraph))
    obj.modifiers.clear()
    obj.data = mesh
    # (the cut faces come with the cutters' empty material slots: they take the body's)
    first = next((m for m in mesh.materials if m is not None), None)
    for i, material in enumerate(mesh.materials):
        if material is None:
            mesh.materials[i] = first
    for cutter in cutters:
        bpy.data.objects.remove(cutter, do_unlink=True)
    for poly in obj.data.polygons:
        poly.use_smooth = False
    return obj


def _curve(points, steps=6):
    """A closed smooth outline through `points` [(x, z)] (Catmull-Rom), for an extruded shape."""
    out = []
    n = len(points)
    for i in range(n):
        p0, p1, p2, p3 = points[i - 1], points[i], points[(i + 1) % n], points[(i + 2) % n]
        for s in range(steps):
            t = s / steps
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * t
                                    + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * t2
                                    + (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * t3) for k in range(2)))
    return out


def _upright(name, outline, depth, y, mat, bevel=0.0):
    """An outline [(x, z)] in the picture's plane, `depth` thick along Y, its middle at y."""
    # (extrude_shape lays the outline in XY and extrudes along Z; turned +90 about X, its Y goes to Z)
    return mk.extrude_shape(name, list(outline), depth, (0, y, 0), rot=(90, 0, 0), mat=mat, bevel=bevel)


@prop("WheelRevolver", pivot="centre", material="Metal", collide=False, texture=1024)
def wheel_revolver():
    """The emote wheel's revolver: a blued snub-nosed frame round a bright steel cylinder of eight chambers, a
    walnut bird's-head grip with a checkered panel and a steel butt cap. Front view: the cylinder's face to -Y."""
    blued = pk.metal("WR_Blued", (30, 34, 44), (64, 70, 86), rough=0.3, metallic=0.9, scale=26)
    steel = pk.metal("WR_Steel", (128, 132, 142), (180, 184, 194), rough=0.2, metallic=0.95, scale=30)
    bore = mk.flat("WR_Bore", srgb(9, 9, 11), 0.9)
    walnut = mk.wood("WR_Walnut", srgb(138, 86, 46), srgb(72, 40, 20), scale=4.0, rings=14.0, roughness=0.45)
    checker = mk.noisy("WR_Checker", srgb(54, 32, 16), srgb(96, 60, 32), scale=90.0, detail=2.0, roughness=0.75)
    knurl = mk.noisy("WR_Knurl", srgb(16, 18, 24), srgb(52, 56, 68), scale=120.0, detail=2.0, roughness=0.5,
                     metallic=0.8)
    length = -2 * WHEEL_FRONT

    # The cylinder: chambers bored from the front with a chamfer at each mouth, the bore down the middle, a flute
    # between each two chambers right through to the front, the front edge bevelled.
    body = mk.cylinder("Cylinder", WHEEL_R, length, (0, 0, 0), rot=(90, 0, 0), mat=steel, verts=96)
    cutters = []
    for k in range(WHEEL_CHAMBERS):
        a = math.radians(k * 360 / WHEEL_CHAMBERS)
        x, z = math.sin(a) * WHEEL_RING, math.cos(a) * WHEEL_RING
        cutters.append(mk.cylinder("ChamberCut", WHEEL_BORE, 1.4, (x, WHEEL_FRONT, z), rot=(90, 0, 0), verts=40))
        cutters.append(mk.cylinder("MouthCut", WHEEL_BORE, 0.16, (x, WHEEL_FRONT - 0.01, z), rot=(90, 0, 0), verts=40,
                                   radius2=WHEEL_BORE + 0.09))
        f = math.radians((k + 0.5) * 360 / WHEEL_CHAMBERS)
        cutters.append(mk.cylinder("FluteCut", 0.3, 2.0, (math.sin(f) * (WHEEL_R + 0.17), 0.1,
                                                          math.cos(f) * (WHEEL_R + 0.17)), rot=(90, 0, 0), verts=32))
    cutters.append(mk.cylinder("BoreCut", 0.66, 0.6, (0, WHEEL_FRONT, 0), rot=(90, 0, 0), verts=48))
    cutters.append(mk.cylinder("BoreMouth", 0.66, 0.12, (0, WHEEL_FRONT - 0.01, 0), rot=(90, 0, 0), verts=48,
                               radius2=0.74))
    _carve(body, cutters)
    mk.add_bevel(body, 0.022, 2)
    cylinder = [body]
    for k in range(WHEEL_CHAMBERS):
        a = math.radians(k * 360 / WHEEL_CHAMBERS)
        x, z = math.sin(a) * WHEEL_RING, math.cos(a) * WHEEL_RING
        # the chamber's dark floor
        cylinder.append(mk.cylinder("ChamberFloor", WHEEL_BORE - 0.005, 0.02, (x, WHEEL_FRONT + 0.68, z),
                                    rot=(90, 0, 0), mat=bore, verts=32))
    # the bore's floor, and the ejector rod's end in it
    cylinder.append(mk.cylinder("BoreFloor", 0.655, 0.02, (0, WHEEL_FRONT + 0.29, 0), rot=(90, 0, 0), mat=bore,
                                verts=48))
    cylinder.append(mk.cylinder("Rod", 0.2, 0.3, (0, WHEEL_FRONT + 0.14, 0), rot=(90, 0, 0), mat=blued, verts=24,
                                bevel=0.02))

    # The frame behind it: the recoil shield (a ring of blued steel round the cylinder), the lug to the barrel.
    parts = [mk.cylinder("Shield", WHEEL_R + 0.17, 0.24, (0, -WHEEL_FRONT + 0.14, 0), rot=(90, 0, 0), mat=blued,
                         verts=96, bevel=0.03),
             pk.rounded("Lug", (0.62, 0.5, 0.92), (WHEEL_R + 0.1, 0.62, 0.32), blued, r=0.08)]
    # The snub barrel out to the right a little over the middle, its rib, the front sight and the ejector shroud
    # under it; the crown a ring of brighter steel at the muzzle.
    bz = 0.42
    # (short enough to stay in the wheel's panel, 470 px across: its crown 2.25 studs, 225 px, out from the middle)
    parts.append(mk.cylinder("Barrel", 0.27, 0.64, (1.91, 0.55, bz), rot=(0, 90, 0), mat=blued, verts=40, bevel=0.03))
    parts.append(pk.rounded("Rib", (0.64, 0.18, 0.12), (1.91, 0.55, bz + 0.28), blued, r=0.04))
    parts.append(mk.extrude_shape("Sight", [(0.0, 0.0), (0.14, 0.0), (0.12, 0.14), (0.05, 0.16)], 0.08,
                                  (2.02, 0.55, bz + 0.33), rot=(90, 0, 0), mat=blued, bevel=0.01))
    parts.append(pk.rounded("Shroud", (0.58, 0.42, 0.34), (1.9, 0.55, bz - 0.36), blued, r=0.12))
    parts.append(mk.cylinder("Crown", 0.275, 0.06, (2.22, 0.55, bz), rot=(0, 90, 0), mat=steel, verts=40, bevel=0.015))
    parts.append(mk.cylinder("Muzzle", 0.13, 0.07, (2.24, 0.55, bz), rot=(0, 90, 0), mat=bore, verts=24))
    # The hammer over the top left: its body down behind the shield, the spur curling back, checkered on top.
    spur = _curve([(-0.22, -0.55), (0.22, -0.55), (0.26, 0.0), (0.18, 0.4), (-0.1, 0.68), (-0.55, 0.78),
                   (-0.82, 0.62), (-0.74, 0.42), (-0.42, 0.38), (-0.22, 0.14)], steps=5)
    # (low enough round the cylinder that its spur stays under the wheel's top edge)
    spur = [(x * 0.8, z * 0.8) for x, z in spur]
    ha = math.radians(140)
    at = (math.cos(ha) * (WHEEL_R - 0.05), 0.6, math.sin(ha) * (WHEEL_R - 0.05))
    hammer = _upright("Hammer", spur, 0.3, 0.6, blued, bevel=0.03)
    grooves = _upright("SpurKnurl", [(x * 0.8 - 0.06, z * 0.8 + 0.1) for x, z in spur[len(spur) // 2:]], 0.31, 0.6,
                       knurl)
    for obj in (hammer, grooves):
        obj.location = at
        obj.rotation_euler = (math.radians(90), math.radians(-34), 0)
        parts.append(obj)
    # The trigger guard under the cylinder, a little left of the middle, and the trigger's blade in it.
    gx, gz = -0.62, -WHEEL_R - 0.12
    parts.append(mk.torus("Guard", 0.36, 0.065, (gx, 0.62, gz), rot=(90, 0, 0), mat=blued, major_segments=40,
                          minor_segments=10))
    parts.append(mk.tube("Trigger", (gx + 0.1, 0.62, gz + 0.26), (gx - 0.04, 0.62, gz - 0.12), 0.055,
                         radius_end=0.04, mat=steel, verts=10))
    # The bird's-head grip down to the bottom left: the frame's grip strap in blued steel, walnut panels standing
    # proud of it with a checkered field, a steel screw, the steel butt cap at the pommel's hook.
    outline = _curve([(-0.55, -1.1), (-1.25, -0.85), (-1.7, -1.15), (-2.02, -1.58), (-2.24, -2.0), (-2.26, -2.3),
                      (-2.06, -2.46), (-1.78, -2.44), (-1.5, -2.22), (-1.2, -1.86), (-0.9, -1.58), (-0.62, -1.4)],
                     steps=6)
    parts.append(_upright("GripFrame", outline, 0.5, 0.7, blued, bevel=0.03))
    inset = _curve([(-1.0, -1.12), (-1.6, -1.3), (-1.92, -1.7), (-2.08, -2.08), (-1.92, -2.26), (-1.64, -2.16),
                    (-1.34, -1.84), (-1.06, -1.56), (-0.86, -1.36)], steps=6)
    parts.append(_upright("Panel", inset, 0.66, 0.7, walnut, bevel=0.04))
    field = [(x * 0.8 - 1.5 * 0.2, z * 0.8 - 1.78 * 0.2) for x, z in inset]
    parts.append(_upright("Checkering", field, 0.68, 0.7, checker, bevel=0.01))
    parts.append(mk.cylinder("Screw", 0.07, 0.7, (-1.5, 0.7, -1.78), rot=(90, 0, 0), mat=steel, verts=16, bevel=0.01))
    cap = _curve([(-2.27, -2.24), (-2.12, -2.46), (-1.86, -2.5), (-1.66, -2.4), (-1.98, -2.32)], steps=4)
    parts.append(_upright("ButtCap", cap, 0.54, 0.7, steel, bevel=0.02))

    more = {
        "into": (0.6, 0.0, 1.0, 1.0),
        "pieces": {"Cylinder": props.piece(cylinder, into=(0.0, 0.0, 0.59, 1.0))},
        "hinge": {"Cylinder": (0.0, WHEEL_FRONT, 0.0)},
    }
    return parts, [], more
