"""Geometry for the map scenes, built directly in Roblox space.

A Scene collects faces per material (with UVs that tile in world space, so neighbouring pieces
continue the same texture), plus everything the game places itself: invisible colliders, props
from the prop library, lights, signs and particle emitters. finish() merges the faces into
meshes named Scene_<Venue>_<Material>_<n>, split into chunks so no mesh is too big for the
importer.

Coordinates: x right, y up, z backwards (Roblox). rot is degrees about +Y, like the map builder:
0 faces -Z, 90 faces -X, 180 faces +Z, -90 faces +X. Faces wind counter-clockwise seen from
outside (Roblox draws only the front of a mesh face).
"""

import math

import bpy

from maps import matlib
from maps.layout import LayoutMixin

CHUNK = 64.0  # studs
MAX_TRIS = 9000
SMALL_TRIS = 5000  # a material with fewer triangles than this stays in one mesh
MAX_SPAN = 1500.0  # ...unless it spreads wider than this (Roblox parts stop at 2048 studs)


def ry(rot):
    """Rotation about +Y by rot degrees, as a function on (x, y, z)."""
    a = math.radians(rot)
    c, s = math.cos(a), math.sin(a)

    def apply(p):
        x, y, z = p
        return (x * c + z * s, y, -x * s + z * c)

    return apply


def add(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def sub(a, b):
    return (a[0] - b[0], a[1] - b[1], a[2] - b[2])


def scale(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def cross(a, b):
    return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def dot(a, b):
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]


def norm(a):
    length = math.sqrt(dot(a, a))
    return scale(a, 1 / length) if length > 1e-9 else a


class Piece:
    __slots__ = ("verts", "faces", "uvs", "centre")

    def __init__(self):
        self.verts = []
        self.faces = []  # tuples of vertex indices
        self.uvs = []  # per face: tuple of (u, v) per corner
        self.centre = (0.0, 0.0, 0.0)


class Scene(LayoutMixin):
    """prefix names the meshes (<prefix>_<Venue>_<Material>_<n>): "Scene" for the venues in the
    shared InkboundMaps.fbx, "Map" for the big venues with an FBX of their own."""

    def __init__(self, venue, prefix="Scene", chunk=CHUNK):
        self.venue = venue
        self.prefix = prefix
        self.chunk = chunk
        self.pieces = {}  # material -> [Piece]
        self.colliders = []  # (x, y, z, sx, sy, sz, rot, query, look)
        self.ramps = []  # tilted walkable slabs (stairs, slopes)
        self.floors = []  # flat triangles (x1, z1, x2, z2, x3, z3, top y, thickness, look, query)
        self.props = []  # (key, x, y, z, rot, scale, flags)
        self.steps = []  # visible steps of stairs, drawn by the greybox: (centre, size, rot, look)
        self.lights = []
        self.signs = []
        self.emitters = []
        self.screens = []  # giant screens the game plays loops on
        self.sounds = []  # ambient sound sources (their ids are the game's to fill in)
        self.train = None  # the metro train's run, for the client to animate
        self.look_zones = []  # boxes with a lighting look of their own (the metro under Tokyo)
        self.waters = []  # boxes the game fills with Terrain water: (centre, size, rot)
        self.blinkers = []  # small lamps the client blinks (aircraft warning lights on towers)
        self.helicopter = None  # the searchlight helicopter's flight past the windows
        self.checks = {}  # the venue's own targets for check_v2 (walk times and where to measure them)
        self.far_chunk = None  # (distance, cell size): bigger chunks for far scenery (see _cell)
        self.used = set()
        self.preview_props = []  # placed by the game's own code; only drawn in previews
        self._layout_init()

    # Low level ------------------------------------------------------------------------------

    def _piece(self, mat):
        piece = Piece()
        self.pieces.setdefault(mat, []).append(piece)
        self.used.add(mat)
        return piece

    def polygon(self, mat, points, uvs=None, tile=None):
        """One face (convex polygon, counter-clockwise from the front). Without uvs, the face is
        mapped on the world plane it faces most."""
        piece = self._piece(mat)
        tile = tile or matlib.tile_size(mat)
        if uvs is None:
            uvs = planar_uvs(points, tile)
        else:
            uvs = [(u / tile, v / tile) for u, v in uvs]
        base = len(piece.verts)
        piece.verts.extend(points)
        n = len(points)
        for i in range(1, n - 1):
            piece.faces.append((base, base + i, base + i + 1))
            piece.uvs.append((uvs[0], uvs[i], uvs[i + 1]))
        piece.centre = scale(tuple(map(sum, zip(*points))), 1 / n)
        return piece

    def quad(self, mat, a, b, c, d, uvs=None, tile=None):
        return self.polygon(mat, [a, b, c, d], uvs, tile)

    # Primitives ----------------------------------------------------------------------------

    def box(self, mat, centre, size, rot=0.0, collide=False, query=True, skip=(), mats=None, tile=None):
        """A box. skip leaves out faces ('+x', '-x', '+y', '-y', '+z', '-z' in the box's own
        axes); mats gives some faces another material. UVs follow the box's axes anchored in
        the world, so boxes in a row continue the texture."""
        sx, sy, sz = (v / 2 for v in size)
        turn = ry(rot)
        back = ry(-rot)
        local_centre = back(centre)
        faces = {
            "+x": [(sx, -sy, sz), (sx, -sy, -sz), (sx, sy, -sz), (sx, sy, sz)],
            "-x": [(-sx, -sy, -sz), (-sx, -sy, sz), (-sx, sy, sz), (-sx, sy, -sz)],
            "+y": [(-sx, sy, sz), (sx, sy, sz), (sx, sy, -sz), (-sx, sy, -sz)],
            "-y": [(-sx, -sy, -sz), (sx, -sy, -sz), (sx, -sy, sz), (-sx, -sy, sz)],
            "+z": [(-sx, -sy, sz), (sx, -sy, sz), (sx, sy, sz), (-sx, sy, sz)],
            "-z": [(sx, -sy, -sz), (-sx, -sy, -sz), (-sx, sy, -sz), (sx, sy, -sz)],
        }
        for key, corners in faces.items():
            if key in skip:
                continue
            face_mat = (mats or {}).get(key, mat)
            t = tile or matlib.tile_size(face_mat)
            uvs = []
            points = []
            for corner in corners:
                lx, ly, lz = add(corner, local_centre)
                if key[1] == "x":
                    uv = (-lz if key[0] == "+" else lz, ly)
                elif key[1] == "y":
                    uv = (lx, -lz if key[0] == "+" else lz)
                else:
                    uv = (lx if key[0] == "+" else -lx, ly)
                uvs.append(uv)
                points.append(add(turn(corner), centre))
            self.polygon(face_mat, points, uvs, t)
        if collide:
            self.collider(centre, size, rot, query, look=mat)

    def obox(self, mat, centre, size, ux, uy, uz, collide=False, skip=()):
        """A box with any orientation: ux, uy, uz are its (unit) axes in the world."""
        hx, hy, hz = (v / 2 for v in size)

        def at(a, b, c):
            return add(centre, add(scale(ux, a * hx), add(scale(uy, b * hy), scale(uz, c * hz))))

        faces = {
            "+x": [at(1, -1, 1), at(1, -1, -1), at(1, 1, -1), at(1, 1, 1)],
            "-x": [at(-1, -1, -1), at(-1, -1, 1), at(-1, 1, 1), at(-1, 1, -1)],
            "+y": [at(-1, 1, 1), at(1, 1, 1), at(1, 1, -1), at(-1, 1, -1)],
            "-y": [at(-1, -1, -1), at(1, -1, -1), at(1, -1, 1), at(-1, -1, 1)],
            "+z": [at(-1, -1, 1), at(1, -1, 1), at(1, 1, 1), at(-1, 1, 1)],
            "-z": [at(1, -1, -1), at(-1, -1, -1), at(-1, 1, -1), at(1, 1, -1)],
        }
        for key, pts in faces.items():
            if key not in skip:
                self.polygon(mat, pts)

    def cylinder(self, mat, centre, radius, height, segments=16, caps=(True, True), radius_top=None, tile=None):
        """Upright cylinder (or cone) standing on centre (its bottom)."""
        radius_top = radius if radius_top is None else radius_top
        self.lathe(mat, centre, [(radius, 0), (radius_top, height)], segments, caps, tile)

    def lathe(self, mat, centre, profile, segments=24, caps=(True, True), tile=None, flutes=0, flute_depth=0.0):
        """Spins profile [(radius, height)] around the vertical axis through centre (the
        profile runs bottom to top). flutes adds vertical grooves."""
        tile = tile or matlib.tile_size(mat)
        cx, cy, cz = centre

        def ring(r, k):
            a = 2 * math.pi * k / segments
            rr = r
            if flutes:
                rr = r - flute_depth * max(0.0, math.cos(a * flutes)) ** 2
            return (cx + math.cos(a) * rr, math.sin(a) * rr, a)

        arc = 2 * math.pi * max(r for r, _ in profile)
        v_acc = [0.0]
        for i in range(1, len(profile)):
            dr = profile[i][0] - profile[i - 1][0]
            dh = profile[i][1] - profile[i - 1][1]
            v_acc.append(v_acc[-1] + math.hypot(dr, dh))
        for i in range(len(profile) - 1):
            (r0, h0), (r1, h1) = profile[i], profile[i + 1]
            for k in range(segments):
                x0, z0, a0 = ring(r0, k)
                x1, z1, _ = ring(r0, k + 1)
                x2, z2, _ = ring(r1, k + 1)
                x3, z3, _ = ring(r1, k)
                u0 = arc * k / segments
                u1 = arc * (k + 1) / segments
                pts = [(x0, cy + h0, cz + z0), (x3, cy + h1, cz + z3), (x2, cy + h1, cz + z2), (x1, cy + h0, cz + z1)]
                uv = [(u0, v_acc[i]), (u0, v_acc[i + 1]), (u1, v_acc[i + 1]), (u1, v_acc[i])]
                if r0 < 1e-6 and r1 < 1e-6:
                    continue
                self.polygon(mat, pts, uv, tile)
        if caps[0] and profile[0][0] > 1e-6:
            r, h = profile[0]
            pts = [(cx + math.cos(a) * r, cy + h, cz + math.sin(a) * r)
                   for a in (2 * math.pi * k / segments for k in range(segments))]
            self.polygon(mat, pts, tile=tile)
        if caps[1] and profile[-1][0] > 1e-6:
            r, h = profile[-1]
            pts = [(cx + math.cos(a) * r, cy + h, cz + math.sin(a) * r)
                   for a in (2 * math.pi * k / segments for k in range(segments))]
            self.polygon(mat, list(reversed(pts)), tile=tile)

    def tube(self, mat, a, b, radius, segments=8, caps=True, radius_b=None):
        """A round bar from a to b (pipes, poles, cables)."""
        radius_b = radius if radius_b is None else radius_b
        axis = sub(b, a)
        length = math.sqrt(dot(axis, axis))
        if length < 1e-6:
            return
        w = norm(axis)
        helper = (0, 1, 0) if abs(w[1]) < 0.9 else (1, 0, 0)
        u = norm(cross(helper, w))
        v = cross(w, u)
        tile = matlib.tile_size(mat)
        circ = 2 * math.pi * radius
        rings = []
        for end, r in ((a, radius), (b, radius_b)):
            rings.append([add(end, add(scale(u, math.cos(2 * math.pi * k / segments) * r),
                                       scale(v, math.sin(2 * math.pi * k / segments) * r))) for k in range(segments)])
        for k in range(segments):
            k1 = (k + 1) % segments
            p0, p1 = rings[0][k], rings[0][k1]
            p2, p3 = rings[1][k1], rings[1][k]
            u0, u1 = circ * k / segments, circ * (k + 1) / segments
            self.polygon(mat, [p0, p1, p2, p3], [(u0, 0), (u1, 0), (u1, length), (u0, length)], tile)
        if caps:
            self.polygon(mat, list(reversed(rings[0])), tile=tile)
            self.polygon(mat, rings[1], tile=tile)

    def sweep(self, mat, a, b, profile, outward, caps=True, tile=None):
        """A moulding along the straight line a -> b. profile is [(out, up)] in the plane across
        the line (out along `outward`, up along +Y), running bottom to top around the outside."""
        tile = tile or matlib.tile_size(mat)
        axis = sub(b, a)
        length = math.sqrt(dot(axis, axis))
        if length < 1e-6:
            return
        w = norm(axis)
        o = norm(outward)
        up = (0, 1, 0)
        ends = []
        for end in (a, b):
            ends.append([add(end, add(scale(o, p[0]), scale(up, p[1]))) for p in profile])
        # The faces must face outward: order depends on which side `outward` is.
        flip = dot(cross(w, up), o) < 0
        along = 0.0
        for i in range(len(profile) - 1):
            seg = math.dist(profile[i], profile[i + 1])
            p0, p1 = ends[0][i], ends[0][i + 1]
            p2, p3 = ends[1][i + 1], ends[1][i]
            pts = [p0, p3, p2, p1] if not flip else [p0, p1, p2, p3]
            uv = [(0, along), (length, along), (length, along + seg), (0, along + seg)]
            if flip:
                uv = [(0, along), (0, along + seg), (length, along + seg), (length, along)]
            self.polygon(mat, pts, uv, tile)
            along += seg
        if caps:
            # In profile order the end face points along -w (or +w when flipped).
            cap_a = list(ends[0])
            cap_b = list(ends[1])
            if flip:
                self.polygon(mat, list(reversed(cap_a)), tile=tile)
                self.polygon(mat, cap_b, tile=tile)
            else:
                self.polygon(mat, cap_a, tile=tile)
                self.polygon(mat, list(reversed(cap_b)), tile=tile)

    def prism(self, mat, outline, y0, y1, top=True, bottom=False, side_mat=None, top_mat=None):
        """Extrudes a polygon outline [(x, z)] (either winding) from y0 to y1."""
        side_mat = side_mat or mat
        top_mat = top_mat or mat
        area = sum(outline[i][0] * outline[(i + 1) % len(outline)][1] - outline[(i + 1) % len(outline)][0] * outline[i][1]
                   for i in range(len(outline)))
        if area < 0:
            outline = list(reversed(outline))
        n = len(outline)
        tile = matlib.tile_size(side_mat)
        along = 0.0
        for i in range(n):
            x0, z0 = outline[i]
            x1, z1 = outline[(i + 1) % n]
            seg = math.hypot(x1 - x0, z1 - z0)
            pts = [(x0, y0, z0), (x0, y1, z0), (x1, y1, z1), (x1, y0, z1)]
            self.polygon(side_mat, pts, [(along, y0), (along, y1), (along + seg, y1), (along + seg, y0)], tile)
            along += seg
        if top:
            self.polygon(top_mat, [(x, y1, z) for x, z in reversed(outline)])
        if bottom:
            self.polygon(top_mat, [(x, y0, z) for x, z in outline])

    # Things the game places -----------------------------------------------------------------

    def collider(self, centre, size, rot=0.0, query=True, look=None):
        """An invisible solid box. look is the material it shows as in the greybox (the map
        without its imported meshes); None keeps it invisible there too (blockers)."""
        self.colliders.append((*centre, *size, rot, query, look))

    def floor_tri(self, a, b, c, y, thick=1.0, look=None, query=True):
        """A solid triangle of floor (a, b, c are (x, z)) whose top is at y: the game builds it
        from two wedges, so floors of any shape have exact edges."""
        self.floors.append((a[0], a[1], b[0], b[1], c[0], c[1], y, thick, look, query))

    def ramp(self, a, b, y0, y1, width, thick=1.0, look="Concrete", query=False):
        """A walkable slope from the middle of its low edge a (x, z) at height y0 to the middle
        of its high edge b at y1: a tilted slab whose top face is the surface (stairs get one
        under their steps, so walking up them is smooth)."""
        run = math.dist(a, b)
        rise = y1 - y0
        length = math.hypot(run, rise)
        pitch = math.degrees(math.atan2(rise, run))
        dx, dz = (b[0] - a[0]) / run, (b[1] - a[1]) / run
        # rot facing the climb (rot 0 faces -Z): the facing vector is (-sin, -cos).
        rot = math.degrees(math.atan2(-dx, -dz))
        tilt = math.radians(pitch)
        mid = ((a[0] + b[0]) / 2, (y0 + y1) / 2, (a[1] + b[1]) / 2)
        normal = (-dx * math.sin(tilt), math.cos(tilt), -dz * math.sin(tilt))
        centre = (mid[0] - normal[0] * thick / 2, mid[1] - normal[1] * thick / 2, mid[2] - normal[2] * thick / 2)
        self.ramps.append({"at": centre, "size": (width, thick, length), "rot": rot, "pitch": pitch, "look": look,
                           "query": query, "a": a, "b": b, "y0": y0, "y1": y1, "width": width})

    def prop(self, key, x, z, rot=0.0, scale_=1.0, y=0.0, dark=False):
        """A prop from the prop library. dark: leave off the light it carries (a string of
        lanterns where only some are lit)."""
        self.props.append((key, x, y, z, rot, scale_, "dark" if dark else ""))

    def step(self, centre, size, rot, look):
        self.steps.append((centre, size, rot, look))

    def preview_prop(self, key, x, z, rot=0.0, scale_=1.0, y=0.0):
        self.preview_props.append((key, x, y, z, rot, scale_))

    def light(self, kind, pos, color, range_, brightness, shadows=False, face="Bottom", angle=90, flicker=False):
        self.lights.append({"kind": kind, "pos": pos, "color": color, "range": range_, "brightness": brightness,
                            "shadows": shadows, "face": face, "angle": angle, "flicker": flicker})

    def sign(self, pos, rot, w, h, text, font="GothamBlack", color=(255, 255, 255), bg=None, glow=None,
             align="Center"):
        self.signs.append({"pos": pos, "rot": rot, "w": w, "h": h, "text": text, "font": font, "color": color,
                           "bg": bg, "glow": glow, "align": align})

    def emitter(self, kind, pos, rot=0.0, size=None):
        """A particle source of a kind the game knows (SceneBuilder); size (x, y, z) for the kinds
        that fill a box (rain on a window, a stream of car lights)."""
        item = {"kind": kind, "pos": pos, "rot": rot}
        if size is not None:
            item["size"] = tuple(size)
        self.emitters.append(item)

    def blinker(self, pos, color=(255, 40, 40), period=2.0, size=1.2, phase=0.0):
        """A small lamp the client switches on and off every `period` seconds."""
        self.blinkers.append({"pos": pos, "color": color, "period": period, "size": size, "phase": phase})

    def fly(self, path, target, every=90.0, duration=16.0):
        """The helicopter that now and then flies `path` [(x, y, z)] past the building, its
        searchlight on `target` [(x, y, z)] (followed in step with the path)."""
        self.helicopter = {"path": [tuple(p) for p in path], "target": [tuple(p) for p in target], "every": every,
                           "duration": duration}

    def screen(self, pos, rot, w, h, loop="ads"):
        """A giant screen facing rot (its face at pos); the game plays `loop` on it."""
        self.screens.append({"pos": pos, "rot": rot, "w": w, "h": h, "loop": loop})

    def sound(self, key, pos, radius=40.0, volume=0.5, loop=True):
        """An ambient sound source: key names an Assets.sfx slot (silent while it is empty)."""
        self.sounds.append({"key": key, "pos": pos, "radius": radius, "volume": volume, "loop": loop})

    def look_zone(self, preset, lo, hi):
        """A box (corners lo, hi as x, y, z) where the camera switches to the lighting preset
        LightingPresets.maps[preset] (a metro under the street, a tunnel)."""
        self.look_zones.append({"preset": preset, "min": lo, "max": hi})

    def water(self, centre, size, rot=0.0):
        """A box the game fills with Terrain water (a river's channel): real waves and reflections,
        out of reach behind the railings."""
        self.waters.append({"at": centre, "size": size, "rot": rot})

    # Output ----------------------------------------------------------------------------------

    def finish(self, collection):
        """Builds the Blender meshes (chunked per material) and returns their names."""
        names = []
        for mat, pieces in sorted(self.pieces.items()):
            # Small materials stay in one mesh; big ones are cut into cells of CHUNK studs. So are
            # small ones spread wider than a Roblox part may be (2048 studs a side), which the
            # importer would otherwise squash.
            total = sum(len(p.faces) for p in pieces)
            xs = [v[0] for p in pieces for v in p.verts]
            zs = [v[2] for p in pieces for v in p.verts]
            wide = max(max(xs) - min(xs), max(zs) - min(zs)) > MAX_SPAN
            cells = {}
            for piece in pieces:
                if total <= SMALL_TRIS and not wide:
                    key = (0, 0, 0)
                else:
                    key = self._cell(piece.centre)
                cells.setdefault(key, []).append(piece)
            chunks = []
            for key in sorted(cells):
                current, tris = [], 0
                for piece in cells[key]:
                    if tris + len(piece.faces) > MAX_TRIS and current:
                        chunks.append(current)
                        current, tris = [], 0
                    current.append(piece)
                    tris += len(piece.faces)
                if current:
                    chunks.append(current)
            for index, chunk in enumerate(chunks, 1):
                name = f"{self.prefix}_{self.venue}_{mat}_{index}"
                names.append(name)
                build_mesh(name, chunk, mat, collection)
        return names

    def _cell(self, centre):
        """The chunk a piece falls in: cells of `chunk` studs; or, past a venue's far_chunk
        (distance, size), much bigger cells for the scenery far out, which needs only a few
        meshes (its pieces must stay well under a Roblox part's 2048 studs)."""
        x, z = centre[0], centre[2]
        far = self.far_chunk
        if far and max(abs(x), abs(z)) > far[0]:
            return (1, math.floor(x / far[1]), math.floor(z / far[1]))
        return (0, math.floor(x / self.chunk), math.floor(z / self.chunk))

    def triangles(self):
        return sum(len(p.faces) for pieces in self.pieces.values() for p in pieces)


def planar_uvs(points, tile):
    """UVs for a flat face, projected on the world plane it faces most."""
    a, b, c = points[0], points[1], points[2]
    n = cross(sub(b, a), sub(c, a))
    ax, ay, az = abs(n[0]), abs(n[1]), abs(n[2])
    uvs = []
    for x, y, z in points:
        if ay >= ax and ay >= az:
            uv = (x, -z if n[1] > 0 else z)
        elif ax >= az:
            uv = (-z if n[0] > 0 else z, y)
        else:
            uv = (x if n[2] > 0 else -x, y)
        uvs.append((uv[0] / tile, uv[1] / tile))
    return uvs


def build_mesh(name, pieces, mat, collection):
    """One Blender mesh object from pieces, converted to Blender space (x -> -x, y <-> z)."""
    verts, faces, uvs = [], [], []
    for piece in pieces:
        base = len(verts)
        verts.extend((-x, z, y) for x, y, z in piece.verts)
        faces.extend(tuple(base + i for i in f) for f in piece.faces)
        uvs.extend(uv for face in piece.uvs for uv in face)
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    layer = mesh.uv_layers.new(name="UVMap")
    flat = [c for uv in uvs for c in uv]
    layer.data.foreach_set("uv", flat)
    mesh.validate(clean_customdata=False)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    obj.data.materials.append(matlib.material(mat, _IMAGES.get("images")))
    collection.objects.link(obj)
    # The object's origin at the middle of its bounds (the importer centres meshes anyway).
    xs = [v[0] for v in verts]
    ys = [v[1] for v in verts]
    zs = [v[2] for v in verts]
    mid = ((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, (min(zs) + max(zs)) / 2)
    mesh.transform(__import__("mathutils").Matrix.Translation((-mid[0], -mid[1], -mid[2])))
    obj.location = mid
    return obj


_IMAGES = {}


def use_images(images):
    """Textures for textured materials (from matlib.make_textures)."""
    _IMAGES["images"] = images
