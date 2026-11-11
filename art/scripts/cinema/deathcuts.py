"""The shop's death scenes (the user's ask of 2026-11-07: "cutscenes for whatever don't have any in the shop"): a
Preview for every custom death (Shared/Cosmetics kind "reason"), starring the player, played by Presentation/WinCinema like the win cutscenes' previews. Written to src/shared/Cinema/DeathCuts.luau
(the WinCuts format, plus the death's own events), so run it after the death clips change:

    blender -b --factory-startup --python art/scripts/cinema/deathcuts.py

Each scene: Death's Manual first (the player's name and the cause written in it, as a death in a case opens), then the
player in a small dark set of their death's own (a ballroom under a chandelier, a drained pool, an empty archive, a
puppet theatre...), the death acted (art/scripts/deaths.py) with its effect, the heart monitor's beats and flatline, the
cause of death across the screen. Every camera is aimed at where the body is at that moment, worked out from the clips,
and checked against the frame the letterbox leaves (`check`). (The death styles' scenes went with the styles,
2026-11-10.)

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
    """Where the star's parts are at a scene's time: its death clip from `at`."""

    def __init__(self, clip, at):
        self.clip, self.at = clip, at

    def parts(self, t):
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
        "-- custom death, starring the player, played by Presentation/WinCinema like the win cutscenes'.",
        "-- The WinCuts format, plus: clipAt (when the star's clip starts) and the death's events: book (Death's Manual,",
        "-- the name written in it: \"$name\" is the star's), lifeless (the star's life layer off: it is acted to the end),",
        "-- deathFx (a custom death's effect, Presentation/CustomDeaths), card (the cause of death across the screen).",
        "-- Keyed by the cosmetic's id.",
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
