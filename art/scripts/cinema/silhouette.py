"""Bodies as flat shapes seen through a shot's own camera: Tool 2 (the spacing strip) and Tool 3 (the silhouette
check) of docs/handoff/animation-cutscene-plan-2026-11-13.md.

    from cinema import silhouette
    silhouette.strip(shot, "self", 3.2, 5.6, "out.png")     # one row of frames, 0.05 s apart, black on white
    for line in silhouette.shape_lint(shot): print(line)    # the holds whose shape reads badly (run_cinema --lint)

Both work from the shot module's own motion (the keys, the springs and the extras of each actor's Motion, through the
R6 rig's forward kinematics, as `framing` and `clearance` do), not from the clips saved in Animations.blend, so they
show what the module says right now, with no clip to rebuild first. The body is the six R6 boxes (the head a 1.2 box,
as `clearance` has it): no hair, no hat, no prop, no set between the lens and the body.

This file stays free of bpy at the top (the drawing and the geometry can be tried in plain Python with numpy);
everything that needs the rig is imported where it is used.

Screen units: u runs right and v up, both in half frame heights from the middle of the picture (so the frame is
u -16/9..16/9 and v -1..1, and the letterbox hides |v| over 0.78). A body part is the convex hull of its box's eight
corners as the lens sees them."""

import math
import os
import struct
import zlib

import numpy as np

ASPECT = 16 / 9
SEEN = 0.78  # what the letterbox leaves (the same as cinema.shot.SEEN)
# R6 part sizes (the same as cinema.clearance.SIZES; the head's mesh is smaller than its 2x1x1 box)
SIZES = {"Torso": (2, 2, 1), "Head": (1.2, 1.2, 1.2), "Left Arm": (1, 2, 1), "Right Arm": (1, 2, 1),
         "Left Leg": (1, 2, 1), "Right Leg": (1, 2, 1)}
CORNERS = {name: np.array([(x * s[0] / 2, y * s[1] / 2, z * s[2] / 2) for x in (-1, 1) for y in (-1, 1) for z in (-1, 1)],
                          float) for name, s in SIZES.items()}
HAND = np.array([0.0, -0.9, 0.0])  # an arm's far end, in the arm's own frame (as framing.body has it)
SHOULDER = np.array([0.0, 1.0, 0.0])  # and its near end, the joint

# Tool 3's numbers (one place to tune them; the plan doc says what they mean)
STEP = 0.05  # the poses are worked out this often
STILL_SAMPLES = 3  # a moment is held when the body has not moved over this many samples either side of it (0.15 s)
STILL_MOVE = 0.25  # studs: the most any hand, the head or the torso's corners may travel over that span
EVERY = 2  # the shape is measured at every second sample of a hold (0.1 s)
MIN_TORSO = 0.2  # a body is read only when its torso is at least this tall on the screen (v units; 0.2 = a tenth of the frame)
HIDDEN = 0.70  # an arm with more than this share of its outline inside the torso's is hidden
HEAD_OVER = 0.40  # a raised arm hides the head when it covers this share of the head's outline
HIDDEN_BLACK = 0.50  # the same two, while the actor is drawn as a black silhouette (the shape is all there is)
HEAD_OVER_BLACK = 0.20
LIFTED = 0.5  # a hand is raised when it is at least this far (studs) above its shoulder joint


# Geometry -----------------------------------------------------------------------------------------------------


class View:
    """A camera at one moment: position, right/up/forward axes and tan of half the vertical field of view."""

    def __init__(self, cam, right, up, forward, tan_v):
        self.cam, self.right, self.up, self.forward, self.tan_v = cam, right, up, forward, tan_v


def view_at(shot, t):
    """The shot's camera at time t (a Retime's own timeline included, as shot.camera_at gives it)."""
    cam, m, fov = shot.camera_at(t)
    return View(np.array(cam, float), m[:, 0], m[:, 1], -m[:, 2], math.tan(math.radians(fov) / 2))


def project(view, points):
    """(u, v) of each 3D point, or None when any of them is at or behind the lens."""
    d = np.asarray(points, float) - view.cam
    depth = d @ view.forward
    if np.any(depth <= 0.1):
        return None
    scale = depth * view.tan_v
    return np.column_stack([(d @ view.right) / scale, (d @ view.up) / scale])


def hull(points):
    """The convex hull of 2D points, counter-clockwise (Andrew's monotone chain)."""
    pts = sorted(set((round(float(x), 6), round(float(y), 6)) for x, y in points))
    if len(pts) < 3:
        return np.array(pts, float)

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return np.array(lower[:-1] + upper[:-1], float)


def area(poly):
    if len(poly) < 3:
        return 0.0
    x, y = poly[:, 0], poly[:, 1]
    return 0.5 * float(np.sum(x * np.roll(y, -1) - np.roll(x, -1) * y))


def clip(subject, window):
    """The part of a convex polygon inside another convex counter-clockwise one (Sutherland-Hodgman)."""
    out = [tuple(p) for p in subject]
    n = len(window)
    for i in range(n):
        a, b = window[i], window[(i + 1) % n]
        if not out:
            break

        def inside(p):
            return (b[0] - a[0]) * (p[1] - a[1]) - (b[1] - a[1]) * (p[0] - a[0]) >= 0

        def meet(p, q):
            # where the segment p-q crosses the line a-b
            r = (q[0] - p[0], q[1] - p[1])
            s = (b[0] - a[0], b[1] - a[1])
            denom = r[0] * s[1] - r[1] * s[0]
            if abs(denom) < 1e-12:
                return q
            k = ((a[0] - p[0]) * s[1] - (a[1] - p[1]) * s[0]) / denom
            return (p[0] + k * r[0], p[1] + k * r[1])

        source, out = out, []
        prev = source[-1]
        for cur in source:
            if inside(cur):
                if not inside(prev):
                    out.append(meet(prev, cur))
                out.append(cur)
            elif inside(prev):
                out.append(meet(prev, cur))
            prev = cur
    return np.array(out, float) if out else np.zeros((0, 2))


def share_inside(poly, other):
    """The share of poly's area that lies inside `other` (0..1)."""
    whole = area(poly)
    if whole < 1e-9 or len(other) < 3:
        return 0.0
    return max(0.0, min(1.0, area(clip(poly, other)) / whole))


# The body through the lens ----------------------------------------------------------------------------------


def _is_warped(motion):
    return hasattr(motion, "old") and hasattr(motion, "motion")


def motion_of(actor):
    """The Motion that acts this actor (a Retime's warped one included), or None for a clip made elsewhere."""
    if actor.motion is not None:
        return actor.motion
    from motion import MOTIONS

    return MOTIONS.get(actor.clip)


def poses(shot, actor, times, springs=True):
    """For each shot time, how `actor` stands then: {"world": {part: (centre, rotation)}, "track": points in the
    character's own frame that say whether the body is moving} (springs on: the head and arms trail as they do in the
    baked clip). A time before or after the acting holds its first or last pose."""
    import posekit
    from animlib import J

    m = motion_of(actor)
    if m is None:
        return None
    local = [min(max(t - actor.at, 0.0), m.length) for t in times]
    inner, at = (m.motion, [m.old(t) for t in local]) if _is_warped(m) else (m, local)
    sprung = inner._sprung(at) if springs and inner.springs else None
    out = []
    for i, t in enumerate(times):
        pose, off = inner.sample(at[i], sprung, i)
        parts = posekit.fk({j: J(v[:3], v[3:]) for j, v in pose.items()}, tuple(off))
        v = actor.path.value(t)
        place, a = np.array(v[:3]), math.radians(float(v[3]))
        turn = np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])
        world = {name: (place + turn @ parts[name][:3, 3], turn @ parts[name][:3, :3]) for name in SIZES}
        track = [parts["Head"][:3, 3]]
        for arm in ("Right Arm", "Left Arm"):
            track.append(parts[arm][:3, 3] + parts[arm][:3, :3] @ HAND)
            track.append(parts[arm][:3, 3])
        for sx in (-1, 1):  # the torso's shoulders and hips: turning or leaning moves them
            for sy in (-1, 1):
                track.append(parts["Torso"][:3, 3] + parts["Torso"][:3, :3] @ np.array([sx, sy, 0.0]))
        out.append({"world": world, "track": np.array(track)})
    return out


def part_hulls(world, view):
    """{part: its outline on the screen} (a part with a corner behind the lens is left out)."""
    out = {}
    for name, (centre, rot) in world.items():
        pts = project(view, centre + CORNERS[name] @ rot.T)
        if pts is not None:
            out[name] = hull(pts)
    return out


# Drawing ----------------------------------------------------------------------------------------------------

GLYPHS = {
    "0": "111101101101111", "1": "010110010010111", "2": "111001111100111", "3": "111001111001111",
    "4": "101101111001001", "5": "111100111001111", "6": "111100111101111", "7": "111001001010010",
    "8": "111101111101111", "9": "111101111001111", ".": "000000000000010", "-": "000000111000000",
    "s": "011100010001110", " ": "000000000000000", "x": "101101010101101",
}


def text(img, x, y, s, scale=2, color=(60, 60, 60)):
    """Writes s onto an RGB uint8 image (a 3x5 digit font), its top left at (x, y)."""
    h, w = img.shape[:2]
    for ch in s:
        bits = GLYPHS.get(ch, GLYPHS[" "])
        for i, b in enumerate(bits):
            if b == "1":
                px, py = x + (i % 3) * scale, y + (i // 3) * scale
                if 0 <= px < w and 0 <= py < h:
                    img[py : min(h, py + scale), px : min(w, px + scale)] = color
        x += 4 * scale
    return img


def fill(mask, poly):
    """Sets the pixels of a boolean mask whose centres lie inside a convex polygon (in pixels)."""
    if len(poly) < 3:
        return
    h, w = mask.shape
    x0, x1 = max(0, int(math.floor(poly[:, 0].min()))), min(w, int(math.ceil(poly[:, 0].max())) + 1)
    y0, y1 = max(0, int(math.floor(poly[:, 1].min()))), min(h, int(math.ceil(poly[:, 1].max())) + 1)
    if x1 <= x0 or y1 <= y0 or abs(area(poly)) < 1e-9:
        return
    xs, ys = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
    sign = 1.0 if area(poly) > 0 else -1.0
    inside = np.ones(xs.shape, bool)
    for i in range(len(poly)):
        a, b = poly[i], poly[(i + 1) % len(poly)]
        inside &= sign * ((b[0] - a[0]) * (ys - a[1]) - (b[1] - a[1]) * (xs - a[0])) >= 0
    mask[y0:y1, x0:x1] |= inside


def write_png(path, rgb):
    """Writes an (h, w, 3) uint8 array as a PNG."""
    h, w = rgb.shape[:2]
    raw = b"".join(b"\x00" + rgb[y].tobytes() for y in range(h))

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


# Tool 2: the spacing strip ----------------------------------------------------------------------------------

OFF_FRAME = (226, 226, 226)  # what the lens does not show: past the frame's edge, under the letterbox
CUT_MARK = (210, 40, 40)
BAR = (40, 90, 200)
SS = 2  # supersampling, for soft edges


def strip(shot, slot, t0, t1, path, step=0.05, height=220, cols=0, fixed=False):
    """One image: the actor's frames from t0 to t1, `step` seconds apart in a row, left to right, each as the shot's
    own camera sees them, the body flat black on white (what the frame does not show, and the letterbox, in grey).
    Under each tile: its time, and a bar for how far the body travelled on the screen since the tile before (the
    biggest in the window is full height, but never under 4% of the frame's height, so a hold stays flat): an even run of bars is a glide, the stiffness that reads as a toy; a spike and
    a flat is a snap and a hold. A red mark on a tile's edge is a cut of the camera.
    `cols`: wrap to rows of this many tiles (0: one row). `fixed`: hold the camera as it is at t0 (to see the body's
    spacing without the camera's own move). Returns a dict of what it drew."""
    from cinema import framing

    actor = framing.actor(shot, slot)
    count = int(round((t1 - t0) / step)) + 1
    times = [t0 + k * step for k in range(count)]
    series = poses(shot, actor, times)
    if series is None:
        raise ValueError(f"{shot.name}: {slot} has no motion in this module (its clip {actor.clip} is made elsewhere)")
    views = [view_at(shot, t0 if fixed else t) for t in times]
    shapes = [part_hulls(s["world"], v) for s, v in zip(series, views)]
    pts = [p for sh in shapes for poly in sh.values() for p in poly]
    if not pts:
        raise ValueError(f"{shot.name}: {slot} is not in front of the camera between {t0:g}s and {t1:g}s")
    pts = np.array(pts)
    u0, v0 = pts.min(axis=0)
    u1, v1 = pts.max(axis=0)
    pad = 0.06 * max(u1 - u0, v1 - v0, 0.1)
    u0, u1 = max(u0 - pad, -ASPECT), min(u1 + pad, ASPECT)
    v0, v1 = max(v0 - pad, -1.0), min(v1 + pad, 1.0)
    if u1 - u0 < 0.05 or v1 - v0 < 0.05:
        raise ValueError(f"{shot.name}: {slot} is outside the frame between {t0:g}s and {t1:g}s")
    scale = height / (v1 - v0)
    if (u1 - u0) * scale > 520:  # a wide body (lying, running across): the tile stays readable
        scale = 520 / (u1 - u0)
    tw, th = max(8, int(round((u1 - u0) * scale))), max(8, int(round((v1 - v0) * scale)))
    visible = SEEN if shot.letterbox else 1.0
    uu = u0 + (np.arange(tw) + 0.5) / scale
    vv = v1 - (np.arange(th) + 0.5) / scale
    off = (np.abs(uu)[None, :] > ASPECT) | (np.abs(vv)[:, None] > visible)
    # how far the body went on the screen since the tile before (the middle of the head, the hands, the torso)
    marks = []
    for s, v in zip(series, views):
        w = s["world"]
        pick = [w["Head"][0], w["Torso"][0]] + [w[a][0] + w[a][1] @ HAND for a in ("Right Arm", "Left Arm")]
        marks.append(project(v, pick))
    cuts = set()
    for c in shot.cut_times():
        for k in range(1, count):
            if times[k - 1] < c - 1e-6 <= times[k] and not fixed:
                cuts.add(k)
    travel = [0.0]
    for k in range(1, count):
        if marks[k] is None or marks[k - 1] is None or k in cuts:
            travel.append(0.0)
        else:
            travel.append(float(np.mean(np.linalg.norm(marks[k] - marks[k - 1], axis=1))) * scale)
    # (a floor under the scale: a hold's tremor, a step under 4% of a frame's height, is not drawn full height)
    top = max(max(travel), 0.04 * th)
    label_h, bar_h, gap = 14, 36, 1
    cell_h = th + label_h + bar_h + 4
    cols = cols if cols > 0 else count
    rows = (count + cols - 1) // cols
    img = np.full((rows * cell_h, cols * (tw + gap), 3), 255, np.uint8)
    every = 1 if tw >= 46 else (2 if tw >= 24 else 4)
    for k in range(count):
        r, c = divmod(k, cols)
        x, y = c * (tw + gap), r * cell_h
        mask = np.zeros((th * SS, tw * SS), bool)
        for poly in shapes[k].values():
            fill(mask, np.column_stack([(poly[:, 0] - u0) * scale * SS, (v1 - poly[:, 1]) * scale * SS]))
        body = mask.reshape(th, SS, tw, SS).mean(axis=(1, 3))
        tile = np.where(off[..., None], np.array(OFF_FRAME, float), 255.0)
        tile = (tile * (1.0 - body[..., None])).astype(np.uint8)
        if k in cuts:
            tile[:, :3] = CUT_MARK
        img[y : y + th, x : x + tw] = tile
        img[y : y + th, x + tw : x + tw + gap] = 190  # (a hairline between the tiles)
        if k % every == 0:
            text(img, x + 2, y + th + 3, f"{times[k]:.2f}")
        height_px = int(round(bar_h * travel[k] / top))
        img[y + th + label_h + bar_h - height_px : y + th + label_h + bar_h, x + 1 : x + tw - 1] = BAR
        img[y + th + label_h + bar_h : y + th + label_h + bar_h + 1, x : x + tw] = 190
    write_png(path, img)
    moving = [d for d in travel[1:] if d > 0.1 * top]
    return {"path": path, "frames": count, "tile": (tw, th), "image": (img.shape[1], img.shape[0]),
            "cuts": [round(times[k], 3) for k in sorted(cuts)], "biggest_step_px": round(max(travel), 1),
            "at": round(times[int(np.argmax(travel))], 3), "still_frames": sum(1 for d in travel[1:] if d <= 0.1 * top),
            "moving_frames": len(moving)}


# Tool 3: the silhouette check -------------------------------------------------------------------------------


def _still(series):
    """For each sample, whether the body rested there: nothing travelled more than STILL_MOVE studs over the
    STILL_SAMPLES samples either side of it."""
    tracks = np.array([s["track"] for s in series])  # (samples, points, 3)
    out = []
    for i in range(len(series)):
        lo, hi = max(0, i - STILL_SAMPLES), min(len(series), i + STILL_SAMPLES + 1)
        window = tracks[lo:hi]
        out.append(hi - lo >= 3
                   and float(np.max(np.linalg.norm(window.max(axis=0) - window.min(axis=0), axis=1))) < STILL_MOVE)
    return out


def _readable(shapes):
    torso = shapes.get("Torso")
    if torso is None or len(torso) < 3:
        return False
    v = torso[:, 1]
    centre = torso.mean(axis=0)
    return bool(v.max() - v.min() >= MIN_TORSO and abs(centre[0]) < ASPECT and abs(centre[1]) < SEEN)


def shape_moments(shot, step=STEP):
    """Every held moment of every actor the lens reads (torso at least MIN_TORSO tall on the screen), with how the
    body's outline reads from the shot's camera then: {"slot", "t", "right" and "left" (the share of each arm's
    outline inside the torso's), "head_right" and "head_left" (the share of the head under that arm, when the hand
    is raised, else 0)}."""
    found = []
    for actor in shot.actors:
        if motion_of(actor) is None:
            continue
        t0, t1 = actor.show
        times = [t0 + i * step for i in range(int((t1 - t0) / step + 1e-6) + 1)]
        # a first look with the springs off: skip a body that is never big enough to read
        coarse = poses(shot, actor, times[:: max(1, int(round(0.25 / step)))], springs=False)
        if not any(_readable(part_hulls(s["world"], view_at(shot, t)))
                   for s, t in zip(coarse, times[:: max(1, int(round(0.25 / step)))])):
            continue
        series = poses(shot, actor, times)
        still = _still(series)
        for i in range(0, len(times), EVERY):
            if not still[i]:
                continue
            shapes = part_hulls(series[i]["world"], view_at(shot, times[i]))
            if not _readable(shapes) or "Head" not in shapes:
                continue
            rec = {"slot": actor.slot, "t": times[i], "right": 0.0, "left": 0.0, "head_right": 0.0, "head_left": 0.0}
            for key, arm in (("right", "Right Arm"), ("left", "Left Arm")):
                if arm in shapes:
                    rec[key] = share_inside(shapes[arm], shapes["Torso"])
                    centre, rot = series[i]["world"][arm]
                    hand, shoulder = centre + rot @ HAND, centre + rot @ SHOULDER
                    if hand[1] - shoulder[1] >= LIFTED:
                        rec["head_" + key] = share_inside(shapes["Head"], shapes[arm])
            found.append(rec)
    return found


def shape_lint(shot, step=STEP):
    """Notes, as time ranges, for the holds whose black shape reads badly from the shot's camera: both arms
    hidden inside the torso's outline, or the head overlapped by a raised arm."""
    silhouettes = {a.slot: a.silhouette for a in shot.actors if a.silhouette}

    def black(slot, t):
        window = silhouettes.get(slot)
        return bool(window) and window[0] - 1e-6 <= t <= window[1] + 1e-6

    flagged = {}  # (slot, what) -> [(t, {the numbers})]
    for rec in shape_moments(shot, step):
        dark = black(rec["slot"], rec["t"])
        hidden, over = (HIDDEN_BLACK, HEAD_OVER_BLACK) if dark else (HIDDEN, HEAD_OVER)
        if rec["right"] > hidden and rec["left"] > hidden:
            flagged.setdefault((rec["slot"], "arms"), []).append((rec["t"], rec))
        for side in ("right", "left"):
            if rec["head_" + side] > over:
                flagged.setdefault((rec["slot"], "head_" + side), []).append((rec["t"], rec))
    lines = []
    for (slot, what), moments in flagged.items():
        runs = [[moments[0][0], moments[0][0], [moments[0][1]]]]
        for t, rec in moments[1:]:
            if t - runs[-1][1] <= step * EVERY * 1.5:
                runs[-1][1] = t
                runs[-1][2].append(rec)
            else:
                runs.append([t, t, [rec]])
        for a, b, recs in runs:
            def mean(key):
                return sum(r[key] for r in recs) / len(recs)

            if what == "arms":
                msg = f"both arms are hidden in the torso's outline (right {mean('right'):.0%}, left {mean('left'):.0%})"
            else:
                side = what[5:]
                msg = f"the head is overlapped by the raised {side} arm ({mean(what):.0%} of the head)"
            tag = " (drawn as a black silhouette)" if black(slot, a) and black(slot, b) else ""
            lines.append((a, f"{a:5.2f}-{b:5.2f}s {slot}: {msg}{tag}"))
    return [line for _, line in sorted(lines)]
