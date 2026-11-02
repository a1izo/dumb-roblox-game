"""Each case map's own furniture (sets "Campus", "Agency" and "Tokyo"): the shared chairs, benches, sofas, plants, cabinets
and desks made again three ways, so no two maps furnish a room alike (maps/ownprops.py says which stands for which).

- Kagegaoka University is old and wooden: bentwood lecture chairs, an oak hall bench, a worn deep-buttoned Chesterfield,
  a fern on its stand, golden oak filing cabinets, a professor's twin pedestal desk and a banker's swivel chair.
- Bureau HQ is steel and federal: cantilever guest chairs, beam seating, a chrome cage lounge sofa, rubber plants in
  square planters, steel security files with their lock bars, the bullpen's desks with flat monitors, reference shelves.
- Tokyo keeps to the street: a perforated steel bench, a channel-backed vinyl booth, black bamboo in a glazed pot,
  crates of mikan.
- The second batch takes on what the maps still shared: the University's blackboards, bentwood coat stands, trophy cases
  and oak lockers, the Bureau's steel lockers and evidence cases.

Each keeps the footprint, seat height and desk height of what it stands for: seated poses, colliders, the walk checks
and the cutscenes were all measured against those. Props face -Y and stand on z = 0, about 3.5 studs to the metre. The
ones a map places by the dozen stay light on triangles; every mesh piece reads as what it is on its own."""

import math
import random

import bmesh
from mathutils import Vector

import modelkit as mk
import propkit as pk
import stationkit as sk
from common import srgb
from props import prop

LAMP = (255, 210, 150)


# Shapes -------------------------------------------------------------------------------------------------


def spline(points, steps=6):
    """Points along a smooth curve through `points` (Catmull-Rom), `steps` to each span."""
    pts = [points[0]] + list(points) + [points[-1]]
    out = []
    for i in range(1, len(pts) - 2):
        p0, p1, p2, p3 = pts[i - 1], pts[i], pts[i + 1], pts[i + 2]
        for k in range(steps):
            t = k / steps
            out.append(tuple(0.5 * (2 * b + (c - a) * t + (2 * a - 5 * b + 4 * c - d) * t * t
                                    + (3 * b - a - 3 * c + d) * t ** 3) for a, b, c, d in zip(p0, p1, p2, p3)))
    out.append(tuple(points[-1]))
    return out


def hoop(radius, z, steps=24, y=0.0, x=0.0, squash=1.0):
    """A closed circle of points, the first repeated at the end (for bar())."""
    return [(x + radius * math.cos(2 * math.pi * k / steps), y + radius * squash * math.sin(2 * math.pi * k / steps), z)
            for k in range(steps + 1)]


def mirrored(point):
    return (-point[0], point[1], point[2])


def mirrored_y(point):
    return (point[0], -point[1], point[2])


def arch(half):
    """A half curve from one side to the middle, carried on through its mirror to the other side."""
    return half + [mirrored(p) for p in reversed(half[:-1])]


def bar(name, points, r, mat, sides=6):
    """A round bar along a bent line, shaded smooth."""
    return mk.soften(pk.sweep(name, points, r, mat, sides=sides))


def turned(name, profile, a, b, mat, segments=8):
    """A turned leg from a to b: `profile` is [(radius, share of the length), ...]."""
    a, b = Vector(a), Vector(b)
    axis = b - a
    obj = mk.lathe(name, [(r, t * axis.length) for r, t in profile], mat=mat, segments=segments)
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = axis.normalized().to_track_quat("Z", "Y")
    obj.location = a
    return mk.soften(obj)


def roll(name, r, length, loc, rot, mat, verts=14):
    """An open tube, its ends left to what closes them: shading a capped cylinder smooth tilts its long faces toward
    the ends, and the bake reads that as crumpled foil."""
    obj = mk.lathe(name, [(r, -length / 2), (r, length / 2)], mat=mat, segments=verts, caps=False)
    obj.location = loc
    obj.rotation_euler = tuple(math.radians(a) for a in rot)
    return mk.soften(obj)


def _frame(facing):
    n = Vector(facing).normalized()
    u = n.orthogonal().normalized()
    return n, u, n.cross(u)


def studs(name, points, r, h, mat, sides=6, facing=(0, 0, 1)):
    """Domed heads standing on a surface at points (nails, buttons, screws): a fan of `sides` triangles each."""
    n, u, v = _frame(facing)
    bm = bmesh.new()
    for p in points:
        c = Vector(p)
        ring = [bm.verts.new(c + (u * math.cos(2 * math.pi * k / sides) + v * math.sin(2 * math.pi * k / sides)) * r)
                for k in range(sides)]
        tip = bm.verts.new(c + n * h)
        for k in range(sides):
            bm.faces.new((ring[k], ring[(k + 1) % sides], tip))
    return mk.soften(mk._obj_from_bm(name, bm, mat))


def discs(name, points, r, mat, sides=6, facing=(0, 0, 1)):
    """Flat marks lying on a surface at points (punched holes, pins): one face each."""
    n, u, v = _frame(facing)
    bm = bmesh.new()
    for p in points:
        c = Vector(p)
        bm.faces.new([bm.verts.new(c + (u * math.cos(2 * math.pi * k / sides) + v * math.sin(2 * math.pi * k / sides)) * r)
                      for k in range(sides)])
    return mk._obj_from_bm(name, bm, mat)


def cushion(name, size, loc, mat, e=0.32, segments=20, rings=10):
    """A plump cushion: a rounded block whose faces crown a little (e: 0 a box, 1 an egg)."""
    obj = mk.sphere(name, 1.0, loc, mat=mat, segments=segments, rings=rings)
    for vert in obj.data.vertices:
        vert.co = Vector([math.copysign(abs(c) ** e, c) * s / 2 for c, s in zip(vert.co, size)])
    return mk.soften(obj)


def tufted(name, origin, across, up, out, w, h, dx, dz, mat, n=2, bulge=0.09, dent=0.05):
    """Deep buttoned upholstery: a panel w by h from origin along across and up, its diamonds of leather pillowing
    toward out, the pleats running button to button. Returns the sheet and its buttons' places."""
    across, up, out = Vector(across).normalized(), Vector(up).normalized(), Vector(out).normalized()
    origin = Vector(origin)
    cols, rows = max(1, round(w / dx)), max(1, round(h / dz))
    dx, dz = w / cols, h / rows
    nu, nv = cols * 2 * n, rows * n

    def height(x, z):
        a, b = x / dx + z / (2 * dz), x / dx - z / (2 * dz)
        pillow = (abs(math.sin(math.pi * a)) * abs(math.sin(math.pi * b))) ** 0.55
        edge = max(0.0, min(1.0, min(x, w - x, z, h - z) / (0.45 * dz))) ** 0.5
        ra, rb = round(a), round(b)
        near = math.hypot(x - dx * (ra + rb) / 2, z - dz * (ra - rb))
        return bulge * pillow * edge - dent * math.exp(-((near / (0.26 * dz)) ** 2))

    bm = bmesh.new()
    verts = []
    for j in range(nv + 1):
        z = j * h / nv
        verts.append([bm.verts.new(origin + across * (i * w / nu) + up * z + out * height(i * w / nu, z)) for i in range(nu + 1)])
    flip = across.cross(up).dot(out) < 0
    for j in range(nv):
        for i in range(nu):
            a, b, c, d = verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i]
            tris = ((a, b, c), (a, c, d)) if (i + j) % 2 == 0 else ((a, b, d), (b, c, d))
            for tri in tris:
                bm.faces.new(tri[::-1] if flip else tri)
    buttons = []
    for row in range(1, rows):
        for col in range(1, cols * 2):
            if (row + col) % 2 == 0:
                x, z = col * dx / 2, row * dz
                buttons.append(tuple(origin + across * x + up * z + out * (height(x, z) - 0.006)))
    return mk.soften(mk._obj_from_bm(name, bm, mat)), buttons


def blade(name, points, faces, mat, apart=0.006):
    """A two-faced sheet: faces (lists of indices) over points, and the same again a hair behind them, turned the other
    way. Behind along its own normals, not down (modelkit.sheet): where a leaf hangs, faces apart in Z lie in one plane
    and the bake blacks them out."""
    bm = bmesh.new()
    front = [bm.verts.new(p) for p in points]
    for face in faces:
        bm.faces.new([front[i] for i in face])
    bm.normal_update()
    back = [bm.verts.new(v.co - v.normal * apart) for v in front]
    for face in faces:
        bm.faces.new([back[i] for i in reversed(face)])
    return mk._obj_from_bm(name, bm, mat)


def bowl(name, w, d, top, dish, thick, mat, rings=4, steps=20, power=2.8):
    """A shaped seat: a rounded square hollowed toward its middle, its edge rolled under."""
    bm = bmesh.new()

    def loop(share, z):
        out = []
        for k in range(steps):
            a = 2 * math.pi * k / steps
            c, s = math.cos(a), math.sin(a)
            out.append(bm.verts.new((share * w / 2 * math.copysign(abs(c) ** (2 / power), c),
                                     share * d / 2 * math.copysign(abs(s) ** (2 / power), s), z)))
        return out

    centre = bm.verts.new((0, 0, top - dish))
    prev = None
    for k in range(1, rings + 1):
        share = k / rings
        cur = loop(share, top - dish * (1 - share * share) * (1 - 0.5 * share))
        for i in range(steps):
            j = (i + 1) % steps
            bm.faces.new((centre, cur[i], cur[j]) if prev is None else (prev[i], cur[i], cur[j], prev[j]))
        prev = cur
    for share, z in ((1.0, top - thick * 0.55), (0.9, top - thick)):
        cur = loop(share, z)
        for i in range(steps):
            j = (i + 1) % steps
            bm.faces.new((prev[i], cur[i], cur[j], prev[j]))
        prev = cur
    bm.faces.new(prev[::-1])
    return mk.soften(mk._obj_from_bm(name, bm, mat))


# Surfaces -----------------------------------------------------------------------------------------------


def lattice(name, ground, mark, pitch, u, v, share=0.32, roughness=0.45, metallic=0.0, square=False):
    """A surface with a regular grid of round (or square) marks drawn in its colour, so they cost no triangles. u and v
    say which coordinates the grid runs along (see _axis, _plus, _from)."""
    mat, nodes, links, bsdf = mk._new_material(name)
    split = nodes.new("ShaderNodeSeparateXYZ")
    links.new(mk._coord(nodes, links), split.inputs[0])
    join = nodes.new("ShaderNodeCombineXYZ")
    links.new(u(nodes, links, split), join.inputs["X"])
    links.new(v(nodes, links, split), join.inputs["Y"])
    grid = nodes.new("ShaderNodeTexVoronoi")
    grid.voronoi_dimensions = "2D"
    if square:
        grid.distance = "CHEBYCHEV"
    grid.inputs["Scale"].default_value = 1.0 / pitch
    grid.inputs["Randomness"].default_value = 0.0
    links.new(join.outputs[0], grid.inputs["Vector"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    ramp.color_ramp.elements[0].color = (*srgb(*mark), 1)
    ramp.color_ramp.elements[1].position = share
    ramp.color_ramp.elements[1].color = (*srgb(*ground), 1)
    links.new(grid.outputs["Distance"], ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = roughness
    bsdf.inputs["Metallic"].default_value = metallic
    return mat


def _axis(name):
    return lambda nodes, links, split: split.outputs[name]


def _plus(a, b):
    """The sum of two axes: on a sheet bent from seat to back it runs on unbroken round the bend."""

    def socket(nodes, links, split):
        add = nodes.new("ShaderNodeMath")
        add.operation = "ADD"
        links.new(split.outputs[a], add.inputs[0])
        links.new(split.outputs[b], add.inputs[1])
        return add.outputs[0]

    return socket


def _from(name, line):
    """An axis measured from `line`, so a row of marks falls on that line."""

    def socket(nodes, links, split):
        sub = nodes.new("ShaderNodeMath")
        sub.operation = "SUBTRACT"
        links.new(split.outputs[name], sub.inputs[0])
        sub.inputs[1].default_value = line
        return sub.outputs[0]

    return socket


def punched(name, plate, hole, pitch, share=0.32, roughness=0.45, metallic=0.5):
    """A steel sheet punched with round holes, the grid running across X and along Y + Z."""
    return lattice(name, plate, hole, pitch, _axis("X"), _plus("Y", "Z"), share, roughness, metallic)


def dotted(name, ground, head, pitch, along, across, line, share=0.3):
    """A row of round heads (upholstery nails) along one axis, on the line `line` of another."""
    return lattice(name, ground, head, pitch, _axis(along), _from(across, line), share, 0.4, 0.0)


# Kagegaoka University -----------------------------------------------------------------------------------


@prop("LectureChair", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus", exact=True)
def lecture_chair():
    """A bentwood lecture chair, stained beech steamed into shape: one hoop runs from a back foot up over the top and
    down to the other, a smaller hoop inside it, the round seat of pressed plywood in its bent rim with the rosette of
    holes the factory punched in it, turned front legs, the bent ring that ties all four legs, two curved braces under
    the seat's back, felt tips on the feet and the hall's little brass seat tag on the back of the rim."""
    wood = mk.wood("LChair_Wood", srgb(70, 44, 27), srgb(54, 33, 20), roughness=0.42)
    ply = mk.wood("LChair_Ply", srgb(120, 82, 50), srgb(88, 58, 34), roughness=0.5)
    hole = mk.flat("LChair_Hole", srgb(12, 9, 8), 0.9)
    felt = mk.flat("LChair_Felt", srgb(18, 18, 20), 0.95)
    brass = pk.metal("LChair_Brass", (120, 92, 46), (176, 142, 78), rough=0.35, metallic=1.0)
    top = 1.745
    # The seat: a shallow dished disc in its rim.
    parts = [mk.lathe("Seat", [(0.0, top - 0.03), (0.5, top - 0.018), (0.78, top), (0.78, top - 0.09), (0.0, top - 0.09)],
                      mat=ply, segments=20),
             bar("SeatRim", hoop(0.82, top - 0.05, 20), 0.056, wood)]
    dots = []
    for r, n, a0 in ((0.2, 8, 0.0), (0.4, 12, 0.13), (0.6, 16, 0.0)):
        for k in range(n):
            a = a0 + 2 * math.pi * k / n
            dots.append((r * math.cos(a), r * math.sin(a), top - 0.03 + 0.03 * (r / 0.78) ** 2 + 0.012))
    parts.append(discs("SeatHole", dots, 0.032, hole))
    # The back: one bent hoop from foot to foot, a smaller one inside it.
    outer = [(0.76, 0.84, 0.03), (0.73, 0.8, 0.8), (0.7, 0.72, top - 0.1), (0.66, 0.76, 2.45), (0.54, 0.84, 3.2),
             (0.3, 0.87, 3.62), (0.0, 0.88, 3.74)]
    parts.append(bar("BackHoop", arch(spline(outer, 4)), 0.068, wood, sides=6))
    inner = [(0.36, 0.76, top - 0.06), (0.38, 0.8, 2.35), (0.28, 0.83, 2.9), (0.14, 0.84, 3.14), (0.0, 0.85, 3.2)]
    parts.append(bar("BackInner", arch(spline(inner, 4)), 0.048, wood, sides=5))
    # The turned front legs and the bent ring round all four.
    leg = [(0.0, 0.0), (0.04, 0.0), (0.05, 0.06), (0.068, 0.42), (0.05, 0.57), (0.072, 0.62), (0.062, 0.8), (0.056, 1.0),
           (0.0, 1.0)]
    for side in (-1, 1):
        parts.append(turned("FrontLeg", leg, (side * 0.76, -0.76, 0.02), (side * 0.63, -0.62, top - 0.08), wood))
        parts.append(mk.cylinder("Felt", 0.052, 0.03, (side * 0.76, -0.76, 0.015), mat=felt, verts=8))
        parts.append(mk.cylinder("Felt", 0.07, 0.03, (side * 0.76, 0.84, 0.015), mat=felt, verts=8))
        # (a brace from the back leg up under the rim)
        parts.append(bar("Brace", spline([(side * 0.72, 0.76, 1.3), (side * 0.58, 0.5, 1.5), (side * 0.3, 0.72, 1.64)], 3),
                         0.03, wood, sides=5))
    parts.append(bar("LegRing", hoop(0.7, 0.97, 20, y=0.05, squash=1.09), 0.034, wood, sides=5))
    # The seat tag on the rim's back.
    parts.append(mk.box("SeatTag", (0.26, 0.016, 0.09), (0, 0.885, top - 0.05), mat=brass, bevel=0.003))
    return parts, []


@prop("BankerChair", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus", exact=True)
def banker_chair():
    """A professor's oak swivel chair: a saddled seat on a cast iron spider of four sweeping legs on castors, the spring
    tilt under it, a horseshoe arm bow running round the back, turned spindles through it up to the steam-bent crest."""
    oak = mk.wood("BChair_Oak", srgb(132, 92, 54), srgb(84, 56, 32), roughness=0.42)
    worn = mk.wood("BChair_Seat", srgb(150, 108, 66), srgb(104, 72, 42), roughness=0.36)
    iron = pk.metal("BChair_Iron", (22, 22, 24), (58, 56, 54), rough=0.55, metallic=0.9)
    brass = pk.metal("BChair_Brass", (120, 92, 46), (176, 142, 78), rough=0.35, metallic=1.0)
    tyre = pk.rubber("BChair_Tyre")
    seat_top = 1.72
    parts = [bowl("Seat", 1.92, 1.8, seat_top, 0.1, 0.17, worn)]
    # The spider, its column and the tilt.
    parts.append(turned("Column", [(0.0, 0.0), (0.2, 0.0), (0.2, 0.1), (0.09, 0.22), (0.075, 0.5), (0.1, 0.55), (0.1, 0.92),
                                   (0.16, 1.0), (0.0, 1.0)], (0, 0, 0.62), (0, 0, 1.3), iron, segments=10))
    parts.append(pk.rounded("Tilt", (0.74, 0.86, 0.12), (0, 0.04, 1.42), iron, r=0.03))
    parts.append(mk.cylinder("TiltSpring", 0.1, 0.5, (0, -0.1, 1.33), rot=(0, 90, 0), mat=brass, verts=10))
    for k in range(4):
        a = math.radians(45 + 90 * k)
        c, s = math.cos(a), math.sin(a)
        reach = spline([(0.14 * c, 0.14 * s, 0.72), (0.4 * c, 0.4 * s, 0.62), (0.7 * c, 0.7 * s, 0.42),
                        (0.92 * c, 0.92 * s, 0.3)], 2)
        parts.append(bar("SpiderLeg", reach, [0.1 - 0.05 * j / (len(reach) - 1) for j in range(len(reach))], iron))
        turn = (90, 0, math.degrees(a))
        parts.append(mk.soften(mk.cylinder("Castor", 0.14, 0.1, (0.98 * c, 0.98 * s, 0.14), rot=turn, mat=tyre, verts=12)))
        parts.append(mk.cylinder("CastorHub", 0.05, 0.115, (0.98 * c, 0.98 * s, 0.14), rot=turn, mat=brass, verts=6))

    # The bow, the spindles and the crest, on circles round the sitter (0 degrees: straight behind them).
    def round_back(radius, z, a):
        a = math.radians(a)
        return (radius * math.sin(a), 0.02 + radius * math.cos(a), z)

    bow = [round_back(0.98, 2.46, -110 + 220 * k / 16) for k in range(17)]
    parts.append(bar("ArmBow", bow, [0.09] + [0.07] * 15 + [0.09], oak))
    parts.append(bar("Crest", [round_back(0.9, 3.56, -55 + 110 * k / 10) for k in range(11)], 0.1, oak))
    for k in range(9):
        a = -48 + 96 * k / 8
        low, mid, high = round_back(0.74, seat_top - 0.08, a), round_back(0.98, 2.46, a), round_back(0.9, 3.5, a)
        parts.append(mk.soften(mk.tube("Spindle", low, mid, 0.045, 0.036, mat=oak, verts=6)))
        parts.append(mk.soften(mk.tube("Spindle", mid, high, 0.036, 0.03, mat=oak, verts=6)))
    post = [(0.0, 0.0), (0.06, 0.0), (0.08, 0.12), (0.05, 0.4), (0.075, 0.7), (0.05, 1.0), (0.0, 1.0)]
    for side in (-1, 1):  # (the two turned posts that hold the bow's arms up)
        a = side * 96
        parts.append(turned("ArmPost", post, round_back(0.8, seat_top - 0.1, a), round_back(0.98, 2.42, a), oak))
    return parts, []


@prop("OakBench", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus")
def oak_bench():
    """The university's oak bench: four posts, the back ones raked above the seat, rails let into them with their tenons
    showing and pegged, seven seat slats, a shaped apron, flat arms on their corbels, thirteen splats between the rails,
    an arched crest with the alumni's brass plate."""
    oak = mk.wood("OBench_Oak", srgb(146, 104, 62), srgb(96, 66, 38), roughness=0.5)
    rail = mk.wood("OBench_Wood", srgb(118, 82, 48), srgb(78, 52, 30), roughness=0.55)
    peg = mk.flat("OBench_Peg", srgb(40, 26, 16), 0.7)
    brass = pk.metal("OBench_Brass", (120, 92, 46), (176, 142, 78), rough=0.35, metallic=1.0)
    rake = math.degrees(math.atan2(0.2, 1.8))

    def back_y(z):
        return 0.61 + (z - 1.5) / 1.8 * 0.2

    parts = []
    for side in (-1, 1):
        x = side * 2.74
        parts.append(mk.box("FrontPost", (0.22, 0.2, 2.3), (x, -0.7, 1.15), mat=oak, bevel=0.025, segments=1))
        parts.append(sk.wedge("BackPost", [(0.5, 0.0), (0.72, 0.0), (0.72, 1.5), (0.92, 3.3), (0.7, 3.3), (0.5, 1.5)], 0.22,
                              x, oak, bevel=0.02))
        parts.append(mk.box("SideRail", (0.1, 1.24, 0.3), (x, -0.02, 1.4), mat=rail, bevel=0.012, segments=1))
        parts.append(mk.box("Stretcher", (0.1, 1.24, 0.16), (x, -0.02, 0.48), mat=rail, bevel=0.012, segments=1))
        # (the arm on its corbel)
        parts.append(pk.rounded("Arm", (0.3, 1.78, 0.1), (x, 0.0, 2.35), oak, r=0.03))
        parts.append(mk.box("Corbel", (0.14, 0.09, 0.26), (x, -0.56, 2.17), mat=rail, bevel=0.03, segments=2))
        # (the tenons of the rails through the posts, pegged)
        parts.append(mk.box("Tenon", (0.05, 0.03, 0.16), (x, -0.81, 1.4), mat=rail, bevel=0.008, segments=1))
        parts.append(mk.box("Tenon", (0.05, 0.03, 0.09), (x, -0.81, 0.48), mat=rail, bevel=0.008, segments=1))
        pegs = [(x + side * 0.112, -0.7, z) for z in (1.32, 1.48, 0.48)]
        parts.append(studs("Peg", pegs, 0.02, 0.008, peg, facing=(side, 0, 0)))
    # The seat: a framed apron under seven slats.
    apron = [(-2.62, 0.3), (-2.62, 0.0)]
    for k in range(13):
        x = -2.3 + 4.6 * k / 12
        apron.append((x, 0.12 * (1 - (x / 2.3) ** 2)))
    apron += [(2.62, 0.0), (2.62, 0.3)]
    parts.append(mk.extrude_shape("Apron", apron, 0.09, (0, -0.7, 1.2), rot=(90, 0, 0), mat=rail))
    parts.append(mk.box("BackRailLow", (5.24, 0.09, 0.3), (0, 0.6, 1.36), mat=rail, bevel=0.012, segments=1))
    parts.append(mk.box("Stretcher", (5.24, 0.1, 0.18), (0, 0.6, 0.48), mat=rail, bevel=0.012, segments=1))
    for k in range(7):
        y = -0.68 + k * 0.205
        parts.append(mk.box("Slat", (5.26, 0.18, 0.075), (0, y, 1.56), mat=oak, bevel=0.025, segments=2 if k == 0 else 1))
    # The back: a rail, thirteen splats, the crest.
    low, high = 2.04, 3.0
    parts.append(mk.box("BackRail", (5.26, 0.09, 0.16), (0, back_y(low), low), rot=(-rake, 0, 0), mat=rail, bevel=0.012,
                        segments=1))
    for k in range(13):
        x = -2.4 + 4.8 * k / 12
        mid = (low + high) / 2
        parts.append(mk.box("Splat", (0.2, 0.045, high - low), (x, back_y(mid), mid), rot=(-rake, 0, 0), mat=oak, bevel=0.01,
                            segments=1))
    crest = [(-2.63, 0.0), (2.63, 0.0)]
    for k in range(13):
        x = 2.63 - 5.26 * k / 12
        crest.append((x, 0.2 + 0.1 * math.cos(x / 2.63 * math.pi / 2)))
    parts.append(mk.extrude_shape("Crest", crest, 0.09, (0, back_y(high - 0.02), high - 0.02), rot=(90 - rake, 0, 0), mat=oak))
    plate = back_y(low) - 0.055
    parts.append(mk.box("Plate", (0.9, 0.015, 0.11), (0, plate, low), rot=(-rake, 0, 0), mat=brass, bevel=0.004))
    parts.append(studs("PlatePin", [(-0.4, plate - 0.008, low), (0.4, plate - 0.008, low)], 0.016, 0.006, peg, facing=(0, -1, 0)))
    return parts, []


@prop("ChesterfieldSofa", pivot="bottom", material="Leather", collide=True, texture=1024, set="Campus", exact=True)
def chesterfield_sofa():
    """The common room's Chesterfield, its cognac hide worn thin at the edges: deep buttoned diamonds across the back and
    inside the arms, the arms rolled at the height of the back, rows of brass nails along the rail and up the arm fronts,
    three loose seat cushions with their piping, turned bun feet on brass castor cups."""
    leather = mk.noisy("Chest_Leather", srgb(62, 32, 20), srgb(126, 76, 44), roughness=0.42)
    rolled = mk.noisy("ChestRoll_Leather", srgb(74, 40, 24), srgb(140, 88, 52), roughness=0.38)
    pipe = mk.noisy("ChestPipe_Leather", srgb(44, 24, 16), srgb(84, 50, 30), roughness=0.5)
    wood = mk.wood("Chest_Wood", srgb(70, 44, 27), srgb(44, 27, 17), roughness=0.4)
    brass = pk.metal("Chest_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    nails_along = dotted("Chest_NailsAlong", (82, 46, 28), (200, 164, 96), 0.14, "X", "Z", 0.56)
    nails_left = dotted("Chest_NailsLeft", (82, 46, 28), (200, 164, 96), 0.14, "Z", "X", -3.3)
    nails_right = dotted("Chest_NailsRight", (82, 46, 28), (200, 164, 96), 0.14, "Z", "X", 3.3)
    parts = [pk.rounded("BaseRail", (7.1, 2.76, 0.92), (0, 0.06, 0.86), leather, r=0.1),
             pk.rounded("BackBody", (6.5, 0.72, 1.52), (0, 1.0, 1.96), leather, r=0.1),
             roll("BackRoll", 0.41, 6.3, (0, 1.04, 2.66), (0, 90, 0), rolled)]
    for side in (-1, 1):
        x = side * 3.25
        parts.append(pk.rounded("ArmBody", (0.76, 2.92, 1.4), (side * 3.3, -0.02, 1.94), leather, r=0.1))
        parts.append(roll("ArmRoll", 0.45, 2.96, (x, -0.02, 2.62), (90, 0, 0), rolled))
        parts.append(mk.cylinder("ArmBack", 0.42, 0.03, (x, 1.46, 2.62), rot=(90, 0, 0), mat=pipe, verts=14))
        # (the roll's end: a disc ringed with nails round its button, and a column of nails down the arm's front)
        face = -1.5
        parts.append(mk.cylinder("ArmEnd", 0.42, 0.03, (x, face, 2.62), rot=(90, 0, 0), mat=pipe, verts=14))
        nails = [(x + 0.34 * math.cos(2 * math.pi * k / 14), face - 0.016, 2.62 + 0.34 * math.sin(2 * math.pi * k / 14))
                 for k in range(14)]
        parts.append(studs("ArmNail", nails, 0.032, 0.012, brass, facing=(0, -1, 0)))
        parts.append(mk.box("ArmNailRow", (0.075, 0.01, 1.42), (side * 3.3, -1.482, 1.32), mat=nails_left if side < 0 else nails_right))
        parts.append(studs("ArmButton", [(x, face - 0.016, 2.62)], 0.07, 0.03, pipe, sides=8, facing=(0, -1, 0)))
        sheet, buttons = tufted("ArmTuft", (side * 2.91, -1.32 if side > 0 else 0.86, 1.72), (0, side, 0), (0, 0, 1), (-side, 0, 0),
                                2.18, 0.6, 0.72, 0.3, leather, n=2, bulge=0.05, dent=0.03)
        parts.append(sheet)
        parts.append(studs("ArmTuftButton", buttons, 0.05, 0.022, pipe, facing=(-side, 0, 0)))
    # The buttoned back.
    sheet, buttons = tufted("BackTuft", (-2.92, 0.64, 1.72), (1, 0, 0), (0, 0.05, 1), (0, -1, 0), 5.84, 0.96, 0.84, 0.32, leather,
                            n=3, bulge=0.1, dent=0.06)
    parts.append(sheet)
    parts.append(studs("BackButton", buttons, 0.055, 0.024, pipe, facing=(0, -1, 0)))
    # The seat.
    for x in (-1.95, 0.0, 1.95):
        parts.append(cushion("SeatCushion", (1.94, 2.2, 0.56), (x, -0.32, 1.565), leather, e=0.3))
        lip = [(x - 0.88, 0.7, 1.8), (x - 0.9, -1.2, 1.8), (x - 0.62, -1.4, 1.8), (x + 0.62, -1.4, 1.8), (x + 0.9, -1.2, 1.8),
               (x + 0.88, 0.7, 1.8)]
        parts.append(bar("Piping", spline(lip, 2), 0.022, pipe, sides=4))
    # The nails along the rail, the feet.
    parts.append(mk.box("RailNailRow", (6.9, 0.01, 0.075), (0, -1.335, 0.56), mat=nails_along))
    for x in (-3.25, 3.25):
        for y in (-1.1, 1.2):
            parts.append(mk.lathe("Foot", [(0.0, 0.08), (0.12, 0.09), (0.2, 0.2), (0.2, 0.27), (0.14, 0.36), (0.16, 0.42), (0.0, 0.42)],
                                  (x, y, 0), mat=wood, segments=10))
            parts.append(mk.lathe("Castor", [(0.0, 0.0), (0.09, 0.0), (0.12, 0.04), (0.12, 0.1), (0.0, 0.1)], (x, y, 0), mat=brass,
                                  segments=8))
    return parts, []


def frond(azimuth, reach, rise, droop, base, mat, pairs=16, width=0.17):
    """One arching fern frond: a thin rib with a leaflet each side at every joint, swept toward the tip and getting
    smaller. One connected sheet, not a scatter of loose leaves: tiny loose faces cannot hold a bake."""
    c, s = math.cos(azimuth), math.sin(azimuth)
    side = Vector((-s, c, 0))

    def spine(t):
        out = reach * t ** 0.9
        return Vector((base[0] + c * out, base[1] + s * out, base[2] + 4 * rise * t * (1 - t) - droop * t ** 3))

    points, faces = [], []
    for k in range(pairs + 1):
        mid = spine(k / pairs)
        points += [tuple(mid + side * 0.012), tuple(mid - side * 0.012)]
    for k in range(pairs):
        t = (k + 0.5) / pairs
        a, b = 2 * k, 2 * k + 1
        faces.append((a, b, b + 2, a + 2))
        forward = (spine((k + 1) / pairs) - spine(k / pairs)).normalized()
        size = width * math.sin(math.pi * (t * 0.8 + 0.16)) ** 0.8
        at = spine(t)
        tips = len(points)
        points += [tuple(at + side * size + forward * size * 1.1), tuple(at - side * size + forward * size * 1.1)]
        faces += [(a + 2, tips, a), (b, tips + 1, b + 2)]
    return blade("Frond", points, faces, mat)


@prop("FernStand", pivot="bottom", material="Grass", collide=True, texture=512, set="Campus", exact=True, ao=0.25)
def fern_stand():
    """A Boston fern in a sage glazed cachepot on a turned oak plant stand with a low shelf: its fronds spring from the
    crown, arch up and hang over the rim, pale young ones at the middle."""
    oak = mk.wood("Fern_Oak", srgb(112, 78, 46), srgb(70, 46, 28), roughness=0.45)
    pot = mk.noisy("Fern_Glaze", srgb(92, 112, 96), srgb(136, 156, 136), roughness=0.22, kind="plastic")
    band = mk.noisy("Fern_Band", srgb(150, 130, 90), srgb(190, 170, 124), roughness=0.3, kind="plastic")
    soil = mk.noisy("Fern_Soil", srgb(20, 14, 10), srgb(40, 30, 22), roughness=1.0)
    deep = mk.noisy("Fern_Leaf", srgb(28, 62, 34), srgb(56, 100, 50), roughness=0.55)
    mid = mk.noisy("Fern_LeafMid", srgb(42, 84, 42), srgb(76, 120, 58), roughness=0.55)
    young = mk.noisy("Fern_LeafYoung", srgb(68, 116, 52), srgb(110, 148, 70), roughness=0.55)
    parts = [mk.lathe("Top", [(0.0, 1.3), (0.6, 1.3), (0.66, 1.34), (0.64, 1.4), (0.0, 1.4)], mat=oak, segments=20),
             mk.lathe("Shelf", [(0.0, 0.42), (0.5, 0.42), (0.54, 0.46), (0.5, 0.5), (0.0, 0.5)], mat=oak, segments=16),
             turned("Column", [(0.0, 0.0), (0.1, 0.0), (0.13, 0.08), (0.06, 0.3), (0.12, 0.45), (0.05, 0.62), (0.1, 0.88), (0.14, 1.0),
                               (0.0, 1.0)], (0, 0, 0.5), (0, 0, 1.3), oak)]
    for k in range(3):
        a = math.radians(90 + 120 * k)
        c, s = math.cos(a), math.sin(a)
        leg = spline([(0.52 * c, 0.52 * s, 1.3), (0.6 * c, 0.6 * s, 0.9), (0.72 * c, 0.72 * s, 0.42), (0.96 * c, 0.96 * s, 0.08),
                      (1.02 * c, 1.02 * s, 0.03)], 2)
        parts.append(bar("Leg", leg, [0.075 - 0.025 * j / (len(leg) - 1) for j in range(len(leg))], oak))
    parts += [mk.lathe("Pot", [(0.0, 1.4), (0.3, 1.4), (0.34, 1.46), (0.42, 1.7), (0.48, 2.0), (0.52, 2.08), (0.5, 2.14),
                               (0.44, 2.14), (0.42, 2.06), (0.0, 2.06)], mat=pot, segments=20),
              mk.lathe("PotBand", [(0.43, 1.76), (0.452, 1.77), (0.47, 1.9), (0.45, 1.92)], mat=band, segments=20, caps=False),
              mk.cylinder("Soil", 0.43, 0.03, (0, 0, 2.06), mat=soil, verts=16)]
    rng = random.Random(23)
    for k in range(30):
        azimuth = k * 2.39996 + rng.uniform(-0.15, 0.15)
        share = k / 30  # (young and upright at the crown's middle, long and arching over at its edge)
        reach = 0.42 + 0.84 * share + rng.uniform(-0.06, 0.06)
        rise = 1.2 - 0.55 * share + rng.uniform(-0.1, 0.1)
        droop = 0.1 + 0.7 * share
        base = (0.05 * math.cos(azimuth), 0.05 * math.sin(azimuth), 2.08)
        parts.append(frond(azimuth, reach, rise, droop, base, young if share < 0.25 else (mid if k % 3 == 0 else deep)))
    return parts, []


def bin_pull(name, x, y, z, mat, w=0.46):
    """A cast brass cup pull on a face at y (facing -Y)."""
    obj = sk.wedge(name, [(0.0, 0.0), (0.0, -0.17), (-0.05, -0.16), (-0.12, -0.1), (-0.13, -0.04), (-0.06, 0.0)], w, x, mat)
    obj.location = (x, y, z)
    return obj


def card_frame(prefix, x, y, z, frame, card, w=0.66, h=0.24):
    """A brass label frame on a face at y, with its card."""
    t = 0.03
    return [mk.box(prefix + "Card", (w - t, 0.012, h - t), (x, y - 0.006, z), mat=card),
            mk.box(prefix + "FrameT", (w, 0.022, t), (x, y - 0.011, z + h / 2 - t / 2), mat=frame),
            mk.box(prefix + "FrameB", (w, 0.022, t), (x, y - 0.011, z - h / 2 + t / 2), mat=frame),
            mk.box(prefix + "FrameL", (t, 0.022, h - 2 * t), (x - w / 2 + t / 2, y - 0.011, z), mat=frame),
            mk.box(prefix + "FrameR", (t, 0.022, h - 2 * t), (x + w / 2 - t / 2, y - 0.011, z), mat=frame)]


@prop("OakCabinet", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus")
def oak_cabinet():
    """A faculty filing cabinet in golden oak: a plinth and a moulded cornice round a panelled carcass, four fielded drawers
    in a face frame, each with its brass label frame and cup pull, the lock in the top one."""
    oak = mk.wood("OFile_Oak", srgb(170, 124, 72), srgb(108, 74, 42), roughness=0.45)
    frame = mk.wood("OFile_Wood", srgb(132, 92, 54), srgb(88, 58, 34), roughness=0.5)
    brass = pk.metal("OFile_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    card = mk.noisy("OFile_Card", srgb(206, 196, 170), srgb(232, 224, 200), roughness=0.9)
    dark = mk.flat("OFile_Dark", srgb(30, 22, 16), 0.8)
    parts = [mk.box("Carcass", (2.26, 1.92, 4.56), (0, 0.11, 2.5), mat=frame),
             pk.rounded("Plinth", (2.36, 2.0, 0.24), (0, 0.1, 0.12), frame, r=0.02),
             mk.box("PlinthCap", (2.31, 1.96, 0.05), (0, 0.1, 0.265), mat=oak, bevel=0.015, segments=1),
             mk.box("CorniceLow", (2.31, 2.02, 0.08), (0, 0.06, 4.8), mat=oak, bevel=0.02, segments=1),
             pk.rounded("Cornice", (2.4, 2.2, 0.15), (0, 0.0, 4.915), oak, r=0.03)]
    # The sides: stiles and rails round two raised panels.
    for side in (-1, 1):
        x = side * 1.135
        for y in (-0.76, 0.98):
            parts.append(mk.box("Stile", (0.04, 0.16, 4.5), (x, y, 2.52), mat=oak))
        for z in (0.38, 2.52, 4.68):
            parts.append(mk.box("Rail", (0.04, 1.58, 0.16), (x, 0.11, z), mat=oak))
        for z in (1.45, 3.6):
            parts.append(mk.box("Panel", (0.03, 1.42, 1.84), (x, 0.11, z), mat=oak, bevel=0.012, segments=1))
    # The front: a face frame, four drawers.
    front = -0.85
    tall = 1.1
    parts += [mk.box("FaceL", (0.12, 0.03, 4.48), (-1.07, front, 2.52), mat=oak),
              mk.box("FaceR", (0.12, 0.03, 4.48), (1.07, front, 2.52), mat=oak)]
    for k in range(4):
        z = 0.34 + tall * (k + 0.5) + 0.03 * k
        parts.append(mk.box("FaceRail", (2.02, 0.03, 0.05), (0, front, z + tall / 2 + 0.015), mat=oak))
        parts.append(pk.rounded("Drawer", (1.96, 0.06, tall - 0.04), (0, front - 0.02, z), oak, r=0.018))
        parts.append(mk.box("Field", (1.68, 0.03, tall - 0.3), (0, front - 0.055, z), mat=frame, bevel=0.012, segments=1))
        parts += card_frame("Label", 0, front - 0.07, z + 0.2, brass, card)
        parts.append(mk.box("Typed", (0.36, 0.005, 0.05), (0, front - 0.083, z + 0.2), mat=dark))
        parts.append(bin_pull("Pull", 0, front - 0.07, z - 0.1, brass))
    top = 0.34 + tall * 3.5 + 0.09
    parts.append(mk.cylinder("Lock", 0.05, 0.02, (0.72, front - 0.075, top + 0.32), rot=(90, 0, 0), mat=brass, verts=10))
    parts.append(mk.box("Keyhole", (0.018, 0.006, 0.05), (0.72, front - 0.088, top + 0.32), mat=dark))
    return parts, []


def bail(prefix, x, y, z, plate, w=0.42):
    """A brass bail pull on a face at y (facing -Y): two round rosettes and the swung handle hanging between them."""
    pts = spline([(x - w / 2, y - 0.03, z), (x - w / 2, y - 0.05, z - 0.08), (x - w * 0.28, y - 0.06, z - 0.15),
                  (x + w * 0.28, y - 0.06, z - 0.15), (x + w / 2, y - 0.05, z - 0.08), (x + w / 2, y - 0.03, z)], 2)
    return [mk.cylinder(prefix + "Rose", 0.06, 0.016, (x - w / 2, y - 0.008, z), rot=(90, 0, 0), mat=plate, verts=8),
            mk.cylinder(prefix + "Rose", 0.06, 0.016, (x + w / 2, y - 0.008, z), rot=(90, 0, 0), mat=plate, verts=8),
            bar(prefix + "Bail", pts, 0.016, plate, sides=4)]


@prop("ProfessorDesk", pivot="bottom", material="Wood", collide=True, texture=1024, set="Campus")
def professor_desk():
    """A professor's twin pedestal desk in dark oak: a moulded top with its tooled green leather writing surface, two
    pedestals of three drawers with brass bail pulls and keyhole plates on plinths, a panelled back, the shallow centre
    drawer over the knee. On it a banker's lamp with its green shade lit, an open book, a stack of old volumes, loose
    sheets and a fountain pen on its tray."""
    oak = mk.wood("PDesk_Oak", srgb(96, 62, 36), srgb(56, 36, 22), roughness=0.42)
    panel = mk.wood("PDesk_Wood", srgb(84, 54, 32), srgb(50, 32, 20), roughness=0.48)
    hide = mk.noisy("PDesk_Leather", srgb(26, 50, 38), srgb(48, 80, 58), roughness=0.42)
    gilt = pk.metal("PDesk_Gold", (150, 118, 60), (200, 168, 96), rough=0.4, metallic=1.0)
    brass = pk.metal("PDesk_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    paper = mk.noisy("PDesk_Paper", srgb(204, 196, 176), srgb(232, 226, 208), roughness=0.9)
    pages = mk.noisy("PDesk_Pages", srgb(196, 186, 160), srgb(224, 214, 190), roughness=0.9)
    writing = mk.flat("PDesk_Writing", srgb(30, 30, 36), 0.7)
    covers = [mk.noisy(f"PDesk_Book{i}", srgb(*c), srgb(*[v + 30 for v in c]), roughness=0.6)
              for i, c in enumerate(((84, 30, 28), (34, 48, 70), (58, 52, 34)))]
    glass = mk.noisy("PDesk_Plastic", srgb(16, 62, 40), srgb(30, 96, 64), roughness=0.12)
    rng = random.Random(7)
    h = 3.05
    parts = [pk.rounded("Top", (6.0, 3.0, 0.13), (0, 0, h - 0.065), oak, r=0.04),
             mk.box("TopMould", (5.88, 2.88, 0.07), (0, 0, h - 0.165), mat=panel, bevel=0.02, segments=1),
             mk.box("WritingHide", (5.3, 2.34, 0.014), (0, 0, h + 0.002), mat=hide),
             mk.box("KneeDrawer", (2.5, 0.05, 0.3), (0, -1.28, h - 0.38), mat=oak, bevel=0.012, segments=1),
             mk.box("Apron", (2.6, 2.5, 0.34), (0, 0.04, h - 0.38), mat=panel)]
    for y in (1.15, -1.15):
        parts.append(mk.box("Tooling", (5.2, 0.012, 0.004), (0, y, h + 0.011), mat=gilt))
    for x in (-2.6, 2.6):
        parts.append(mk.box("Tooling", (0.012, 2.3, 0.004), (x, 0, h + 0.011), mat=gilt))
    parts += bail("Centre", 0, -1.305, h - 0.34, brass, w=0.5)
    parts.append(mk.box("Back", (2.7, 0.08, 1.9), (0, 1.32, h - 1.3), mat=panel))
    # The pedestals.
    for side in (-1, 1):
        x = side * 2.12
        parts += [mk.box("Pedestal", (1.56, 2.72, 2.62), (x, 0.02, 1.53), mat=panel),
                  pk.rounded("Plinth", (1.66, 2.82, 0.22), (x, 0.02, 0.11), oak, r=0.02)]
        for y in (-0.72, 0.76):  # (the outer side's panels)
            parts.append(mk.box("SidePanel", (0.03, 1.1, 2.0), (side * 2.915, y, 1.54), mat=oak, bevel=0.012, segments=1))
        tall = 0.8
        for k in range(3):
            z = 0.28 + (tall + 0.05) * (k + 0.5)
            parts.append(pk.rounded("Drawer", (1.42, 0.05, tall), (x, -1.34, z), oak, r=0.016))
            parts.append(mk.box("Bead", (1.26, 0.02, tall - 0.16), (x, -1.37, z), mat=panel, bevel=0.008, segments=1))
            parts += bail("Pull", x, -1.38, z + 0.1, brass)
            parts.append(mk.box("KeyPlate", (0.08, 0.012, 0.14), (x, -1.385, z + 0.26), mat=brass))
    # The lamp: a brass stand with its green shade over a lit bulb.
    lx, ly = -1.9, 0.72
    parts += [mk.lathe("LampFoot", [(0.0, h), (0.34, h), (0.36, h + 0.03), (0.3, h + 0.07), (0.08, h + 0.12), (0.05, h + 0.18),
                                    (0.0, h + 0.18)], (lx, ly, 0), mat=brass, segments=14),
              bar("LampStem", spline([(lx, ly, h + 0.16), (lx, ly - 0.01, h + 0.7), (lx, ly - 0.12, h + 1.0), (lx, ly - 0.3, h + 1.12)], 3),
                  0.03, brass, sides=5),
              mk.soften(mk.cylinder("LampShade", 0.17, 0.95, (lx, ly - 0.32, h + 1.13), rot=(0, 90, 0), mat=glass, verts=10)),
              bar("LampPull", [(lx + 0.3, ly - 0.42, h + 1.04), (lx + 0.3, ly - 0.42, h + 0.86)], 0.008, brass, sides=4)]
    glow = [mk.box("Bulb", (0.8, 0.14, 0.03), (lx, ly - 0.34, h + 0.97), mat=pk.glow("PDesk_Bulb", LAMP, 5))]
    # The work: an open book, loose sheets, a stack of volumes, the pen on its tray.
    parts += sk.open_book("Book", 0.1, -0.35, h + 0.016, covers[0], pages, writing, rng, yaw=-4, w=1.6, d=1.05)
    parts += sk.papers("Sheet", -1.4, -0.55, h + 0.016, paper, rng, n=3)
    parts += sk.written("Sheet", -1.4, -0.55, h + 0.066, writing, rng, lines=5)
    z = h + 0.016
    for k, (w, d, tall, yaw) in enumerate(((1.1, 1.5, 0.22, 4), (1.0, 1.36, 0.18, -7), (0.86, 1.2, 0.17, 10))):
        parts += sk.book(f"Vol{k}", 1.9, 0.5, z, covers[k], pages, yaw=yaw, w=w, d=d, h=tall)
        z += tall
    parts.append(pk.rounded("Tray", (0.86, 0.22, 0.03), (1.2, -0.92, h + 0.03), oak, r=0.01))
    parts += sk.pen("FountainPen", (0.86, -0.93, h + 0.056), (1.44, -0.91, h + 0.056), mk.flat("PDesk_Pen", srgb(14, 14, 16), 0.3), cap=gilt)
    return parts, glow


# Bureau HQ ----------------------------------------------------------------------------------------------


def loop(w, d, z, c=0.12, steps=3, x=0.0, y=0.0):
    """A closed rounded rectangle of points lying at z, the first repeated at the end."""
    pts = []
    for sx, sy, a0 in ((1, 1, 0), (-1, 1, 90), (-1, -1, 180), (1, -1, 270)):
        for k in range(steps + 1):
            a = math.radians(a0 + 90 * k / steps)
            pts.append((x + sx * (w / 2 - c) + c * math.cos(a), y + sy * (d / 2 - c) + c * math.sin(a), z))
    return pts + [pts[0]]


def leaf(name, base, along, side, length, width, droop, mat, rows=5, fold=0.25, apart=0.006):
    """A broad leaf: a sheet from base along `along`, bending down by `droop` of its length, widest past its middle and
    drawn to a point, folded along its rib."""
    base, along, side = Vector(base), Vector(along).normalized(), Vector(side).normalized()
    points, faces = [], []
    for k in range(rows + 1):
        t = k / rows
        half = width * math.sin(math.pi * t ** 0.75) ** 0.8 if 0 < k < rows else 0.002
        mid = base + along * (length * t) - Vector((0, 0, droop * length * t * t))
        lift = Vector((0, 0, half * fold))
        points += [tuple(mid + side * half + lift), tuple(mid), tuple(mid - side * half + lift)]
        if k:
            n = 3 * k
            faces += [(n - 3, n - 2, n + 1, n), (n - 2, n - 1, n + 2, n + 1)]
    return blade(name, points, faces, mat, apart)


@prop("BureauChair", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency", exact=True)
def bureau_chair():
    """The Bureau's guest chair: one chrome tube bent from the top of the back down its side, forward under the seat, down
    to the floor and back round behind the feet; a herringbone wool seat and back with piped edges, clamped to the tube
    on black steel pans, rubber glides under the runners and a property tag riveted to the back."""
    tube = pk.chrome("BuChair_Chrome")
    wool = mk.noisy("BuChair_Cloth", srgb(30, 32, 38), srgb(60, 64, 72), roughness=0.85, kind="wool")
    pipe = mk.noisy("BuChair_Leather", srgb(14, 14, 18), srgb(34, 34, 40), roughness=0.5)
    pan = pk.metal("BuChair_Steel", (28, 28, 32), (52, 52, 58), rough=0.5, metallic=0.7)
    alu = pk.metal("BuChair_Alu", (150, 154, 160), (190, 194, 200), rough=0.35, metallic=1.0)
    rubber = pk.rubber("BuChair_Rubber")
    x = 0.8
    half = [(x, 0.82, 3.42), (x, 0.74, 2.4), (x, 0.7, 1.86), (x, 0.6, 1.6), (x, 0.3, 1.52), (x, -0.6, 1.52), (x, -0.78, 1.44),
            (x, -0.83, 1.2), (x, -0.8, 0.3), (x, -0.76, 0.11), (x, -0.6, 0.055), (x, 0.3, 0.055), (x, 0.62, 0.055), (x - 0.03, 0.74, 0.055),
            (x - 0.16, 0.8, 0.055), (0.4, 0.8, 0.055), (0.0, 0.8, 0.055)]
    parts = [bar("Frame", arch(spline(half, 2)), 0.055, tube),
             cushion("SeatPad", (1.46, 1.66, 0.22), (0, -0.04, 1.635), wool, segments=16, rings=8),
             bar("SeatWelt", loop(1.36, 1.56, 1.665, c=0.1), 0.018, pipe, sides=4),
             pk.rounded("SeatPan", (1.32, 1.5, 0.05), (0, -0.04, 1.5), pan, r=0.02)]
    back = cushion("BackPad", (1.46, 0.18, 1.2), (0, 0.7, 2.86), wool, segments=16, rings=8)
    shell = cushion("BackPan", (1.38, 0.08, 1.12), (0, 0.8, 2.86), pan, e=0.25, segments=12, rings=6)
    back.rotation_euler = shell.rotation_euler = (math.radians(-7), 0, 0)
    parts += [back, shell]
    for side in (-1, 1):
        for y in (-0.5, 0.42):  # (the seat's clamps)
            parts.append(mk.box("SeatClamp", (0.2, 0.14, 0.05), (side * 0.72, y, 1.53), mat=pan, bevel=0.012, segments=1))
        for z, y in ((2.5, 0.76), (3.2, 0.81)):  # (the back's)
            parts.append(mk.box("BackClamp", (0.2, 0.12, 0.1), (side * 0.72, y, z), mat=pan, bevel=0.012, segments=1))
        for y in (-0.5, 0.5):
            parts.append(mk.box("Glide", (0.13, 0.26, 0.03), (side * x, y, 0.015), mat=rubber))
        parts.append(mk.box("Plug", (0.095, 0.09, 0.05), (side * x, 0.825, 3.45), rot=(-4, 0, 0), mat=rubber))
    parts.append(mk.box("PropertyTag", (0.26, 0.012, 0.12), (0, 0.845, 2.6), rot=(-7, 0, 0), mat=alu, bevel=0.003))
    return parts, []


@prop("BureauBench", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency", exact=True, normal=512)
def bureau_bench():
    """Waiting room beam seating: three seats of punched black steel with leather pads, bolted on a steel beam carried by
    two T legs anchored through floor plates, flat arms between the seats."""
    sheet = punched("BuBench_Steel", (46, 48, 54), (8, 8, 10), 0.075, share=0.3, roughness=0.45, metallic=0.6)
    frame = pk.metal("BuBench_Frame", (56, 58, 64), (84, 86, 92), rough=0.4, metallic=0.8)
    leather = mk.noisy("BuBench_Leather", srgb(14, 14, 18), srgb(40, 40, 48), roughness=0.42)
    arm = mk.noisy("BuBenchArm_Leather", srgb(12, 12, 16), srgb(34, 34, 40), roughness=0.5)
    bolt = pk.metal("BuBench_Bolt", (110, 112, 118), (150, 152, 158), rough=0.4, metallic=1.0)
    profile = [(-0.82, 1.44), (-0.76, 1.37), (0.3, 1.35), (0.54, 1.41), (0.66, 1.62), (0.76, 2.4), (0.86, 3.28), (0.8, 3.3), (0.7, 2.4),
               (0.6, 1.66), (0.48, 1.47), (0.28, 1.41), (-0.72, 1.43), (-0.8, 1.5)]
    parts = [pk.rounded("Beam", (5.72, 0.34, 0.18), (0, 0.02, 1.12), frame, r=0.03)]
    for x in (-1.92, 0.0, 1.92):
        parts.append(sk.wedge("Shell", profile, 1.76, x, sheet, bevel=0.012))
        parts.append(cushion("SeatPad", (1.62, 1.16, 0.17), (x, -0.14, 1.515), leather, segments=14, rings=7))
        pad = cushion("BackPad", (1.62, 0.13, 1.16), (x, 0.66, 2.56), leather, segments=14, rings=7)
        pad.rotation_euler = (math.radians(-8), 0, 0)
        parts.append(pad)
        for side in (-1, 1):
            parts.append(mk.box("Mount", (0.12, 0.52, 0.16), (x + side * 0.5, 0.02, 1.28), mat=frame, bevel=0.012, segments=1))
    for x in (-2.02, 2.02):
        parts += [mk.box("Post", (0.22, 0.2, 0.98), (x, 0.02, 0.54), mat=frame, bevel=0.02, segments=1),
                  mk.box("Plinth", (0.26, 1.6, 0.08), (x, 0.02, 0.04), mat=frame, bevel=0.02, segments=1)]
        anchors = [(x + sx * 0.07, 0.02 + sy * 0.68, 0.08) for sx in (-1, 1) for sy in (-1, 1)]
        parts.append(studs("Anchor", anchors, 0.04, 0.018, bolt))
    for x in (-2.84, -0.96, 0.96, 2.84):
        parts += [mk.box("ArmBlade", (0.07, 0.14, 1.04), (x, 0.24, 1.68), mat=frame, bevel=0.012, segments=1),
                  pk.rounded("ArmPad", (0.17, 1.14, 0.1), (x, -0.08, 2.22), arm, r=0.04)]
    return parts, []


@prop("BureauSofa", pivot="bottom", material="Leather", collide=True, texture=512, set="Agency", exact=True, normal=512)
def bureau_sofa():
    """The executive floor's lounge sofa: a cage of chrome tube standing round loose cushions of black leather, the base
    cushion, three seats, three backs and the arms each with its piped seam."""
    leather = mk.noisy("BuSofa_Leather", srgb(14, 15, 20), srgb(44, 46, 58), roughness=0.4)
    pipe = mk.noisy("BuSofaPipe_Leather", srgb(8, 8, 12), srgb(24, 24, 30), roughness=0.5)
    tube = pk.chrome("BuSofa_Chrome")
    rubber = pk.rubber("BuSofa_Rubber")
    parts = [bar("BottomRail", loop(7.2, 2.9, 0.66, c=0.14), 0.06, tube),
             bar("TopRail", [(3.6, -1.42, 2.4)] + loop(7.2, 2.9, 2.4, c=0.14)[:8] + [(-3.6, -1.42, 2.4)], 0.06, tube)]
    for x in (-3.6, 3.6):
        for y in (-1.42, 1.4):
            parts.append(mk.soften(mk.tube("Leg", (x, y, 0.02), (x, y, 2.4), 0.06, mat=tube, verts=8)))
            parts.append(mk.cylinder("Foot", 0.075, 0.03, (x, y, 0.015), mat=rubber, verts=8))
    parts.append(mk.soften(mk.tube("Leg", (0, 1.45, 0.02), (0, 1.45, 2.4), 0.06, mat=tube, verts=8)))
    parts.append(mk.cylinder("Foot", 0.075, 0.03, (0, 1.45, 0.015), mat=rubber, verts=8))
    parts.append(cushion("BaseCushion", (6.96, 2.66, 0.62), (0, 0.02, 0.99), leather, e=0.24, segments=16, rings=8))
    for x in (-2.26, 0.0, 2.26):
        parts.append(cushion("SeatCushion", (2.24, 2.2, 0.56), (x, -0.22, 1.565), leather, e=0.26, segments=16, rings=8))
        parts.append(bar("SeatWelt", loop(2.1, 2.06, 1.78, c=0.14, x=x, y=-0.22), 0.02, pipe, sides=4))
        parts.append(cushion("BackCushion", (2.24, 0.62, 1.5), (x, 1.04, 2.34), leather, e=0.26, segments=16, rings=8))
    for side in (-1, 1):
        parts.append(cushion("ArmCushion", (0.58, 2.74, 1.16), (side * 3.27, 0.02, 1.9), leather, e=0.26, segments=16, rings=8))
    return parts, []


@prop("OfficeFicus", pivot="bottom", material="Grass", collide=True, texture=512, set="Agency", exact=True, ao=0.3)
def office_ficus():
    """A rubber plant in a square fibre cement planter: three stems out of a bed of grey pebbles, broad dark leaves
    spiralling up them, each folded on its rib, a red sheath at each growing tip."""
    planter = mk.noisy("Ficus_Concrete", srgb(58, 60, 64), srgb(92, 94, 98), roughness=0.75)
    rim = pk.metal("Ficus_Steel", (34, 36, 40), (60, 62, 68), rough=0.45, metallic=0.8)
    soil = mk.noisy("Ficus_Soil", srgb(24, 22, 20), srgb(46, 42, 38), roughness=1.0)
    pebble = mk.noisy("Ficus_Stone", srgb(90, 92, 96), srgb(140, 142, 146), roughness=0.8)
    stem = mk.noisy("Ficus_Bark", srgb(52, 42, 30), srgb(86, 72, 52), roughness=0.7)
    dark = mk.noisy("Ficus_Leaf", srgb(12, 34, 22), srgb(30, 64, 40), roughness=0.34)
    fresh = mk.noisy("Ficus_LeafFresh", srgb(20, 50, 28), srgb(44, 86, 50), roughness=0.34)
    sheath = mk.noisy("Ficus_Sheath", srgb(120, 30, 34), srgb(170, 50, 50), roughness=0.4)
    parts = [mk.cylinder("Planter", 0.86, 1.1, (0, 0, 0.55), rot=(0, 0, 45), mat=planter, verts=4, radius2=0.98),
             mk.box("Rim", (1.46, 1.46, 0.06), (0, 0, 1.13), mat=rim, bevel=0.015, segments=1),
             mk.box("Soil", (1.3, 1.3, 0.04), (0, 0, 1.15), mat=soil)]
    rng = random.Random(41)
    for k in range(20):
        a, r = rng.uniform(0, 6.28), rng.uniform(0.1, 0.6)
        parts.append(mk.sphere("Pebble", rng.uniform(0.06, 0.1), (r * math.cos(a), r * math.sin(a), 1.18),
                               scale=(1, rng.uniform(0.7, 1.0), 0.6), mat=pebble, segments=5, rings=3))
    count = 0
    for (x, y, top, lean, n) in ((0.1, -0.08, 3.56, 0.14, 10), (-0.2, 0.14, 3.0, -0.2, 8), (0.22, 0.2, 2.6, 0.24, 7)):
        path = spline([(x, y, 1.14), (x + lean * 0.2, y, 1.9), (x + lean * 0.5, y - lean * 0.1, top - 0.6), (x + lean, y - lean * 0.2, top)], 2)
        parts.append(bar("Stem", path, [0.055 - 0.03 * j / (len(path) - 1) for j in range(len(path))], stem, sides=5))
        tip = Vector(path[-1])
        parts.append(mk.soften(mk.tube("Sheath", tip, tip + Vector((0, 0, 0.3)), 0.026, 0.004, mat=sheath, verts=5)))
        for j in range(n):
            t = (j + 1) / n
            at = Vector(path[0]).lerp(tip, 0.18 + 0.82 * t)
            a = count * 2.39996
            count += 1
            out = Vector((math.cos(a), math.sin(a), 0.42 + 0.5 * t))
            side = Vector((-math.sin(a), math.cos(a), 0))
            parts.append(leaf("Leaf", at, out, side, 1.1 - 0.42 * t, 0.3 - 0.08 * t, 0.42, fresh if t > 0.7 else dark))
    return parts, []


@prop("BureauCabinet", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency")
def bureau_cabinet():
    """A security file in grey enamelled steel: four drawers with recessed pulls, thumb latches and card holders, a lock bar
    down the front through its staples with a brass padlock at the top, the red classification magnet on the top
    drawer, ribbed sides and a black kick plinth."""
    body = pk.metal("BuFile_Steel", (70, 76, 74), (104, 110, 106), rough=0.42, metallic=0.5)
    bright = pk.metal("BuFile_Chrome", (126, 130, 134), (176, 180, 184), rough=0.3, metallic=1.0)
    dark = pk.metal("BuFile_Iron", (18, 18, 20), (38, 38, 42), rough=0.55, metallic=0.6)
    brass = pk.metal("BuFile_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    card = mk.noisy("BuFile_Card", srgb(214, 208, 190), srgb(238, 232, 214), roughness=0.9)
    red = mk.flat("BuFile_Plastic", srgb(150, 24, 30), 0.4)
    white = mk.flat("BuFileBand_Plastic", srgb(226, 222, 214), 0.4)
    typed = mk.flat("BuFile_Print", srgb(26, 26, 30), 0.8)
    front = -0.92
    parts = [mk.box("Carcass", (2.36, 2.02, 4.72), (0, 0.09, 2.62), mat=body, bevel=0.03, segments=1),
             mk.box("Kick", (2.26, 1.9, 0.26), (0, 0.09, 0.13), mat=dark),
             mk.box("TopPlate", (2.4, 2.06, 0.06), (0, 0.09, 4.97), mat=body, bevel=0.02, segments=1)]
    for side in (-1, 1):
        for k in range(5):
            parts.append(mk.box("SideRib", (0.03, 0.09, 4.3), (side * 1.18, -0.56 + 0.32 * k, 2.62), mat=body, bevel=0.01, segments=1))
    tall = 1.13
    for k in range(4):
        z = 0.3 + tall * (k + 0.5)
        parts.append(pk.rounded("Drawer", (2.24, 0.05, tall - 0.05), (0, front - 0.025, z), body, r=0.018))
        parts.append(mk.box("PullShadow", (1.0, 0.012, 0.13), (-0.14, front - 0.053, z + 0.06), mat=dark))
        parts.append(mk.box("PullLip", (1.06, 0.05, 0.05), (-0.14, front - 0.075, z + 0.14), mat=bright, bevel=0.012, segments=1))
        parts.append(mk.box("Latch", (0.14, 0.05, 0.1), (-0.14, front - 0.08, z + 0.05), mat=bright, bevel=0.012, segments=1))
        parts += card_frame("Label", -0.14, front - 0.05, z + 0.34, bright, card, w=0.62, h=0.2)
        parts.append(mk.box("Typed", (0.34, 0.005, 0.04), (-0.14, front - 0.063, z + 0.34), mat=typed))
    # The lock bar, its staples and padlock.
    lx = 0.86
    parts.append(mk.box("LockBar", (0.17, 0.04, 4.46), (lx, front - 0.09, 2.54), mat=bright, bevel=0.01, segments=1))
    for k in range(5):
        parts.append(mk.box("Staple", (0.27, 0.05, 0.1), (lx, front - 0.075, 0.5 + 1.03 * k), mat=dark, bevel=0.01, segments=1))
    parts.append(mk.box("Hasp", (0.24, 0.05, 0.16), (lx, front - 0.09, 4.84), mat=dark, bevel=0.01, segments=1))
    parts.append(pk.rounded("Padlock", (0.2, 0.09, 0.2), (lx, front - 0.145, 4.62), brass, r=0.03))
    parts.append(bar("Shackle", spline([(lx - 0.055, front - 0.145, 4.7), (lx - 0.055, front - 0.145, 4.8), (lx, front - 0.145, 4.84),
                                        (lx + 0.055, front - 0.145, 4.8), (lx + 0.055, front - 0.145, 4.7)], 2), 0.018, bright, sides=5))
    # The classification magnet.
    parts += [mk.box("Magnet", (0.62, 0.016, 0.26), (-0.14, front - 0.058, 3.82 + 0.26), mat=red),
              mk.box("MagnetBand", (0.52, 0.006, 0.07), (-0.14, front - 0.069, 3.82 + 0.26), mat=white)]
    return parts, []


@prop("BureauDesk", pivot="bottom", material="Metal", collide=True, texture=1024, set="Agency")
def bureau_desk():
    """A bullpen desk: a charcoal laminate top with its aluminium edge on two steel legs with levelling feet, a punched
    modesty panel, a locking drawer pedestal on castors, a flat monitor lit with a case system, keyboard, mouse, a desk
    telephone, a mug, loose reports and a case folder with its red tab."""
    top = mk.noisy("BuDesk_Plastic", srgb(70, 72, 76), srgb(96, 98, 102), roughness=0.35)
    edge = pk.metal("BuDesk_Alu", (120, 124, 130), (166, 170, 176), rough=0.35, metallic=1.0)
    frame = pk.metal("BuDesk_Steel", (34, 36, 40), (60, 62, 68), rough=0.45, metallic=0.7)
    panel = punched("BuDeskPanel_Steel", (52, 54, 60), (12, 12, 14), 0.09, share=0.3, roughness=0.45, metallic=0.5)
    drawer = pk.metal("BuDeskDrawer_Steel", (56, 60, 62), (84, 88, 90), rough=0.42, metallic=0.5)
    shell = pk.plastic("BuDesk_Bezel", (26, 27, 30))
    dark = pk.plastic("BuDeskDark_Plastic", (12, 12, 14))
    keys = lattice("BuDesk_Keys", (12, 12, 14), (64, 66, 72), 0.115, _axis("X"), _axis("Y"), share=0.4, roughness=0.5, square=True)
    pad = lattice("BuDesk_Dial", (24, 25, 28), (150, 152, 158), 0.1, _axis("X"), _axis("Y"), share=0.34, roughness=0.5, square=True)
    rubber = pk.rubber("BuDesk_Rubber")
    paper = mk.noisy("BuDesk_Paper", srgb(214, 212, 204), srgb(240, 238, 230), roughness=0.9)
    manila = mk.noisy("BuDesk_Folder", srgb(180, 150, 100), srgb(210, 182, 130), roughness=0.85)
    tab = mk.flat("BuDeskTab_Plastic", srgb(150, 24, 30), 0.4)
    writing = mk.flat("BuDesk_Print", srgb(40, 40, 46), 0.8)
    mug = mk.noisy("BuDeskMug_Plastic", srgb(190, 190, 186), srgb(226, 226, 222), roughness=0.3)
    coffee = mk.flat("BuDesk_Coffee", srgb(30, 18, 12), 0.2)
    rng = random.Random(19)
    h = 3.05
    parts = [pk.rounded("Top", (6.0, 3.0, 0.09), (0, 0, h - 0.045), top, r=0.018),
             mk.box("TopEdge", (5.94, 2.94, 0.04), (0, 0, h - 0.11), mat=edge),
             mk.box("Beam", (5.4, 0.14, 0.18), (0, 0.6, h - 0.22), mat=frame),
             mk.box("Modesty", (5.3, 0.04, 1.4), (0, 1.2, h - 0.95), mat=panel)]
    for side in (-1, 1):
        x = side * 2.78
        parts += [mk.box("LegFoot", (0.2, 2.8, 0.1), (x, 0, 0.08), mat=frame, bevel=0.025, segments=1),
                  mk.box("LegColumn", (0.2, 0.46, h - 0.3), (x, 0.1, 0.13 + (h - 0.3) / 2), mat=frame, bevel=0.02, segments=1),
                  mk.box("LegArm", (0.16, 2.6, 0.08), (x, 0, h - 0.17), mat=frame)]
        parts += pk.feet("Glide", [(x, -1.25), (x, 1.25)], rubber, r=0.07, h=0.04)
    # The pedestal under the left hand, on its castors.
    px, py = -1.86, 0.06
    parts.append(pk.rounded("Pedestal", (1.44, 2.3, 2.0), (px, py, 1.22), drawer, r=0.02))
    for sx in (-1, 1):
        for sy in (-1, 1):
            parts.append(mk.soften(mk.cylinder("Castor", 0.1, 0.09, (px + sx * 0.56, py + sy * 0.96, 0.1), rot=(0, 90, 0), mat=rubber, verts=10)))
    tall = 0.64
    front = py - 1.15
    for k in range(3):
        z = 0.26 + (tall + 0.02) * (k + 0.5)
        parts.append(pk.rounded("Drawer", (1.34, 0.04, tall), (px, front - 0.015, z), drawer, r=0.012))
        parts.append(mk.box("Pull", (0.6, 0.04, 0.05), (px, front - 0.05, z + 0.18), mat=edge, bevel=0.012, segments=1))
        parts.append(mk.box("Holder", (0.34, 0.012, 0.12), (px, front - 0.04, z - 0.1), mat=paper))
    parts.append(mk.cylinder("Lock", 0.04, 0.03, (px + 0.54, front - 0.04, 2.08), rot=(90, 0, 0), mat=edge, verts=8))
    # The monitor, its screen lit.
    slot = (0.1, 0.42, h + 1.12, 2.4, 1.36, 6)
    monitor, lamps = sk.lcd("Monitor", slot, shell, dark, stand_to=h)
    screen = mk.box("Screen", (2.36, 0.02, 1.32), slot[:3], mat=pk.glow("BuDesk_Screen", (58, 90, 120), 2.2))
    sk.tilt_about([screen], slot[:3], slot[5])
    parts += monitor
    # The keyboard and mouse.
    parts += [pk.rounded("KeyCase", (2.0, 0.7, 0.09), (0, -0.78, h + 0.05), shell, r=0.03),
              mk.box("KeyTops", (1.86, 0.56, 0.02), (0, -0.78, h + 0.1), mat=keys),
              cushion("Mouse", (0.22, 0.38, 0.12), (1.36, -0.76, h + 0.06), shell, e=0.7, segments=8, rings=5)]
    # The desk telephone.
    phone = sk.wedge("Phone", [(-0.4, 0.0), (0.4, 0.0), (0.4, 0.3), (0.1, 0.32), (-0.4, 0.12)], 0.9, 2.2, dark, bevel=0.03)
    phone.location = (2.2, 0.5, h)
    parts += [phone,
              mk.box("Dial", (0.42, 0.34, 0.02), (2.2, 0.28, h + 0.17), rot=(-14, 0, 0), mat=pad),
              bar("Handset", spline([(1.78, 0.72, h + 0.38), (1.88, 0.74, h + 0.44), (2.52, 0.74, h + 0.44), (2.62, 0.72, h + 0.38)], 2), 0.07, dark)]
    # The work: reports, a case folder, the mug.
    parts += sk.papers("Report", -1.5, -0.45, h, paper, rng, n=3)
    parts += sk.written("Report", -1.5, -0.45, h + 0.05, writing, rng, lines=5)
    parts += sk.folder("Case", -2.1, 0.8, h, manila, paper, yaw=8, tab=tab)
    parts += sk.mug("Mug", 1.7, -0.32, h, mug, coffee, handle_yaw=40)
    return parts, [screen] + lamps


@prop("ArchiveShelf", pivot="bottom", material="Metal", collide=True, texture=1024, set="Agency", exact=True)
def archive_shelf():
    """Steel records shelving: four angle posts punched for their shelf clips, tie plates, five folded shelves; on them case
    binders with white spine labels, grey archive boxes with their label plates and finger holes, and flat stacks of files."""
    post = lattice("Shelf_Steel", (60, 64, 66), (12, 12, 14), 0.2, _axis("Y"), _axis("Z"), share=0.24, roughness=0.45, metallic=0.6)
    shelf = pk.metal("ShelfBoard_Steel", (64, 68, 70), (96, 100, 102), rough=0.42, metallic=0.6)
    box = mk.noisy("Shelf_Card", srgb(116, 112, 104), srgb(146, 142, 132), roughness=0.85)
    lid = mk.noisy("ShelfLid_Card", srgb(96, 92, 86), srgb(124, 120, 112), roughness=0.85)
    label = mk.noisy("Shelf_Label", srgb(214, 208, 192), srgb(238, 232, 216), roughness=0.9)
    hole = mk.flat("Shelf_Hole", srgb(14, 14, 16), 0.9)
    files = mk.noisy("Shelf_Folder", srgb(176, 148, 100), srgb(206, 178, 128), roughness=0.85)
    papers = mk.noisy("Shelf_Paper", srgb(204, 200, 190), srgb(232, 228, 218), roughness=0.9)
    binders = [mk.noisy(f"ShelfBinder{i}_Plastic", srgb(*c), srgb(*[v + 26 for v in c]), roughness=0.4)
               for i, c in enumerate(((20, 28, 48), (24, 26, 30), (60, 22, 26)))]
    w, d = 3.1, 1.76
    parts = []
    for x in (-w / 2 + 0.08, w / 2 - 0.08):
        for y in (-d / 2 + 0.08, d / 2 - 0.08):
            parts.append(mk.box("Post", (0.16, 0.16, 8.0), (x, y, 4.0), mat=post))
    for x in (-w / 2 + 0.03, w / 2 - 0.03):  # (the tie plates on the ends)
        for z in (0.7, 4.0, 7.3):
            parts.append(mk.box("Tie", (0.03, d - 0.3, 0.28), (x, 0, z), mat=shelf))
    rng = random.Random(5)
    levels = [0.3, 1.82, 3.34, 4.86, 6.38, 7.9]
    for n, z in enumerate(levels):
        parts.append(mk.box("Board", (w - 0.02, d - 0.02, 0.08), (0, 0, z), mat=shelf, bevel=0.012, segments=1))
        parts.append(mk.box("Lip", (w - 0.3, 0.03, 0.12), (0, -d / 2 + 0.03, z - 0.1), mat=shelf))
    for n, z in enumerate(levels[:-1]):
        z += 0.04
        x = -w / 2 + 0.26
        end = w / 2 - 0.26
        if n % 2 == 0:  # (a run of binders, then whatever fits)
            while x < end - 0.3:
                wide = rng.choice((0.2, 0.2, 0.26))
                tall = rng.uniform(1.12, 1.2)
                c = rng.choice(binders)
                parts.append(mk.box("Binder", (wide, 1.2, tall), (x + wide / 2, -0.12, z + tall / 2), mat=c, bevel=0.012, segments=1))
                parts.append(mk.box("BinderLabel", (wide * 0.66, 0.008, 0.36), (x + wide / 2, -0.725, z + tall * 0.68), mat=label))
                parts.append(mk.box("BinderHole", (0.07, 0.008, 0.07), (x + wide / 2, -0.725, z + tall * 0.22), mat=hole))
                x += wide + 0.012
        else:
            while x < end - 0.7:
                wide = 0.86
                tall = 1.02
                parts.append(mk.box("ArchiveBox", (wide, 1.3, tall), (x + wide / 2, -0.08, z + tall / 2), mat=box, bevel=0.012, segments=1))
                parts.append(mk.box("BoxLid", (wide + 0.02, 1.32, 0.14), (x + wide / 2, -0.08, z + tall - 0.05), mat=lid, bevel=0.01, segments=1))
                parts.append(mk.box("BoxLabel", (0.5, 0.008, 0.26), (x + wide / 2, -0.736, z + tall * 0.58), mat=label))
                parts.append(mk.box("BoxHandle", (0.26, 0.008, 0.07), (x + wide / 2, -0.736, z + tall * 0.24), mat=hole))
                x += wide + 0.05
            if x < end - 0.2:  # (a flat stack in the gap)
                for k in range(5):
                    parts.append(mk.box("Files", (end - x, 1.1, 0.06), (x + (end - x) / 2 + rng.uniform(-0.02, 0.02), -0.12, z + 0.03 + k * 0.07),
                                        mat=files if k % 2 else papers))
    return parts, []


# Tokyo --------------------------------------------------------------------------------------------------


def channels(name, origin, across, up, out, w, h, flutes, mat, bulge=0.1, rows=4, per=4):
    """Channel tufted upholstery: vertical flutes of vinyl side by side across a panel, rounded over at top and bottom."""
    across, up, out = Vector(across).normalized(), Vector(up).normalized(), Vector(out).normalized()
    origin = Vector(origin)
    nu, nv = flutes * per, rows
    bm = bmesh.new()
    verts = []
    for j in range(nv + 1):
        z = j * h / nv
        fade = min(1.0, min(z, h - z) / (0.3 * h / rows + 1e-6) + 0.35)
        verts.append([bm.verts.new(origin + across * (i * w / nu) + up * z
                                   + out * (bulge * fade * abs(math.sin(math.pi * i / per)) ** 0.6)) for i in range(nu + 1)])
    flip = across.cross(up).dot(out) < 0
    for j in range(nv):
        for i in range(nu):
            face = (verts[j][i], verts[j][i + 1], verts[j + 1][i + 1], verts[j + 1][i])
            bm.faces.new(face[::-1] if flip else face)
    return mk.soften(mk._obj_from_bm(name, bm, mat))


@prop("StreetBench", pivot="bottom", material="Metal", collide=True, texture=512, set="Tokyo")
def street_bench():
    """A Tokyo street bench: one sheet of punched steel powder coated slate blue, bent from the seat's lip up into the back,
    carried by three cast frames bolted to concrete pads, the middle frame raised into the arm that stops anyone lying down."""
    sheet = punched("TBench_Steel", (46, 62, 76), (10, 12, 16), 0.085, share=0.3, roughness=0.4, metallic=0.55)
    frame = pk.metal("TBench_Iron", (24, 26, 30), (48, 50, 56), rough=0.5, metallic=0.8)
    concrete = mk.noisy("TBench_Concrete", srgb(96, 94, 90), srgb(136, 134, 128), roughness=0.85)
    bolt = pk.metal("TBench_Bolt", (110, 112, 118), (150, 152, 158), rough=0.4, metallic=1.0)
    plate = pk.metal("TBench_Alu", (150, 154, 160), (190, 194, 200), rough=0.35, metallic=1.0)
    curve = spline([(-0.9, 1.47), (-0.84, 1.56), (-0.7, 1.6), (0.3, 1.55), (0.52, 1.64), (0.64, 2.0), (0.78, 2.7), (0.9, 3.3)], 3)
    under = [(y + 0.03 * (1 if k < 12 else 0.6), z - 0.055) for k, (y, z) in enumerate(curve)]
    shape = under + curve[::-1]
    parts = [sk.wedge("Sheet", shape, 5.76, 0.0, sheet, bevel=0.008)]
    for x in (-2.5, 0.0, 2.5):
        side = [(-0.58, 0.14), (-0.3, 0.14), (-0.26, 1.2), (0.3, 1.2), (0.42, 0.14), (0.7, 0.14), (0.56, 1.24), (0.7, 1.78), (0.84, 2.7),
                (0.74, 2.7), (0.56, 1.8), (0.42, 1.52), (-0.62, 1.54), (-0.68, 1.42)]
        parts.append(sk.wedge("Frame", side, 0.14, x, frame, bevel=0.012))
        parts.append(pk.rounded("Pad", (0.44, 1.56, 0.14), (x, 0.06, 0.07), concrete, r=0.03))
        anchors = [(x + sx * 0.12, 0.06 + sy * 0.56, 0.14) for sx in (-1, 1) for sy in (-1, 1)]
        parts.append(studs("Anchor", anchors, 0.04, 0.016, bolt))
    # The arm in the middle, and the ward's little plate on the back.
    arm = sk.wedge("Arm", [(-0.68, 1.56), (-0.58, 2.1), (-0.38, 2.26), (0.4, 2.26), (0.56, 2.14), (0.5, 1.9), (-0.32, 2.08), (-0.46, 1.58)], 0.12,
                   0.0, frame, bevel=0.012)
    parts.append(arm)
    parts.append(mk.box("WardPlate", (0.5, 0.012, 0.16), (1.3, 0.9, 2.84), rot=(-11, 0, 0), mat=plate, bevel=0.003))
    return parts, []


@prop("BoothSofa", pivot="bottom", material="Leather", collide=True, texture=1024, set="Tokyo", exact=True)
def booth_sofa():
    """A kissaten's booth seat: a tall back of channel tufted teal vinyl, a long sprung seat with a rolled front and its
    piping, black laminate ends edged in chrome, a chrome kick strip along the bottom."""
    vinyl = mk.noisy("Booth_Leather", srgb(14, 50, 54), srgb(40, 100, 100), roughness=0.3)
    pipe = mk.noisy("BoothPipe_Leather", srgb(8, 26, 30), srgb(22, 58, 60), roughness=0.4)
    laminate = mk.noisy("Booth_Plastic", srgb(16, 16, 18), srgb(36, 36, 40), roughness=0.3)
    wood = mk.wood("Booth_Wood", srgb(70, 46, 28), srgb(44, 28, 18), roughness=0.45)
    chrome = pk.chrome("Booth_Chrome")
    parts = [mk.box("Base", (6.96, 2.3, 1.26), (0, 0.0, 0.68), mat=wood, bevel=0.02, segments=1),
             mk.box("Kick", (7.0, 0.04, 0.2), (0, -1.17, 0.14), mat=chrome, bevel=0.008, segments=1),
             mk.box("KickBack", (6.96, 0.04, 0.14), (0, -1.14, 0.3), mat=laminate),
             cushion("Seat", (6.94, 2.22, 0.62), (0, -0.14, 1.53), vinyl, e=0.26, segments=28, rings=8),
             bar("SeatPiping", spline([(-3.4, -1.2, 1.74), (-3.42, -1.2, 1.74), (0.0, -1.24, 1.74), (3.42, -1.2, 1.74), (3.4, -1.2, 1.74)], 2),
                 0.024, pipe, sides=4),
             mk.box("BackBoard", (6.96, 0.3, 2.92), (0, 1.2, 1.62), mat=laminate, bevel=0.02, segments=1),
             channels("Back", (-3.46, 0.92, 1.72), (1, 0, 0), (0, 0.06, 1), (0, -1, 0), 6.92, 1.28, 14, vinyl, bulge=0.13, rows=5, per=4),
             roll("BackRoll", 0.13, 6.96, (0, 1.1, 3.0), (0, 90, 0), vinyl, verts=10)]
    for side in (-1, 1):
        x = side * 3.6
        parts.append(mk.box("End", (0.18, 2.84, 2.92), (x, 0.0, 1.5), mat=laminate, bevel=0.02, segments=1))
        trim = [(x, -1.43, 0.03), (x, -1.43, 2.76)] + [(x, -1.43 + 0.2 * (1 - math.cos(a)), 2.76 + 0.2 * math.sin(a))
                                                       for a in (0.4, 0.8, 1.2, 1.57)]
        trim += [mirrored_y(p) for p in reversed(trim)]
        parts.append(bar("EndTrim", trim, 0.06, chrome, sides=6))
    return parts, []


@prop("BambooPot", pivot="bottom", material="Grass", collide=True, texture=512, set="Tokyo", exact=True, ao=0.3)
def bamboo_pot():
    """Black bamboo in a glazed Shigaraki pot on a shop's step: seven jointed canes rising out of raked gravel and a rope
    round the pot's shoulder, sprays of narrow leaves off the upper joints."""
    pot = mk.noisy("BPot_Glaze", srgb(26, 30, 40), srgb(58, 68, 86), roughness=0.2, kind="plastic")
    rope = mk.noisy("BPot_Rope", srgb(116, 96, 62), srgb(160, 138, 96), roughness=0.9)
    soil = mk.noisy("BPot_Stone", srgb(120, 118, 112), srgb(170, 168, 160), roughness=0.85)
    cane = mk.noisy("BPot_Stick", srgb(14, 14, 12), srgb(52, 44, 34), roughness=0.3)
    node = mk.noisy("BPotNode_Stick", srgb(120, 110, 74), srgb(160, 150, 104), roughness=0.5)
    green = mk.noisy("BPot_Leaf", srgb(40, 88, 44), srgb(80, 136, 66), roughness=0.5)
    pale = mk.noisy("BPot_LeafPale", srgb(70, 120, 56), srgb(120, 160, 80), roughness=0.5)
    parts = [mk.lathe("Pot", [(0.0, 0.0), (0.46, 0.0), (0.5, 0.04), (0.56, 0.2), (0.78, 0.74), (0.8, 0.9), (0.72, 1.02), (0.72, 1.12), (0.78, 1.16),
                              (0.74, 1.2), (0.66, 1.2), (0.64, 1.1), (0.0, 1.1)], mat=pot, segments=20),
             bar("Rope", hoop(0.8, 0.92, 22), 0.032, rope, sides=5),
             mk.cylinder("Gravel", 0.66, 0.04, (0, 0, 1.12), mat=soil, verts=18)]
    rng = random.Random(31)
    stems = [(0.0, 0.0, 3.9), (0.3, 0.16, 3.5), (-0.28, 0.2, 3.7), (0.16, -0.32, 3.3), (-0.2, -0.26, 3.05), (0.42, -0.12, 2.8), (-0.42, -0.04, 2.6)]
    for n, (x, y, top) in enumerate(stems):
        lean = (x * 0.35, y * 0.35)
        joints = int((top - 1.12) / 0.34)
        pts = [(x + lean[0] * j / joints, y + lean[1] * j / joints, 1.12 + (top - 1.12) * j / joints) for j in range(joints + 1)]
        parts.append(bar("Cane", pts, [0.06 - 0.03 * j / joints for j in range(joints + 1)], cane, sides=5))
        for j, p in enumerate(pts[1:-1], 1):
            parts.append(mk.torus("Joint", 0.062 - 0.03 * j / joints, 0.012, p, mat=node, major_segments=6, minor_segments=3))
            if j / joints > 0.45:  # (a spray of leaves off the upper joints)
                a0 = rng.uniform(0, 6.28)
                for k in range(3):
                    a = a0 + k * 0.5 + rng.uniform(-0.15, 0.15)
                    out = Vector((math.cos(a), math.sin(a), rng.uniform(-0.15, 0.25)))
                    side = Vector((-math.sin(a), math.cos(a), 0))
                    parts.append(leaf("Leaf", p, out, side, rng.uniform(0.5, 0.72), 0.075, 0.42, pale if k == 1 else green, rows=4))
    return parts, []


# The second batch: what the three maps still shared --------------------------------------------------------


@prop("ChalkBoard", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus", exact=True)
def chalk_board():
    """A lecture room's blackboard on its oak easel: slate in a moulded frame hung between two posts on brass pivots, the
    feet on castors, a ledge with its chalks and felt duster, a proof and a sketched curve left on the board."""
    oak = mk.wood("Chalk_Oak", srgb(112, 78, 46), srgb(72, 48, 28), roughness=0.5)
    slate = mk.noisy("Chalk_Stone", srgb(26, 34, 32), srgb(48, 58, 54), roughness=0.65)
    chalk = mk.noisy("Chalk_Mark", srgb(196, 200, 192), srgb(232, 234, 226), roughness=0.9)
    brass = pk.metal("Chalk_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    felt = mk.flat("Chalk_Felt", srgb(70, 60, 50), 0.9)
    tyre = pk.rubber("Chalk_Tyre")
    cz, wide, tall = 3.8, 5.6, 3.6
    parts = [mk.box("Slate", (wide - 0.1, 0.06, tall - 0.1), (0, 0, cz), mat=slate),
             mk.box("Cross", (6.0, 0.12, 0.14), (0, 0, 0.72), mat=oak, bevel=0.02, segments=1)]
    for z, name in ((cz + tall / 2 - 0.06, "FrameTop"), (cz - tall / 2 + 0.06, "FrameBottom")):
        parts.append(mk.box(name, (wide, 0.12, 0.13), (0, 0, z), mat=oak, bevel=0.02, segments=1))
    for x in (-wide / 2 + 0.06, wide / 2 - 0.06):
        parts.append(mk.box("FrameSide", (0.13, 0.12, tall - 0.2), (x, 0, cz), mat=oak, bevel=0.02, segments=1))
    for side in (-1, 1):
        x = side * 3.05
        parts += [mk.box("Post", (0.17, 0.17, 5.7), (x, 0, 3.05), mat=oak, bevel=0.025, segments=1),
                  sk.wedge("Foot", [(-1.0, 0.2), (1.0, 0.2), (0.86, 0.34), (0.1, 0.42), (-0.1, 0.42), (-0.86, 0.34)], 0.17, x, oak, bevel=0.02),
                  mk.cylinder("Pivot", 0.1, 0.36, (side * 2.92, 0, cz), rot=(0, 90, 0), mat=brass, verts=10),
                  mk.lathe("Finial", [(0.0, 5.9), (0.08, 5.9), (0.1, 5.96), (0.05, 6.04), (0.0, 6.1)], (x, 0, 0), mat=oak, segments=8)]
        for y in (-0.88, 0.88):
            parts.append(mk.soften(mk.cylinder("Castor", 0.1, 0.09, (x, y, 0.1), rot=(0, 90, 0), mat=tyre, verts=10)))
    # The ledge, chalk and duster.
    ledge = cz - tall / 2 - 0.03
    parts.append(mk.box("Ledge", (5.2, 0.34, 0.05), (0, -0.2, ledge), mat=oak, bevel=0.012, segments=1))
    for x, r in ((-1.9, 0), (-1.72, 8), (-1.5, -4), (1.3, 3)):
        parts.append(mk.cylinder("Stick", 0.03, 0.42, (x, -0.2, ledge + 0.055), rot=(0, 90, r), mat=chalk, verts=6))
    parts.append(pk.rounded("Duster", (0.54, 0.22, 0.13), (0.5, -0.2, ledge + 0.09), felt, r=0.03))
    # The proof and the curve (the slate's face is y = -0.03).
    face = -0.036
    for k, (left, right) in enumerate((("f(x)", "ax^2"), ("f'(x)", "2ax"), ("x", "0"))):
        z = cz + 1.0 - k * 0.72
        parts += pk.label("Proof", left, 0.34, (-2.0, face, z), chalk)
        parts += pk.label("Proof", right, 0.34, (-0.3, face, z), chalk)
        # (the equals sign drawn by hand: a thin stroke of a font's is lost in the bake)
        for dz in (-0.05, 0.05):
            parts.append(mk.box("Equals", (0.24, 0.008, 0.045), (-1.3, face, z + dz), mat=chalk))
    curve = [(1.15 + 0.11 * k, face, cz - 0.1 + 0.95 * ((k - 7) / 7) ** 2 - 0.5) for k in range(15)]
    parts.append(bar("Curve", curve, 0.024, chalk, sides=3))
    parts.append(mk.box("AxisX", (1.8, 0.008, 0.04), (1.92, face, cz - 0.62), mat=chalk))
    parts.append(mk.box("AxisY", (0.04, 0.008, 1.5), (1.92, face, cz + 0.05), mat=chalk))
    return parts, []


@prop("BentwoodCoatStand", pivot="bottom", material="Wood", collide=True, texture=256, set="Campus", exact=True)
def bentwood_coat_stand():
    """A bentwood hat and coat stand: a turned column on four sweeping legs, an umbrella ring round its middle, six hooks
    curling out of it at the top and six more below."""
    wood = mk.wood("CStand_Wood", srgb(72, 46, 28), srgb(54, 34, 20), roughness=0.42)
    brass = pk.metal("CStand_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    parts = [turned("Column", [(0.0, 0.0), (0.12, 0.0), (0.1, 0.03), (0.082, 0.45), (0.115, 0.5), (0.078, 0.56), (0.07, 0.94), (0.1, 0.97),
                               (0.04, 1.0), (0.0, 1.0)], (0, 0, 0.4), (0, 0, 6.34), wood, segments=8)]
    for k in range(4):
        a = math.radians(45 + 90 * k)
        c, s = math.cos(a), math.sin(a)
        leg = spline([(0.05 * c, 0.05 * s, 2.0), (0.24 * c, 0.24 * s, 1.5), (0.5 * c, 0.5 * s, 0.8), (0.82 * c, 0.82 * s, 0.22),
                      (0.92 * c, 0.92 * s, 0.05)], 3)
        parts.append(bar("Leg", leg, [0.045 + 0.03 * j / (len(leg) - 1) for j in range(len(leg))], wood, sides=5))
        parts.append(mk.cylinder("Tip", 0.06, 0.05, (0.92 * c, 0.92 * s, 0.025), mat=brass, verts=6))
    parts.append(bar("UmbrellaRing", hoop(0.46, 1.62, 16), 0.024, wood, sides=4))
    for k in range(6):
        a = math.radians(60 * k)
        c, s = math.cos(a), math.sin(a)
        for z, reach in ((5.72, 0.62), (4.92, 0.46)):
            hook = spline([(0.04 * c, 0.04 * s, z + 0.2), (reach * 0.5 * c, reach * 0.5 * s, z + 0.1), (reach * 0.9 * c, reach * 0.9 * s, z - 0.08),
                           (reach * c, reach * s, z + 0.08), (reach * 0.86 * c, reach * 0.86 * s, z + 0.18)], 2)
            parts.append(bar("Hook", hook, 0.034, wood, sides=4))
    return parts, []


def trophy(prefix, x, y, z, h, mat):
    """A two handled cup on its stepped plinth."""
    w = h * 0.3
    base = mk.lathe(prefix + "Cup", [(0.0, 0.0), (w * 0.8, 0.0), (w * 0.8, 0.08), (w * 0.55, 0.12), (w * 0.2, 0.2 * h), (w * 0.12, 0.34 * h),
                                     (w * 0.3, 0.4 * h), (w * 0.72, 0.55 * h), (w, h), (w * 0.9, h), (w * 0.64, 0.56 * h), (0.0, 0.46 * h)],
                    (x, y, z), mat=mat, segments=12)
    parts = [base]
    for side in (-1, 1):
        handle = spline([(x + side * w * 0.72, y, z + 0.56 * h), (x + side * w * 1.3, y, z + 0.62 * h), (x + side * w * 1.3, y, z + 0.88 * h),
                         (x + side * w * 0.96, y, z + 0.92 * h)], 2)
        parts.append(bar(prefix + "Handle", handle, 0.022, mat, sides=4))
    return parts


@prop("OakDisplayCase", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus", exact=True)
def oak_display_case():
    """The university's trophy case: an oak cabinet with panelled doors, an open case on it in brass edging over green baize,
    rowing and kendo cups on their plinths, a row of medals, a lit strip under the top rail. (Open: glass bakes solid.)"""
    oak = mk.wood("OCase_Oak", srgb(120, 84, 50), srgb(76, 50, 30), roughness=0.45)
    panel = mk.wood("OCase_Wood", srgb(100, 68, 40), srgb(62, 40, 24), roughness=0.5)
    baize = mk.noisy("OCase_Felt", srgb(20, 54, 40), srgb(40, 84, 62), roughness=0.9)
    brass = pk.metal("OCase_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    gold = pk.metal("OCase_Gold", (176, 140, 66), (230, 194, 108), rough=0.22, metallic=1.0)
    silver = pk.metal("OCase_Chrome", (150, 154, 160), (214, 218, 224), rough=0.22, metallic=1.0)
    ribbon = mk.flat("OCase_Ribbon", srgb(120, 26, 34), 0.7)
    parts = [pk.rounded("Cabinet", (5.96, 2.3, 2.2), (0, 0, 1.2), panel, r=0.03),
             pk.rounded("Plinth", (6.04, 2.38, 0.14), (0, 0, 0.07), oak, r=0.02),
             pk.rounded("TopBoard", (6.1, 2.46, 0.1), (0, 0, 2.34), oak, r=0.03),
             mk.box("Baize", (5.8, 2.2, 0.04), (0, 0, 2.4), mat=baize)]
    for k in range(4):
        x = -2.2 + k * 1.466
        parts.append(mk.box("Door", (1.34, 0.04, 1.84), (x, -1.16, 1.2), mat=oak, bevel=0.012, segments=1))
        parts.append(mk.box("DoorField", (1.06, 0.03, 1.5), (x, -1.19, 1.2), mat=panel, bevel=0.012, segments=1))
        parts.append(mk.sphere("Knob", 0.05, (x + (0.5 if k % 2 == 0 else -0.5), -1.22, 1.3), mat=brass, segments=6, rings=4))
    for x in (-3.0, 3.0):
        for y in (-1.16, 1.16):
            parts.append(mk.box("Corner", (0.09, 0.09, 1.06), (x, y, 2.93), mat=brass))
    for y in (-1.16, 1.16):
        parts.append(mk.box("Rail", (6.09, 0.09, 0.09), (0, y, 3.47), mat=brass))
    for x in (-3.0, 3.0):
        parts.append(mk.box("Rail", (0.09, 2.23, 0.09), (x, 0, 3.47), mat=brass))
    z = 2.42
    for k, (x, h, mat) in enumerate(((-2.1, 0.86, silver), (-0.9, 0.7, gold), (0.9, 0.96, gold), (2.1, 0.62, silver))):
        parts.append(pk.rounded("Plinth", (0.52, 0.52, 0.12), (x, 0.3, z + 0.06), oak, r=0.015))
        parts += trophy(f"T{k}", x, 0.3, z + 0.12, h, mat)
    for k in range(6):
        x = -1.5 + k * 0.6
        parts.append(mk.box("Ribbon", (0.14, 0.32, 0.012), (x, -0.56, z + 0.006), mat=ribbon))
        parts.append(mk.cylinder("Medal", 0.12, 0.02, (x, -0.8, z + 0.012), mat=gold if k % 3 else silver, verts=10))
    glows = [mk.box("CaseLight", (5.6, 0.14, 0.04), (0, 0.9, 3.4), mat=pk.glow("OCase_Light", (255, 232, 200), 3))]
    return parts, glows


@prop("OakLockers", pivot="bottom", material="Wood", collide=True, texture=512, set="Campus", exact=True, normal=128)
def oak_lockers():
    """The student union's lockers: two tiers of six oak doors in a carcass with its plinth and cornice, each door with three
    louvres, a brass number plate and a latch, padlocks and club notices on some."""
    oak = mk.wood("OLock_Oak", srgb(136, 96, 56), srgb(88, 60, 34), roughness=0.5)
    frame = mk.wood("OLock_Wood", srgb(96, 64, 38), srgb(60, 40, 24), roughness=0.55)
    dark = mk.flat("OLock_Dark", srgb(18, 14, 12), 0.8)
    brass = pk.metal("OLock_Brass", (124, 96, 50), (190, 156, 90), rough=0.32, metallic=1.0)
    steel = pk.metal("OLock_Steel", (110, 112, 118), (160, 162, 168), rough=0.35, metallic=1.0)
    paper = mk.noisy("OLock_Paper", srgb(200, 194, 176), srgb(232, 226, 208), roughness=0.9)
    print_ = mk.flat("OLock_Print", srgb(44, 44, 50), 0.8)
    rng = random.Random(12)
    front = -1.2
    parts = [mk.box("Carcass", (5.86, 2.46, 6.3), (0, 0.05, 3.4), mat=frame),
             pk.rounded("Plinth", (5.96, 2.56, 0.26), (0, 0.05, 0.13), oak, r=0.02),
             pk.rounded("Cornice", (6.0, 2.6, 0.2), (0, 0.0, 6.7), oak, r=0.03),
             mk.box("Band", (5.92, 2.52, 0.08), (0, 0.03, 6.57), mat=frame, bevel=0.015, segments=1)]
    wide, tall = 0.9, 3.04
    number = 1
    for row in range(2):
        z = 0.32 + (tall + 0.06) * (row + 0.5)
        for col in range(6):
            x = -2.4 + col * 0.96
            parts.append(mk.box("Door", (wide, 0.05, tall), (x, front - 0.025, z), mat=oak, bevel=0.014, segments=1))
            for k in range(3):
                parts.append(mk.box("Louvre", (wide * 0.62, 0.012, 0.05), (x, front - 0.054, z + tall * 0.34 - k * 0.11), mat=dark))
            parts.append(mk.box("NumberPlate", (0.3, 0.014, 0.16), (x, front - 0.056, z - tall * 0.06), mat=brass, bevel=0.004))
            parts += pk.label("Number", str(number), 0.09, (x, front - 0.066, z - tall * 0.06), dark)
            parts.append(mk.box("Latch", (0.1, 0.05, 0.3), (x + wide * 0.34, front - 0.07, z - tall * 0.18), mat=steel, bevel=0.01, segments=1))
            if rng.random() < 0.3:
                parts.append(pk.rounded("Padlock", (0.13, 0.05, 0.15), (x + wide * 0.34, front - 0.115, z - tall * 0.27), brass, r=0.018))
            if rng.random() < 0.35:
                nx, nz = x - wide * 0.1, z - tall * 0.27
                parts.append(mk.box("Notice", (0.42, 0.006, 0.56), (nx, front - 0.054, nz), rot=(0, rng.uniform(-5, 5), 0), mat=paper))
                parts.append(mk.box("NoticeLine", (0.3, 0.004, 0.05), (nx, front - 0.059, nz + 0.16), mat=print_))
            number += 1
    return parts, []


@prop("StaffLockers", pivot="bottom", material="Metal", collide=True, texture=512, set="Agency", exact=True, normal=128)
def staff_lockers():
    """The Bureau's changing room lockers: five full height doors in gunmetal steel with a sloped top that sheds dust, slotted
    vents top and bottom, a keypad lock, a recessed pull and a typed name card."""
    body = pk.metal("SLock_Steel", (44, 48, 54), (72, 76, 84), rough=0.42, metallic=0.6)
    door = pk.metal("SLockDoor_Steel", (54, 58, 66), (84, 88, 96), rough=0.4, metallic=0.6)
    vent = lattice("SLock_Vent", (54, 58, 66), (8, 8, 10), 0.09, _axis("X"), _axis("Z"), share=0.36, roughness=0.45, metallic=0.5, square=True)
    pad = lattice("SLock_Keys", (20, 21, 24), (150, 152, 158), 0.09, _axis("X"), _axis("Z"), share=0.34, roughness=0.5, square=True)
    dark = pk.metal("SLock_Iron", (14, 14, 16), (34, 34, 38), rough=0.55, metallic=0.6)
    bright = pk.metal("SLock_Chrome", (126, 130, 134), (176, 180, 184), rough=0.3, metallic=1.0)
    card = mk.noisy("SLock_Card", srgb(214, 208, 190), srgb(238, 232, 214), roughness=0.9)
    typed = mk.flat("SLock_Print", srgb(26, 26, 30), 0.8)
    front = -1.26
    parts = [mk.box("Carcass", (5.9, 2.5, 6.1), (0, 0.04, 3.45), mat=body),
             mk.box("Kick", (5.8, 2.4, 0.4), (0, 0.06, 0.2), mat=dark),
             sk.wedge("SlopeTop", [(-1.3, 6.5), (1.32, 6.5), (1.32, 6.8), (-1.3, 6.54)], 6.0, 0.0, body, bevel=0.012)]
    wide = 1.12
    for k in range(5):
        x = -2.36 + k * 1.18
        parts += [mk.box("Door", (wide, 0.05, 5.96), (x, front - 0.025, 3.45), mat=door, bevel=0.014, segments=1),
                  mk.box("VentTop", (0.64, 0.01, 0.46), (x, front - 0.054, 5.9), mat=vent),
                  mk.box("VentLow", (0.64, 0.01, 0.46), (x, front - 0.054, 1.0), mat=vent),
                  mk.box("PullShadow", (0.2, 0.01, 0.62), (x + 0.36, front - 0.054, 3.3), mat=dark),
                  mk.box("PullLip", (0.26, 0.05, 0.05), (x + 0.36, front - 0.075, 3.6), mat=bright, bevel=0.012, segments=1),
                  mk.box("KeyPlate", (0.3, 0.04, 0.4), (x + 0.36, front - 0.07, 4.14), mat=dark, bevel=0.01, segments=1),
                  mk.box("Keys", (0.2, 0.008, 0.27), (x + 0.36, front - 0.092, 4.14), mat=pad)]
        parts += card_frame("Name", x, front - 0.05, 4.86, bright, card, w=0.62, h=0.2)
        parts.append(mk.box("Typed", (0.36, 0.005, 0.04), (x, front - 0.063, 4.86), mat=typed))
    return parts, []


@prop("EvidenceCrate", pivot="bottom", material="Plastic", collide=True, texture=512, set="Agency", exact=True, normal=128)
def evidence_crate():
    """A sealed evidence transit case on its pallet: a ribbed black case with steel corners, butterfly latches, carry handles,
    a stencilled lid, the case label and a red numbered tamper strap across the front."""
    case = mk.noisy("ECase_Plastic", srgb(16, 17, 19), srgb(40, 42, 46), roughness=0.45)
    steel = pk.metal("ECase_Steel", (110, 112, 118), (160, 162, 168), rough=0.35, metallic=1.0)
    pine = mk.wood("ECase_Wood", srgb(140, 108, 70), srgb(96, 70, 44), roughness=0.75)
    white = mk.flat("ECaseStencil_Plastic", srgb(214, 212, 204), 0.6)
    red = mk.flat("ECaseSeal_Plastic", srgb(160, 24, 30), 0.4)
    label = mk.noisy("ECase_Label", srgb(214, 208, 190), srgb(238, 232, 214), roughness=0.9)
    typed = mk.flat("ECase_Print", srgb(26, 26, 30), 0.8)
    parts = []
    # The pallet.
    for x in (-1.72, 0.0, 1.72):
        parts.append(mk.box("Runner", (0.42, 3.98, 0.26), (x, 0, 0.13), mat=pine, bevel=0.012, segments=1))
    for k in range(6):
        parts.append(mk.box("Deck", (4.04, 0.56, 0.08), (0, -1.71 + k * 0.684, 0.3), mat=pine, bevel=0.012, segments=1))
    # The case and its lid.
    parts += [pk.rounded("Body", (3.72, 3.72, 2.8), (0, 0, 1.75), case, r=0.1),
              pk.rounded("Lid", (3.8, 3.8, 0.84), (0, 0, 3.5), case, r=0.12)]
    for k in range(5):  # (ribs moulded round the body)
        x = -1.5 + k * 0.75
        parts.append(mk.box("RibFront", (0.14, 0.06, 2.4), (x, -1.87, 1.75), mat=case, bevel=0.02, segments=1))
        parts.append(mk.box("RibBack", (0.14, 0.06, 2.4), (x, 1.87, 1.75), mat=case, bevel=0.02, segments=1))
        parts.append(mk.box("RibSide", (0.06, 0.14, 2.4), (-1.87, x, 1.75), mat=case, bevel=0.02, segments=1))
        parts.append(mk.box("RibSide", (0.06, 0.14, 2.4), (1.87, x, 1.75), mat=case, bevel=0.02, segments=1))
    for sx in (-1, 1):
        for sy in (-1, 1):
            for z in (0.5, 3.79):
                parts.append(pk.rounded("Corner", (0.36, 0.36, 0.42), (sx * 1.84, sy * 1.84, z), steel, r=0.05))
    # The latches, the handles, the seal and the label.
    for x in (-1.1, 1.1):
        parts += [mk.box("LatchPlate", (0.42, 0.04, 0.5), (x, -1.92, 3.13), mat=steel, bevel=0.012, segments=1),
                  mk.cylinder("Butterfly", 0.13, 0.05, (x, -1.96, 3.19), rot=(90, 0, 0), mat=steel, verts=8)]
    for side in (-1, 1):
        parts.append(bar("Handle", spline([(side * 1.94, -0.5, 2.3), (side * 2.01, -0.4, 2.16), (side * 2.01, 0.4, 2.16), (side * 1.94, 0.5, 2.3)], 2),
                         0.04, steel, sides=5))
    parts += [mk.box("SealStrap", (0.1, 0.012, 1.0), (0, -1.915, 3.01), mat=red),
              mk.box("SealTag", (0.32, 0.016, 0.2), (0, -1.925, 2.49), mat=red, bevel=0.004),
              mk.box("CaseLabel", (1.1, 0.012, 0.66), (-0.9, -1.907, 1.5), mat=label),
              mk.box("LabelLine", (0.8, 0.004, 0.06), (-0.9, -1.915, 1.66), mat=typed),
              mk.box("LabelLine", (0.6, 0.004, 0.06), (-1.0, -1.915, 1.5), mat=typed),
              mk.box("LabelLine", (0.7, 0.004, 0.06), (-0.95, -1.915, 1.34), mat=typed)]
    parts += pk.label("Stencil", "EVIDENCE", 0.36, (0.0, 0.0, 3.925), white, rot=(0, 0, 0))
    return parts, []


@prop("MarketCrate", pivot="bottom", material="WoodPlanks", collide=True, texture=512, set="Tokyo", exact=True, normal=128)
def market_crate():
    """Two slatted wooden produce crates stacked at a Tokyo shop front, corner posts, end boards with a stencilled grower's mark,
    the top one heaped with mikan on green paper."""
    pine = mk.wood("MCrate_Wood", srgb(170, 134, 88), srgb(118, 86, 52), roughness=0.75)
    post = mk.wood("MCrate_Oak", srgb(142, 106, 66), srgb(96, 68, 40), roughness=0.75)
    dark = mk.flat("MCrate_Dark", srgb(22, 18, 14), 0.9)
    paper = mk.noisy("MCrate_Paper", srgb(44, 110, 70), srgb(70, 140, 92), roughness=0.8)
    stencil = mk.flat("MCrate_Print", srgb(150, 36, 30), 0.8)
    mikan = mk.noisy("MCrate_Fruit", srgb(226, 120, 24), srgb(246, 158, 44), roughness=0.5, kind="plastic")
    stalk = mk.flat("MCrate_Stem", srgb(50, 70, 30), 0.7)
    parts = []

    def crate(z0, tall, prefix):
        half = 1.95
        out = [mk.box(prefix + "Inside", (3.74, 3.74, tall - 0.16), (0, 0, z0 + tall / 2), mat=dark)]
        for sx in (-1, 1):
            for sy in (-1, 1):
                out.append(mk.box(prefix + "Post", (0.22, 0.22, tall), (sx * (half - 0.11), sy * (half - 0.11), z0 + tall / 2), mat=post, bevel=0.015, segments=1))
        rows = 3
        board = (tall - 0.1) / rows - 0.06
        for k in range(rows):
            z = z0 + 0.1 + (board + 0.06) * (k + 0.5)
            for sy in (-1, 1):
                out.append(mk.box(prefix + "Slat", (3.5, 0.06, board), (0, sy * (half - 0.03), z), mat=pine, bevel=0.012, segments=1))
            for sx in (-1, 1):
                out.append(mk.box(prefix + "Slat", (0.06, 3.5, board), (sx * (half - 0.03), 0, z), mat=pine, bevel=0.012, segments=1))
        return out

    parts += crate(0.0, 1.9, "Low")
    parts += crate(1.92, 1.76, "High")
    parts.append(mk.box("Base", (3.8, 3.8, 0.06), (0, 0, 0.03), mat=pine))
    parts += pk.label("Mark", "MIKAN", 0.3, (0.0, -1.992, 0.95), stencil)
    parts.append(mk.box("Lining", (3.6, 3.6, 0.04), (0, 0, 3.4), mat=paper))
    rng = random.Random(8)
    for layer, (count, spread, z) in enumerate(((24, 1.6, 3.56), (14, 1.2, 3.72))):
        for k in range(count):
            x, y = rng.uniform(-spread, spread), rng.uniform(-spread, spread)
            r = rng.uniform(0.24, 0.29)
            fruit = mk.sphere("Mikan", r, (x, y, min(3.8, z)), scale=(1, 1, 0.84), mat=mikan, segments=7, rings=4)
            parts.append(mk.soften(fruit))
            if k % 3 == 0:
                parts.append(mk.cylinder("Stem", 0.03, 0.03, (x, y, min(3.8, z) + r * 0.84), mat=stalk, verts=5))
    return parts, []
