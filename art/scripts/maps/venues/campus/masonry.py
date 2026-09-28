"""The campus's building kit: the old brick faculties (the map kit's walls have rectangular
openings only, and its roofs are gables and pyramids).

- `shell()` builds a building's four outer walls. Each window and door opening is rectangular
  (so is its collider) with an arch drawn into its head: brick spandrels fill the rectangle's
  top corners on both faces, and stone voussoirs ring the arch outside. The kit's window
  frame, glass and sill do the rest.
- Upper storeys are look-only: their windows are lit or dark panes.
- Stone plinth and cornice mouldings; buttresses.
- Roofs lie under snow: gable, hip and flat. Each has a flat collider at the eaves, so the
  falling snow stops indoors and the camera never enters the attic.
- The clock tower: its faces lit, its hands left to the game (`s.clock` markers).
- The arcade along Law & Letters.
- The red gate, the guard booth and the 1960s concrete club house.

Walls run so their "n" side is outside (see face_line)."""

import math
import random

from maps import city, kit
from maps import geo2d as g2
from maps.venues.campus import fit
from maps.venues.campus import plan as P

T = P.WALL_T
STONE = "Stone"
SNOW = "Snow"


def face_line(r, face):
    """The centre line (a, b) of a building's outer wall on one face ("n", "e", "s", "w"), running
    so that the wall's "n" side is outside: the north and south walls span the full width, the
    east and west ones fit between them."""
    x0, z0, x1, z1 = r
    h = T / 2
    if face == "n":
        return (x0, z0 + h), (x1, z0 + h)
    if face == "s":
        return (x1, z1 - h), (x0, z1 - h)
    if face == "e":
        return (x1 - h, z0 + T), (x1 - h, z1 - T)
    return (x0 + h, z1 - T), (x0 + h, z0 + T)


def along(r, face, c):
    """How far along face_line(r, face) lies the point whose x (north, south faces) or z (east,
    west faces) is c."""
    a, _ = face_line(r, face)
    if face == "n":
        return c - a[0]
    if face == "s":
        return a[0] - c
    if face == "e":
        return c - a[1]
    return a[1] - c


def spaced(length, avoid, width=4.0, spacing=9.0, margin=5.0, gap=2.5):
    """Window positions along a wall of `length`, clear of the openings avoid [(at, w)]."""
    spots = []
    count = int((length - margin * 2) // spacing) + 1
    if count < 1:
        return spots
    start = (length - (count - 1) * spacing) / 2
    for i in range(count):
        at = start + i * spacing
        if all(abs(at - a_at) > a_w / 2 + width / 2 + gap for a_at, a_w in avoid):
            spots.append(at)
    return spots


# Arched heads ---------------------------------------------------------------------------------------------


def arch_curve(hw, rise, steps=6):
    """The right half of an arch over a span 2*hw wide rising `rise` (a pointed two-centred arch,
    or a semicircle when rise == hw): points (u, y) from the springing (hw, 0) up to the apex
    (0, rise)."""
    e = (rise * rise - hw * hw) / (2 * hw)
    rr = hw + e
    top = math.acos(max(-1.0, min(1.0, e / rr)))
    return [(-e + rr * math.cos(top * k / steps), rr * math.sin(top * k / steps)) for k in range(steps + 1)], (-e, rr)


def _world(a, t, n, u, y, out):
    """A point u along a wall (t, n: the map kit's 3D wall axes) at height y, `out` off its line."""
    return (a[0] + t[0] * u + n[0] * out, y, a[1] + t[2] * u + n[2] * out)


def _face(s, mat, pts, normal):
    """A flat polygon facing `normal` (x, z)."""
    p0, p1, p2 = pts[0], pts[1], pts[2]
    ux, uy, uz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
    vx, vy, vz = p2[0] - p0[0], p2[1] - p0[1], p2[2] - p0[2]
    nx, nz = uy * vz - uz * vy, ux * vy - uy * vx
    if nx * normal[0] + nz * normal[1] < 0:
        pts = list(reversed(pts))
    s.polygon(mat, pts)


def arch_head(s, a, t, n, thick, u, w, top, rise, outer, inner, stone=STONE, ring=0.55):
    """Turns the top of a rectangular opening (centred u along the wall, w wide, its top at
    top) into an arch springing at top - rise: brick spandrels in the corners on both faces and
    a ring of stone voussoirs outside."""
    hw = w / 2
    curve, (cu, _) = arch_curve(hw, rise)
    spring = top - rise
    for side, mat, off in ((1, outer, thick / 2 + 0.03), (-1, inner, -(thick / 2 + 0.03))):
        normal = (n[0] * side, n[2] * side)
        for sign in (1, -1):
            corner = _world(a, t, n, u + sign * hw, top, off)
            arc = [_world(a, t, n, u + sign * cu_, spring + cy, off) for cu_, cy in curve]
            _face(s, mat, [corner] + arc, normal)
    # The voussoirs: a band round the arch on the outside face.
    for sign in (1, -1):
        for k in range(len(curve) - 1):
            (u0, y0), (u1, y1) = curve[k], curve[k + 1]
            cx, cy = cu, 0.0
            # Outward from the arc's own centre (mirrored for the left half).
            d0 = math.hypot(u0 - cx, y0 - cy) or 1.0
            d1 = math.hypot(u1 - cx, y1 - cy) or 1.0
            o0 = (u0 + (u0 - cx) / d0 * ring, y0 + (y0 - cy) / d0 * ring)
            o1 = (u1 + (u1 - cx) / d1 * ring, y1 + (y1 - cy) / d1 * ring)
            quad = [(u0, y0), (u1, y1), o1, o0]
            pts = [_world(a, t, n, u + sign * qu, spring + qy, thick / 2 + 0.07) for qu, qy in quad]
            _face(s, stone, pts, (n[0], n[2]))


# The outer walls -----------------------------------------------------------------------------------------


def shell(s, r, eaves, doors, *, brick="BrickRed", inside="PlasterLight", storeys=None, arch="pointed",
          ground_windows=("n", "e", "s", "w"), upper_windows=("n", "e", "s", "w"), window_w=3.6, spacing=9.0,
          door_top=fit.DOOR_H, lit=0.4, seed=1, skip=(), gaps=None, plinth=True, cornice=True, faces=None,
          avoid=None, pane=None, trim=STONE, see_through=False):
    """A building's outer walls from the ground to its eaves.
    - doors: [(face, centre x or z, width)] (the plan's DOORS).
    - storeys: floor heights, the ground floor first (default: 0, then P.GF, then every P.UP).
    - Ground-floor windows show the rooms behind them in clear glass. Those on the storeys above
      are lit or dark panes (look-only).
    - skip: faces not built (another wall stands there).
    - gaps: {face: [(u0, u1)]} spans left open (where another building joins on).
    - faces: which walls to build (all four by default).
    - door_top: where the doors' arches spring (their openings rise an arch higher).
    - arch: "pointed", "round" or None (plain rectangular openings, as on the 1960s blocks).
    - avoid: {face: [(centre along the wall, width)]} kept clear of windows (where the tower
      stands against a face).
    - pane(face, u, level): the glass for an upper window instead of a lit or dark pane (the
      reading room's tall windows), or None.
    - trim: the frames, sills and mouldings ("Stone"; "ConcreteDark" on concrete).
    - see_through: the ground floor's windows let sight lines (a letter flash) through."""
    rng = random.Random(seed)
    storeys = storeys or [0.0] + [P.GF + P.UP * k for k in range(int((eaves - P.GF) // P.UP))]
    for face in faces or ("n", "e", "s", "w"):
        if face in skip:
            continue
        a, b = face_line(r, face)
        # A side wall runs on to the corner where the front or back wall is left out.
        lead = 0.0
        if face == "e" and "n" in skip:
            a, lead = (a[0], r[1]), T
        if face == "w" and "s" in skip:
            a, lead = (a[0], r[3]), T
        if face == "e" and "s" in skip:
            b = (b[0], r[3])
        if face == "w" and "n" in skip:
            b = (b[0], r[1])
        length, t, n, rot = kit.wall_frame(a, b)
        ops, arches = [], []
        door_spans = []
        for f, c, w in doors:
            if f != face:
                continue
            at = along(r, face, c) + lead
            rise = 0.0 if arch is None else (w / 2 if arch == "round" else w * 0.6)
            ops.append({"at": at, "w": w, "bottom": 0.0, "top": door_top + rise, "kind": "door", "frame": trim,
                        "casing": 0.5})
            if rise:
                arches.append((at, w, door_top + rise, rise))
            door_spans.append((at, w))
        door_spans += (avoid or {}).get(face, [])
        for u0, u1 in (gaps or {}).get(face, []):
            ops.append({"at": (u0 + u1) / 2, "w": u1 - u0, "bottom": 0.0, "top": eaves, "kind": "gap"})
            door_spans.append(((u0 + u1) / 2, u1 - u0 + 4))
        for level_i, y in enumerate(storeys):
            ground = level_i == 0
            if (face not in ground_windows) if ground else (face not in upper_windows):
                continue
            height = (storeys[level_i + 1] if level_i + 1 < len(storeys) else eaves) - y
            sill = y + (3.4 if ground else 2.6)
            head = y + height - (3.4 if ground else 2.4)
            if head - sill < 3:
                continue
            rise = 0.0 if arch is None else (window_w / 2 if arch == "round" else window_w * 0.6)
            for at in spaced(length, door_spans, window_w, spacing):
                glass = pane(face, at, level_i) if (pane and not ground) else None
                if glass is None and ground:
                    glass = "Glass"
                elif glass is None:
                    roll = rng.random()
                    glass = "WindowLit" if roll < lit else ("WindowCool" if roll < lit + 0.12 else "WindowDark")
                ops.append({"at": at, "w": window_w, "bottom": sill, "top": head, "kind": "window", "frame": trim,
                            "mullions": "BlackMetal", "cols": 2 if window_w < 5 else 3, "rows": 3, "glass": glass,
                            "sill": trim, "casing": 0.35, "see_through": see_through and ground})
                if rise:
                    arches.append((at, window_w, head, rise))
        kit.wall(s, a, b, eaves, thick=T, core=brick, side_n=brick, side_s=inside, openings=ops,
                 trim_s={"base": "BlackTrim"})
        for at, w, top, rise in arches:
            arch_head(s, a, t, n, T, at, w, top, rise, brick, inside)
        if plinth:
            cursor = 0.0
            profile = [(o + T / 2, y) for o, y in ((0, 0), (0.35, 0), (0.35, 1.3), (0.1, 1.6), (0, 1.7))]
            doorways = [(at, w) for f, c, w in doors if f == face for at in (along(r, face, c),)]
            for at, w in sorted(doorways) + [(length + 10, 0)]:
                end = min(length, at - w / 2 - 0.5)
                if end - cursor > 0.1:
                    s.sweep(trim, kit.point_on(a, t, cursor), kit.point_on(a, t, end), profile, n)
                cursor = at + w / 2 + 0.5
        if cornice:
            s.sweep(trim, kit.point_on(a, t, 0.0, 0.0), kit.point_on(a, t, length, 0.0),
                    [(o + T / 2, y) for o, y in ((0, eaves - 1.4), (0.2, eaves - 1.2), (0.5, eaves - 0.5),
                                                  (0.5, eaves), (0, eaves))], n)
            # Snow along the cornice's top.
            mid = kit.point_on(a, t, length / 2)
            s.box(SNOW, (mid[0] + n[0] * (T / 2 + 0.28), eaves + 0.08, mid[2] + n[2] * (T / 2 + 0.28)),
                  (length, 0.16, 0.5), rot, skip=("-y",))
        # Band courses between the storeys.
        mid = kit.point_on(a, t, length / 2)
        for y in storeys[1:]:
            s.box(trim, (mid[0] + n[0] * (T / 2 + 0.1), y + 0.3, mid[2] + n[2] * (T / 2 + 0.1)), (length, 0.6, 0.3),
                  rot)


def buttress(s, x, z, face_dir, h, w=1.6, depth=1.6, mat="BrickRed"):
    """A buttress against a wall at (x, z) (on the wall's outer face), sticking out along face_dir
    (x, z), h tall with a sloped stone top and a stone base."""
    rot = g2.rot_of((face_dir[1], -face_dir[0]))
    cx, cz = x + face_dir[0] * depth / 2, z + face_dir[1] * depth / 2
    s.box(mat, (cx, h / 2, cz), (w, h, depth), rot, collide=True)
    s.box(STONE, (cx, 0.8, cz), (w + 0.3, 1.6, depth + 0.3), rot)
    top = [(x + face_dir[0] * depth + dx, h, z + face_dir[1] * depth + dz) for dx, dz in
           (((face_dir[1]) * w / 2, (-face_dir[0]) * w / 2), ((-face_dir[1]) * w / 2, (face_dir[0]) * w / 2))]
    back = [(x + dx, h + depth * 0.8, z + dz) for dx, dz in
            (((-face_dir[1]) * w / 2, (face_dir[0]) * w / 2), ((face_dir[1]) * w / 2, (-face_dir[0]) * w / 2))]
    _face(s, STONE, [top[0], top[1], back[0], back[1]], face_dir)
    s.polygon(SNOW, [(p[0], p[1] + 0.12, p[2]) for p in (top[1], top[0], back[1], back[0])])


# Roofs -------------------------------------------------------------------------------------------------------


def roof_collider(s, r, eaves):
    x0, z0, x1, z1 = r
    s.collider(((x0 + x1) / 2, eaves + 0.5, (z0 + z1) / 2), (x1 - x0, 1.0, z1 - z0), 0, True, None)


def _plane(s, pts, top_mat=SNOW, under="Slate", lift=0.35):
    """A roof plane: its snowy top face, and its underside (seen under the eaves) just below."""
    s.polygon(top_mat, pts)
    s.polygon(under, [(x, y - lift, z) for x, y, z in reversed(pts)])


def gable_roof(s, r, eaves, rise, gable="BrickRed", overhang=1.3, along_x=None):
    """A pitched roof under snow over rectangle r (walls up to eaves), its ridge along the longer
    side (or along x when along_x), gable ends filled in the wall's material."""
    x0, z0, x1, z1 = r
    if along_x is None:
        along_x = (x1 - x0) >= (z1 - z0)
    drop = overhang * rise / (((z1 - z0) if along_x else (x1 - x0)) / 2)
    if along_x:
        zm = (z0 + z1) / 2
        ridge = [(x0 - overhang, eaves + rise, zm), (x1 + overhang, eaves + rise, zm)]
        north = [(x0 - overhang, eaves - drop, z0 - overhang), (x1 + overhang, eaves - drop, z0 - overhang)]
        south = [(x1 + overhang, eaves - drop, z1 + overhang), (x0 - overhang, eaves - drop, z1 + overhang)]
        _plane(s, [north[0], ridge[0], ridge[1], north[1]])
        _plane(s, [south[0], ridge[1], ridge[0], south[1]])
        for x, out in ((x0, (-1, 0)), (x1, (1, 0))):
            city_tri = [(x, eaves, z0), (x, eaves, z1), (x, eaves + rise - 0.3, zm)]
            _face(s, gable, city_tri, out)
            out3 = (out[0], 0.0, out[1])
            s.sweep(STONE, (x, eaves, z0), (x, eaves + rise, zm), [(0, 0), (0.4, 0), (0.4, 0.5), (0, 0.5)], out3,
                    caps=True)
            s.sweep(STONE, (x, eaves + rise, zm), (x, eaves, z1), [(0, 0), (0.4, 0), (0.4, 0.5), (0, 0.5)], out3,
                    caps=True)
        s.tube(STONE, ridge[0], ridge[1], 0.3, 6)
        s.tube(SNOW, (ridge[0][0], ridge[0][1] + 0.3, zm), (ridge[1][0], ridge[1][1] + 0.3, zm), 0.28, 5)
    else:
        xm = (x0 + x1) / 2
        ridge = [(xm, eaves + rise, z0 - overhang), (xm, eaves + rise, z1 + overhang)]
        west = [(x0 - overhang, eaves - drop, z1 + overhang), (x0 - overhang, eaves - drop, z0 - overhang)]
        east = [(x1 + overhang, eaves - drop, z0 - overhang), (x1 + overhang, eaves - drop, z1 + overhang)]
        _plane(s, [west[0], ridge[1], ridge[0], west[1]])
        _plane(s, [east[0], ridge[0], ridge[1], east[1]])
        for z, out in ((z0, (0, -1)), (z1, (0, 1))):
            _face(s, gable, [(x0, eaves, z), (x1, eaves, z), (xm, eaves + rise - 0.3, z)], out)
        s.tube(STONE, ridge[0], ridge[1], 0.3, 6)
        s.tube(SNOW, (xm, ridge[0][1] + 0.3, ridge[0][2]), (xm, ridge[1][1] + 0.3, ridge[1][2]), 0.28, 5)
    roof_collider(s, r, eaves)


def hip_roof(s, r, eaves, rise, overhang=1.3):
    """A hipped roof under snow over rectangle r: two trapezoids and two triangles."""
    x0, z0, x1, z1 = r
    ex0, ez0, ex1, ez1 = x0 - overhang, z0 - overhang, x1 + overhang, z1 + overhang
    w, d = ex1 - ex0, ez1 - ez0
    drop = overhang * rise / (min(x1 - x0, z1 - z0) / 2)
    y0 = eaves - drop
    y1 = eaves + rise
    nw, ne, se, sw = (ex0, y0, ez0), (ex1, y0, ez0), (ex1, y0, ez1), (ex0, y0, ez1)
    if w >= d:
        zm = (ez0 + ez1) / 2
        rw, re_ = (ex0 + d / 2, y1, zm), (ex1 - d / 2, y1, zm)
        _plane(s, [nw, rw, re_, ne])
        _plane(s, [se, re_, rw, sw])
        _plane(s, [sw, rw, nw])
        _plane(s, [ne, re_, se])
        s.tube(SNOW, (rw[0], y1 + 0.2, zm), (re_[0], y1 + 0.2, zm), 0.3, 5)
    else:
        xm = (ex0 + ex1) / 2
        rn, rs = (xm, y1, ez0 + w / 2), (xm, y1, ez1 - w / 2)
        _plane(s, [sw, rs, rn, nw])
        _plane(s, [ne, rn, rs, se])
        _plane(s, [nw, rn, ne])
        _plane(s, [se, rs, sw])
        s.tube(SNOW, (xm, y1 + 0.2, rn[2]), (xm, y1 + 0.2, rs[2]), 0.3, 5)
    # The fascia round the eaves.
    for (a, b) in ((nw, ne), (ne, se), (se, sw), (sw, nw)):
        length = math.dist((a[0], a[2]), (b[0], b[2]))
        mid = ((a[0] + b[0]) / 2, y0 - 0.25, (a[2] + b[2]) / 2)
        s.box("Slate", mid, (length, 0.5, 0.3), g2.rot_of(((b[0] - a[0]) / length, (b[2] - a[2]) / length)))
    roof_collider(s, r, eaves)


def flat_roof(s, r, eaves, parapet=1.4, mat="ConcreteDark"):
    """A flat roof under snow inside a parapet, with a roof plant box or two."""
    x0, z0, x1, z1 = r
    city.up_face(s, SNOW, P.box(x0 + 0.4, z0 + 0.4, x1 - 0.4, z1 - 0.4), eaves + 0.15)
    for a, b, out in (((x0, z0), (x1, z0), (0, -1)), ((x1, z0), (x1, z1), (1, 0)), ((x1, z1), (x0, z1), (0, 1)),
                      ((x0, z1), (x0, z0), (-1, 0))):
        length = math.dist(a, b)
        mid = ((a[0] + b[0]) / 2 - out[0] * 0.2, (a[1] + b[1]) / 2 - out[1] * 0.2)
        rot = g2.rot_of(((b[0] - a[0]) / length, (b[1] - a[1]) / length))
        s.box(mat, (mid[0], eaves + parapet / 2, mid[1]), (length, parapet, 0.4), rot)
        s.box(SNOW, (mid[0], eaves + parapet + 0.08, mid[1]), (length, 0.16, 0.5), rot, skip=("-y",))
    roof_collider(s, r, eaves)


# The clock tower -------------------------------------------------------------------------------------------


def clock_face(s, cx, cy, cz, rot, radius):
    """A lit clock face on a tower's face (centre (cx, cy, cz), facing rot): the glowing dial in
    a stone ring with its hour marks. The hands are the game's (s.clock)."""
    turn = kit.ry(rot)
    n = turn((0, 0, -1))
    side = turn((1, 0, 0))
    ring = [(cx + side[0] * math.cos(a) * radius + n[0] * 0.05, cy + math.sin(a) * radius,
             cz + side[2] * math.cos(a) * radius + n[2] * 0.05) for a in (2 * math.pi * k / 32 for k in range(32))]
    s.polygon("WindowLit", list(reversed(ring)))
    for k in range(32):
        s.tube(STONE, ring[k], ring[(k + 1) % 32], 0.4, 6, caps=False)
    for k in range(12):
        a = 2 * math.pi * k / 12
        p = (cx + side[0] * math.cos(a) * radius * 0.82 + n[0] * 0.1, cy + math.sin(a) * radius * 0.82,
             cz + side[2] * math.cos(a) * radius * 0.82 + n[2] * 0.1)
        s.box("BlackTrim", p, (0.3, 0.7 if k % 3 == 0 else 0.4, 0.08), rot)
    s.clock((cx + n[0] * 0.25, cy, cz + n[2] * 0.25), rot, radius)
    s.light("point", (cx + n[0] * 2.5, cy, cz + n[2] * 2.5), (255, 220, 160), 18, 0.8)


def clock_tower(s, r, top, base=P.EAVES["auditorium"], clock_y=P.CLOCK_Y, clock_r=P.CLOCK_R, spire=P.SPIRE,
                brick="BrickRed"):
    """The tower over the auditorium's entrance: brick walls with stone quoins and bands (from the
    ground on three faces; the fourth rises from the auditorium's roof), the clock on all four
    faces, the belfry's arched openings, pinnacles on the parapet and the slate spire."""
    x0, z0, x1, z1 = r
    cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
    w, d = x1 - x0, z1 - z0
    # Walls above the ground floor (the vestibule's own walls are built by the auditorium).
    for face, (a, b) in (("n", ((x0, z0), (x1, z0))), ("e", ((x1, z0), (x1, z1))), ("s", ((x1, z1), (x0, z1))),
                         ("w", ((x0, z1), (x0, z0)))):
        length = math.dist(a, b)
        dx, dz = (b[0] - a[0]) / length, (b[1] - a[1]) / length
        out = (dz, -dx)
        y0 = base if face == "n" else P.GF
        city.vquad(s, brick, a, b, y0, top, out)
        s.collider(((a[0] + b[0]) / 2 - out[0] * 0.7, (y0 + top) / 2, (a[1] + b[1]) / 2 - out[1] * 0.7),
                   (length, top - y0, 1.4), g2.rot_of((dx, dz)), True, brick)
        # Belfry openings (dark) under the parapet.
        for k in (-1, 1):
            u = length / 2 + k * length * 0.2
            p = (a[0] + dx * u + out[0] * 0.03, a[1] + dz * u + out[1] * 0.03)
            s.box("BlackTrim", (p[0], top - 5.5, p[1]), (2.6, 6.0, 0.06), g2.rot_of((dx, dz)))
            curve, (cu, _) = arch_curve(1.3, 1.6)
            pts = [(p[0] + dx * (sg * cu_), top - 2.5 + cy, p[1] + dz * (sg * cu_)) for sg in (1,)
                   for cu_, cy in curve] + [(p[0] + dx * (-cu_), top - 2.5 + cy, p[1] + dz * (-cu_))
                                            for cu_, cy in reversed(curve[:-1])]
            _face(s, "BlackTrim", pts, out)
            s.box(STONE, (p[0] + out[0] * 0.2, top - 8.6, p[1] + out[1] * 0.2), (3.2, 0.4, 0.5), g2.rot_of((dx, dz)))
    # Quoins up the corners and stone bands.
    for sx, sz in ((x0, z0), (x1, z0), (x1, z1), (x0, z1)):
        y = P.GF
        k = 0
        while y < top - 1:
            big = k % 2 == 0
            s.box(STONE, (sx, y + 0.95, sz), (1.9 if big else 1.2, 1.9, 1.9 if big else 1.2))
            y += 2.0
            k += 1
    for y in (base + 0.5, clock_y - clock_r - 1.6, clock_y + clock_r + 1.6, top - 0.5):
        s.box(STONE, (cx, y, cz), (w + 0.8, 1.0, d + 0.8))
        s.box(SNOW, (cx, y + 0.56, cz), (w + 0.8, 0.12, d + 0.8), skip=("-y",))
    for rot in (0, 90, 180, -90):
        turn = kit.ry(rot)
        nrm = turn((0, 0, -1))
        half = d / 2 if rot in (0, 180) else w / 2
        clock_face(s, cx + nrm[0] * (half + 0.45), clock_y, cz + nrm[2] * (half + 0.45), rot, clock_r)
    # The parapet, pinnacles at the corners, the spire.
    s.box(STONE, (cx, top + 0.8, cz), (w + 1.0, 1.6, d + 1.0), skip=("-y",))
    s.box(SNOW, (cx, top + 1.68, cz), (w + 1.0, 0.16, d + 1.0), skip=("-y",))
    for sx, sz in ((x0, z0), (x1, z0), (x1, z1), (x0, z1)):
        s.box(STONE, (sx, top + 3.0, sz), (1.4, 3.0, 1.4))
        kit.pyramid_roof(s, sx, sz, 1.6, top + 4.5, 3.5, mat="Slate", finial="Brass")
    kit.pyramid_roof(s, cx, cz, min(w, d) - 1.0, top + 1.6, spire, mat="Slate", finial="Brass")
    s.collider((cx, top + 1.0, cz), (w + 1.0, 2.0, d + 1.0), 0, True, None)
    s.light("point", (cx, top - 4.0, cz), (255, 190, 120), 14, 0.5)


# The arcade ------------------------------------------------------------------------------------------------


def arcade(s, r, h=12.0, pier=1.2, bay=6.5, brick="BrickDark"):
    """A covered walk along a building's east face (r: from the wall's outer face out to the pier
    line): stone piers with pointed arches between them, a brick spandrel wall up to a lean-to
    roof under snow, lanterns hanging in the bays."""
    x0, z0, x1, z1 = r
    px = x1 - pier / 2
    count = max(2, round((z1 - z0 - pier) / bay))
    step = (z1 - z0 - pier) / count
    s.box("Stone", ((x0 + x1) / 2, 0.02, (z0 + z1) / 2), (x1 - x0, 0.04, z1 - z0), skip=("-y",))
    spring = 7.0
    for k in range(count + 1):
        z = z0 + pier / 2 + k * step
        s.box(STONE, (px, spring / 2, z), (pier, spring, pier), collide=True)
        s.box(STONE, (px, spring + 0.25, z), (pier + 0.3, 0.5, pier + 0.3))
    # Arches and the wall above them, bay by bay, on the open face.
    _, t, n, _ = kit.wall_frame((px, z0), (px, z1))
    ops = []
    for k in range(count):
        mid = pier / 2 + (k + 0.5) * step
        ops.append({"at": mid, "w": step - pier, "bottom": 0.0, "top": spring + (step - pier) * 0.6, "kind": "gap"})
    kit.wall(s, (px, z0), (px, z1), h, thick=pier, core=brick, side_n=brick, side_s=brick, openings=ops, collide=False)
    for op in ops:
        arch_head(s, (px, z0), t, n, pier, op["at"], op["w"], op["top"], (step - pier) * 0.6, brick, brick)
    s.collider((px, (spring + 3.0 + h) / 2, (z0 + z1) / 2), (pier, h - spring - 3.0, z1 - z0), 0, True, brick)
    # The lean-to roof from the building's wall down to the arcade's face.
    roof_hi, roof_lo = h + 2.5, h
    _plane(s, [(x0, roof_hi, z0 - 0.5), (x0, roof_hi, z1 + 0.5), (x1 + 0.8, roof_lo, z1 + 0.5), (x1 + 0.8, roof_lo, z0 - 0.5)])
    city.down_face(s, "WoodPanel", P.box(x0, z0, x1 - pier, z1), h - 0.5)
    s.collider(((x0 + x1) / 2, h, (z0 + z1) / 2), (x1 - x0, 1.0, z1 - z0), 0, True, None)
    for k in range(count):
        z = z0 + pier / 2 + (k + 0.5) * step
        if k % 2 == 0:
            kit.pendant(s, (x0 + x1) / 2, h - 0.5, z, drop=2.4, shade="BlackMetal", color=fit.WARM, range_=16,
                        brightness=0.9, wide=0.9)
    s.zone("lane", P.box(x0, z0, x1, z1), 0.0, name="the arcade")


# The red gate, the guard booth, the club house -----------------------------------------------------------


def red_gate(s, x0, x1, z, depth=6.0, h=12.0):
    """The red gate: vermilion pillars (two tall ones at the passage, two shorter behind), a heavy
    tiled gable roof under snow with its ridge ends turned up, the leaves swung open against the
    side walls, white plaster side walls with a tile coping."""
    zf, zb = z - depth / 2, z + depth / 2
    for x in (x0, x1):
        for zz in (zf, zb):
            s.box("Vermilion", (x, h / 2, zz), (1.6, h, 1.6), collide=True)
            s.box("BlackTrim", (x, 0.4, zz), (1.9, 0.8, 1.9))
        s.box("Vermilion", (x, h - 1.0, z), (1.2, 1.2, depth), collide=False)
        # The open leaves against the side, inside the passage.
        leaf_x = x + (1.4 if x == x0 else -1.4)
        s.box("Vermilion", (leaf_x, 4.6, zf - 4.0), (0.3, 9.2, 8.0), collide=True)
        for k in range(4):
            s.box("Brass", (leaf_x + (0.18 if x == x0 else -0.18), 1.5 + k * 2.2, zf - 4.0), (0.08, 0.2, 7.6))
    for zz in (zf, zb):
        s.box("Vermilion", ((x0 + x1) / 2, h - 1.4, zz), (x1 - x0, 1.6, 1.2))
        s.box("Vermilion", ((x0 + x1) / 2, h - 3.6, zz), (x1 - x0, 0.8, 0.9))
        # The bracket beam over each row of pillars, up under the eaves.
        s.box("Vermilion", ((x0 + x1) / 2, h + 1.2, zz), (x1 - x0 + 2.0, 2.4, 1.0))
    for x in (x0, x1):
        s.box("Vermilion", (x, h + 0.7, z), (1.4, 1.4, depth + 1.0))
    # The tie beam across the passage that the lanterns hang from.
    s.box("Vermilion", ((x0 + x1) / 2, h + 0.3, z), (x1 - x0, 0.6, 0.8))
    # The roof: slate-dark tiles, its snowy planes on deep, gently sloping eaves, the ridge with
    # its ends turned up.
    gable_roof(s, (x0 - 1.0, zf - 2.5, x1 + 1.0, zb + 2.5), h + 1.0, 4.0, gable="Vermilion", overhang=1.5,
               along_x=True)
    s.box("Slate", ((x0 + x1) / 2, h + 5.3, z), (x1 - x0 + 5.0, 1.0, 1.0))
    for x in (x0 - 2.2, x1 + 2.2):
        s.box("Slate", (x, h + 6.1, z), (1.2, 1.6, 1.3))
    s.sign(((x0 + x1) / 2, h - 2.4, zf - 0.7), 0, 6.0, 1.2, P.UNIVERSITY, "Garamond", (236, 214, 150), (30, 22, 18))
    # Two lanterns hanging under the roof, lighting the passage.
    for x in (x0 + (x1 - x0) * 0.3, x0 + (x1 - x0) * 0.7):
        s.tube("BlackMetal", (x, h, z), (x, h - 2.0, z), 0.05, 5)
        s.lathe("NeonWarm", (x, h - 3.6, z), [(0.0, 0.0), (0.7, 0.2), (0.8, 0.8), (0.7, 1.4), (0.0, 1.6)], 12)
        s.light("point", (x, h - 3.0, z), (255, 196, 130), 22, 1.1)


def booth(s, r, door):
    """The guard booth: stone walls, a door, windows all round (the tip box stands under the one
    facing the avenue), a hipped roof under snow."""
    shell(s, r, P.EAVES["booth"], [door], brick="Stone", inside="PlasterGrey", storeys=[0.0], arch="round",
          window_w=3.4, spacing=5.0, door_top=6.4, plinth=False, cornice=True, seed=9, see_through=True)
    hip_roof(s, r, P.EAVES["booth"], 3.5, overhang=1.2)
