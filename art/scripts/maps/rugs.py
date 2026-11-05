"""Woven rugs for the maps' rooms: a field inside a border band, both drawn over the carpet scan (scanlib's Carpet016),
so a rug reads as a thing woven and laid down, not a coloured quad.

The border is its own surface (RugBorder): one repeat runs PERIOD studs along the rug's edge and the full band
across it, outer edge at v = 0. Its ornament (guard stripes, a running row of lozenges in madder and indigo, an inner
guard) is the same at every point along u, so it tiles round any size of rug. The four border pieces meet in mitres
at the corners, like a picture frame. The fields (RugField, oxblood; RugFieldNavy, indigo) are an all-over lattice
that tiles every FIELD studs, laid on the world like any floor.

Colours are an old rug's: muted, a little faded, never a flag's. Arrays are [v, u] with v = 0 at the bottom
(scanlib's convention)."""

import math

import numpy as np

BAND = 1.3  # studs across the border band
PERIOD = BAND  # studs one repeat of the border's ornament covers along the edge (square: its picture is not stretched)
FIELD = 3.0  # studs one repeat of a field's lattice covers, both ways
HEIGHT = 0.05  # how far a rug stands off its floor (its pile)

# The border's colours (sRGB): a near-black oxblood ground, old gold, madder, indigo.
GROUND = (32, 17, 19)
GOLD = (122, 98, 60)
MADDER = (88, 30, 30)
INDIGO = (34, 40, 62)
DARK = (18, 14, 16)

# The fields: ground, the lattice's lines, the dot at each diamond's heart and the one at each crossing.
FIELDS = {
    "RugField": dict(ground=(54, 21, 24), line=(30, 13, 15), heart=(96, 78, 50), cross=(36, 40, 62), seed=183),
    "RugFieldNavy": dict(ground=(30, 35, 56), line=(17, 19, 32), heart=(96, 78, 50), cross=(80, 30, 31), seed=184),
}


def _lin(rgb):
    c = np.asarray(rgb, dtype=np.float32) / 255.0
    return np.where(c <= 0.04045, c / 12.92, np.power((c + 0.055) / 1.055, 2.4))


def _base(colour, studs, seed, scale):
    """The carpet scan graded to colour: its size, normal (-1..1), roughness, u and v (0..1) and the pile's light and
    dark as a factor."""
    from maps import scanlib

    base = scanlib.surface("Carpet016", colour, studs, "wall", 1, keep=0.0, contrast=0.7, rough=0.95, seed=seed)[0](scale)
    color = base["color"].astype(np.float32)
    size = color.shape[0]
    normal = base["normal"].astype(np.float32)
    if normal.shape[0] != size:
        normal = normal.repeat(size // normal.shape[0], 0).repeat(size // normal.shape[1], 1)
    rough = base["rough"].astype(np.float32)
    rough = rough.repeat(size // rough.shape[0], 0).repeat(size // rough.shape[1], 1)
    vv, uu = np.mgrid[0:size, 0:size].astype(np.float32) / size
    pile = (scanlib.to_linear(color) @ scanlib.LUMA) / max(1e-4, float(_lin(colour) @ scanlib.LUMA))
    return size, normal * 2 - 1, rough, uu, vv, np.clip(pile, 0.6, 1.5)[..., None]


def _finish(lin, pile, rough, normal, sunk, size, studs, seed):
    """Pile, fading and wear over the drawn colours; the lines between colours sunk into the pile (normal map)."""
    from maps import scanlib

    r = np.random.default_rng(seed)
    grey = (lin @ scanlib.LUMA)[..., None]
    lin = grey + (lin - grey) * 0.78  # faded
    wear = 0.9 + 0.2 * scanlib.drift(r, size, 1, 3)  # broad patches, lighter where feet go
    lin = lin * pile * wear[..., None]
    rough = np.clip(rough * 0.3 + 0.68, 0, 1)
    h = sunk * -0.03
    du = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * size / studs
    dv = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * size / studs
    nrm = normal * 0.7 + np.stack([-du, -dv, np.zeros_like(du)], axis=-1)
    nrm = nrm / np.linalg.norm(nrm, axis=-1, keepdims=True)
    return {
        "color": np.clip(scanlib.to_srgb(lin), 0, 1),
        "normal": np.clip(nrm * 0.5 + 0.5, 0, 1),
        "rough": np.clip(scanlib.half(rough), 0.03, 1),
    }


def border(scale=1):
    """The colour (sRGB), normal and roughness maps of the border, in scanlib's form (u along the edge, v from the
    outer edge in)."""
    size, normal, rough, uu, vv, pile = _base(GROUND, PERIOD, 181, scale)

    def band(v0, v1):
        return (vv >= v0) & (vv < v1)

    lin = np.broadcast_to(_lin(GROUND), (size, size, 3)).copy()
    sunk = np.zeros((size, size), dtype=np.float32)
    # Outer guard: a dark binding, a thin gold line.
    lin[band(0.0, 0.08)] = _lin(DARK)
    lin[band(0.11, 0.14)] = _lin(GOLD)
    # The main border (v 0.18 .. 0.68): two lozenges a repeat, madder and indigo in turn, each outlined in gold with
    # a gold heart, a gold dot between each two.
    mid, half_u, half_v = 0.43, 0.2, 0.2
    for k, centre in enumerate((0.25, 0.75)):
        diamond = np.abs(uu - centre) / half_u + np.abs(vv - mid) / half_v
        lin[diamond < 0.8] = _lin(MADDER if k % 2 == 0 else INDIGO)
        lin[(diamond >= 0.8) & (diamond < 1.0)] = _lin(GOLD)
        lin[diamond < 0.2] = _lin(GOLD)
        sunk = np.where(np.abs(diamond - 1.0) < 0.06, 1.0, sunk)
    for centre in (0.0, 0.5, 1.0):
        lin[np.hypot((uu - centre) / 0.036, (vv - mid) / 0.05) < 1.0] = _lin(GOLD)
    lin[band(0.19, 0.21)] = _lin(GOLD)
    lin[band(0.65, 0.67)] = _lin(GOLD)
    # Inner guard: madder with a row of dark dots, a dark line into the field.
    inner = band(0.72, 0.88)
    lin[inner] = _lin(MADDER)
    lin[inner & (np.hypot(((uu * 5.0) % 1.0 - 0.5) / 0.15, (vv - 0.8) / 0.03) < 1.0)] = _lin(DARK)
    lin[band(0.9, 1.01)] = _lin(DARK)
    for v in (0.08, 0.11, 0.14, 0.19, 0.21, 0.65, 0.67, 0.72, 0.88, 0.9):
        sunk = np.where(np.abs(vv - v) < 0.006, 1.0, sunk)
    return _finish(lin, pile, rough, normal, sunk, size, PERIOD, 181)


def field(name, scale=1):
    """A field's maps: a diamond lattice of fine lines, a dot at each diamond's heart and at each crossing."""
    spec = FIELDS[name]
    size, normal, rough, uu, vv, pile = _base(spec["ground"], FIELD, spec["seed"], scale)
    lin = np.broadcast_to(_lin(spec["ground"]), (size, size, 3)).copy()
    # Two diamonds a repeat each way: lines along u + v and u - v.
    a = (uu + vv) * 2.0
    b = (uu - vv) * 2.0
    near_a = np.abs(a - np.round(a))
    near_b = np.abs(b - np.round(b))
    lines = (near_a < 0.035) | (near_b < 0.035)
    lin[lines] = _lin(spec["line"])
    # Hearts (between the lines) and crossings (where they meet).
    heart = np.hypot(np.abs(a - np.floor(a) - 0.5), np.abs(b - np.floor(b) - 0.5)) < 0.06
    lin[heart] = _lin(spec["heart"])
    cross = np.hypot(near_a, near_b) < 0.07
    lin[cross] = _lin(spec["cross"])
    sunk = (lines & ~cross).astype(np.float32)
    return _finish(lin, pile, rough, normal, sunk, size, FIELD, spec["seed"])


def surface(name="RugBorder"):
    """The scanlib.LIBRARY entry for the border or a field."""
    if name == "RugBorder":
        return (lambda scale=1: border(scale)), PERIOD
    return (lambda scale=1: field(name, scale)), FIELD


# Laying a rug -----------------------------------------------------------------------------------------------


def lay(s, x, z, w, d, rot=0.0, y=0.0, field="RugField", border="RugBorder"):
    """A rug w x d (studs) centred on (x, z), turned by rot (the map kit's ry), on a floor at y: the field, the border
    (BAND wide) in four mitred pieces, and its edges. Nothing to collide with: it is a few hundredths of a stud thick."""
    band = BAND
    a = math.radians(rot)
    ca, sa = math.cos(a), math.sin(a)

    def at(lx, lz, h):
        return (x + lx * ca + lz * sa, y + h, z - lx * sa + lz * ca)

    top = HEIGHT
    hw, hd = w / 2, d / 2
    iw, id_ = hw - band, hd - band
    # The field: one face, mapped on the world (its lattice runs on whatever the rug's size).
    s.polygon(field, [at(-iw, id_, top), at(iw, id_, top), at(iw, -id_, top), at(-iw, -id_, top)])
    # The border: each side from its outer edge (v 0) to its inner one (v 1), u along it from its own corner.
    corners = [(-hw, -hd), (hw, -hd), (hw, hd), (-hw, hd)]
    inner = [(-iw, -id_), (iw, -id_), (iw, id_), (-iw, id_)]
    for k in range(4):
        o0, o1 = corners[k], corners[(k + 1) % 4]
        i0, i1 = inner[k], inner[(k + 1) % 4]
        length = math.dist(o0, o1)
        u0, u1 = 0.0, length / PERIOD
        ui0, ui1 = band / PERIOD, (length - band) / PERIOD
        pts = [at(o0[0], o0[1], top), at(i0[0], i0[1], top), at(i1[0], i1[1], top), at(o1[0], o1[1], top)]
        uvs = [(u0, 0.0), (ui0, 1.0), (ui1, 1.0), (u1, 0.0)]
        # (Outer corner, inner, inner, outer runs clockwise in x, z, which faces up, as city.up_face's do.)
        s.polygon(border, pts, uvs=uvs, tile=1.0)
        # Its edge, down to the floor (the binding: the border's outer dark line).
        side = [at(o1[0], o1[1], 0.0), at(o0[0], o0[1], 0.0), at(o0[0], o0[1], top), at(o1[0], o1[1], top)]
        s.polygon(border, side, uvs=[(u1, 0.0), (u0, 0.0), (u0, 0.06), (u1, 0.06)], tile=1.0)
