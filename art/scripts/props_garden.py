"""The Grey Realm's garden of the dead (set "Lobby", asked 2026-11-10 with fifteen pictures: Bloodborne's moonlit hill
of white flowers under a great tree with broken columns on the skyline, a gothic castle on a crag with a dragon over
it, white roses on a balustrade with urns, ruined gothic arches, a stone bridge over a lily pond, stairs with water
running down them between lanterns, an avenue of old trees arching over a path, a willow by a pond with a rotunda).
"Everything should be the grey colour though (except for flowers, if you make flowers make the petals white)."

Every piece is a tiled prop: it wears the map's own surfaces (RuinFlag, RealmShard, Basalt, RockGrey, RealmAsh) at
their density, so it costs no new textures, and the flat colours (PetalWhite, LeafGrey, PondWater, WaterFall) cost
nothing at all; each flat colour is a piece of its own that ModelLibrary paints (its FLAT table). Front to -Y, up Z.

    LobbyFlowersA    a drift of white flowers (open six-petalled blossoms on stems, grey leaves)
    LobbyRoseBush    a low bush of grey leaves with white roses
    LobbyGreatTree   the great old tree: buttressed trunk, roots, huge limbs spreading wide, fine twigs
    LobbyArchTree    an old tree leaning over, its crown arching (in pairs, the avenue)
    LobbyWillow      a willow, its strands hanging to the ground
    LobbyColumn      a fluted column snapped off, on its base; a fallen drum beside it
    LobbyGothicRuin  a ruined wall with two pointed arches, clustered shafts, a broken top, fallen stones
    LobbyRotunda     a round temple: two steps, ten fluted columns, an entablature, a dome with a lantern
    LobbyBridge      a stone footbridge with one arch and parapets
    LobbyBalustrade  a run of balustrade 8 studs long
    LobbyUrn         a stone urn on a pedestal, white roses spilling over it
    LobbyLantern     a stone post with an iron lantern, a pale light in it
    LobbyLilies      lily pads with white water lilies
    LobbyCascade     a stone stair with water running down its steps into a basin
    LobbyCastle      a gothic castle (far off, on a crag the map stands it on)
    LobbyDragon      a dragon, wings spread (it circles the castle: World/LobbyDragon)
"""

import math
import random

import bmesh
from mathutils import Matrix, Vector
from mathutils.geometry import tessellate_polygon

import modelkit as mk
import propkit as pk
from props import prop
from props_realm import surface


def mesh_obj(name, verts, faces, mat):
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass
    return mk._obj_from_bm(name, bm, mat)


class Mesh:
    """Vertices and faces gathered for one surface, made into one object at the end."""

    def __init__(self):
        self.verts, self.faces = [], []

    def add(self, pts, both=False):
        base = len(self.verts)
        self.verts.extend(tuple(p) for p in pts)
        idx = list(range(base, base + len(pts)))
        self.faces.append(idx)
        if both:
            self.faces.append(list(reversed(idx)))

    def obj(self, name, mat):
        return mesh_obj(name, self.verts, self.faces, mat) if self.faces else None


def slab_poly(name, outline, depth, mat, y=0.0):
    """A flat outline [(x, z)] (concave is fine) stood upright in the XZ plane, `depth` thick along Y about y."""
    tris = tessellate_polygon([[Vector((x, z, 0.0)) for x, z in outline]])
    n = len(outline)
    verts = [(x, y - depth / 2, z) for x, z in outline] + [(x, y + depth / 2, z) for x, z in outline]
    faces = []
    for a, b, c in tris:
        faces.append([a, b, c])
        faces.append([n + c, n + b, n + a])
    for i in range(n):
        j = (i + 1) % n
        faces.append([i, n + i, n + j, j])
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        try:
            bm.faces.new([vs[i] for i in f])
        except ValueError:
            pass
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mk._obj_from_bm(name, bm, mat)


def fluted(name, r, z0, z1, mat, flutes=20, depth=0.08, top=None, rng=None, taper=0.0):
    """A fluted shaft from z0 to z1 (radius r, tapering by `taper` toward the top); top: None for a flat cap, else the
    height of a jagged break (each corner of the top ring knocked down a different amount)."""
    n = flutes * 2
    ring0, ring1 = [], []
    for k in range(n):
        a = math.tau * k / n
        rr = r * (1.0 if k % 2 == 0 else 1 - depth)
        ring0.append((math.cos(a) * rr, math.sin(a) * rr, z0))
        rt = rr * (1 - taper)
        zz = z1 if top is None else z1 - rng.uniform(0.0, top)
        ring1.append((math.cos(a) * rt, math.sin(a) * rt, zz))
    verts = ring0 + ring1 + [(0.0, 0.0, z0), (0.0, 0.0, (z1 - (top or 0.0) * 0.6) if top else z1)]
    c0, c1 = 2 * n, 2 * n + 1
    faces = []
    for k in range(n):
        j = (k + 1) % n
        faces.append([k, j, n + j, n + k])
        faces.append([c0, j, k])
        faces.append([c1, n + k, n + j])
    bm = bmesh.new()
    vs = [bm.verts.new(v) for v in verts]
    for f in faces:
        bm.faces.new([vs[i] for i in f])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return mk._obj_from_bm(name, bm, mat)


def flipped(obj):
    """The object with every face turned the other way (a shell seen from inside)."""
    for poly in obj.data.polygons:
        poly.flip()
    obj.data.update()
    return obj


# Flowers --------------------------------------------------------------------------------------------------------


def blossom(m, at, normal, r, rng, petals=6):
    """An open blossom at `at` facing `normal`: pointed petals cupped up a little round a raised heart."""
    nz = Vector(normal).normalized()
    helper = Vector((1, 0, 0)) if abs(nz.x) < 0.9 else Vector((0, 1, 0))
    u = nz.cross(helper).normalized()
    v = nz.cross(u)
    at = Vector(at)
    turn = rng.uniform(0, math.tau)
    for k in range(petals):
        a = turn + math.tau * k / petals + rng.uniform(-0.12, 0.12)
        length = r * rng.uniform(0.85, 1.1)

        def p(rad, side, lift):
            aa = a + side
            return at + (u * math.cos(aa) + v * math.sin(aa)) * rad + nz * lift

        cup = length * 0.28
        pts = [p(0.12 * length, -0.32, 0.05 * length), p(0.6 * length, -0.2, cup * 0.6), p(length, 0.0, cup),
               p(0.6 * length, 0.2, cup * 0.6), p(0.12 * length, 0.32, 0.05 * length)]
        m.add(pts)
    # the heart: a small raised star of three short quads
    heart = [at + nz * (0.12 * r) + (u * math.cos(math.tau * k / 5) + v * math.sin(math.tau * k / 5)) * 0.14 * r
             for k in range(5)]
    m.add(heart)


def leaf(m, base, direction, length, width, rng, droop=0.35):
    """A lanceolate leaf from `base` along `direction` (its blade arching over and down a little)."""
    d = Vector(direction).normalized()
    side = d.cross(Vector((0, 0, 1)))
    if side.length < 1e-3:
        side = Vector((1, 0, 0))
    side.normalize()
    base = Vector(base)
    pts_l, pts_r = [], []
    for k, (t, w) in enumerate(((0.0, 0.0), (0.25, 0.8), (0.55, 1.0), (0.82, 0.6), (1.0, 0.0))):
        c = base + d * length * t + Vector((0, 0, -droop * length * t * t))
        pts_l.append(c - side * width * w / 2)
        pts_r.append(c + side * width * w / 2)
    outline = [pts_l[0]] + pts_r[1:4] + [pts_r[4]] + list(reversed(pts_l[1:4]))
    m.add(outline)


def stem_sweep(name, pts, r, mat):
    return pk.sweep(name, pts, [r, r * 0.8, r * 0.6][:len(pts)] + [r * 0.5] * max(0, len(pts) - 3), mat, sides=3,
                    caps=False)


def flower_patch(seed, count, radius):
    crust, petal, green = surface("RealmAsh"), surface("PetalWhite"), surface("LeafGrey")
    rng = random.Random(seed)
    parts = []
    petals, leaves = Mesh(), Mesh()
    stems = []
    for k in range(count):
        a = rng.uniform(0, math.tau)
        d = radius * math.sqrt(rng.random())
        x, y = math.cos(a) * d, math.sin(a) * d
        h = rng.uniform(0.45, 1.25)
        lean = Vector((rng.uniform(-0.25, 0.25), rng.uniform(-0.25, 0.25), 1.0)).normalized()
        top = Vector((x, y, 0.0)) + lean * h
        stems.append([(x, y, -0.05), tuple(Vector((x, y, 0)) + lean * h * 0.5 + Vector((0.03, 0, 0))), tuple(top)])
        face = (lean + Vector((rng.uniform(-0.5, 0.5), rng.uniform(-0.5, 0.5), 0.6))).normalized()
        blossom(petals, top, face, rng.uniform(0.24, 0.36), rng)
        for j in range(rng.choice((2, 3))):
            b = rng.uniform(0, math.tau)
            leaf(leaves, (x, y, 0.02 + 0.05 * j), (math.cos(b), math.sin(b), rng.uniform(0.5, 1.1)),
                 rng.uniform(0.35, 0.6), rng.uniform(0.09, 0.14), rng)
    # (the first part's surface is the prop's own mesh: a few clods of the ground the stems stand in)
    for k in range(max(3, count // 12)):
        a = rng.uniform(0, math.tau)
        d = radius * 0.7 * math.sqrt(rng.random())
        parts.append(mk.sphere("Clod", rng.uniform(0.18, 0.32), (math.cos(a) * d, math.sin(a) * d, -0.04),
                               scale=(1.0, 0.8, 0.3), mat=crust, segments=8, rings=4))
    for k, pts in enumerate(stems):
        parts.append(stem_sweep("Stem", pts, 0.022, green))
    parts.append(leaves.obj("Leaves", green))
    parts.append(petals.obj("Petals", petal))
    return [p for p in parts if p is not None], []


@prop("LobbyFlowersA", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Lobby", tiled=True)
def lobby_flowers_a():
    """A drift of white flowers (Bloodborne's hill under the moon): about 46 open six-petalled blossoms on thin stems,
    grey lance leaves at their feet, over a patch 9 studs across."""
    return flower_patch(11, 50, 4.5)


def rose(m, at, r, rng):
    """A white rose, open: three rings of cupped petals, each ring smaller and more upright, round a closed heart."""
    at = Vector(at)
    turn = rng.uniform(0, math.tau)
    for ring, (count, rad, rise, open_) in enumerate(((6, 1.0, 0.25, 0.85), (5, 0.7, 0.45, 0.55), (4, 0.42, 0.6, 0.3))):
        for k in range(count):
            a = turn + math.tau * k / count + ring * 0.5
            out = Vector((math.cos(a), math.sin(a), 0.0))
            side = Vector((-math.sin(a), math.cos(a), 0.0))
            w = r * rad * 0.62
            base = at + out * r * rad * 0.25
            tip = at + out * r * rad * open_ + Vector((0, 0, r * rise))
            mid = base.lerp(tip, 0.55) + Vector((0, 0, r * 0.08))
            m.add([base - side * w * 0.4, mid - side * w, tip - side * w * 0.6, tip + side * w * 0.6, mid + side * w,
                   base + side * w * 0.4], both=ring == 0)
    m.add([at + Vector((math.cos(math.tau * k / 5) * r * 0.16, math.sin(math.tau * k / 5) * r * 0.16, r * 0.55))
           for k in range(5)], both=True)


def rose_cluster(prefix, rng, centre, radius, height, roses, petal, green, parts, dome=True, leafy=9):
    leaves, blooms = Mesh(), Mesh()
    cx, cy, cz = centre
    for k in range(int(roses * leafy)):
        a = rng.uniform(0, math.tau)
        d = radius * math.sqrt(rng.random())
        z = cz + (height * math.sqrt(max(0.0, 1 - (d / radius) ** 2)) if dome else height * rng.random())
        base = (cx + math.cos(a) * d, cy + math.sin(a) * d, z * rng.uniform(0.6, 1.0))
        b = rng.uniform(0, math.tau)
        leaf(leaves, base, (math.cos(b), math.sin(b), rng.uniform(-0.2, 0.6)), rng.uniform(0.3, 0.48),
             rng.uniform(0.18, 0.26), rng, droop=0.2)
    for k in range(roses):
        a = rng.uniform(0, math.tau)
        d = radius * 0.85 * math.sqrt(rng.random())
        z = cz + (height * math.sqrt(max(0.0, 1 - (d / radius) ** 2)) if dome else height * rng.uniform(0.5, 1.0))
        rose(blooms, (cx + math.cos(a) * d, cy + math.sin(a) * d, z + 0.05), rng.uniform(0.26, 0.38), rng)
    parts.append(leaves.obj(prefix + "Leaves", green))
    parts.append(blooms.obj(prefix + "Roses", petal))


@prop("LobbyRoseBush", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Lobby", tiled=True)
def lobby_rose_bush():
    """A low bush of white roses (the castle's garden, picture 8): a mound of grey leaves, thorny canes, a dozen roses
    open on it, 4 studs across."""
    crust, petal, green = surface("RealmAsh"), surface("PetalWhite"), surface("LeafGrey")
    rng = random.Random(31)
    parts = [mk.sphere("Clod", 0.7, (0, 0, 0.0), scale=(1.0, 1.0, 0.2), mat=crust, segments=8, rings=4)]
    for k in range(9):
        a = math.tau * k / 9
        parts.append(stem_sweep("Cane", [(0, 0, 0), (math.cos(a) * 0.6, math.sin(a) * 0.6, 0.6),
                                          (math.cos(a) * 1.1, math.sin(a) * 1.1, 0.8)], 0.05, green))
    rose_cluster("Bush", rng, (0, 0, 0.3), 2.0, 1.6, 10, petal, green, parts, leafy=16)
    return [p for p in parts if p is not None], []


# Trees ----------------------------------------------------------------------------------------------------------


def _bend(d, angle, rng):
    helper = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
    u = d.cross(helper).normalized()
    v = d.cross(u)
    around = rng.uniform(0, math.tau)
    side = u * math.cos(around) + v * math.sin(around)
    a = math.radians(angle)
    return (d * math.cos(a) + side * math.sin(a)).normalized()


def tree(prefix, seed, bark, height, trunk, levels, spread, lean=(0.0, 0.0), droop=0.0, sides=12, first=0.36,
         forks=(2, 3), roots=7, strands=None):
    """A gnarled old tree: a buttressed trunk flaring into roots, forking into limbs that fork again, bending as they
    go; droop pulls the outer limbs down. strands: (mat, count per tip, length) for hanging twigs (the willow's)."""
    rng = random.Random(seed)
    parts, tips = [], []

    def limb(p, d, length, r, level):
        n = 5 if level == 0 else (4 if level < 3 else 3)
        pts, radii = [p], [r]
        q, cur = p, d
        for k in range(n):
            cur = _bend(cur, rng.uniform(6, 18) if level else rng.uniform(3, 9), rng)
            cur = (cur + Vector((0, 0, 0.12 - droop * level * 0.18))).normalized()
            q = q + cur * length / n
            pts.append(q)
            radii.append(r * (1 - 0.42 * (k + 1) / n))
        parts.append(pk.sweep(prefix + "Limb", [tuple(v) for v in pts], radii, bark,
                              sides=max(3, sides - 3 * level), caps=level > 0))
        if level >= levels:
            tips.append((q, cur, radii[-1]))
            return
        n_forks = forks[0] if level == 0 else rng.choice(forks)
        base = rng.uniform(0, math.tau)
        for f in range(n_forks):
            nd = _bend(cur, spread * rng.uniform(0.7, 1.3), rng)
            limb(q, nd, length * rng.uniform(0.62, 0.8), radii[-1] * 0.95, level + 1)
        if level < levels - 1 and rng.random() < 0.65:
            mid = pts[len(pts) // 2]
            limb(mid, _bend(d, spread * 1.5, rng), length * 0.5, r * 0.42, level + 2)

    # the root flare: buttresses running out and down into the ground
    for k in range(roots):
        a = math.tau * k / roots + rng.uniform(-0.25, 0.25)
        out = Vector((math.cos(a), math.sin(a), 0.0))
        reach = trunk * rng.uniform(2.2, 3.4)
        pts = [Vector((0, 0, trunk * 1.8)) + out * trunk * 0.6, out * trunk * 1.1 + Vector((0, 0, trunk * 0.7)),
               out * reach * 0.7 + Vector((0, 0, 0.1)), out * reach + Vector((0, 0, -0.5))]
        parts.append(pk.sweep(prefix + "Root", [tuple(v) for v in pts],
                              [trunk * 0.5, trunk * 0.42, trunk * 0.22, trunk * 0.08], bark, sides=7))
    limb(Vector((0, 0, -0.4)), Vector((lean[0], lean[1], 1.0)).normalized(), height * first, trunk, 0)
    if strands:
        mat, per, length = strands
        for q, cur, r in tips:
            for j in range(per):
                start = q + Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), rng.uniform(-0.3, 0.3)))
                drop = length * rng.uniform(0.6, 1.2)
                if start.z - drop < 0.4:
                    drop = max(1.0, start.z - 0.4)
                sway = Vector((rng.uniform(-0.6, 0.6), rng.uniform(-0.6, 0.6), 0.0))
                pts = [start, start + cur * 0.6 + sway * 0.2 + Vector((0, 0, -drop * 0.15)),
                       start + sway * 0.6 + Vector((0, 0, -drop * 0.55)), start + sway + Vector((0, 0, -drop))]
                parts.append(pk.sweep(prefix + "Strand", [tuple(v) for v in pts], [0.11, 0.08, 0.06, 0.02], mat,
                                      sides=3, caps=False))
    else:
        # fine twigs off every tip, a few hanging
        for q, cur, r in tips:
            for j in range(3):
                nd = _bend(cur, 40, rng)
                end = q + nd * rng.uniform(1.2, 2.6) + Vector((0, 0, -rng.uniform(0.0, 1.2)))
                parts.append(pk.sweep(prefix + "Twig", [tuple(q), tuple(q.lerp(end, 0.5) + Vector((0, 0, 0.2))),
                                                        tuple(end)], [r * 0.8, r * 0.5, 0.02], bark, sides=3,
                                      caps=False))
    return parts


@prop("LobbyGreatTree", pivot="bottom", material="Slate", collide=False, texture=256, set="Lobby", tiled=True,
      anchor=(0, 0))
def lobby_great_tree():
    """The great old tree of the hill (pictures 5 and 6): a trunk six studs thick, buttressed and flaring into roots
    that run into the flowers, forking low into huge limbs that spread wide and droop at their ends, fine twigs at
    every tip. 50 studs tall, 60 across."""
    return tree("Great", 6, surface("Basalt"), 92.0, 5.0, 4, 34.0, lean=(0.05, -0.04), droop=0.3, sides=12,
                first=0.24, forks=(3, 3), roots=9), []


@prop("LobbyArchTree", pivot="bottom", material="Slate", collide=False, texture=256, set="Lobby", tiled=True,
      anchor=(0, 0))
def lobby_arch_tree():
    """An old tree leaning over (picture 13's avenue): its trunk leaning toward +X and its crown arching over, so a pair
    of them, facing, close over a path."""
    return tree("Arch", 13, surface("Basalt"), 44.0, 1.9, 4, 30.0, lean=(0.55, 0.0), droop=0.25, sides=10,
                first=0.42), []


@prop("LobbyWillow", pivot="bottom", material="Slate", collide=False, texture=256, set="Lobby", tiled=True,
      anchor=(0, 0))
def lobby_willow():
    """A willow by water (picture 14): a leaning trunk, limbs arching out and over, and from every tip long strands of
    grey leaves hanging nearly to the ground."""
    trunk = tree("Willow", 21, surface("Basalt"), 44.0, 2.1, 4, 36.0, lean=(0.35, -0.1), droop=0.15, sides=10,
                 first=0.36, forks=(2, 3), roots=6, strands=(surface("LeafGrey"), 5, 15.0))
    return trunk, []


# Stone ----------------------------------------------------------------------------------------------------------


@prop("LobbyColumn", pivot="bottom", material="Slate", collide=True, texture=256, set="Lobby", tiled=True)
def lobby_column():
    """A column standing alone, snapped off (picture 5's skyline): a square plinth, a moulded base, a fluted shaft 22
    studs tall broken off jagged; a fallen drum lying in front of it."""
    stone = surface("RealmShard")
    rng = random.Random(41)
    parts = [mk.box("Plinth", (3.6, 3.6, 1.2), (0, 0, 0.6), mat=stone, bevel=0.06),
             mk.lathe("Base", [(1.55, 0.0), (1.55, 0.25), (1.35, 0.42), (1.42, 0.6), (1.2, 0.8), (1.18, 0.95)],
                      loc=(0, 0, 1.2), mat=stone, segments=24),
             fluted("Shaft", 1.12, 2.1, 24.0, stone, flutes=14, depth=0.07, top=3.2, rng=rng, taper=0.12)]
    # the fallen drum, lying on its side in front, broken across
    drum = fluted("Drum", 1.0, -1.1, 1.1, stone, flutes=14, depth=0.07, top=0.5, rng=rng)
    drum.rotation_euler = (0.0, math.radians(90), math.radians(28))
    drum.location = (2.4, -3.6, 1.0)
    parts.append(drum)
    for k in range(5):
        parts.append(mk.box("Chip", (rng.uniform(0.4, 0.9), rng.uniform(0.3, 0.7), rng.uniform(0.2, 0.4)),
                            (rng.uniform(-3, 3), rng.uniform(-3.5, -1.6), 0.1),
                            rot=(rng.uniform(0, 30), rng.uniform(0, 30), rng.uniform(0, 90)), mat=stone, bevel=0.05))
    return parts, []


def pointed(cx, w, spring, steps=10, sharp=0.75):
    """The inside line of a pointed arch over span w centred on cx from its springing height: two arcs of radius
    sharp * w meeting at the top. Left springing to right springing."""
    R = sharp * w
    left_c = cx - w / 2 + R
    right_c = cx + w / 2 - R
    apex_cos = (cx - left_c) / R
    a_top = math.acos(max(-1.0, min(1.0, apex_cos)))
    pts = []
    for k in range(steps + 1):
        a = math.pi - (math.pi - a_top) * k / steps
        pts.append((left_c + math.cos(a) * R, spring + math.sin(a) * R))
    # (the right arc: the left one mirrored about the middle)
    _ = right_c
    return pts + [(2 * cx - x, z) for x, z in reversed(pts[:-1])]


@prop("LobbyGothicRuin", pivot="bottom", material="Slate", collide=False, texture=256, set="Lobby", tiled=True,
      anchor=(0, 0))
def lobby_gothic_ruin():
    """A ruined chapel wall (picture 9): rough masonry 26 studs long and 3 thick with two tall pointed arches (the
    right one taller), clustered shafts on the piers, an arch ring round each, its top broken off jagged and high at
    the ends; a broken stub of a side wall running back at the right; fallen blocks at its feet."""
    stone = surface("RuinFlag")
    rng = random.Random(51)
    T = 3.0
    # (x along the wall from -13 to 13, z up)
    a1 = (-5.5, 8.0, 10.0)  # centre, span, springing
    a2 = (6.0, 10.0, 12.0)
    arch1 = pointed(a1[0], a1[1], a1[2])
    arch2 = pointed(a2[0], a2[1], a2[2])
    top = []
    for k in range(27):
        x = 13.0 - k
        h = 24.0 + 6.0 * math.cos(x / 13.0 * math.pi) * 0.5 + rng.uniform(-2.2, 2.2)
        if -3 < x < 4:
            h -= 5.0  # the middle fallen in
        top.append((x, h))
    outline = [(-13.0, 0.0), (a1[0] - a1[1] / 2, 0.0)]
    outline += arch1
    outline += [(a1[0] + a1[1] / 2, 0.0), (a2[0] - a2[1] / 2, 0.0)]
    outline += arch2
    outline += [(a2[0] + a2[1] / 2, 0.0), (13.0, 0.0)]
    outline += top[:]  # (from x 13 back to -13)
    parts = [slab_poly("Wall", outline, T, stone)]
    # the arch rings: a moulded band round each opening, standing proud of both faces
    for arch in (arch1, arch2):
        for side in (-1, 1):
            pts = [(x, side * (T / 2 + 0.15), z) for x, z in arch]
            parts.append(pk.sweep("Ring", pts, 0.32, stone, sides=4))
    # clustered shafts up the piers' faces to the springing
    for x, h in ((a1[0] - a1[1] / 2 - 0.5, a1[2]), (a1[0] + a1[1] / 2 + 0.6, a1[2]), (a2[0] - a2[1] / 2 - 0.6, a2[2]),
                 (a2[0] + a2[1] / 2 + 0.5, a2[2])):
        for side in (-1, 1):
            for dx in (-0.35, 0.35):
                parts.append(mk.cylinder("Shaft", 0.22, h, loc=(x + dx, side * (T / 2 + 0.2), h / 2), mat=stone, verts=8))
            parts.append(mk.box("Capital", (1.3, 0.6, 0.5), (x, side * (T / 2 + 0.2), h + 0.2), mat=stone, bevel=0.05))
    # a plinth course along the foot
    for x0, x1 in ((-13.0, a1[0] - a1[1] / 2), (a1[0] + a1[1] / 2, a2[0] - a2[1] / 2), (a2[0] + a2[1] / 2, 13.0)):
        parts.append(mk.box("Plinth", (x1 - x0 + 0.4, T + 0.8, 1.0), ((x0 + x1) / 2, 0, 0.5), mat=stone, bevel=0.08))
    # the side wall's broken stub at the right, running back
    stub = [(-1.5, 0.0), (8.0, 0.0), (8.0, 6.0), (6.5, 9.0), (4.0, 12.5), (1.5, 15.0), (-1.5, 19.0)]
    side = slab_poly("Side", stub, 2.6, stone)
    side.rotation_euler = (0, 0, math.radians(90))
    side.location = (11.7, 1.5, 0)
    parts.append(side)
    # fallen blocks
    for k in range(9):
        x = rng.uniform(-14, 14)
        y = rng.choice((-1, 1)) * rng.uniform(2.5, 7.0)
        s = rng.uniform(0.7, 1.8)
        parts.append(mk.box("Block", (s * 1.4, s, s * 0.8), (x, y, s * 0.3),
                            rot=(rng.uniform(-20, 20), rng.uniform(-20, 20), rng.uniform(0, 90)), mat=stone, bevel=0.08))
    return parts, []


@prop("LobbyRotunda", pivot="bottom", material="Slate", collide=False, texture=256, set="Lobby", tiled=True)
def lobby_rotunda():
    """A round temple by the water (pictures 14 and 15): two steps, ten fluted columns with moulded bases and capitals,
    a heavy entablature with a cornice, a dome over it (seen from inside too) with a little lantern and a finial."""
    stone, dark = surface("RealmShard"), surface("Basalt")
    parts = [mk.lathe("Steps", [(9.4, 0.0), (9.4, 0.5), (8.6, 0.5), (8.6, 1.0), (0.0, 1.0)], mat=stone, segments=30)]
    R, n = 7.2, 10
    top = 13.0
    rng = random.Random(61)
    for k in range(n):
        a = math.tau * (k + 0.5) / n
        x, y = math.cos(a) * R, math.sin(a) * R
        base = mk.lathe("ColBase", [(0.95, 0.0), (0.95, 0.3), (0.8, 0.45), (0.85, 0.6), (0.7, 0.75)], mat=stone,
                        segments=12)
        base.location = (x, y, 1.0)
        parts.append(base)
        shaft = fluted("ColShaft", 0.66, 1.75, top - 0.9, stone, flutes=10, depth=0.08, taper=0.08)
        shaft.location = (x, y, 0)
        parts.append(shaft)
        cap = mk.lathe("ColCap", [(0.6, 0.0), (0.72, 0.25), (0.9, 0.5), (0.9, 0.62)], mat=stone, segments=12)
        cap.location = (x, y, top - 0.9)
        parts.append(cap)
        parts.append(mk.box("Abacus", (2.0, 2.0, 0.28), (x, y, top - 0.14), rot=(0, 0, math.degrees(a)), mat=stone))
    # the entablature: a ring band, a frieze, a cornice; then the dome
    parts.append(mk.lathe("Entab", [(R - 1.1, 0.0), (R + 1.1, 0.0), (R + 1.1, 1.2), (R + 1.0, 1.25), (R + 1.0, 2.0),
                                    (R + 1.7, 2.3), (R + 1.7, 2.6), (R - 1.1, 2.6)], loc=(0, 0, top), mat=stone,
                          segments=30, caps=False))
    parts.append(flipped(mk.lathe("EntabIn", [(R - 1.1, 0.0), (R - 1.1, 2.6)], loc=(0, 0, top), mat=stone,
                                  segments=30, caps=False)))
    dome_prof = [(R + 0.6, 0.0)]
    for k in range(1, 9):
        a = math.pi / 2 * k / 9
        dome_prof.append(((R + 0.6) * math.cos(a), 5.6 * math.sin(a)))
    dome_prof += [(1.1, 5.6), (0.0, 5.6)]
    parts.append(mk.lathe("Dome", dome_prof, loc=(0, 0, top + 2.6), mat=dark, segments=28, caps=False))
    inner_prof = [((R - 0.8) * math.cos(math.pi / 2 * k / 6), 5.3 * math.sin(math.pi / 2 * k / 6)) for k in range(6)]
    parts.append(flipped(mk.lathe("DomeIn", inner_prof + [(0.0, 5.3)], loc=(0, 0, top + 2.6), mat=stone, segments=20,
                                  caps=False)))
    # ribs over the dome
    for k in range(0, 10, 2):
        a = math.tau * k / 10
        pts = [((R + 0.65) * math.cos(b) * math.cos(a), (R + 0.65) * math.cos(b) * math.sin(a),
                top + 2.6 + 5.65 * math.sin(b)) for b in [math.pi / 2 * j / 8 for j in range(8)]]
        parts.append(pk.sweep("Rib", pts, 0.18, dark, sides=4))
    # the lantern and its finial
    lz = top + 2.6 + 5.6
    for k in range(6):
        a = math.tau * k / 6
        parts.append(mk.box("LanternPost", (0.25, 0.25, 1.4), (math.cos(a) * 0.95, math.sin(a) * 0.95, lz + 0.7),
                            mat=stone))
    parts.append(mk.lathe("LanternCap", [(1.3, 0.0), (1.3, 0.25), (0.6, 0.9), (0.15, 1.3), (0.3, 1.6), (0.0, 2.4)],
                          loc=(0, 0, lz + 1.4), mat=dark, segments=12))
    _ = rng
    return parts, []


@prop("LobbyBridge", pivot="bottom", material="Slate", collide=False, texture=256, set="Lobby", tiled=True)
def lobby_bridge():
    """A stone footbridge over the lily pond (picture 11): one arch of dressed stone 12 studs across, its deck rising
    gently from both ends to 2.6 over the water, low parapets with a coping. 24 long (along Y), 5 wide."""
    stone = surface("RuinFlag")
    L, W = 24.0, 5.0

    def deck(y):
        u = y / (L / 2)
        return 0.2 + 2.4 * (1 - u * u)

    span, rise = 12.0, 3.4
    under = []
    for k in range(17):
        a = math.pi * k / 16
        under.append((-math.cos(a) * span / 2, 0.0 + math.sin(a) * rise - 1.0))
    outline = [(-L / 2, -0.6), (-span / 2, -0.6)] + under[1:-1] + [(span / 2, -0.6), (L / 2, -0.6)]
    outline += [(y, deck(y)) for y in [L / 2 - k * L / 16 for k in range(17)]]
    body = slab_poly("Body", outline, W, stone)
    body.rotation_euler = (0, 0, math.radians(90))
    parts = [body]
    for side in (-1, 1):
        rail = [(-L / 2, deck(-L / 2))] + [(y, deck(y) + 1.1) for y in [-L / 2 + k * L / 12 for k in range(13)]] + \
               [(L / 2, deck(L / 2))]
        top_line = [(y, z) for y, z in rail]
        para = slab_poly("Parapet", [(-L / 2, deck(-L / 2) - 0.2)] + top_line[1:-1] +
                         [(L / 2, deck(L / 2) - 0.2)] + [(y, deck(y) - 0.2) for y in
                                                          [L / 2 - k * L / 12 for k in range(1, 12)]], 0.6, stone)
        para.rotation_euler = (0, 0, math.radians(90))
        para.location = (side * (W / 2 - 0.3), 0, 0)
        parts.append(para)
        pts = [(side * (W / 2 - 0.3), y, deck(y) + 1.2) for y in [-L / 2 + k * L / 12 for k in range(13)]]
        parts.append(pk.sweep("Coping", pts, 0.42, stone, sides=4))
        for y in (-L / 2 + 0.4, L / 2 - 0.4):
            parts.append(mk.box("EndPost", (0.9, 0.9, 1.9), (side * (W / 2 - 0.3), y, deck(y) + 0.75), mat=stone,
                                bevel=0.06))
    # the arch's voussoirs: a band of blocks round the opening on both faces
    for side in (-1, 1):
        pts = [(side * (W / 2 + 0.1), x, z) for x, z in under]
        parts.append(pk.sweep("Voussoir", pts, 0.45, stone, sides=4))
    return parts, []


@prop("LobbyBalustrade", pivot="bottom", material="Slate", collide=True, texture=256, set="Lobby", tiled=True)
def lobby_balustrade():
    """A run of stone balustrade 8 studs long (picture 8): a base rail, ten turned balusters, a moulded top rail, a
    square post at one end (the next run's start). 3.4 tall."""
    stone = surface("RuinFlag")
    parts = [mk.box("BaseRail", (8.0, 1.1, 0.45), (0, 0, 0.22), mat=stone, bevel=0.05),
             mk.box("TopRail", (8.0, 1.1, 0.4), (0, 0, 3.0), mat=stone, bevel=0.06),
             mk.box("TopCap", (8.0, 1.3, 0.22), (0, 0, 3.3), mat=stone, bevel=0.05),
             mk.box("Post", (1.3, 1.3, 3.4), (-3.4, 0, 1.7), mat=stone, bevel=0.06),
             mk.box("PostCap", (1.6, 1.6, 0.3), (-3.4, 0, 3.55), mat=stone, bevel=0.06)]
    prof = [(0.22, 0.0), (0.28, 0.12), (0.18, 0.3), (0.32, 0.9), (0.38, 1.25), (0.2, 1.75), (0.15, 2.0), (0.28, 2.15),
            (0.0, 2.15)]
    for k in range(7):
        x = -2.1 + k * 0.7
        b = mk.lathe("Baluster", prof, loc=(x, 0, 0.45), mat=stone, segments=8)
        parts.append(b)
    return parts, []


@prop("LobbyUrn", pivot="bottom", material="Slate", collide=True, texture=256, set="Lobby", tiled=True)
def lobby_urn():
    """A stone urn on a pedestal (picture 8), white roses spilling over its lip: a square pedestal with a moulded base
    and cap, a turned urn with handles, the bush in it. 6 tall."""
    stone, petal, green = surface("RuinFlag"), surface("PetalWhite"), surface("LeafGrey")
    rng = random.Random(71)
    parts = [mk.box("PedBase", (2.2, 2.2, 0.4), (0, 0, 0.2), mat=stone, bevel=0.05),
             mk.box("PedDie", (1.7, 1.7, 2.4), (0, 0, 1.6), mat=stone, bevel=0.05),
             mk.box("PedCap", (2.2, 2.2, 0.35), (0, 0, 2.97), mat=stone, bevel=0.05),
             mk.lathe("Urn", [(0.5, 0.0), (0.38, 0.25), (0.42, 0.45), (0.95, 0.9), (1.15, 1.4), (1.05, 1.8),
                              (1.2, 1.95), (1.2, 2.1), (0.0, 2.1)], loc=(0, 0, 3.15), mat=stone, segments=16)]
    for side in (-1, 1):
        parts.append(pk.sweep("Handle", [(side * 0.95, 0, 4.75), (side * 1.45, 0, 4.7), (side * 1.4, 0, 4.25),
                                         (side * 1.05, 0, 4.0)], 0.1, stone, sides=5))
    rose_cluster("Urn", rng, (0, 0, 5.1), 1.35, 0.9, 7, petal, green, parts)
    # a few roses trailing down over the lip
    blooms, leaves = Mesh(), Mesh()
    for k in range(3):
        a = rng.uniform(0, math.tau)
        z = rng.uniform(3.8, 4.8)
        rose(blooms, (math.cos(a) * 1.35, math.sin(a) * 1.35, z), 0.28, rng)
        leaf(leaves, (math.cos(a) * 1.2, math.sin(a) * 1.2, z + 0.3), (math.cos(a), math.sin(a), -0.6), 0.4, 0.18, rng)
    parts.append(leaves.obj("TrailLeaves", green))
    parts.append(blooms.obj("TrailRoses", petal))
    return [p for p in parts if p is not None], []


@prop("LobbyLantern", pivot="bottom", material="Slate", collide=True, texture=256, set="Lobby", tiled=True,
      lights=[dict(at=(0, 0, 4.55), kind="point", color=(226, 228, 236), range=16, brightness=0.9)])
def lobby_lantern():
    """A lantern on a stone post (picture 12): a square post with a moulded base and cap, an iron lantern on it (four
    corner bars, a pierced hood, a finial), a pale light inside. 6 tall."""
    stone, iron = surface("RuinFlag"), surface("BlackTrim")
    parts = [mk.box("Base", (1.3, 1.3, 0.5), (0, 0, 0.25), mat=stone, bevel=0.05),
             mk.box("Post", (0.8, 0.8, 3.0), (0, 0, 2.0), mat=stone, bevel=0.05),
             mk.box("Cap", (1.2, 1.2, 0.3), (0, 0, 3.65), mat=stone, bevel=0.05),
             mk.box("Floor", (1.0, 1.0, 0.12), (0, 0, 3.86), mat=iron)]
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.box("Bar", (0.1, 0.1, 1.35), (sx * 0.45, sy * 0.45, 4.6), mat=iron))
    parts.append(mk.lathe("Hood", [(0.7, 0.0), (0.7, 0.12), (0.18, 0.6), (0.1, 0.9), (0.18, 1.0), (0.0, 1.3)],
                          loc=(0, 0, 5.25), mat=iron, segments=4))
    glows = [mk.box("Glass", (0.78, 0.78, 1.25), (0, 0, 4.55), mat=pk.glow("LL_Glow", (226, 228, 236), 3.0))]
    return parts, glows


@prop("LobbyLilies", pivot="bottom", material="SmoothPlastic", collide=False, texture=256, set="Lobby", tiled=True)
def lobby_lilies():
    """Lily pads on still water with white water lilies among them (picture 11), 8 studs across."""
    crust, petal, green = surface("RealmAsh"), surface("PetalWhite"), surface("LeafGrey")
    rng = random.Random(81)
    pads, blooms = Mesh(), Mesh()
    for k in range(26):
        a = rng.uniform(0, math.tau)
        d = 4.0 * math.sqrt(rng.random())
        cx, cy = math.cos(a) * d, math.sin(a) * d
        r = rng.uniform(0.35, 0.8)
        notch = rng.uniform(0, math.tau)
        pts = [(cx, cy, 0.02)]
        for j in range(14):
            b = notch + 0.35 + (math.tau - 0.7) * j / 13
            pts.append((cx + math.cos(b) * r, cy + math.sin(b) * r, 0.02 + 0.03 * math.sin(j)))
        pads.add(pts)
        if k % 4 == 0:
            blossom(blooms, (cx + 0.1, cy, 0.12), (0, 0, 1), r * 0.55, rng, petals=8)
    parts = [mk.sphere("Clod", 0.15, (0, 0, -0.3), scale=(1, 1, 0.3), mat=crust, segments=6, rings=3),
             pads.obj("Pads", green), blooms.obj("Lilies", petal)]
    return [p for p in parts if p is not None], []


@prop("LobbyCascade", pivot="bottom", material="Slate", collide=False, texture=256, set="Lobby", tiled=True,
      anchor=(0, 0))
def lobby_cascade():
    """Stairs with water running down them (picture 12): six broad stone steps between low walls falling 6 studs from a
    spring at the back (+Y) to a round basin at the front, a sheet of water on every tread and falling over every
    nosing, foam where it lands. 4.4 wide, 16 long."""
    stone, water, fall = surface("RuinFlag"), surface("PondWater"), surface("WaterFall")
    parts = []
    n, rise, run, w = 6, 1.0, 2.0, 3.4
    for k in range(n):
        z = (k + 1) * rise
        y = k * run
        parts.append(mk.box("Step", (w, run, z), (0, y + run / 2, z / 2), mat=stone, bevel=0.06))
    parts.append(mk.box("Head", (w, 2.6, n * rise + 0.4), (0, n * run + 1.3, (n * rise + 0.4) / 2), mat=stone,
                        bevel=0.08))
    for side in (-1, 1):
        prof = [(-0.5, 0.0), (n * run + 2.6, 0.0), (n * run + 2.6, n * rise + 1.3)]
        prof += [(k * run, (k + 1) * rise + 0.9) for k in range(n - 1, -1, -1)] + [(-0.5, 1.3)]
        wall = slab_poly("Wall", [(y, z) for y, z in prof], 0.6, stone)
        wall.rotation_euler = (0, 0, math.radians(90))
        wall.location = (side * (w / 2 + 0.3), 0, 0)
        parts.append(wall)
    # the basin at the foot
    parts.append(mk.lathe("Basin", [(2.9, 0.0), (2.9, 0.75), (2.5, 0.85), (2.4, 0.3), (0.0, 0.3)], loc=(0, -2.6, 0),
                          mat=stone, segments=24))
    # the water: a film on every tread, a sheet over every nosing, the basin's surface, the spring's pool
    films = Mesh()
    sheets = Mesh()
    hw = w / 2 - 0.15
    for k in range(n):
        z = (k + 1) * rise + 0.05
        y0, y1 = k * run, (k + 1) * run
        films.add([(-hw, y0 + 0.05, z), (hw, y0 + 0.05, z), (hw, y1, z), (-hw, y1, z)])
        # the fall over the nosing: bowed out a little, down to the tread below
        zb = k * rise + 0.05 if k else 0.8
        sheets.add([(-hw * 0.9, y0 - 0.05, z), (hw * 0.9, y0 - 0.05, z), (hw * 0.9, y0 - 0.25, zb + 0.2),
                    (-hw * 0.9, y0 - 0.25, zb + 0.2)], both=True)
    films.add([(math.cos(math.tau * j / 24) * 2.35, -2.6 + math.sin(math.tau * j / 24) * 2.35, 0.7)
               for j in range(24)])
    films.add([(-hw, n * run + 0.2, n * rise + 0.45), (hw, n * run + 0.2, n * rise + 0.45),
               (hw, n * run + 2.2, n * rise + 0.45), (-hw, n * run + 2.2, n * rise + 0.45)])
    parts.append(films.obj("Films", water))
    parts.append(sheets.obj("Sheets", fall))
    return [p for p in parts if p is not None], []


# Far off --------------------------------------------------------------------------------------------------------


def spire_tower(parts, mat, roof, x, y, r, h, spire, sides=6, pinnacles=True):
    parts.append(mk.cylinder("Tower", r, h, loc=(x, y, h / 2), mat=mat, verts=sides))
    parts.append(mk.cylinder("Corbel", r * 1.12, 1.2, loc=(x, y, h - 0.6), mat=mat, verts=sides))
    for k in range(sides):
        a = math.tau * (k + 0.5) / sides
        parts.append(mk.box("Merlon", (r * 0.35, r * 0.35, 1.4), (x + math.cos(a) * r * 1.02, y + math.sin(a) * r * 1.02,
                                                                    h + 0.7), mat=mat))
    parts.append(mk.cylinder("Spire", r * 0.92, spire, loc=(x, y, h + spire / 2), mat=roof, verts=sides, radius2=0.05))
    if pinnacles:
        for k in range(4):
            a = math.tau * k / 4 + math.pi / sides
            px, py = x + math.cos(a) * r * 0.95, y + math.sin(a) * r * 0.95
            parts.append(mk.cylinder("Pinnacle", r * 0.18, spire * 0.3, loc=(px, py, h + 1.4 + spire * 0.15), mat=roof,
                                     verts=4, radius2=0.02))


def gabled(parts, mat, roof, x, y, w, d, h, pitch, along="y"):
    """A block with a steep gabled roof (its ridge along y, or x)."""
    parts.append(mk.box("Hall", (w, d, h), (x, y, h / 2), mat=mat))
    span = w if along == "y" else d
    tri = [(-span / 2 - 0.4, 0.0), (span / 2 + 0.4, 0.0), (0.0, pitch)]
    r = slab_poly("Roof", tri, (d if along == "y" else w) + 0.6, roof)
    # (slab_poly stands the outline in XZ, thick along Y: a ridge along Y as made, turned for one along X)
    if along != "y":
        r.rotation_euler = (0, 0, math.radians(90))
    r.location = (x, y, h)
    parts.append(r)


@prop("LobbyCastle", pivot="bottom", material="Slate", collide=False, texture=256, set="Lobby", tiled=True)
def lobby_castle():
    """The castle on the crag (pictures 7, 8, 10), seen far off through the fog: a cathedral-tall great hall with a
    steep roof between two tall spired towers at its west front, a ring of curtain walls with round towers on the
    crag's edge, lesser halls and turrets crowding up to it, pinnacles everywhere. About 150 studs tall."""
    stone, roof = surface("Basalt"), surface("RockGrey")
    parts = []
    # the curtain wall: a ring of walls between round towers
    ring = [(-48, -30), (-10, -42), (34, -36), (52, -6), (44, 30), (8, 44), (-36, 36), (-54, 4)]
    for k, (x, y) in enumerate(ring):
        nx, ny = ring[(k + 1) % len(ring)]
        mx, my = (x + nx) / 2, (y + ny) / 2
        length = math.hypot(nx - x, ny - y)
        ang = math.degrees(math.atan2(ny - y, nx - x))
        parts.append(mk.box("Curtain", (length, 3.0, 22.0), (mx, my, 11.0), rot=(0, 0, ang), mat=stone))
        for j in range(int(length / 5.0)):
            t = (j + 0.5) / int(length / 5.0)
            parts.append(mk.box("Crenel", (1.6, 3.2, 2.0), (x + (nx - x) * t, y + (ny - y) * t, 23.0), rot=(0, 0, ang),
                                mat=stone))
        spire_tower(parts, stone, roof, x, y, 5.0, 30.0 + (k % 3) * 6, 14.0 + (k % 2) * 8)
    # the great hall (nave along y), its transept, and the west front's twin spires
    gabled(parts, stone, roof, 0, 0, 22, 50, 58, 26, along="y")
    gabled(parts, stone, roof, 0, 6, 46, 16, 48, 22, along="x")
    for side in (-1, 1):
        spire_tower(parts, stone, roof, side * 12, -27, 6.5, 92.0, 52.0, sides=8)
        spire_tower(parts, stone, roof, side * 25, 6, 4.0, 62.0, 26.0)
    spire_tower(parts, stone, roof, 0, 10, 4.5, 84.0, 46.0, pinnacles=False)  # the crossing's spire
    # buttresses down the nave's sides, pinnacled
    for side in (-1, 1):
        for k in range(6):
            y = -20 + k * 8
            parts.append(mk.box("Buttress", (4.0, 2.2, 44.0), (side * 13.5, y, 22.0), mat=stone))
            parts.append(mk.cylinder("ButPin", 0.9, 10.0, loc=(side * 14.8, y, 49.0), mat=roof, verts=4, radius2=0.05))
    # lesser halls and turrets crowding up the slope
    rng = random.Random(91)
    for k in range(6):
        a = rng.uniform(0, math.tau)
        d = rng.uniform(20, 36)
        x, y = math.cos(a) * d, math.sin(a) * d
        if abs(x) < 14 and -32 < y < 30:
            continue
        gabled(parts, stone, roof, x, y, rng.uniform(8, 14), rng.uniform(10, 18), rng.uniform(26, 40),
               rng.uniform(8, 14), along=rng.choice(("x", "y")))
        spire_tower(parts, stone, roof, x + rng.uniform(-4, 4), y + rng.uniform(-4, 4), rng.uniform(2.2, 3.4),
                    rng.uniform(38, 60), rng.uniform(14, 26), sides=6, pinnacles=False)
    return parts, []


@prop("LobbyDragon", pivot="centre", material="Slate", collide=False, texture=256, set="Lobby", tiled=True)
def lobby_dragon():
    """The dragon over the castle (picture 7), a dark shape in the fog: a long neck and tail, a horned head, two great
    wings spread, ribbed with long finger bones and the membrane between them scalloped. Flying toward -Y, 36 studs
    across the wings."""
    hide = surface("Basalt")
    parts = []
    spine = [(0, -11, 0.6), (0, -8.5, 0.9), (0, -6, 0.7), (0, -3, 0.2), (0, 0, 0), (0, 3, -0.2), (0, 6, -0.4),
             (0, 9, -0.2), (0, 12, 0.6), (0, 15, 1.6), (0.6, 18, 2.6)]
    radii = [0.45, 0.5, 0.6, 1.1, 1.4, 1.2, 0.9, 0.6, 0.4, 0.25, 0.08]
    parts.append(pk.sweep("Body", spine, radii, hide, sides=7))
    # the head: a long wedge with jaws and two swept horns
    parts.append(mk.box("Skull", (0.9, 2.4, 0.8), (0, -12.4, 0.7), rot=(-8, 0, 0), mat=hide, bevel=0.2))
    parts.append(mk.box("Jaw", (0.7, 1.8, 0.35), (0, -12.7, 0.2), rot=(10, 0, 0), mat=hide, bevel=0.12))
    for side in (-1, 1):
        parts.append(pk.sweep("Horn", [(side * 0.3, -11.6, 1.0), (side * 0.6, -10.6, 1.5), (side * 0.7, -9.6, 1.6)],
                              [0.18, 0.1, 0.02], hide, sides=4))
    # the wings: an arm out to the wrist, four fingers fanning back, the membrane between them
    membrane = Mesh()
    for side in (-1, 1):
        shoulder = Vector((side * 0.8, -3.5, 0.6))
        elbow = Vector((side * 7.0, -5.5, 2.6))
        wrist = Vector((side * 12.0, -3.0, 3.4))
        parts.append(pk.sweep("Arm", [tuple(shoulder), tuple(elbow), tuple(wrist)], [0.5, 0.35, 0.25], hide, sides=5))
        tips = [Vector((side * 18.0, -4.0, 2.0)), Vector((side * 17.5, 1.5, 1.4)), Vector((side * 14.0, 5.5, 0.8)),
                Vector((side * 8.5, 7.0, 0.3))]
        for t in tips:
            parts.append(pk.sweep("Finger", [tuple(wrist), tuple(wrist.lerp(t, 0.5) + Vector((0, 0, 0.4))), tuple(t)],
                                  [0.18, 0.12, 0.04], hide, sides=4))
        edge = [wrist] + tips + [Vector((side * 1.2, 4.0, 0.0)), shoulder, elbow]
        # the membrane: fan triangles from the wrist and the body, scalloped between the fingers
        prev = None
        for k, t in enumerate(tips):
            if prev is not None:
                mid = prev.lerp(t, 0.5) + (wrist - prev.lerp(t, 0.5)) * 0.18
                membrane.add([tuple(wrist), tuple(prev), tuple(mid)], both=True)
                membrane.add([tuple(wrist), tuple(mid), tuple(t)], both=True)
            prev = t
        membrane.add([tuple(wrist), tuple(tips[-1]), tuple(Vector((side * 1.2, 4.0, 0.0)))], both=True)
        membrane.add([tuple(wrist), tuple(Vector((side * 1.2, 4.0, 0.0))), tuple(shoulder)], both=True)
        membrane.add([tuple(wrist), tuple(shoulder), tuple(elbow)], both=True)
        _ = edge
        # the hind legs tucked under
        parts.append(pk.sweep("Leg", [(side * 0.8, 5.0, -0.6), (side * 1.4, 6.5, -1.6), (side * 1.0, 8.5, -1.4)],
                              [0.45, 0.3, 0.15], hide, sides=5))
    parts.append(membrane.obj("Membrane", hide))
    return [p for p in parts if p is not None], []
