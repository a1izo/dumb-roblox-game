"""The shop's death scenes (the user's ask of 2026-11-07: "cutscenes for whatever don't have any in the shop"): a
Preview for every custom death (Shared/Cosmetics kind "reason") and every death style (kind "death"), starring the
player, played by Presentation/WinCinema like the win cutscenes' previews. Written to src/shared/Cinema/DeathCuts.luau
(the WinCuts format, plus the death's own events), so run it after the death clips change:

    blender -b --factory-startup --python art/scripts/cinema/deathcuts.py

Each scene: Death's Manual first (the player's name and the cause written in it, as a death in a case opens), then the
player in a small dark set of their death's own (a ballroom under a chandelier, a drained pool, an empty archive, a
puppet theatre...), the death acted (art/scripts/deaths.py) with its effect, the heart monitor's beats and flatline, the
cause of death across the screen; a death style's scene has the heart attack and then the style's acting on the
fallen body (fallen.py). Every camera is aimed at where the body is at that moment, worked out from the clips
(the style's acting laid over the body where it lies, as Presentation/Fallen does), and checked against the frame the
letterbox leaves (`check`).

Space as in WinCuts: the star's floor frame, x to its right, y up, z behind it (it faces -z); studs."""

import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))

import numpy as np  # noqa: E402

import posekit  # noqa: E402
from animlib import J  # noqa: E402
import deaths  # noqa: E402,F401  (defines the death clips)
import deaths_scenes  # noqa: E402,F401  (the second batch, and the grave's salute)
import fallen  # noqa: E402,F401  (defines the style clips)
from motion import MOTIONS  # noqa: E402

OUT = os.path.normpath(os.path.join(HERE, "..", "..", "..", "src", "shared", "Cinema", "DeathCuts.luau"))
BOOK = 2.8  # Death's Manual, the sentence written in it (ManualTiming.BOOK)
LETTERBOX = 0.11  # of the screen's height, top and bottom (Cinema.letterbox)
ASPECT = 16 / 9


# Bodies ----------------------------------------------------------------------------------------------------------

def _pose(name, t):
    m = MOTIONS[name]
    pose, off = m.sample(max(0.0, min(m.length, t)))
    return posekit.fk({j: J(v[:3], v[3:]) for j, v in pose.items()}, tuple(off))


class Timeline:
    """Where the star's parts are at a scene's time: its death clip from `at`, and (for a style) the style's clip from
    `style_at`, laid over the body where it lies, as Presentation/Fallen does."""

    def __init__(self, clip, at, style=None, style_at=None):
        self.clip, self.at, self.style_at = clip, at, style_at
        self.style_clip = None
        self.base = np.identity(4)
        if style:
            end = _pose(clip, MOTIONS[clip].length)
            down = (end["Torso"][:3, :3] @ np.array([0, 0, -1.0]))[1] < 0
            self.style_clip = f"fallen{style.capitalize()}{'Down' if down else 'Up'}"
            first = _pose(self.style_clip, 0.0)
            self.base = end["Torso"] @ np.linalg.inv(first["Torso"])

    def parts(self, t):
        if self.style_clip and t >= self.style_at:
            w = _pose(self.style_clip, t - self.style_at)
            return {k: self.base @ v for k, v in w.items()}
        return _pose(self.clip, t - self.at)

    def point(self, t, part="Head", local=(0, 0, 0)):
        return (self.parts(t)[part] @ np.array([*local, 1.0]))[:3]

    def middle(self, t):
        """The body's middle (the torso and the head between them)."""
        w = self.parts(t)
        return 0.6 * w["Torso"][:3, 3] + 0.4 * w["Head"][:3, 3]


# Cameras ---------------------------------------------------------------------------------------------------------

def r3(v):
    return [round(float(x), 2) for x in v]


def around(target, angle, distance, height):
    """An eye `distance` from `target` (flat), `angle` degrees round from the front (0: in front, +: to the star's
    left... its own right is +x, so +90 is on its right side), `height` above the target."""
    a = math.radians(angle)
    return np.array([target[0] + math.sin(a) * distance, target[1] + height, target[2] - math.cos(a) * distance])


def shot(at, eye, look, fov, glide=0.0, to=None):
    s = {"at": round(at, 2), "eye": r3(eye), "look": r3(look), "fov": fov}
    if glide:
        s["glide"] = glide
    if to:
        s["to"] = {k: (r3(v) if k in ("eye", "look") else v) for k, v in to.items()}
    return s


PROBLEMS = []


def check(name, shots, tl, length):
    """Every shot, at its start, middle and end: the head and the body's middle inside the frame the letterbox leaves
    (with a margin), and not filling it."""
    for i, s in enumerate(shots):
        t0 = s["at"] + s.get("glide", 0.0)
        t1 = shots[i + 1]["at"] if i + 1 < len(shots) else length
        for t in (t0, (t0 + t1) / 2, t1 - 0.05):
            u = 0.0 if t1 <= t0 else (t - t0) / (t1 - t0)
            eye = np.array(s["eye"], float)
            look = np.array(s["look"], float)
            fov = s["fov"]
            if "to" in s:
                eye = eye + (np.array(s["to"].get("eye", s["eye"]), float) - eye) * u
                look = look + (np.array(s["to"].get("look", s["look"]), float) - look) * u
                fov = fov + (s["to"].get("fov", fov) - fov) * u
            fwd = look - eye
            fwd /= np.linalg.norm(fwd)
            right = np.cross(fwd, [0, 1.0, 0])
            right /= np.linalg.norm(right)
            up = np.cross(right, fwd)
            half_v = math.tan(math.radians(fov / 2))
            half_h = half_v * ASPECT
            for label, p in (("head", tl.point(t)), ("middle", tl.middle(t))):
                d = p - eye
                z = d @ fwd
                if z < 1.5:
                    PROBLEMS.append(f"{name} shot {i} t={t:.2f}: {label} behind or too near the camera ({z:.2f})")
                    continue
                x, y = (d @ right) / (z * half_h), (d @ up) / (z * half_v)
                bound = 1 - 2 * LETTERBOX - 0.06
                if abs(x) > 0.92 or abs(y) > bound:
                    PROBLEMS.append(f"{name} shot {i} t={t:.2f}: {label} off frame ({x:.2f}, {y:.2f})")


# Sets ------------------------------------------------------------------------------------------------------------

def part(name=None, size=(1, 1, 1), at=(0, 0, 0), color=(40, 40, 44), material=None, shape=None, rot=None,
         alpha=None, glow=None, light=None, emit=None, hidden=None, text=None):
    p = {"size": list(size), "at": list(at), "color": list(color)}
    if name:
        p["name"] = name
    for k, v in (("material", material), ("shape", shape), ("rot", rot), ("alpha", alpha), ("glow", glow),
                 ("light", light), ("emit", emit), ("hidden", hidden), ("text", text)):
        if v is not None:
            p[k] = v
    return p


def lamp(name, at, color, range_, brightness, visible=None):
    """A light: a hidden point, or `visible` (size, colour) a glowing fitting."""
    if visible:
        size, glow_color = visible
        return part(name, size, at, glow_color, glow=True, light={"color": list(color), "range": range_,
                                                                  "brightness": brightness})
    return part(name, (0.2, 0.2, 0.2), at, color, alpha=1, light={"color": list(color), "range": range_,
                                                                 "brightness": brightness})


class Set(list):
    """A set's dressing, with the room it stands in (`spec`): the room is built round the dressing by the scene,
    once the dressing is placed (CAMERAS deep in front of the star, to the dressing's far side behind it)."""

    def __init__(self, items, spec):
        super().__init__(items)
        self.spec = spec

    def __add__(self, other):
        return Set(list(self) + list(other), self.spec)


CAMERAS = 13.0  # studs in front of the star the room keeps clear for the cameras


def room(w, d, h, floor, wall, floor_mat="SmoothPlastic", wall_mat="SmoothPlastic", ceiling=True, cx=0.0, cz=0.0,
         ceiling_color=None):
    """A box round the mark: the floor (its top at 0), four walls and a ceiling, so nothing of the world is seen. Built
    by the scene round its dressing (`Set`); w and h as given, its depth from the dressing and the cameras."""
    return Set([], dict(w=w, d=d, h=h, floor=floor, wall=wall, floor_mat=floor_mat, wall_mat=wall_mat,
                        ceiling=ceiling, cx=cx, cz=cz, ceiling_color=ceiling_color))


def build_room(spec, z0, z1):
    w, h, cx = spec["w"], spec["h"], spec["cx"]
    d, cz = z1 - z0, (z0 + z1) / 2
    floor, wall = spec["floor"], spec["wall"]
    out = [part("Floor", (w, 1, d), (cx, -0.5, cz), floor, spec["floor_mat"])]
    out += [
        part(None, (w, h, 1), (cx, h / 2, z0 - 0.5), wall, spec["wall_mat"]),
        part(None, (w, h, 1), (cx, h / 2, z1 + 0.5), wall, spec["wall_mat"]),
        part(None, (1, h, d), (cx - w / 2 - 0.5, h / 2, cz), wall, spec["wall_mat"]),
        part(None, (1, h, d), (cx + w / 2 + 0.5, h / 2, cz), wall, spec["wall_mat"]),
    ]
    if spec["ceiling"]:
        out.append(part(None, (w + 2, 1, d + 2), (cx, h + 0.5, cz), spec["ceiling_color"] or wall, spec["wall_mat"]))
    return out


def dress(set_parts, set_props, flip):
    """The set's parts and props: the dressing put behind the star (when `flip`) and the room built round it."""
    spec = getattr(set_parts, "spec", None)
    parts, props = list(set_parts), list(set_props)
    if flip:
        parts, props = behind(parts, props)
    if spec:
        if flip:
            far = [p["at"][2] + p["size"][2] / 2 for p in parts] + [q["at"][2] + 2.0 for q in props]
            z1 = max([spec["d"] / 2 - spec["cz"]] + far) + 1.0
            z0 = -CAMERAS
        else:
            z0, z1 = spec["cz"] - spec["d"] / 2, spec["cz"] + spec["d"] / 2
        parts = build_room(spec, z0, z1) + parts
    return parts, props


def prop(key, at, turn=0, size=None, color=(60, 50, 40), name=None, hidden=None):
    p = {"key": key, "at": list(at), "color": list(color)}
    if turn:
        p["turn"] = turn
    if size:
        p["size"] = size
    if name:
        p["name"] = name
    if hidden:
        p["hidden"] = True
    return p


# Scenes ----------------------------------------------------------------------------------------------------------

def name_of(cosmetic_cause):
    return cosmetic_cause


def behind(parts, props):
    """The set mirrored to the star's back (z to -z): the cameras stand in front of it, looking past it."""
    out_parts, out_props = [], []
    for p in parts:
        q = dict(p)
        q["at"] = [p["at"][0], p["at"][1], -p["at"][2]]
        if "rot" in p:
            q["rot"] = [-p["rot"][0], -p["rot"][1], p["rot"][2]]
        out_parts.append(q)
    for p in props:
        q = dict(p)
        q["at"] = [p["at"][0], p["at"][1], -p["at"][2]]
        q["turn"] = 180 - p.get("turn", 0)
        out_props.append(q)
    return out_parts, out_props


def death_scene(item, cause, clip, reason, mood, set_parts, set_props=(), set_events=(), shots_fn=None, flip=True):
    """A custom death's scene: the book, a wide on the player in the set, the death in two or three shots aimed at
    the body, and the body on the floor under the cause of death."""
    set_parts, set_props = dress(set_parts, set_props, flip)
    set_parts = set_parts + key_lights(mood)
    t = deaths.TIMING[clip]
    clip_at = BOOK + 1.1
    tl = Timeline(clip, clip_at)
    hit = clip_at + t["hit"]
    end = clip_at + t["still"] + 1.7
    shots = shots_fn(tl, clip_at, t, end) if shots_fn else default_shots(tl, clip_at, t, end)
    events = [
        {"at": 0, "act": "book", "seconds": BOOK, "cause": cause},
        {"at": round(clip_at - 0.05, 2), "act": "lifeless"},
    ]
    if t["fx"] is not None:
        events.append({"at": round(clip_at + t["fx"], 2), "act": "deathFx", "reason": reason,
                       "hit": round(t["hit"] - t["fx"], 2)})
    events.append({"at": round(hit + 0.3, 2), "act": "card", "kicker": "Cause of death: " + cause,
                   "subtitle": "is dead."})
    events += list(set_events)
    events.sort(key=lambda e: e["at"])
    cut = {
        "kind": "death", "item": item, "clip": clip, "clipAt": round(clip_at, 2), "length": round(end, 2),
        "grade": mood["grade"], "vignette": mood.get("vignette", {"strength": 0.5}), "props": list(set_props),
        "parts": list(set_parts), "shots": shots, "events": events,
        "beats": [{"at": round(hit, 2), "kind": "shake", "strength": 0.12, "seconds": 0.25}],
        "sounds": [{"at": round(clip_at, 2), "slot": "heartbeat"}, {"at": round(clip_at + 0.8, 2), "slot": "heartbeat"},
                   {"at": round(hit + 0.35, 2), "slot": "flatline"}],
    }
    check(item, shots, tl, end)
    return cut


def default_shots(tl, clip_at, t, end):
    """Wide on the player standing; medium on the first beat; low beside the body as it falls; high over it after."""
    hit = clip_at + t["hit"]
    stand = tl.middle(clip_at)
    lying = tl.middle(clip_at + t["still"])
    mid = (stand + lying) / 2
    out = [
        shot(BOOK, around(stand, 28, 9.5, 1.6), stand + [0, 0.3, 0], 46,
             to={"eye": around(stand, 22, 7.8, 1.2), "fov": 44}),
    ]
    beat = clip_at + 0.25
    fall_at = hit - 0.55
    if fall_at - beat >= 0.8:
        # (time for a medium shot on the first beat: a quick death goes from the wide straight to the fall)
        head = tl.point(beat)
        out.append(shot(beat, around(head, 38, 5.6, 0.2), head, 42,
                        to={"eye": around(head, 46, 6.6, 0.6), "look": tl.point(fall_at)}))
    else:
        fall_at = clip_at + 0.15
    out.append(shot(fall_at, around(mid, 72, 6.4 + 0.4 * np.linalg.norm(lying - stand), -0.4), mid, 50,
                    to={"eye": around(lying, 66, 5.4, -0.2), "look": lying}))
    after = hit + 0.75
    out.append(shot(after, around(lying, 30, 4.6, 5.0), lying, 44,
                    to={"eye": around(lying, 36, 3.6, 3.8), "fov": 42}))
    return out


def style_scene(item, style, mood, set_parts, set_props=(), set_events=(), style_shot=None, flip=True):
    """A death style's scene: the book (the heart attack written), the heart attack, a beat on the floor, and the
    style's acting on the body, from where it shows best."""
    set_parts, set_props = dress(set_parts, set_props, flip)
    set_parts = set_parts + key_lights(mood)
    clip = "collapseHeart"
    t = deaths.TIMING[clip]
    clip_at = BOOK + 1.0
    style_at = clip_at + t["length"] + 0.5
    tl = Timeline(clip, clip_at, style, style_at)
    sclip = tl.style_clip
    slen = MOTIONS[sclip].length
    end = style_at + slen + 0.6
    hit = clip_at + t["hit"]
    stand = tl.middle(clip_at)
    lying = tl.middle(clip_at + t["still"])
    shots = [shot(BOOK, around(stand, 28, 9.5, 1.6), stand + [0, 0.3, 0], 46,
                  to={"eye": around(stand, 22, 7.8, 1.2), "fov": 44})]
    beat = clip_at + 0.25
    head = tl.point(beat)
    shots.append(shot(beat, around(head, 38, 5.6, 0.2), head, 42,
                      to={"eye": around(head, 46, 6.6, 0.6), "look": tl.point(hit - 0.5)}))
    shots.append(shot(hit - 0.45, around(lying, 70, 6.6, -0.2), (stand + lying) / 2, 50,
                      to={"eye": around(lying, 60, 5.6, 0.2), "look": lying}))
    shots += style_shot(tl, style_at, slen, end) if style_shot else [
        shot(style_at - 0.3, around(lying, 34, 7.5, 3.0), lying + [0, 0.8, 0], 48,
             to={"eye": around(lying, 30, 6.4, 2.4), "look": tl.middle(style_at + slen * 0.6)})]
    events = [
        {"at": 0, "act": "book", "seconds": BOOK, "cause": "Heart attack"},
        {"at": round(clip_at - 0.05, 2), "act": "lifeless"},
        {"at": round(hit + 0.3, 2), "act": "card", "kicker": "Cause of death: Heart attack", "subtitle": "is dead."},
        {"at": round(style_at, 2), "act": "fallen", "style": style, "from": clip},
    ]
    events += list(set_events)
    events.sort(key=lambda e: e["at"])
    cut = {
        "kind": "death", "item": item, "clip": clip, "clipAt": round(clip_at, 2), "length": round(end, 2),
        "grade": mood["grade"], "vignette": mood.get("vignette", {"strength": 0.5}), "props": list(set_props),
        "parts": list(set_parts), "shots": shots, "events": events,
        "beats": [{"at": round(hit, 2), "kind": "shake", "strength": 0.1, "seconds": 0.25}],
        "sounds": [{"at": round(clip_at, 2), "slot": "heartbeat"}, {"at": round(clip_at + 0.8, 2), "slot": "heartbeat"},
                   {"at": round(hit + 0.35, 2), "slot": "flatline"}],
    }
    check(item, shots, tl, end)
    return cut


# Each mood: the screen's grade, the vignette, and the colour of the key light that picks the star out of the dark.
NIGHT = {"grade": {"saturation": -0.3, "contrast": 0.2, "brightness": 0.0, "tint": [214, 220, 238]},
         "vignette": {"strength": 0.4}, "key": (205, 216, 255)}
WARM = {"grade": {"saturation": -0.15, "contrast": 0.18, "brightness": 0.01, "tint": [246, 230, 210]},
        "vignette": {"strength": 0.4}, "key": (255, 222, 182)}
COLD = {"grade": {"saturation": -0.25, "contrast": 0.16, "brightness": 0.01, "tint": [218, 234, 248]},
        "vignette": {"strength": 0.38}, "key": (205, 230, 255)}
RED = {"grade": {"saturation": -0.2, "contrast": 0.22, "brightness": -0.01, "tint": [242, 216, 216]},
       "vignette": {"strength": 0.42}, "key": (255, 206, 200)}


def key_lights(mood):
    """The noir key on the star (high, in front and to its right: shadows falling away from the lens), a rim behind to
    cut its outline out of the dark, and a little fill low on the other side; added to every set."""
    key = mood.get("key", (240, 236, 228))
    return [lamp("Key", (3.5, 8.5, -5.5), key, 20, 3.2), lamp("Rim", (-2.5, 6.5, 5.0), (210, 220, 255), 14, 2.4),
            lamp("FillLow", (-5.0, 2.5, -6.0), key, 14, 0.7)]

CUTS = {}

# A long fall: a dark marble hall, two columns, one cold shaft of light from a high window across the floor.
CUTS["reason_fall"] = death_scene(
    "reason_fall", "A long fall", "deathFall", "fall", NIGHT,
    room(22, 26, 16, (34, 33, 38), (26, 25, 30), "Marble", "Limestone", cz=-4) + [
        part(None, (2.2, 16, 2.2), (-6.5, 8, -9), (46, 44, 50), "Marble", shape="Cylinder", rot=[0, 0, 90]),
        part(None, (2.2, 16, 2.2), (6.5, 8, -9), (46, 44, 50), "Marble", shape="Cylinder", rot=[0, 0, 90]),
        part(None, (4, 6, 0.4), (0, 11, -17.2), (150, 170, 200), glow=True),
        lamp("Shaft", (0, 13, -10), (170, 190, 230), 24, 2.2),
        lamp("Fill", (4, 4, 6), (120, 120, 150), 14, 0.5),
        part(None, (5, 0.05, 9), (0, 0.03, -4), (60, 62, 72), "Marble", alpha=0.4),
    ],
)

# A broken heart: a wet street at night under a lamp post, in the rain.
CUTS["reason_heart"] = death_scene(
    "reason_heart", "A broken heart", "deathHeart", "heart", RED,
    room(26, 26, 20, (22, 22, 26), (14, 14, 18), "Asphalt", "Brick", ceiling=False) + [
        part(None, (26, 0.4, 3), (0, 0.2, -10), (70, 68, 66), "Concrete"),
        lamp("Lamp", (-2.6, 11, -2), (255, 214, 160), 22, 2.4),
        lamp("Glow", (-2.6, 11.2, -2.3), (255, 214, 160), 4, 0.5, visible=((0.8, 0.6, 0.8), (255, 220, 170))),
        part("Rain", (18, 1, 18), (0, 18, 0), (40, 40, 44), alpha=1, emit="rain"),
        lamp("Sign", (-8, 6, -11), (220, 40, 60), 16, 1.2, visible=((5, 1.2, 0.2), (220, 40, 60))),
    ],
    set_props=[prop("LampPost", (-3.2, 0, -2.4), turn=-90, size=12.2, color=(30, 30, 34))],
)

# Frozen where they stood: a snowfield at night, a cold moon, mist on the snow, dead trees black against it.
CUTS["reason_frost"] = death_scene(
    "reason_frost", "Frozen where they stood", "deathFrost", "frost", COLD,
    room(30, 30, 22, (220, 228, 236), (24, 30, 44), "Snow", "SmoothPlastic", ceiling=False) + [
        lamp("Moon", (-10, 18, -14), (190, 214, 255), 40, 1.6),
        lamp("Fill", (6, 4, 6), (150, 180, 230), 16, 0.6),
        part("Mist", (16, 1, 16), (0, 0.6, -2), (220, 230, 240), alpha=1, emit="fog"),
        part(None, (0.6, 9, 0.6), (-7, 4.5, -10), (14, 14, 18), "Wood"),
        part(None, (0.4, 4, 0.4), (-6.2, 7, -10), (14, 14, 18), "Wood", rot=[0, 0, -35]),
        part(None, (0.7, 11, 0.7), (8, 5.5, -12), (14, 14, 18), "Wood"),
        part(None, (0.4, 5, 0.4), (9, 8, -12), (14, 14, 18), "Wood", rot=[0, 0, 40]),
    ],
)


def chandelier(y=10.5):
    """A chandelier of gold rings and glowing drops on its chain, over the mark (named, so it can fall)."""
    names, out = [], []
    out.append(part("Ch_body", (1.2, 1.6, 1.2), (0, y, -0.4), (200, 160, 70), "Metal", shape="Ball"))
    out.append(part("Ch_ring", (0.25, 4.2, 4.2), (0, y - 0.5, -0.4), (210, 170, 80), "Metal", shape="Cylinder",
                    rot=[0, 0, 90]))
    names += ["Ch_body", "Ch_ring"]
    for k in range(8):
        a = k * math.pi / 4
        n = f"Ch_drop{k}"
        out.append(part(n, (0.35, 0.6, 0.35), (math.cos(a) * 2.0, y - 0.95, -0.4 + math.sin(a) * 2.0),
                        (255, 236, 190), glow=True, shape="Ball"))
        names.append(n)
    out.append(part("Ch_chain", (0.18, 8, 0.18), (0, y + 4.6, -0.4), (120, 100, 60), "Metal"))
    out.append(lamp("Ch_light", (0, y - 1.2, -0.4), (255, 220, 160), 20, 2.2))
    names += ["Ch_light"]
    return out, names


CH_PARTS, CH_NAMES = chandelier()
_ch = deaths.TIMING["deathChandelier"]


def chandelier_shots(tl, clip_at, t, end):
    """The wide; low in front looking up past the head (snapping up at the creak) to the chandelier over it; a hard
    cut on the crush, from the side and above; high over the body after."""
    hit = clip_at + t["hit"]
    stand = tl.middle(clip_at)
    lying = tl.middle(clip_at + t["still"])
    up = np.array([0.0, 6.2, -0.4])
    return [
        shot(BOOK, around(stand, 28, 9.5, 1.6), stand + [0, 0.3, 0], 46, to={"eye": around(stand, 22, 7.8, 1.2)}),
        shot(clip_at + 0.1, around(stand, 24, 6.6, -2.2), up, 68, to={"eye": around(stand, 20, 6.0, -2.0)}),
        shot(hit + 0.03, around(lying, 72, 6.8, 3.0), tl.middle(hit + 0.03), 50,
             to={"eye": around(lying, 66, 5.8, 2.6), "look": lying}),
        shot(hit + 0.9, around(lying, 30, 4.6, 5.0), lying, 44, to={"eye": around(lying, 36, 3.6, 3.8), "fov": 42}),
    ]


CUTS["reason_chandelier"] = death_scene(
    "reason_chandelier", "A chandelier, from above", "deathChandelier", "chandelier", WARM,
    room(24, 24, 22, (40, 26, 22), (52, 36, 30), "Marble", "Wood", ceiling_color=(30, 22, 18)) + CH_PARTS + [
        lamp("Sconce1", (-11, 7, -6), (255, 200, 140), 12, 1.0, visible=((0.5, 0.8, 0.5), (255, 210, 150))),
        lamp("Sconce2", (11, 7, -6), (255, 200, 140), 12, 1.0, visible=((0.5, 0.8, 0.5), (255, 210, 150))),
        part(None, (24, 4, 0.3), (0, 2, -11.8), (70, 44, 34), "Wood"),
    ],
    set_events=[
        {"at": round(BOOK + 1.1 + 0.1, 2), "act": "flash", "targets": ["Ch_light"], "brightness": 3.2, "seconds": 0.25},
        {"at": round(BOOK + 1.1 + _ch["hit"] - 0.42, 2), "act": "fling", "targets": CH_NAMES, "to": [0, 0.6, -0.9],
         "seconds": 0.42, "fall": True, "arc": 0, "spin": [0.05, 0.1, 0.03]},
        {"at": round(BOOK + 1.1 + _ch["hit"] + 0.05, 2), "act": "dim", "target": "Ch_light", "to": 0.25,
         "seconds": 0.5},
    ],
    shots_fn=chandelier_shots,
)

# Drowned on dry land: a drained pool at night, its tiles dry, one pool light still on under where the water was.
CUTS["reason_drown"] = death_scene(
    "reason_drown", "Drowned on dry land", "deathDrown", "drown", COLD,
    room(18, 22, 14, (150, 186, 196), (120, 160, 172), "CeramicTiles", "CeramicTiles", ceiling=False, cz=-2) + [
        part(None, (18, 0.3, 0.4), (0, 0.15, -6), (40, 60, 120), "CeramicTiles"),
        part(None, (0.2, 0.2, 22), (-4, 0.02, -2), (30, 50, 110), "CeramicTiles"),
        part(None, (0.2, 0.2, 22), (4, 0.02, -2), (30, 50, 110), "CeramicTiles"),
        lamp("PoolLight", (0, 1.6, -12.7), (110, 200, 255), 20, 2.0, visible=((1.6, 1.0, 0.2), (150, 220, 255))),
        lamp("Moon", (6, 16, 8), (180, 200, 240), 30, 0.9),
        part(None, (0.25, 6, 0.25), (-6.4, 3, -12.6), (200, 204, 210), "Metal"),
        part(None, (0.25, 6, 0.25), (-5.2, 3, -12.6), (200, 204, 210), "Metal"),
    ],
)

# Struck by lightning: a flat roof under a clear night sky, an antenna and a water tank against it.
CUTS["reason_lightning"] = death_scene(
    "reason_lightning", "Struck by lightning", "deathLightning", "lightning", NIGHT,
    room(30, 30, 8, (44, 44, 48), (36, 36, 40), "Concrete", "Concrete", ceiling=False) + [
        part(None, (30, 1.6, 1), (0, 0.8, -12), (60, 60, 64), "Concrete"),
        part(None, (0.3, 12, 0.3), (-7, 6, -9), (120, 120, 128), "Metal"),
        part(None, (3.4, 0.2, 0.2), (-7, 10.5, -9), (120, 120, 128), "Metal"),
        part(None, (4.2, 5, 4.2), (8, 4.5, -10), (70, 60, 52), "WoodPlanks", shape="Cylinder", rot=[0, 0, 90]),
        lamp("Sky", (0, 22, -6), (150, 170, 220), 40, 0.8),
        lamp("Fill", (-5, 3, 6), (140, 150, 190), 14, 0.5),
    ],
)

# A thousand paper cuts: an archive's dead end, shelves to the ceiling, papers over the floor, one desk lamp.
CUTS["reason_pages"] = death_scene(
    "reason_pages", "A thousand paper cuts", "deathPages", "pages", WARM,
    room(18, 20, 12, (60, 46, 34), (40, 32, 26), "WoodPlanks", "Wood", cz=-2) + [
        lamp("Lamp", (4, 5, -7), (255, 220, 160), 18, 1.6, visible=((0.6, 0.4, 0.6), (255, 226, 170))),
        lamp("Fill", (-3, 6, 5), (200, 170, 140), 14, 0.5),
    ] + [part(None, (1.1, 0.05, 1.5), (x, 0.03, z), (226, 218, 198), rot=[0, r, 0])
         for x, z, r in ((-2.5, -3, 20), (1.8, -4.5, -35), (3.2, 1.5, 60), (-3.4, 2.2, -10), (0.6, -6.5, 80),
                         (-1.2, 3.8, 45))],
    set_props=[prop("Bookshelf", (-6.5, 0, -10.6), size=8.1), prop("Bookshelf", (-3.2, 0, -10.6), size=8.1),
               prop("Bookshelf", (0, 0, -10.6), size=8.1), prop("Bookshelf", (3.2, 0, -10.6), size=8.1),
               prop("Bookshelf", (6.5, 0, -10.6), size=8.1), prop("Bookshelf", (-8.4, 0, -4), turn=-90, size=8.1),
               prop("Bookshelf", (8.4, 0, -4), turn=90, size=8.1), prop("Desk", (4.2, 0, -7.8), size=6)],
)

# Burned from within: a dark parlour, a fireplace that flares as they burn.
CUTS["reason_burn"] = death_scene(
    "reason_burn", "Burned from within", "deathBurn", "burn", WARM,
    room(20, 20, 12, (54, 34, 28), (34, 24, 22), "Carpet", "Plaster", cz=-2) + [
        part(None, (6, 5, 1.6), (0, 2.5, -11.2), (60, 44, 40), "Brick"),
        part("Hearth", (3.2, 2.2, 0.8), (0, 1.3, -10.6), (20, 12, 10), emit="fire"),
        lamp("FireLight", (0, 1.8, -9.6), (255, 140, 60), 18, 1.4),
        lamp("Fill", (5, 6, 4), (160, 120, 110), 14, 0.4),
    ],
    set_props=[prop("Sofa", (-5.5, 0, -2), turn=90, size=7.4), prop("Plant", (6.5, 0, -8), size=4)],
    set_events=[{"at": round(BOOK + 1.1 + deaths.TIMING["deathBurn"]["fx"], 2), "act": "ignite", "targets": ["Hearth"],
                 "scale": 1.6, "flare": True},
                {"at": round(BOOK + 1.1 + deaths.TIMING["deathBurn"]["fx"], 2), "act": "flash", "targets": ["FireLight"],
                 "brightness": 4, "seconds": 1.2}],
)

# Choked on a potato chip: a bedroom desk at night, the television's glow, the bag of chips.
CUTS["reason_chip"] = death_scene(
    "reason_chip", "Choked on a potato chip", "deathChip", "chip", NIGHT,
    room(18, 18, 11, (52, 50, 56), (40, 44, 52), "Carpet", "Plaster", cz=-2) + [
        lamp("TV", (-2.6, 4.2, -6.4), (150, 190, 255), 16, 1.6),
        lamp("Desk", (3.4, 5, -5.2), (255, 226, 170), 10, 0.8),
        lamp("Fill", (4, 6, 6), (130, 130, 160), 14, 0.4),
    ],
    set_props=[prop("Desk", (1.6, 0, -6.2), size=6), prop("CRTTelevision", (-2.6, 0, -7), size=4.2),
               prop("ChipBag", (2.4, 4.58, -6.0), turn=20, size=1.3), prop("ChairOffice", (4.8, 0, -2.6), turn=200,
                                                                          size=5.3)],
)


def clock_face():
    """A great clock on the back wall, its hand at forty."""
    out = [part(None, (0.4, 9, 9), (0, 7, -11.3), (226, 218, 196), "SmoothPlastic", shape="Cylinder", rot=[0, 90, 0]),
           part(None, (0.3, 9.6, 9.6), (0, 7, -11.5), (60, 46, 30), "Wood", shape="Cylinder", rot=[0, 90, 0])]
    for k in range(12):
        a = k * math.pi / 6
        out.append(part(None, (0.25, 0.9, 0.12), (math.sin(a) * 3.8, 7 + math.cos(a) * 3.8, -11.05), (30, 26, 22),
                        rot=[0, 0, -math.degrees(a)]))
    a = 40 / 60 * 2 * math.pi  # forty
    out.append(part(None, (0.18, 3.6, 0.1), (math.sin(a) * 1.6, 7 + math.cos(a) * 1.6, -10.95), (160, 20, 30),
                    rot=[0, 0, -math.degrees(a)]))
    return out


CUTS["reason_clock"] = death_scene(
    "reason_clock", "Their time ran out", "deathClock", "clock", WARM,
    room(18, 20, 15, (44, 36, 30), (36, 30, 26), "WoodPlanks", "Wood", cz=-2) + clock_face() + [
        lamp("Clock", (0, 7, -8.5), (255, 230, 190), 16, 1.4),
        lamp("Fill", (-4, 5, 5), (170, 150, 130), 14, 0.5),
    ],
)

# Taken by the dark: a long corridor, its lamps going out behind them one by one.
CORRIDOR = [lamp(f"Lamp{k}", (0, 8.6, z), (255, 226, 180), 12, 1.4, visible=((1.2, 0.3, 1.2), (255, 230, 190)))
            for k, z in enumerate((-8, -2, 4, 10))]
_dk = deaths.TIMING["deathDark"]
def dark_shots(tl, clip_at, t, end):
    """The look back from behind; the yank from the side; then low on the floor in front of them as they are dragged
    away from us into the dark, the hands reaching for the lens."""
    hit = clip_at + t["hit"]
    stand = tl.middle(clip_at)
    down = tl.middle(hit + 0.1)
    gone = tl.middle(clip_at + t["still"])
    return [
        shot(BOOK, stand + [1.4, 1.4, 8.0], stand + [0, 0.3, 0], 48, to={"eye": stand + [1.2, 1.1, 6.8]}),
        shot(clip_at + 0.62, stand + [-2.2, 1.2, -6.4], (stand + down) / 2, 52, to={"eye": down + [-2.0, 1.0, -5.6],
                                                                                 "look": down}),
        shot(hit + 0.35, down + [0.6, 1.4, -4.8], down + [0, 0.1, 0], 50, to={"eye": down + [0.5, 1.2, -4.2],
                                                                           "look": gone + [0, 0.2, 0], "fov": 42}),
    ]


CUTS["reason_dark"] = death_scene(
    "reason_dark", "Taken by the dark", "deathDark", "dark", RED,
    room(8, 34, 9, (40, 36, 34), (52, 46, 42), "WoodPlanks", "Plaster", cz=2) + CORRIDOR,
    shots_fn=dark_shots,
    flip=False,
    set_events=[{"at": round(BOOK + 1.1 + 0.6 + k * 0.32, 2), "act": "out", "targets": [f"Lamp{3 - k}"]}
                for k in range(3)],
)

# Ash to Ash: a burnt-out room, embers in the ash on the floor.
CUTS["death_ash"] = style_scene(
    "death_ash", "ash", WARM,
    room(18, 18, 12, (34, 30, 28), (24, 20, 18), "Slate", "Slate", cz=-2) + [
        lamp("Ember", (0, 1, -3), (255, 120, 60), 14, 0.9),
        lamp("Top", (0, 10, -1), (220, 200, 180), 16, 1.0),
        part(None, (5, 0.3, 3.6), (-4.5, 0.15, -6), (60, 56, 52), "Sand"),
        part(None, (3, 0.25, 2.4), (5, 0.12, -5), (60, 56, 52), "Sand"),
    ],
)


def stage_parts():
    """A puppet theatre's stage: boards, red curtains either side and behind, footlights along its front edge."""
    out = room(26, 22, 18, (70, 46, 30), (14, 10, 12), "WoodPlanks", "Fabric", cz=-2)
    out = out + [part(None, (4, 16, 0.6), (-8, 8, -8), (120, 16, 24), "Fabric"),
            part(None, (4, 16, 0.6), (8, 8, -8), (120, 16, 24), "Fabric"),
            part(None, (26, 16, 0.6), (0, 8, -12.4), (96, 12, 20), "Fabric"),
            part(None, (26, 3, 0.6), (0, 15.5, -8), (120, 16, 24), "Fabric")]
    out = out + [lamp(f"Foot{k}", (x, 0.12, 6.2), (255, 220, 160), 10, 0.9, visible=((0.6, 0.2, 0.2),
                                                                                       (255, 226, 170)))
                 for k, x in enumerate((-7, -3.5, 3.5, 7))]
    return out + [lamp("Spot", (0, 15, 2), (255, 236, 200), 26, 1.8)]


def strings_shot(tl, style_at, slen, end):
    """Low in front, looking up at it hanging from its strings, the bar above."""
    lying = tl.middle(style_at)
    hang = tl.middle(style_at + 1.6)
    floor = tl.middle(style_at + slen)
    snap = style_at + fallen.SNAP
    return [
        shot(style_at - 0.3, around(hang, 18, 8.6, -0.6), lying + [0, 0.6, 0], 52,
             to={"eye": around(hang, 24, 7.6, -0.9), "look": hang + [0, 1.0, 0]}),
        shot(snap + 0.32, around(floor, 40, 6.4, 2.4), floor, 46, to={"eye": around(floor, 34, 5.4, 2.0)}),
    ]


CUTS["death_strings"] = style_scene("death_strings", "strings", WARM, stage_parts(), style_shot=strings_shot)


def crows_shot(tl, style_at, slen, end):
    """Low and wide, the body lifting into the frame, the burst against the sky."""
    top = tl.middle(style_at + 1.6)
    return [shot(style_at - 0.3, around(top, 24, 9.5, -1.6), top + [0, -0.6, 0], 54,
                 to={"eye": around(top, 18, 8.6, -1.2), "look": top})]


# Murder of Crows: a graveyard at night, crooked stones, a dead tree, fog.
CUTS["death_crows"] = style_scene(
    "death_crows", "crows", NIGHT,
    room(30, 30, 22, (30, 34, 28), (20, 22, 26), "Ground", "SmoothPlastic", ceiling=False) + [
        lamp("Moon", (8, 18, -12), (190, 205, 240), 40, 1.4),
        part("Fog", (18, 1, 18), (0, 0.5, -2), (200, 210, 220), alpha=1, emit="fog"),
    ] + [part(None, (1.6, 2.6, 0.5), (x, 1.2, z), (90, 92, 96), "Slate", rot=[0, r, tilt])
         for x, z, r, tilt in ((-5, -7, 8, 6), (-1.5, -9, -4, -4), (3, -7.5, 12, 3), (6.5, -9.5, -10, 8),
                               (-7.5, -3, 20, -6))],
    set_props=[prop("Tree", (-9, 0, -11), size=13.7, color=(20, 20, 22))],
    style_shot=crows_shot,
)


def stone_shot(tl, style_at, slen, end):
    """Medium on the reach, from the side it reaches to."""
    reach = tl.middle(style_at + 1.4)
    return [shot(style_at - 0.3, around(reach, -40, 6.8, 1.4), reach + [0, 0.6, 0], 46,
                 to={"eye": around(reach, -34, 5.6, 1.0), "look": reach + [0, 0.8, 0]})]


# Petrified: a courtyard of old statues under the moon.
CUTS["death_stone"] = style_scene(
    "death_stone", "stone", COLD,
    room(28, 28, 22, (96, 94, 90), (40, 42, 48), "Cobblestone", "Limestone", ceiling=False) + [
        lamp("Moon", (-8, 18, -10), (190, 205, 240), 40, 1.5),
        lamp("Fill", (6, 4, 6), (150, 160, 190), 16, 0.5),
        part(None, (2.4, 1.2, 2.4), (-7, 0.6, -9), (110, 108, 104), "Limestone"),
        part(None, (1.6, 5, 1.2), (-7, 3.7, -9), (120, 118, 112), "Limestone"),
        part(None, (1.2, 1.2, 1.2), (-7, 6.8, -9), (120, 118, 112), "Limestone", shape="Ball"),
        part(None, (2.4, 1.2, 2.4), (7, 0.6, -10), (110, 108, 104), "Limestone"),
        part(None, (1.6, 4.6, 1.2), (7, 3.5, -10), (120, 118, 112), "Limestone", rot=[0, 0, 8]),
    ],
    style_shot=stone_shot,
)


def glass_shot(tl, style_at, slen, end):
    """Front and close on the glass figure risen on its knees, its last look, the shatter."""
    risen = tl.middle(style_at + 1.3)
    head = tl.point(style_at + 1.5)
    return [shot(style_at - 0.3, around(risen, 30, 6.8, 1.6), risen, 46,
                 to={"eye": around(head, 14, 4.6, 0.3), "look": head + [0, -0.4, 0], "fov": 42})]


# Shattered: a hall of mirrors, tall dark glass on every side.
CUTS["death_glass"] = style_scene(
    "death_glass", "glass", COLD,
    room(20, 20, 14, (24, 26, 30), (16, 18, 22), "Marble", "SmoothPlastic", cz=-2) + [
        lamp("Top", (0, 12, -2), (200, 220, 240), 20, 1.6),
        lamp("Rim", (0, 5, -10), (160, 200, 255), 14, 0.8),
    ] + [part(None, (3.4, 10, 0.2), (x, 5, -11.5), (170, 190, 210), "Glass", alpha=0.45) for x in (-6, -2, 2, 6)]
    + [part(None, (0.2, 10, 3.4), (x, 5, z), (170, 190, 210), "Glass", alpha=0.45) for x in (-9.5, 9.5)
       for z in (-6, -1)],
    style_shot=glass_shot,
)


# The second batch of custom deaths (2026-11-08, deaths_scenes.py): each in a set after its scene's own place.

VOID = {"grade": {"saturation": -0.2, "contrast": 0.22, "brightness": 0.0, "tint": [228, 216, 246]},
        "vignette": {"strength": 0.42}, "key": (226, 210, 255)}
COSMIC = {"grade": {"saturation": -0.05, "contrast": 0.24, "brightness": 0.0, "tint": [236, 220, 250]},
          "vignette": {"strength": 0.45}, "key": (240, 200, 255)}
GOLDEN = {"grade": {"saturation": -0.05, "contrast": 0.14, "brightness": 0.02, "tint": [255, 240, 205]},
          "vignette": {"strength": 0.35}, "key": (255, 232, 180)}
MUTED = {"grade": {"saturation": -0.45, "contrast": 0.1, "brightness": 0.03, "tint": [236, 236, 230]},
         "vignette": {"strength": 0.35}, "key": (236, 236, 230)}


def batch_shots(moments, fall_angle=60.0, fall_height=1.6):
    """The batch's cameras: the wide; a shot on each of the death's own moments (`moments`: at (s into the clip),
    angle, dist, height, fov, head (aim at the head, not the middle)), each pushing in a little and following the body
    to the next; the fall from higher and further than the default's (a body thrown on its back must not come at the
    lens), and the high shot over the body after."""

    def fn(tl, clip_at, t, end):
        hit = clip_at + t["hit"]
        stand = tl.middle(clip_at)
        lying = tl.middle(clip_at + t["still"])
        fall_at = hit - 0.6
        out = [shot(BOOK, around(stand, 28, 9.5, 1.6), stand + [0, 0.3, 0], 46,
                    to={"eye": around(stand, 22, 7.8, 1.2), "fov": 44})]
        kept = [m for m in moments if clip_at + m["at"] < fall_at - 0.5]
        for i, m in enumerate(kept):
            at = clip_at + m["at"]
            until = clip_at + kept[i + 1]["at"] if i + 1 < len(kept) else fall_at

            def aim(time, m=m):
                return tl.point(time) + [0, -0.3, 0] if m.get("head") else tl.middle(time)

            first, last = aim(at), aim(until - 0.05)
            out.append(shot(at, around(first, m["angle"], m["dist"], m["height"]), first, m.get("fov", 44),
                            to={"eye": around(last, m["angle"] + m.get("turn", 6), m["dist"] * 0.88, m["height"]),
                                "look": last}))
        mid = (tl.middle(fall_at) + lying) / 2
        out.append(shot(fall_at, around(mid, fall_angle, 7.6, fall_height), mid, 50,
                        to={"eye": around(lying, fall_angle - 6, 6.4, fall_height + 0.6), "look": lying}))
        out.append(shot(hit + 0.75, around(lying, 30, 4.6, 5.0), lying, 44,
                        to={"eye": around(lying, 36, 3.6, 3.8), "fov": 42}))
        return out

    return fn


BATCH_SHOTS = {
    # the lunge; close on the face as they look at their hands ("What? Why?"); the barrage from the side
    "reason_requiem": batch_shots([dict(at=0.1, angle=34, dist=5.6, height=0.3),
                                   dict(at=1.5, angle=14, dist=3.6, height=0.1, head=True, fov=40),
                                   dict(at=2.18, angle=56, dist=5.8, height=0.4)], fall_angle=70, fall_height=2.0),
    "reason_blackwall": batch_shots([dict(at=0.2, angle=20, dist=3.8, height=0.2, head=True, fov=42),
                                     dict(at=1.25, angle=40, dist=6.2, height=0.6)]),
    "reason_god": batch_shots([dict(at=0.2, angle=-24, dist=6.0, height=-1.2, fov=46),
                               dict(at=1.4, angle=30, dist=5.0, height=0.2)]),
    # close on the raised fist and the face over it; wider for the snap and the stagger
    "reason_ironman": batch_shots([dict(at=0.45, angle=28, dist=3.4, height=0.1, head=True, fov=40),
                                   dict(at=1.62, angle=44, dist=7.0, height=0.8, fov=46),
                                   dict(at=2.75, angle=60, dist=5.4, height=0.6)], fall_angle=66, fall_height=1.8),
    "reason_sam": batch_shots([dict(at=0.3, angle=-30, dist=5.2, height=0.0),
                               dict(at=1.5, angle=24, dist=4.6, height=0.4)]),
    "reason_walrider": batch_shots([dict(at=0.15, angle=14, dist=6.0, height=0.6)], fall_angle=64, fall_height=2.2),
    # the doze; the smug line and the cut; following the walk aside
    "reason_sans": batch_shots([dict(at=0.15, angle=20, dist=4.4, height=0.2, head=True, fov=42),
                                dict(at=1.35, angle=26, dist=5.6, height=0.3),
                                dict(at=3.3, angle=40, dist=7.4, height=0.8, fov=46)]),
    "reason_patriot": batch_shots([dict(at=0.2, angle=22, dist=6.0, height=0.5)], fall_angle=62, fall_height=2.0),
}


def batch_scene(item, *args, **kwargs):
    return death_scene(item, *args, shots_fn=BATCH_SHOTS[item], **kwargs)

# This is... requiem: an old Roman street at night, travertine arches behind, one warm lamp.
CUTS["reason_requiem"] = batch_scene(
    "reason_requiem", "This is... requiem", "deathRequiem", "requiem", VOID,
    room(26, 26, 18, (120, 112, 98), (70, 64, 56), "Cobblestone", "Limestone", ceiling=False) + [
        part(None, (2.2, 12, 2.2), (x, 6, -12), (150, 140, 120), "Limestone") for x in (-9, -3, 3, 9)
    ] + [
        part(None, (26, 2.2, 2.2), (0, 13, -12), (150, 140, 120), "Limestone"),
        part(None, (26, 6, 1), (0, 17, -12.6), (130, 122, 106), "Limestone"),
        lamp("Lamp", (-6, 8, -6), (255, 214, 160), 22, 1.8, visible=((0.7, 1.0, 0.7), (255, 220, 170))),
        lamp("Night", (6, 16, 6), (170, 160, 230), 30, 0.8),
    ],
)

# Blackwall gateway: a netrunner's dark back room, red and cyan strips of light, a wall of red static.
CUTS["reason_blackwall"] = batch_scene(
    "reason_blackwall", "Blackwall gateway", "deathBlackwall", "blackwall", RED,
    room(18, 20, 11, (22, 22, 26), (16, 16, 20), "DiamondPlate", "Metal", cz=-2) + [
        part(None, (10, 5, 0.3), (0, 4.5, -11.6), (255, 40, 50), glow=True, alpha=0.35),
        lamp("Wall", (0, 4.5, -10), (255, 40, 50), 20, 1.6),
        part(None, (0.2, 0.2, 18), (-8.8, 8.5, -2), (60, 230, 255), glow=True),
        part(None, (0.2, 0.2, 18), (8.8, 8.5, -2), (255, 40, 60), glow=True),
        lamp("Cyan", (-7, 7, -4), (60, 220, 255), 14, 0.8),
        part(None, (2.4, 1.6, 1.2), (5.5, 0.8, -8), (40, 40, 46), "Metal"),
        part(None, (2.0, 1.2, 0.1), (5.5, 2.3, -8.6), (255, 60, 60), glow=True),
    ],
)

# A GOD.. IS NOT... AFRAID OF...: a dark platform under a violet sky full of stars.
CUTS["reason_god"] = batch_scene(
    "reason_god", "A GOD.. IS NOT... AFRAID OF...", "deathGod", "god", COSMIC,
    room(30, 30, 24, (26, 20, 34), (14, 8, 26), "Slate", "SmoothPlastic", ceiling=False) + [
        part(None, (14, 0.6, 14), (0, -0.2, -2), (40, 30, 56), "Marble"),
        lamp("Magenta", (-6, 9, -8), (255, 70, 220), 26, 1.6),
        lamp("Cyan", (7, 6, -6), (70, 230, 255), 22, 1.2),
    ] + [part(None, (0.25, 0.25, 0.25), (x, y, -14.3), (255, 255, 255), glow=True, shape="Ball")
         for x, y in ((-12, 9), (-8, 15), (-4, 11), (-1, 19), (3, 13), (6, 18), (9, 10), (12, 16), (-10, 20),
                      (0, 8.5), (10, 21), (-6, 6))],
)

# and I.. am..: a ruined battlefield at dusk, broken walls and rubble, the light low and orange through the dust.
CUTS["reason_ironman"] = batch_scene(
    "reason_ironman", "and I.. am..", "deathIronMan", "ironMan", WARM,
    room(28, 28, 18, (70, 62, 54), (60, 54, 48), "Ground", "Concrete", ceiling=False) + [
        part(None, (6, 7, 1), (-6, 3.5, -11), (90, 84, 76), "Concrete", rot=[0, 0, 4]),
        part(None, (4, 3.5, 1), (5, 1.75, -12), (90, 84, 76), "Concrete", rot=[0, 8, -6]),
        part(None, (2.4, 1.2, 1.8), (-3, 0.6, -6), (80, 74, 66), "Concrete", rot=[0, 30, 8]),
        part(None, (1.6, 0.9, 1.4), (4, 0.45, -5), (80, 74, 66), "Concrete", rot=[0, -20, -10]),
        part(None, (1.0, 0.6, 1.0), (-6.5, 0.3, -2), (80, 74, 66), "Concrete", rot=[0, 50, 12]),
        part("Dust", (18, 1, 18), (0, 0.6, -2), (200, 170, 130), alpha=1, emit="fog"),
        lamp("Dusk", (10, 6, -12), (255, 150, 80), 34, 1.8),
    ],
)

# Let's dance!: moonlit rock on a windy night.
CUTS["reason_sam"] = batch_scene(
    "reason_sam", "Let's dance!", "deathSam", "sam", COLD,
    room(30, 30, 22, (70, 66, 64), (20, 22, 30), "Rock", "SmoothPlastic", ceiling=False) + [
        part(None, (6, 4, 5), (-8, 1.6, -11), (60, 58, 56), "Rock", rot=[8, 20, 4]),
        part(None, (4, 2.6, 4), (7, 1.0, -10), (60, 58, 56), "Rock", rot=[-6, -30, 10]),
        lamp("Moon", (-8, 18, -14), (190, 210, 255), 40, 1.7),
        part("Wind", (16, 1, 16), (0, 0.6, -2), (190, 196, 210), alpha=1, emit="fog"),
    ],
)

# Walrider: the asylum's tiled lab, a fluorescent tube, the doorway behind them bright with the soldiers' lights.
CUTS["reason_walrider"] = batch_scene(
    "reason_walrider", "Walrider", "deathWalrider", "walrider", NIGHT,
    room(18, 22, 10, (70, 76, 72), (110, 118, 112), "CeramicTiles", "CeramicTiles", cz=-2) + [
        part(None, (4, 7, 0.4), (0, 3.5, -12.6), (230, 236, 255), glow=True),
        lamp("Door", (0, 4, -10.5), (220, 230, 255), 24, 2.0),
        lamp("Tube", (0, 9.6, -3), (200, 240, 210), 16, 1.0, visible=((5, 0.2, 0.4), (220, 250, 225))),
        part(None, (3, 1, 1.6), (-6, 0.5, -8), (60, 64, 62), "Metal"),
    ],
)

# heh, didja really think-: a long golden hall, light through tall windows, pillars.
CUTS["reason_sans"] = batch_scene(
    "reason_sans", "heh, didja really think-", "deathSans", "sans", GOLDEN,
    room(26, 24, 18, (214, 190, 120), (230, 206, 140), "Marble", "Plaster", cz=-2) + [
        part(None, (1.8, 16, 1.8), (x, 8, -11), (240, 220, 160), "Marble", shape="Cylinder", rot=[0, 0, 90])
        for x in (-10, -5, 0, 5, 10)
    ] + [
        part(None, (3, 9, 0.2), (x, 8, -12.4), (255, 236, 170), glow=True) for x in (-7.5, -2.5, 2.5, 7.5)
    ] + [
        lamp("Sun", (-4, 12, -9), (255, 226, 150), 34, 1.8),
        lamp("Fill", (5, 5, 6), (230, 200, 150), 16, 0.6),
    ],
)

# A true patriot: a field of white flowers under a pale sky, one tree.
CUTS["reason_patriot"] = batch_scene(
    "reason_patriot", "A true patriot", "deathPatriot", "patriot", MUTED,
    room(30, 30, 22, (92, 104, 80), (190, 196, 196), "Grass", "SmoothPlastic", ceiling=False) + [
        lamp("Sky", (4, 18, -8), (236, 236, 230), 40, 1.6),
        part("Haze", (18, 1, 18), (0, 0.6, -2), (230, 232, 230), alpha=1, emit="fog"),
    ] + [part(None, (0.3, 0.3, 0.3), (x, 0.15, z), (245, 245, 238), shape="Ball")
         for x, z in ((-3.2, -2.1), (-2.4, -4.6), (-1.1, -3.3), (1.4, -2.8), (2.6, -4.1), (3.4, -1.6), (-4.1, -0.8),
                      (4.2, -5.6), (-3.6, -6.2), (0.4, -6.9), (2.0, -7.4), (-1.6, -8.1), (5.2, -3.2), (-5.4, -4.4),
                      (3.0, 1.2), (-2.6, 1.4), (5.6, 0.4), (-5.8, 0.8), (1.2, -10.2), (-4.4, -9.6), (4.6, -9.0))],
    set_props=[prop("Tree", (-8, 0, -11), size=12, color=(40, 44, 36))],
)


# The grave, after "A true patriot" (the reference's 1:50-2:15): the one who salutes (a friend of the dead in the server
# first, else anyone in it: DeathNoteService, or the Preview's own pick in WinCinema) at a white headstone with the
# dead's name on it, rows of white headstones fading into the mist. The headstone first, close, the name read; low
# and in front as the salute comes up; close on the face (a tear); the wide among the stones; close on the salute.
def grave_cut():
    tl = Timeline("graveSalute", 0.0)
    length = 10.6
    head = tl.point(4.6)
    stone_z = -3.8
    parts = room(70, 70, 30, (78, 90, 70), (196, 200, 200), "Grass", "SmoothPlastic", ceiling=False, cz=-10)
    parts = build_room(parts.spec, -45, 25)
    stone = (238, 238, 232)
    parts += [
        part("Grave", (1.9, 2.4, 0.4), (0, 1.2, stone_z), stone, "Marble"),
        part(None, (0.4, 1.9, 1.9), (0, 2.4, stone_z), stone, "Marble", shape="Cylinder", rot=[0, 90, 0]),
        part("Above", (1.7, 0.32, 0.05), (0, 2.05, stone_z + 0.23), stone, alpha=1,
             text={"text": "IN MEMORY OF", "face": "Back", "color": [70, 70, 74], "font": "Merriweather", "tilt": 0}),
        part("Name", (1.7, 0.5, 0.05), (0, 1.55, stone_z + 0.23), stone, alpha=1,
             text={"text": "$dead", "face": "Back", "color": [50, 50, 54], "font": "Merriweather", "tilt": 0}),
        part("Below", (1.7, 0.3, 0.05), (0, 1.05, stone_z + 0.23), stone, alpha=1,
             text={"text": "A TRUE PATRIOT", "face": "Back", "color": [70, 70, 74], "font": "Merriweather",
                   "tilt": 0}),
    ]
    parts += [part(None, (0.22, 0.22, 0.22), (x, 0.12, stone_z + 0.55 + z), (250, 250, 244), shape="Ball")
              for x, z in ((-0.5, 0.0), (-0.2, 0.15), (0.15, 0.05), (0.45, 0.18), (0.0, 0.32), (0.3, -0.05))]
    # the rows of headstones, all alike, fading into the mist (none where the cameras stand)
    rows = []
    for zi, z in enumerate(range(-36, 22, 5)):
        for x in range(-26, 27, 4):
            if abs(x) < 4 and -8 < z < 6:
                continue
            if 10 < x < 22 and -24 < z < -12:
                continue
            xs = x + (1.5 if zi % 2 else 0)
            rows.append(part(None, (1.2, 1.8, 0.28), (xs, 0.9, z), stone, "Marble"))
            rows.append(part(None, (0.28, 1.2, 1.2), (xs, 1.8, z), stone, "Marble", shape="Cylinder",
                             rot=[0, 90, 0]))
    parts += rows
    # mist: veils further off, and drifting fog low over the grass
    parts += [part(None, (70, 14, 0.2), (0, 7, z), (214, 218, 220), alpha=a) for z, a in ((-18, 0.86), (-30, 0.7))]
    parts += [part(None, (0.2, 14, 70), (x, 7, -10), (214, 218, 220), alpha=0.8) for x in (-20, 24)]
    parts += [part(f"Mist{k}", (24, 1, 24), (x, 0.8, z), (220, 224, 226), alpha=1, emit="fog")
              for k, (x, z) in enumerate(((0, -6), (-14, -20), (14, -20), (0, 10)))]
    parts += [lamp("Sky", (6, 22, -6), (232, 234, 236), 50, 1.4), lamp("Key", (3.5, 8.5, -5.5), (236, 236, 230), 20, 2.0),
              lamp("Rim", (-2.5, 6.5, 5.0), (214, 222, 236), 14, 1.6)]
    face = head + np.array([0.0, -0.05, 0.0])
    shots = [
        shot(0.0, (0.55, 1.95, -1.1), (0, 1.6, stone_z), 42, to={"eye": (0.35, 1.85, -1.6), "fov": 38}),
        shot(2.5, around(head, 40, 6.2, -1.4), head + [0, -0.7, 0], 44,
             to={"eye": around(head, 34, 5.4, -1.1), "look": head + [0, -0.4, 0]}),
        shot(5.0, around(face, -20, 4.0, 0.1), face, 36, to={"eye": around(face, -15, 3.5, 0.05), "fov": 34}),
        shot(6.9, (15.0, 6.2, -15.5), head + [0, -1.2, 0], 40, to={"eye": (17.5, 7.0, -19.5), "fov": 38}),
        shot(8.9, around(head, -32, 5.2, -0.6), head + [0, -0.5, 0], 40, to={"eye": around(head, -26, 4.6, -0.5)}),
    ]
    check("patriot_grave", shots[1:], tl, length)
    return {
        "kind": "grave", "clip": "graveSalute", "clipAt": 0, "length": length,
        "grade": MUTED["grade"], "vignette": MUTED["vignette"], "parts": parts, "props": [], "shots": shots,
        "events": [{"at": 5.5, "act": "tear", "seconds": 1.3, "side": -0.24}],
        "beats": [],
        "sounds": [],
    }


CUTS["patriot_grave"] = grave_cut()
CUTS["reason_patriot"]["after"] = "patriot_grave"


# Luau ------------------------------------------------------------------------------------------------------------

def luau(v, indent=1):
    pad = "\t" * indent
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        f = float(v)
        return str(int(f)) if f == int(f) and abs(f) < 1e9 else f"{round(f, 3):g}"
    if isinstance(v, str):
        return '"' + v.replace("\\", "\\\\").replace('"', '\\"') + '"'
    if isinstance(v, (list, tuple)):
        if not v:
            return "{}"
        if all(isinstance(x, (int, float)) for x in v):
            return "{ " + ", ".join(luau(x) for x in v) + " }"
        inner = ",\n".join(pad + "\t" + luau(x, indent + 1) for x in v)
        return "{\n" + inner + ",\n" + pad + "}" if v else "{}"
    if isinstance(v, dict):
        items = []
        for k in v:
            key = k if k.isidentifier() else f'["{k}"]'
            items.append(f"{pad}\t{key} = {luau(v[k], indent + 1)}")
        return "{\n" + ",\n".join(items) + ",\n" + pad + "}" if items else "{}"
    raise TypeError(type(v))


def write():
    lines = [
        "--!strict",
        "-- The shop's death scenes (written by art/scripts/cinema/deathcuts.py: do not edit by hand): a Preview for every",
        "-- custom death and death style, starring the player, played by Presentation/WinCinema like the win cutscenes'.",
        "-- The WinCuts format, plus: clipAt (when the star's clip starts) and the death's events: book (Death's Manual,",
        "-- the name written in it: \"$name\" is the star's), lifeless (the star's life layer off: it is acted to the end),",
        "-- deathFx (a custom death's effect, Presentation/CustomDeaths), fallen (a death style's acting on the fallen body,",
        "-- Presentation/Fallen), card (the cause of death across the screen). Keyed by the cosmetic's id.",
        "",
        "return " + luau(CUTS, 0) + " :: { [string]: any }",
    ]
    text = "\n".join(lines) + "\n"
    with open(OUT, "w", encoding="utf-8", newline="\n") as fh:
        fh.write(text)
    print(f"[deathcuts] {len(CUTS)} scenes -> {OUT}")
    for p in PROBLEMS:
        print("[deathcuts] frame:", p)
    print(f"[deathcuts] {len(PROBLEMS)} framing notes")


write()
