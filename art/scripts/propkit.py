"""Parts for detailed props, on top of modelkit: the small things that make a prop read as real
at arm's length. Bolts, panel seams, louvred vents, handles, hinges, printed labels, rubber feet,
wheels with tyres and rims, cans and bottles, pipes with flanges.

Everything is in Blender space: x across, y depth (props face -Y), z up; 1 unit = 1 stud, and
props are built at about 3.5 studs to the metre (a player is 5.2 studs tall)."""

import math

import bpy

import modelkit as mk
from common import srgb

M = 3.5  # studs per metre

FONT_PATHS = [r"C:\Windows\Fonts\YuGothB.ttc", r"C:\Windows\Fonts\msgothic.ttc"]


# Materials ------------------------------------------------------------------------------------------


def metal(name, rgb_a, rgb_b, rough=0.4, metallic=0.6, scale=18):
    return mk.noisy(name, srgb(*rgb_a), srgb(*rgb_b), scale=scale, roughness=rough, metallic=metallic)


def paint(name, rgb, rough=0.45, wear=12, scale=14):
    """Painted metal or plastic: the colour with a little grime mixed in."""
    r, g, b = rgb
    return mk.noisy(name, srgb(max(0, r - wear), max(0, g - wear), max(0, b - wear)), srgb(r, g, b), scale=scale,
                    roughness=rough)


def plastic(name, rgb, rough=0.35):
    return paint(name, rgb, rough=rough, wear=6, scale=24)


def rubber(name="PK_Rubber"):
    return mk.noisy(name, srgb(16, 16, 18), srgb(30, 30, 32), scale=30, roughness=0.9)


def chrome(name="PK_Chrome"):
    return metal(name, (150, 154, 160), (200, 204, 210), rough=0.2, metallic=1.0, scale=30)


def dark_glass(name="PK_DarkGlass", tint=(24, 30, 40)):
    """Glass seen from outside at night: dark, slightly blue, with a soft sheen (it bakes opaque)."""
    r, g, b = tint
    return mk.noisy(name, srgb(r, g, b), srgb(r + 26, g + 32, b + 44), scale=3, roughness=0.08, stretch=(1, 1, 0.2))


def glow(name, rgb, strength=4.0):
    return mk.emissive(name, srgb(*rgb), strength)


# Letters --------------------------------------------------------------------------------------------


def font():
    f = bpy.data.fonts.get("InkboundJP")
    if f:
        return f
    for path in FONT_PATHS:
        try:
            f = bpy.data.fonts.load(path)
            f.name = "InkboundJP"
            return f
        except Exception:  # noqa: BLE001 - try the next font
            continue
    return None


def text(name, body, size, loc, mat, rot=(90, 0, 0), depth=0.0, align="CENTER"):
    """Letters as geometry (baked into the prop's texture), facing -Y by default."""
    curve = bpy.data.curves.new(name, "FONT")
    curve.body = body
    curve.size = size
    curve.extrude = depth
    curve.resolution_u = 2
    curve.align_x = align
    curve.align_y = "CENTER"
    f = font()
    if f:
        curve.font = f
    curve.materials.append(mat)
    obj = bpy.data.objects.new(name, curve)
    obj.location = loc
    obj.rotation_euler = [math.radians(a) for a in rot]
    mk._link(obj)
    return obj


def label(name, body, size, loc, ink, plate=None, pad=0.15, rot=(90, 0, 0), plate_depth=0.04):
    """A printed label: letters on a plate that faces -Y (or turned by rot about its centre)."""
    parts = [text(name, body, size, loc, ink, rot=rot)]
    if plate is not None:
        n = max(1, len(body))
        w = size * 0.95 * n + pad * 2
        h = size * 1.2 + pad * 2
        x, y, z = loc
        if tuple(rot) == (90, 0, 0):
            parts.append(mk.box(name + "Plate", (w, plate_depth, h), (x, y + plate_depth / 2 + 0.005, z), mat=plate))
    return parts


# Small parts ----------------------------------------------------------------------------------------


def bolts(name, points, mat, r=0.06, depth=0.05, axis="y"):
    """Round bolt heads at points, standing out along -Y (axis "y"), +Z ("z") or -X ("x")."""
    rot = {"y": (90, 0, 0), "z": (0, 0, 0), "x": (0, 90, 0)}[axis]
    return [mk.cylinder(name, r, depth, p, rot=rot, mat=mat, verts=8) for p in points]


def seam(name, a, b, mat, w=0.04, d=0.02):
    """A thin dark line between panels, from a to b (both on a face)."""
    return mk.tube(name, a, b, w / 2, mat=mat, verts=4)


def louvres(name, x, y, z, w, h, mat, count=None, depth=0.08, tilt=30):
    """A louvred vent on a face at -Y: slats across (w by h), centred at (x, y, z)."""
    count = count or max(3, int(h / 0.22))
    parts = [mk.box(name + "Frame", (w, depth, h), (x, y + depth / 2, z), mat=mat, bevel=0.02)]
    for k in range(count):
        zz = z - h / 2 + h * (k + 0.5) / count
        parts.append(mk.box(name + "Slat", (w - 0.08, 0.05, h / count * 0.7), (x, y - 0.03, zz), rot=(tilt, 0, 0),
                            mat=mat))
    return parts


def handle(name, x, y, z, length, mat, vertical=True, stand=0.12, r=0.05):
    """A bar handle standing `stand` out from a face at -Y, with two stubs."""
    if vertical:
        a, b = (x, y - stand, z - length / 2), (x, y - stand, z + length / 2)
        s0, s1 = (x, y, z - length / 2 + 0.05), (x, y, z + length / 2 - 0.05)
    else:
        a, b = (x - length / 2, y - stand, z), (x + length / 2, y - stand, z)
        s0, s1 = (x - length / 2 + 0.05, y, z), (x + length / 2 - 0.05, y, z)
    return [mk.tube(name, a, b, r, mat=mat, verts=8),
            mk.tube(name + "S", s0, (s0[0], s0[1] - stand, s0[2]), r * 0.8, mat=mat, verts=6),
            mk.tube(name + "S", s1, (s1[0], s1[1] - stand, s1[2]), r * 0.8, mat=mat, verts=6)]


def hinge(name, x, y, z, h, mat):
    return [mk.cylinder(name, 0.06, h, (x, y, z), mat=mat, verts=8)]


def feet(name, points, mat, r=0.12, h=0.1):
    return [mk.cylinder(name, r, h, (x, y, h / 2), mat=mat, verts=10) for x, y in points]


def wheel(prefix, x, y, r, width, tyre, rim, hub=None, spokes=5, z=None):
    """A wheel turning about X at (x, y), its bottom on the ground (or centred at z): a tyre with a
    rounded tread, a rim with spokes and a hub cap."""
    z = r if z is None else z
    hub = hub or rim
    parts = [
        mk.cylinder(prefix + "Tyre", r, width, (x, y, z), rot=(0, 90, 0), mat=tyre, verts=24, bevel=width * 0.25),
        mk.cylinder(prefix + "Rim", r * 0.62, width + 0.04, (x, y, z), rot=(0, 90, 0), mat=rim, verts=20),
        mk.cylinder(prefix + "Hub", r * 0.2, width + 0.1, (x, y, z), rot=(0, 90, 0), mat=hub, verts=12),
    ]
    side = 1 if x >= 0 else -1
    face = x + side * (width / 2 + 0.03)
    for k in range(spokes):
        a = 2 * math.pi * k / spokes
        parts.append(mk.tube(prefix + "Spoke", (face, y, z), (face, y + math.cos(a) * r * 0.58, z + math.sin(a) * r * 0.58),
                             r * 0.07, mat=rim, verts=5))
    return parts


def spoked_wheel(prefix, x, y, r, tyre, rim, spokes=16):
    """A bicycle wheel turning about X, in the YZ plane at x: a thin tyre, a rim and wire spokes."""
    parts = [mk.torus(prefix + "Tyre", r - 0.06, 0.07, (x, y, r), rot=(0, 90, 0), mat=tyre, major_segments=28,
                      minor_segments=6),
             mk.torus(prefix + "Rim", r - 0.16, 0.035, (x, y, r), rot=(0, 90, 0), mat=rim, major_segments=24,
                      minor_segments=4),
             mk.cylinder(prefix + "Hub", 0.1, 0.28, (x, y, r), rot=(0, 90, 0), mat=rim, verts=8)]
    for k in range(spokes):
        a = 2 * math.pi * k / spokes
        off = 0.1 if k % 2 else -0.1
        parts.append(mk.tube(prefix + "Spoke", (x + off, y, r), (x, y + math.cos(a) * (r - 0.18), r + math.sin(a) * (r - 0.18)),
                             0.012, mat=rim, verts=3))
    return parts


def can(name, x, y, z, mat, top, r=0.22, h=0.8):
    """A drinks can standing at (x, y, z)."""
    return [mk.cylinder(name, r, h, (x, y, z + h / 2), mat=mat, verts=12),
            mk.cylinder(name + "Top", r * 0.86, 0.06, (x, y, z + h + 0.02), mat=top, verts=12)]


def bottle(name, x, y, z, mat, cap, r=0.24, h=1.3):
    """A plastic drinks bottle: body, shoulder, neck and cap."""
    body = mk.lathe(name, [(0.0, 0), (r, 0.02), (r, h * 0.62), (r * 0.9, h * 0.7), (r * 0.42, h * 0.84),
                           (r * 0.36, h * 0.92), (0.0, h * 0.92)], (x, y, z), mat=mat, segments=12)
    return [body, mk.cylinder(name + "Cap", r * 0.4, h * 0.1, (x, y, z + h * 0.97), mat=cap, verts=10)]


def pipe(name, a, b, r, mat, flanges=True):
    parts = [mk.tube(name, a, b, r, mat=mat, verts=12)]
    if flanges:
        for p in (a, b):
            parts.append(mk.tube(name + "F", p, tuple(pv + (bv - pv) * 0.04 for pv, bv in zip(p, b)), r * 1.5, mat=mat,
                                 verts=12))
    return parts


def rounded(name, size, loc, mat, r=0.08, rot=(0, 0, 0)):
    """A box with rounded edges (bevel of 3 segments)."""
    return mk.box(name, size, loc, rot=rot, mat=mat, bevel=r, segments=3)


def frame(name, w, h, t, depth, loc, mat, rot=(0, 0, 0)):
    """A rectangular frame (w by h, bar thickness t) lying in the XZ plane at loc, `depth` deep."""
    x, y, z = loc
    return [
        mk.box(name + "T", (w, depth, t), (x, y, z + h / 2 - t / 2), rot=rot, mat=mat, bevel=0.02),
        mk.box(name + "B", (w, depth, t), (x, y, z - h / 2 + t / 2), rot=rot, mat=mat, bevel=0.02),
        mk.box(name + "L", (t, depth, h - 2 * t), (x - w / 2 + t / 2, y, z), rot=rot, mat=mat, bevel=0.02),
        mk.box(name + "R", (t, depth, h - 2 * t), (x + w / 2 - t / 2, y, z), rot=rot, mat=mat, bevel=0.02),
    ]
