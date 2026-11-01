"""The parts the case-file stations are made of, at the semi-real standard (see propkit): a monitor
round the game's screen slot (a flat panel, a CRT, a screen set into a panel), keyboards with their
keys, desk phones with a coiled cord, steel and wooden desks with drawers that open, a mug with its
handle, papers, folders, pens, lamps and cables.

Coordinates are a station's: x across, y depth (the worker stands at -Y), z up, the design origin
on the station's spot, the game's invisible desk (5 x 2.4 x 3) standing on it. A screen slot is
(x, y, z, width, height, tilt): the middle of the screen's face; the game's screen part (0.2 deep)
fills it, so nothing here stands in front of that face, and every bezel keeps the face clear."""

import math

import bmesh
from mathutils import Matrix, Vector

import modelkit as mk
import propkit as pk


# Placing ----------------------------------------------------------------------------------------------


def tilt_about(parts, centre, tilt):
    """Leans parts back about the X axis through centre (their top goes to +Y), as a screen slot's
    tilt leans the game's screen."""
    if not tilt:
        return parts
    c = Vector(centre)
    m = Matrix.Translation(c) @ Matrix.Rotation(math.radians(-tilt), 4, "X") @ Matrix.Translation(-c)
    for obj in parts:
        obj.matrix_basis = m @ obj.matrix_basis
    return parts


def turn_about(parts, centre, yaw):
    """Turns parts about the Z axis through centre by yaw degrees."""
    if not yaw:
        return parts
    c = Vector(centre)
    m = Matrix.Translation(c) @ Matrix.Rotation(math.radians(yaw), 4, "Z") @ Matrix.Translation(-c)
    for obj in parts:
        obj.matrix_basis = m @ obj.matrix_basis
    return parts


def loft(name, front, back, y0, y1, centre, mat, back_dz=0.0, bevel=0.0):
    """A solid from a front rectangle (w, h) at y0 to a back one at y1 (a CRT's tapered body, a
    monitor's rear), centred on centre's x and z; back_dz lifts or drops the back."""
    cx, _, cz = centre
    bm = bmesh.new()
    (fw, fh), (bw, bh) = front, back
    f = [bm.verts.new((cx + sx * fw / 2, y0, cz + sz * fh / 2)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    b = [bm.verts.new((cx + sx * bw / 2, y1, cz + back_dz + sz * bh / 2)) for sx, sz in ((-1, -1), (1, -1), (1, 1), (-1, 1))]
    bm.faces.new(f)
    bm.faces.new(list(reversed(b)))
    for k in range(4):
        j = (k + 1) % 4
        bm.faces.new((f[k], b[k], b[j], f[j]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    obj = mk._obj_from_bm(name, bm, mat)
    if bevel > 0:
        mk.add_bevel(obj, bevel, 2)
    return obj


def wedge(name, profile, width, x, mat, bevel=0.0):
    """A side profile [(y, z), ...] (anticlockwise seen from +X) extruded `width` across X, centred on x:
    a desk phone's sloped body, a console's raked face."""
    obj = mk.extrude_shape(name, [(y, z) for y, z in profile], width, mat=mat, bevel=bevel)
    # (extrude_shape draws in XY and extrudes along Z: turn it so the profile stands in YZ)
    obj.rotation_euler = (math.radians(90), 0, math.radians(90))
    obj.location = (x, 0, 0)
    return obj


def cable(name, points, mat, r=0.03, sides=6):
    """A cable along a bent line (pk.sweep), with a little sag between the points."""
    pts = [Vector(p) for p in points]
    out = [pts[0]]
    for a, b in zip(pts, pts[1:]):
        for k in (1, 2, 3):
            t = k / 4
            p = a.lerp(b, t)
            p.z -= 0.05 * math.sin(math.pi * t) * min(1.0, (b - a).length)
            out.append(p)
        out.append(b)
    return pk.sweep(name, out, r, mat, sides=sides)


def screws(name, points, mat, r=0.035, axis="y"):
    return pk.bolts(name, points, mat, r=r, depth=0.025, axis=axis)


# Screens ----------------------------------------------------------------------------------------------


def bezel(prefix, slot, mat, border=0.14, depth=0.22, lip=0.03, bevel=0.03):
    """A bezel round a screen slot: four bars round the face, their front `lip` proud of it, so the
    game's screen sits in the frame and nothing covers it. Returns the parts, tilted."""
    x, y, z, w, h = slot[:5]
    tilt = slot[5] if len(slot) > 5 else 0
    front = y - 0.1 - lip
    cy = front + depth / 2
    W, H = w + 2 * border, h + 2 * border
    parts = [mk.box(prefix + "BezelT", (W, depth, border), (x, cy, z + h / 2 + border / 2 + 0.005), mat=mat, bevel=bevel),
             mk.box(prefix + "BezelB", (W, depth, border), (x, cy, z - h / 2 - border / 2 - 0.005), mat=mat, bevel=bevel),
             mk.box(prefix + "BezelL", (border, depth, h + 0.01), (x - w / 2 - border / 2 - 0.005, cy, z), mat=mat,
                    bevel=bevel),
             mk.box(prefix + "BezelR", (border, depth, h + 0.01), (x + w / 2 + border / 2 + 0.005, cy, z), mat=mat,
                    bevel=bevel)]
    return tilt_about(parts, (x, y, z), tilt)


def lcd(prefix, slot, shell, dark, stand_to=None, foot=(1.3, 0.75), border=0.1, back=0.22, neck_y=None, logo=None):
    """A flat panel monitor round a screen slot: a slim bezel, the panel's back with its bulge and
    vents, a VESA plate, the neck and an oval foot standing on stand_to (None: wall- or arm-hung).
    Returns (parts, glows): the glow is the power lamp."""
    x, y, z, w, h = slot[:5]
    tilt = slot[5] if len(slot) > 5 else 0
    parts = bezel(prefix, (x, y, z, w, h, 0), shell, border=border, depth=0.18, lip=0.02, bevel=0.025)
    W, H = w + 2 * border, h + 2 * border
    parts += [mk.box(prefix + "Panel", (W - 0.02, back * 0.45, H - 0.02), (x, y + 0.08 + back * 0.22, z), mat=shell,
                     bevel=0.04),
              loft(prefix + "Bulge", (W * 0.7, H * 0.66), (W * 0.46, H * 0.44), y + 0.08 + back * 0.44, y + 0.08 + back,
                   (x, 0, z - H * 0.04), shell, bevel=0.03)]
    for k in range(5):  # (vent slots across the back's top)
        parts.append(mk.box(prefix + "Vent", (W * 0.5, 0.03, 0.025), (x, y + 0.13 + back * 0.6, z + H * 0.24 - k * 0.07),
                            rot=(0, 0, 0), mat=dark))
    parts.append(mk.box(prefix + "Chin", (0.5, 0.02, 0.04), (x + w / 2 - 0.25, y - 0.122, z - h / 2 - border / 2), mat=dark))
    if logo:
        parts += pk.label(prefix + "Logo", logo, 0.06, (x, y - 0.125, z - h / 2 - border / 2), dark)
    glows = [mk.box(prefix + "PowerLed", (0.05, 0.02, 0.03), (x + w / 2 - 0.05, y - 0.122, z - h / 2 - border / 2),
                    mat=pk.glow(prefix + "Led", (120, 200, 255), 4))]
    tilt_about(parts + glows, (x, y, z), tilt)
    if stand_to is not None:
        ny = y + 0.08 + back + 0.12 if neck_y is None else neck_y
        top = z - h * 0.05
        fw, fd = foot
        parts += [mk.box(prefix + "Vesa", (0.5, 0.06, 0.5), (x, ny - 0.1, z), mat=dark, bevel=0.02),
                  mk.box(prefix + "Neck", (0.34, 0.14, top - stand_to - 0.06), (x, ny, (top + stand_to) / 2 + 0.03), mat=shell,
                         bevel=0.05),
                  mk.box(prefix + "NeckSlot", (0.12, 0.02, (top - stand_to) * 0.4), (x, ny + 0.075, stand_to + (top - stand_to) * 0.4),
                         mat=dark),
                  _oval(prefix + "Foot", fw / 2, fd / 2, 0.07, (x, ny - fd * 0.25, stand_to + 0.035), shell)]
    return parts, glows


def _oval(name, rx, ry, h, loc, mat):
    obj = mk.cylinder(name, 1.0, h, loc, mat=mat, verts=24, bevel=0.0)
    obj.scale = (rx, ry, 1.0)
    return obj


def crt(prefix, slot, housing, bezel_mat, dark, depth=1.8, base_to=None, border=0.26, knobs=True, chin=0.18):
    """A CRT monitor round a screen slot: a deep bezel with its rounded lip and the controls under
    the face, the tapered body and neck of the tube behind it with vent slots, standing on base_to
    on a swivel base (or on short feet when it sits low). Returns (parts, glows)."""
    x, y, z, w, h = slot[:5]
    tilt = slot[5] if len(slot) > 5 else 0
    chin = chin if knobs else 0.0
    parts = bezel(prefix, (x, y, z, w, h, 0), bezel_mat, border=border, depth=0.3, lip=0.04, bevel=0.06)
    W, H = w + 2 * border, h + 2 * border
    face_back = y - 0.1 - 0.04 + 0.3
    if chin:
        parts.append(mk.box(prefix + "Chin", (W, 0.3, chin), (x, y + 0.01, z - H / 2 - chin / 2 - 0.005), mat=bezel_mat,
                            bevel=0.04))
    parts += [mk.box(prefix + "Shell", (W + 0.04, 0.4, H + chin + 0.04), (x, face_back + 0.19, z - chin / 2), mat=housing,
                     bevel=0.08),
              loft(prefix + "Body", (W * 0.94, (H + chin) * 0.92), (W * 0.58, H * 0.56), face_back + 0.38, face_back + depth * 0.75,
                   (x, 0, z - chin / 2), housing, back_dz=0.06, bevel=0.06),
              loft(prefix + "Neck", (W * 0.4, H * 0.38), (W * 0.24, H * 0.24), face_back + depth * 0.75, face_back + depth,
                   (x, 0, z + 0.06), housing, bevel=0.04)]
    for k in range(6):  # (vent slots raked along the top of the body)
        t = 0.2 + k * 0.1
        yy = face_back + 0.38 + (depth * 0.75 - 0.38) * t
        top = z - chin / 2 + ((H + chin) * 0.92 * (1 - t) + H * 0.56 * t) / 2 + 0.06 * t
        parts.append(mk.box(prefix + "Vent", (W * 0.5, 0.05, 0.03), (x, yy, top + 0.005), mat=dark))
    glows = []
    if knobs:
        cz = z - H / 2 - chin / 2
        for k in range(3):
            parts.append(mk.cylinder(prefix + "Knob", 0.05, 0.05, (x + w / 2 - 0.15 - k * 0.17, y - 0.155, cz), rot=(90, 0, 0),
                                     mat=dark, verts=10))
        parts.append(mk.box(prefix + "Switch", (0.16, 0.04, 0.08), (x - w / 2 + 0.15, y - 0.15, cz), mat=dark, bevel=0.01))
        glows.append(mk.box(prefix + "PowerLed", (0.05, 0.02, 0.05), (x - w / 2 + 0.34, y - 0.15, cz),
                            mat=pk.glow(prefix + "Led", (110, 255, 140), 4)))
    tilt_about(parts + glows, (x, y, z), tilt)
    bottom = z - H / 2 - chin - 0.02
    if base_to is not None and bottom - base_to < 0.25:
        gap = max(0.03, bottom - base_to + 0.02)
        for sx in (-1, 1):
            for fy in (face_back + 0.1, face_back + depth * 0.6):
                parts.append(mk.box(prefix + "Foot", (0.22, 0.22, gap), (x + sx * W * 0.32, fy, base_to + gap / 2), mat=dark))
    elif base_to is not None:
        parts += [mk.cylinder(prefix + "Swivel", 0.5, max(0.05, bottom - base_to - 0.08), (x, face_back + 0.45,
                                                                                         (bottom + base_to + 0.08) / 2),
                              mat=dark, verts=16),
                  pk.rounded(prefix + "Base", (W * 0.62, 1.0, 0.1), (x, face_back + 0.45, base_to + 0.05), housing, r=0.04)]
    return parts, glows


# Desk things ------------------------------------------------------------------------------------------


def keyboard(prefix, x, y, z, case, key, w=2.0, d=0.72, tilt=5, numpad=True, yaw=0):
    """A keyboard lying on a desk at z: its case and rows of keys (a long space bar), raked toward
    the worker."""
    parts = [pk.rounded(prefix + "Case", (w, d, 0.1), (x, y, z + 0.05), case, r=0.03)]
    main_w = w * (0.76 if numpad else 0.94)
    left = x - w / 2 + 0.05
    pitch = main_w / 15
    rows = 5
    for r in range(rows):
        ry = y - d / 2 + 0.1 + (r + 0.5) * (d - 0.16) / rows
        rz = z + 0.11 + r * 0.008
        if r == 0:  # (the bottom row: modifiers either side of the space bar)
            parts.append(mk.box(prefix + "Space", (pitch * 6.4, pitch * 0.82, 0.04), (left + main_w * 0.5, ry, rz), mat=key,
                                bevel=0.008))
            for k in (0, 1, 2, 12, 13, 14):
                parts.append(mk.box(prefix + "Key", (pitch * 0.82, pitch * 0.82, 0.04), (left + (k + 0.5) * pitch, ry, rz),
                                    mat=key, bevel=0.008))
            continue
        count = 15 - (r % 2)
        off = (r % 2) * pitch * 0.5
        for k in range(count):
            parts.append(mk.box(prefix + "Key", (pitch * 0.82, pitch * 0.82, 0.04), (left + off + (k + 0.5) * pitch, ry, rz),
                                mat=key, bevel=0.008))
    if numpad:
        nl = x + w / 2 - 0.05 - pitch * 4
        for r in range(rows):
            ry = y - d / 2 + 0.1 + (r + 0.5) * (d - 0.16) / rows
            for k in range(4):
                parts.append(mk.box(prefix + "Num", (pitch * 0.82, pitch * 0.82, 0.04), (nl + (k + 0.5) * pitch, ry, z + 0.11),
                                    mat=key, bevel=0.008))
    tilt_about(parts, (x, y, z), -tilt * 0)  # (laid flat; the rake is in the rows' heights)
    return turn_about(parts, (x, y, z), yaw)


def mouse(prefix, x, y, z, body, dark, cable_to=None):
    m = mk.sphere(prefix + "Mouse", 1.0, (x, y, z + 0.05), scale=(0.13, 0.21, 0.07), mat=body, segments=14, rings=8)
    parts = [m, mk.box(prefix + "MouseSplit", (0.006, 0.12, 0.02), (x, y + 0.1, z + 0.11), mat=dark)]
    if cable_to:
        parts.append(cable(prefix + "MouseCord", [(x, y + 0.2, z + 0.04), cable_to], dark, r=0.015, sides=4))
    return parts


def desk_phone(prefix, x, y, z, body, key, cord, yaw=0, lines=0):
    """A desk telephone at z: the raked body with its keypad and line keys, the handset in its
    cradle across the top, the coiled cord down its side. Returns (parts, glows): the line lamps."""
    parts = [wedge(prefix + "Body", [(-0.42, 0.0), (0.42, 0.0), (0.42, 0.34), (0.1, 0.36), (-0.42, 0.12)], 0.95, x, body,
                   bevel=0.04)]
    parts[0].location = (x, y, z)
    for r in range(4):
        for c in range(3):
            parts.append(mk.box(prefix + "Key", (0.11, 0.08, 0.05),
                                (x - 0.13 + c * 0.13, y - 0.3 + r * 0.095, z + 0.15 + r * 0.03 + 0.02), rot=(-17, 0, 0),
                                mat=key, bevel=0.01))
    parts.append(mk.box(prefix + "Display", (0.36, 0.1, 0.03), (x + 0.0, y + 0.07, z + 0.31), rot=(-17, 0, 0), mat=cord))
    # The handset across the top, ear at the left, in its two cups.
    hx = x
    parts += [pk.sweep(prefix + "Handset", [(hx - 0.42, y + 0.22, z + 0.42), (hx - 0.3, y + 0.24, z + 0.49), (hx + 0.3, y + 0.24, z + 0.49),
                                            (hx + 0.42, y + 0.22, z + 0.42)], 0.07, body, sides=8),
              mk.sphere(prefix + "Ear", 1.0, (hx - 0.42, y + 0.22, z + 0.4), scale=(0.11, 0.14, 0.07), mat=body, segments=12, rings=6),
              mk.sphere(prefix + "Mouth", 1.0, (hx + 0.42, y + 0.22, z + 0.4), scale=(0.11, 0.14, 0.07), mat=body, segments=12,
                        rings=6),
              pk.coil(prefix + "Cord", (hx - 0.47, y + 0.12, z + 0.34), (x - 0.5, y - 0.1, z + 0.06), 6, 0.04, 0.012, cord)]
    glows = []
    for k in range(lines):
        glows.append(mk.box(prefix + "LineLamp", (0.06, 0.03, 0.03), (x + 0.33, y - 0.3 + k * 0.09, z + 0.16 + k * 0.03),
                            rot=(-17, 0, 0), mat=pk.glow(prefix + "Line", (255, 170, 60) if k % 2 else (255, 80, 50), 4)))
        parts.append(mk.box(prefix + "LineKey", (0.1, 0.07, 0.04), (x + 0.24, y - 0.3 + k * 0.09, z + 0.16 + k * 0.03),
                            rot=(-17, 0, 0), mat=key, bevel=0.01))
    turn_about(parts + glows, (x, y, z), yaw)
    return parts, glows


def mug(prefix, x, y, z, mat, inside=None, r=0.16, h=0.36, handle_yaw=0):
    """A mug standing at z: an open cup with its wall's thickness, the coffee near the rim and the
    handle at its side."""
    t = 0.025
    parts = [mk.lathe(prefix + "Mug", [(0.0, 0.0), (r * 0.94, 0.0), (r, 0.03), (r, h), (r - t, h), (r - t, 0.05), (0.0, 0.05)],
                      (x, y, z), mat=mat, segments=16)]
    if inside is not None:
        parts.append(mk.cylinder(prefix + "Coffee", r - t - 0.004, 0.01, (x, y, z + h * 0.78), mat=inside, verts=16))
    a = math.radians(handle_yaw)
    hx, hy = x + math.cos(a) * r, y + math.sin(a) * r
    pts = []
    for k in range(9):
        b = math.pi * k / 8
        reach = 0.1 * math.sin(b)
        pts.append((hx + math.cos(a) * reach, hy + math.sin(a) * reach, z + h * 0.5 + math.cos(b) * h * 0.3))
    parts.append(pk.sweep(prefix + "Handle", pts, 0.022, mat, sides=6))
    return parts


def papers(prefix, x, y, z, mat, rng, n=4, w=0.85, d=1.1, spread=0.08, turn=8, yaw=0):
    """A stack of loose sheets on a surface at z, each a little off the one under it."""
    parts = []
    for k in range(n):
        parts.append(mk.box(prefix + "Sheet", (w, d, 0.012), (x + rng.uniform(-spread, spread), y + rng.uniform(-spread, spread),
                                                             z + 0.008 + k * 0.016), rot=(0, 0, yaw + rng.uniform(-turn, turn)),
                            mat=mat))
    return parts


def written(prefix, x, y, z, ink, rng, lines=6, w=0.6, d=0.9, yaw=0, upright=False):
    """Lines of writing (thin ink strokes) on a sheet whose top is at z; upright: on a sheet standing
    on a wall or a box's side, facing -Y, its face at y and its middle at z (d is then its height)."""
    parts = []
    for k in range(lines):
        lw = w * rng.uniform(0.5, 0.95)
        down = d / 2 - 0.12 - k * (d - 0.2) / lines
        if upright:
            parts.append(mk.box(prefix + "Ink", (lw, 0.004, 0.018), (x - (w - lw) / 2, y - 0.003, z + down), mat=ink))
        else:
            parts.append(mk.box(prefix + "Ink", (lw, 0.018, 0.004), (x - (w - lw) / 2, y + down, z + 0.003), mat=ink))
    return turn_about(parts, (x, y, z), yaw)


def folder(prefix, x, y, z, cover, sheet, yaw=0, w=0.9, d=1.2, thick=0.08, tab=None):
    """A card case folder lying at z with its papers showing at the open edge (and a coloured tab)."""
    parts = [mk.box(prefix + "Back", (w, d, 0.015), (x, y, z + 0.008), mat=cover),
             mk.box(prefix + "Papers", (w - 0.06, d - 0.08, thick - 0.03), (x + 0.03, y - 0.02, z + 0.015 + (thick - 0.03) / 2),
                    mat=sheet),
             mk.box(prefix + "Front", (w, d, 0.015), (x, y, z + thick), rot=(0, 0.6, 0), mat=cover)]
    if tab is not None:
        parts.append(mk.box(prefix + "Tab", (0.25, 0.08, 0.012), (x - w / 2 + 0.25, y + d / 2 + 0.04, z + thick), mat=tab))
    return turn_about(parts, (x, y, z), yaw)


def binder(prefix, x, y, z, cover, label, yaw=0, w=0.28, d=1.0, h=1.15):
    """A ring binder standing on its foot at z, spine to -Y, with its label and finger hole."""
    parts = [pk.rounded(prefix + "Binder", (w, d, h), (x, y, z + h / 2), cover, r=0.02),
             mk.box(prefix + "Label", (w * 0.7, 0.01, h * 0.36), (x, y - d / 2 - 0.004, z + h * 0.62), mat=label),
             mk.cylinder(prefix + "Hole", 0.05, 0.012, (x, y - d / 2 - 0.004, z + h * 0.22), rot=(90, 0, 0), mat=label, verts=10)]
    return turn_about(parts, (x, y, z), yaw)


def book(prefix, x, y, z, cover, pages, yaw=0, w=0.8, d=1.1, h=0.16):
    """A closed book lying at z: boards proud of the page block."""
    parts = [mk.box(prefix + "BoardB", (w, d, 0.025), (x, y, z + 0.0125), mat=cover, bevel=0.006),
             mk.box(prefix + "Block", (w - 0.04, d - 0.06, h - 0.05), (x + 0.015, y, z + h / 2), mat=pages),
             mk.box(prefix + "BoardT", (w, d, 0.025), (x, y, z + h - 0.0125), mat=cover, bevel=0.006),
             mk.box(prefix + "Spine", (0.03, d, h), (x - w / 2 + 0.008, y, z + h / 2), mat=cover, bevel=0.01)]
    return turn_about(parts, (x, y, z), yaw)


def open_book(prefix, x, y, z, cover, pages, ink, rng, yaw=0, w=1.5, d=1.0):
    """A book lying open at z, its two page blocks bowed up to the gutter, writing on the pages."""
    parts = [mk.box(prefix + "Cover", (w + 0.06, d + 0.06, 0.02), (x, y, z + 0.01), mat=cover)]
    for side in (-1, 1):
        parts.append(mk.box(prefix + "Leaves", (w / 2 - 0.04, d, 0.06), (x + side * w / 4, y, z + 0.05), rot=(0, side * -3, 0),
                            mat=pages))
        parts += written(prefix + str(side), x + side * w / 4, y, z + 0.08 + 0.008, ink, rng, lines=7, w=w / 2 - 0.2, d=d - 0.1)
    return turn_about(parts, (x, y, z), yaw)


def pen(prefix, a, b, body, cap=None, r=0.018):
    a, b = Vector(a), Vector(b)
    parts = [mk.tube(prefix + "Pen", a, b, r, r * 0.9, mat=body, verts=6),
             mk.tube(prefix + "Nib", a, a + (a - b).normalized() * 0.05, r * 0.7, 0.004, mat=cap or body, verts=6)]
    if cap is not None:
        parts.append(mk.tube(prefix + "Clip", b - (b - a).normalized() * 0.18, b, r * 1.12, mat=cap, verts=6))
    return parts


def desk_lamp(prefix, x, y, z, arm, shade, bulb_rgb, reach=(0.5, -0.4), rise=1.3, yaw=0):
    """An angle-poise lamp on its weighted base at z: two arm segments with their springs, the
    cone shade at the end pointing down at the desk, the bulb lit inside it. Returns (parts, glows)."""
    ex, ey = reach
    elbow = (x - ex * 0.15, y + 0.15, z + rise)
    head = (x + ex, y + ey, z + rise * 0.82)
    parts = [mk.cylinder(prefix + "Base", 0.24, 0.08, (x, y, z + 0.04), mat=shade, verts=20, bevel=0.02),
             mk.cylinder(prefix + "Pivot", 0.06, 0.12, (x, y, z + 0.14), rot=(0, 90, 0), mat=arm, verts=8),
             mk.tube(prefix + "Arm1", (x, y, z + 0.14), elbow, 0.025, mat=arm, verts=6),
             mk.tube(prefix + "Arm1b", (x + 0.06, y, z + 0.14), (elbow[0] + 0.06, elbow[1], elbow[2]), 0.015, mat=arm, verts=5),
             mk.cylinder(prefix + "Elbow", 0.05, 0.14, elbow, rot=(0, 90, 0), mat=arm, verts=8),
             mk.tube(prefix + "Arm2", elbow, head, 0.022, mat=arm, verts=6),
             pk.coil(prefix + "Spring", (x + 0.05, y + 0.02, z + 0.35), (elbow[0] + 0.05, elbow[1] - 0.02, elbow[2] - 0.35), 8, 0.025,
                     0.007, arm)]
    hx, hy, hz = head
    parts.append(mk.lathe(prefix + "Shade", [(0.08, 0.06), (0.1, 0.0), (0.3, -0.34), (0.27, -0.34), (0.08, -0.03)],
                          (hx, hy, hz), mat=shade, segments=18, caps=False))
    glows = [mk.sphere(prefix + "Bulb", 0.1, (hx, hy, hz - 0.18), mat=pk.glow(prefix + "Bulb", bulb_rgb, 3), segments=10,
                       rings=6)]
    turn_about(parts + glows, (x, y, z), yaw)
    return parts, glows


# Furniture --------------------------------------------------------------------------------------------


def drawer(prefix, x, y, z, w, h, front_mat, pull_mat, gap=0.03, brass=False):
    """A drawer front on a face at y (facing -Y): the front set in its gap, a pull, a little label holder."""
    parts = [mk.box(prefix + "Drawer", (w - gap * 2, 0.05, h - gap * 2), (x, y - 0.02, z), mat=front_mat, bevel=0.015)]
    parts += pk.handle(prefix + "Pull", x, y - 0.045, z + h * 0.18, min(0.6, w * 0.45), pull_mat, vertical=False, stand=0.06,
                       r=0.022)
    if brass:
        parts.append(mk.box(prefix + "Holder", (0.3, 0.015, 0.13), (x, y - 0.05, z - h * 0.18), mat=pull_mat, bevel=0.005))
    return parts


def steel_desk(prefix, top, body, trim, w=5.2, d=2.6, h=2.95, pedestal=1.6, y0=0.0, modesty=True, drawers=3):
    """A steel office desk on the design origin: a laminate top with its edge band, panel ends on
    levelling feet, a drawer pedestal at +X (pedestal: its width; 0: none), a pencil drawer, the
    modesty panel at the back."""
    t = 0.12
    parts = [mk.box(prefix + "Top", (w, d, t - 0.03), (0, y0, h - (t - 0.03) / 2), mat=top, bevel=0.02),
             mk.box(prefix + "Band", (w - 0.01, d - 0.01, 0.04), (0, y0, h - t + 0.02), mat=trim, bevel=0.012),
             mk.box(prefix + "Rail", (w - 0.3, d - 0.4, 0.14), (0, y0 + 0.05, h - t - 0.07), mat=body)]
    for sx in (-1, 1):
        if pedestal and sx > 0:
            continue
        ex = sx * (w / 2 - 0.12)
        parts += [mk.box(prefix + "End", (0.1, d - 0.3, h - t - 0.12), (ex, y0, (h - t) / 2 + 0.04), mat=body, bevel=0.02),
                  mk.box(prefix + "Skid", (0.16, d - 0.2, 0.08), (ex, y0, 0.08), mat=body, bevel=0.02)]
        parts += pk.feet(prefix + "Foot", [(ex, y0 - d / 2 + 0.25), (ex, y0 + d / 2 - 0.25)], trim, r=0.06, h=0.04)
    if pedestal:
        px = w / 2 - pedestal / 2 - 0.06
        ph = h - t - 0.02
        front = y0 - d / 2 + 0.16
        parts += [mk.box(prefix + "Pedestal", (pedestal, d - 0.3, ph - 0.12), (px, y0 + 0.01, 0.12 + (ph - 0.12) / 2), mat=body,
                         bevel=0.02),
                  mk.box(prefix + "Plinth", (pedestal - 0.1, d - 0.4, 0.12), (px, y0 + 0.05, 0.06), mat=trim)]
        dh = (ph - 0.16) / drawers
        for k in range(drawers):
            parts += drawer(prefix + f"D{k}", px, front, 0.14 + dh * (k + 0.5), pedestal - 0.06, dh, body, trim, brass=True)
        parts.append(mk.box(prefix + "Lock", (0.08, 0.02, 0.08), (px + pedestal / 2 - 0.15, front - 0.05, ph - 0.08), mat=trim))
    # The pencil drawer under the top, at the knee.
    kx = -0.4 if pedestal else 0.0
    parts += drawer(prefix + "Pencil", kx, y0 - d / 2 + 0.2, h - t - 0.1, 1.8, 0.2, body, trim)
    if modesty:
        parts.append(mk.box(prefix + "Modesty", (w - 0.4, 0.05, h - 1.2), (0, y0 + d / 2 - 0.22, h - t - (h - 1.2) / 2),
                            mat=body))
    return parts


def wood_desk(prefix, wood, top, brass, w=5.2, d=2.6, h=2.95, pedestal=1.5, y0=0.0, blotter=None):
    """A wooden office desk on the design origin: a moulded top over its apron, a pedestal of
    drawers at +X with brass pulls, a turned-leg end at -X, a panelled back and an optional
    leather blotter."""
    t = 0.14
    parts = [mk.box(prefix + "Top", (w, d, t - 0.04), (0, y0, h - (t - 0.04) / 2), mat=top, bevel=0.035),
             mk.box(prefix + "Mould", (w - 0.08, d - 0.08, 0.05), (0, y0, h - t + 0.025), mat=wood, bevel=0.02),
             mk.box(prefix + "Apron", (w - 0.3, d - 0.3, 0.3), (0, y0, h - t - 0.15), mat=wood, bevel=0.015)]
    px = w / 2 - pedestal / 2 - 0.1
    lx = -w / 2 + 0.22
    for ly in (y0 - d / 2 + 0.22, y0 + d / 2 - 0.22):
        parts.append(mk.lathe(prefix + "Leg", [(0.05, 0.0), (0.09, 0.05), (0.08, 0.6), (0.1, 1.0), (0.07, 1.6), (0.1, h - t - 0.3),
                                               (0.0, h - t - 0.3)], (lx, ly, 0), mat=wood, segments=10))
    ph = h - t - 0.04
    front = y0 - d / 2 + 0.17
    parts += [mk.box(prefix + "Pedestal", (pedestal, d - 0.34, ph - 0.15), (px, y0, 0.15 + (ph - 0.15) / 2), mat=wood, bevel=0.025),
              mk.box(prefix + "Plinth", (pedestal + 0.06, d - 0.28, 0.15), (px, y0, 0.075), mat=top, bevel=0.02)]
    dh = (ph - 0.2) / 3
    for k in range(3):
        parts += drawer(prefix + f"D{k}", px, front, 0.17 + dh * (k + 0.5), pedestal - 0.08, dh, wood, brass, brass=True)
    parts += drawer(prefix + "Knee", -0.45, y0 - d / 2 + 0.15, h - t - 0.15, 1.9, 0.24, wood, brass)
    parts.append(mk.box(prefix + "Back", (w - 0.5, 0.05, h - 1.0), (0, y0 + d / 2 - 0.2, h - t - (h - 1.0) / 2), mat=wood))
    if blotter is not None:
        parts += [mk.box(prefix + "Blotter", (2.6, 1.3, 0.02), (0.1, y0 - 0.45, h + 0.01), mat=blotter),
                  mk.box(prefix + "BlotL", (0.14, 1.32, 0.03), (-1.2, y0 - 0.45, h + 0.016), mat=blotter, bevel=0.008),
                  mk.box(prefix + "BlotR", (0.14, 1.32, 0.03), (1.4, y0 - 0.45, h + 0.016), mat=blotter, bevel=0.008)]
    return parts
