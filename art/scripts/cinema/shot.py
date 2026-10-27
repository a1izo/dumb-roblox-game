"""A cutscene ("shot") described in Roblox scene space and exported for the game's ShotPlayer.

Coordinates are the venue's own scene space (the same numbers the venue scripts in maps/venues use):
x right/east, y up (0 = the floor), z backwards/south; the game adds the venue's origin. Yaw is
degrees round the vertical: 0 faces -z, +90 faces -x (turning left).

    s = Shot("IntroCampus", "Campus", 15.0)
    s.cam(0.0, pos=(0, 8, -70), look=(0, 4, -95), fov=50)
    s.cam(4.0, pos=(4, 6, -80), look=(0, 4, -95), fov=40)
    s.cam(4.0, pos=(30, 5, -90), look=(20, 4, -92), fov=35, cut=True)   # a cut: no blend
    a = s.actor("noticer", motion)            # motion: a motion.Motion named "<shot>_<slot>"
    a.mark(0.0, (10, 0, -90), 0)               # where the actor stands (feet), facing
    a.hold("Pen", "Right Arm", (0, -1.0, -0.2), (90, 0, 0), t0=0, t1=8)
    s.prop("Grimoire").at(6.0, (24, 30, -92), (0, 0, 0)).at(7.2, (26, 0.3, -92), (80, 20, 0), "in")
    s.event(7.2, "sfx", slot="bookImpact")
    s.event(1.0, "subtitle", text="...", dur=2.5)

Actors are cast by the game: a slot name (a player chosen by the server, never by role, unless the
cutscene is that player's own private one), or `extra=True` for a faceless stand-in. Each actor's
body acting is an ordinary clip in Clips.luau (its motion is built with the other clips by
run_anims.py); its path moves it over the set. Camera, paths and props are sampled 30 times a
second and thinned to the keys that matter.
"""

import math
import os

import numpy as np

import common
from motion import Channel

SHOTS = {}
OUT_DIR = os.path.join(common.ROOT, "src", "shared", "Cinema", "Shots")
RATE = 30

# How far a thinned curve may stray from the sampled one.
POS_TOL = 0.01
ANG_TOL = math.radians(0.2)
FOV_TOL = 0.1


def look_rotation(pos, target, roll=0.0):
    """Roblox CFrame.lookAt rotation (columns: right, up, back), rolled `roll` degrees."""
    f = np.array(target, float) - np.array(pos, float)
    f /= np.linalg.norm(f)
    up = np.array([0.0, 1.0, 0.0])
    if abs(f @ up) > 0.999:
        up = np.array([0.0, 0.0, -1.0])
    r = np.cross(f, up)
    r /= np.linalg.norm(r)
    u = np.cross(r, f)
    if roll:
        a = math.radians(roll)
        r, u = r * math.cos(a) + u * math.sin(a), u * math.cos(a) - r * math.sin(a)
    return np.column_stack([r, u, -f])


def yaw_rotation(yaw):
    a = math.radians(yaw)
    return np.array([[math.cos(a), 0, math.sin(a)], [0, 1, 0], [-math.sin(a), 0, math.cos(a)]])


def euler_rotation(x, y, z):
    """CFrame.Angles(x, y, z) in degrees."""
    ax, ay, az = (math.radians(v) for v in (x, y, z))
    rx = np.array([[1, 0, 0], [0, math.cos(ax), -math.sin(ax)], [0, math.sin(ax), math.cos(ax)]])
    ry = np.array([[math.cos(ay), 0, math.sin(ay)], [0, 1, 0], [-math.sin(ay), 0, math.cos(ay)]])
    rz = np.array([[math.cos(az), -math.sin(az), 0], [math.sin(az), math.cos(az), 0], [0, 0, 1]])
    return rx @ ry @ rz


def quat(m):
    """(x, y, z, w) of a rotation matrix."""
    tr = m[0, 0] + m[1, 1] + m[2, 2]
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        w, x, y, z = 0.25 * s, (m[2, 1] - m[1, 2]) / s, (m[0, 2] - m[2, 0]) / s, (m[1, 0] - m[0, 1]) / s
    elif m[0, 0] > m[1, 1] and m[0, 0] > m[2, 2]:
        s = math.sqrt(1.0 + m[0, 0] - m[1, 1] - m[2, 2]) * 2
        w, x, y, z = (m[2, 1] - m[1, 2]) / s, 0.25 * s, (m[0, 1] + m[1, 0]) / s, (m[0, 2] + m[2, 0]) / s
    elif m[1, 1] > m[2, 2]:
        s = math.sqrt(1.0 + m[1, 1] - m[0, 0] - m[2, 2]) * 2
        w, x, y, z = (m[0, 2] - m[2, 0]) / s, (m[0, 1] + m[1, 0]) / s, 0.25 * s, (m[1, 2] + m[2, 1]) / s
    else:
        s = math.sqrt(1.0 + m[2, 2] - m[0, 0] - m[1, 1]) * 2
        w, x, y, z = (m[1, 0] - m[0, 1]) / s, (m[0, 2] + m[2, 0]) / s, (m[1, 2] + m[2, 1]) / s, 0.25 * s
    q = np.array([x, y, z, w])
    return q / np.linalg.norm(q)


def _qangle(a, b):
    return 2 * math.acos(min(1.0, abs(float(np.dot(a, b)))))


def thin(times, rows, err):
    """Douglas-Peucker over samples: keeps the fewest indices so that err(i, j, k) <= 1 for every
    dropped sample k between kept i and j."""
    keep = {0, len(times) - 1}

    def recurse(i, j):
        if j <= i + 1:
            return
        worst, worst_k = -1.0, None
        for k in range(i + 1, j):
            e = err(i, j, k)
            if e > worst:
                worst, worst_k = e, k
        if worst > 1.0:
            keep.add(worst_k)
            recurse(i, worst_k)
            recurse(worst_k, j)

    recurse(0, len(times) - 1)
    return sorted(keep)


def _lerp_frac(times, i, j, k):
    return (times[k] - times[i]) / (times[j] - times[i]) if times[j] > times[i] else 0.0


# Parts ------------------------------------------------------------------------------------------------


class Track:
    """A path through the set: keys of position (x, y, z) and rotation (yaw only, or x/y/z angles)."""

    def __init__(self, length, full_rotation=False):
        self.channel = Channel(length, False)
        self.full = full_rotation

    def key(self, t, pos, rot=0.0, ease="smooth"):
        r = tuple(rot) if self.full else (float(rot),)
        self.channel.add(float(t), np.array([*pos, *r], float), ease)
        return self

    def value(self, t):
        return self.channel.value(t)

    def rotation(self, t):
        v = self.value(t)
        return euler_rotation(*v[3:6]) if self.full else yaw_rotation(v[3])


class Actor:
    def __init__(self, shot, slot, motion=None, clip=None, at=0.0, show=(0.0, None), extra=False,
                 silhouette=None, eyes=None, outfit=None):
        self.shot = shot
        self.slot = slot
        self.clip = clip or (motion.name if motion is not None else None)
        self.motion = motion
        self.at = at  # shot time the clip's time 0 lines up with
        self.show = (show[0], show[1] if show[1] is not None else shot.length)
        self.extra = extra  # a faceless stand-in, not a player
        self.silhouette = silhouette  # (t0, t1): drawn as a black shape between these times
        self.eyes = eyes  # (t0, t1): red glowing eyes between these times
        self.outfit = outfit  # "suit" (default), "hood"
        self.path = Track(shot.length)
        self.held = []  # (prop, arm, offset (x, y, z), rotation (x, y, z degrees), t0, t1)

    def mark(self, t, pos, yaw=0.0, ease="smooth"):
        self.path.key(t, pos, yaw, ease)
        return self

    def hold(self, prop, arm="Right Arm", offset=(0, -1.0, 0), rot=(0, 0, 0), t0=0.0, t1=None):
        """A prop welded to the end of an arm (offset from the arm's middle, in the arm's frame:
        x right, y up the arm, z back) between t0 and t1."""
        self.held.append((prop, arm, tuple(offset), tuple(rot), t0, t1 if t1 is not None else self.shot.length))
        return self


class Prop:
    def __init__(self, shot, model, show=(0.0, None), scale=1.0, open=None):
        self.shot = shot
        self.model = model  # a ModelLibrary / Props.blend name
        self.scale = float(scale)  # the prop's size, times the catalog's
        self.open = open  # Death's Manual (Grimoire): 0 closed .. 1 lying open; None for every other prop
        self.show = (show[0], show[1] if show[1] is not None else shot.length)
        self.path = Track(shot.length, full_rotation=True)

    def at(self, t, pos, rot=(0, 0, 0), ease="smooth"):
        self.path.key(t, pos, rot, ease)
        return self


class Shot:
    def __init__(self, name, venue, length, note="", letterbox=True, skippable=False, mood=None):
        self.name = name
        self.venue = venue  # "Tokyo", "Campus", "Agency", "Meeting", "Sets"
        self.length = float(length)
        self.note = note
        self.letterbox = letterbox
        self.skippable = skippable
        self.mood = mood  # a LightingPresets name the game switches to for the shot
        self.room = None  # (x0, z0, x1, z1, height): lint warns when the camera leaves it
        self.cam_groups = [[]]  # camera keys, split at the cuts
        self.subjects = []  # (t0, t1, slot, back_ok): who the framing helpers aim at (framing_lint)
        self.actors = []
        self.props = []
        self.events = []
        self.sound = None  # (audio(): the voiced line, its bed, the scene's music)
        SHOTS[name] = self

    # --- authoring ---------------------------------------------------------------------------------

    def cam(self, t, pos, look, fov=40.0, roll=0.0, ease="smooth", cut=False):
        if cut and self.cam_groups[-1]:
            self.cam_groups.append([])
        self.cam_groups[-1].append((float(t), np.array([*pos, *look, fov, roll], float), ease))
        return self

    def frame(self, t, slot, kind="medium", **kw):
        """A camera key framing an actor where they really are at t (see framing.py)."""
        from cinema import framing

        framing.frame(self, t, slot, kind, **kw)
        return self

    def pan(self, t0, t1, slot, pos, **kw):
        from cinema import framing

        framing.pan(self, t0, t1, slot, pos, **kw)
        return self

    def follow(self, t0, t1, slot, kind="medium", **kw):
        from cinema import framing

        framing.follow(self, t0, t1, slot, kind, **kw)
        return self

    def actor(self, slot, motion=None, **kw):
        a = Actor(self, slot, motion, **kw)
        self.actors.append(a)
        return a

    def prop(self, model, show=(0.0, None), scale=1.0, open=None):
        p = Prop(self, model, show, scale, open)
        self.props.append(p)
        return p

    def face(self, t, slot, name):
        """From t, `slot` wears the face decal Face<name> (ui/faces.py); name None puts their own face back."""
        return self.event(t, "face", slot=slot, face=name or "")

    def event(self, t, kind, **data):
        self.events.append((float(t), kind, data))
        return self

    # --- sampling ----------------------------------------------------------------------------------

    def times(self):
        count = max(2, int(round(self.length * RATE)))
        return [self.length * i / count for i in range(count + 1)]

    def camera_at(self, t):
        """(position, rotation matrix, fov) of the camera at t."""
        group = self.cam_groups[0]
        for g in self.cam_groups:
            if g and g[0][0] <= t + 1e-9:
                group = g
        ch = Channel(self.length, False)
        for key in group:
            ch.add(*key)
        v = ch.value(t)
        return v[0:3], look_rotation(v[0:3], v[3:6], v[7]), v[6]

    def cut_times(self):
        """When the camera cuts (a Retime replaces this with its own)."""
        return [g[0][0] for g in self.cam_groups[1:] if g]

    def line(self, t, text, times=None, hold=0.9):
        """A spoken line typed at the bottom of the screen word by word as it is said (ShotPlayer "line" events): white
        serif words, a SHOUTED one (all capitals) in red, bigger, with a small shake. Each word's time comes from its
        length and the pauses its punctuation asks for, or from `times` (one per word, from t). A long line is shown a
        sentence at a time. Returns when the last word has been said (shot time)."""
        words = text.split()
        if times is None:
            times, at = [], 0.0
            for word in words:
                times.append(round(at, 3))
                letters = sum(1 for ch in word if ch.isalnum())
                shout = letters > 1 and word.upper() == word and any(ch.isalpha() for ch in word)
                at += (0.08 + 0.055 * letters) * (1.3 if shout else 1.0)
                if word.endswith("..."):
                    at += 0.45
                elif word[-1] in ".?!":
                    at += 0.3
                elif word[-1] == ",":
                    at += 0.15
        assert len(times) == len(words), f"{self.name}: {len(words)} words, {len(times)} times"
        end = t + times[-1] + 0.5
        # (a sentence at a time when the line is long: a page of words ends at a full stop or a question)
        pages, page = [], []
        for k, word in enumerate(words):
            page.append(k)
            closes = word[-1] in ".?!" and not word.endswith("...")
            if closes and sum(len(words[i]) + 1 for i in page) > 40 and k < len(words) - 1:
                pages.append(page)
                page = []
        if page:
            pages.append(page)
        for n, page in enumerate(pages):
            t0 = t + times[page[0]]
            last = pages[n + 1] if n + 1 < len(pages) else None
            t1 = (t + times[last[0]] - 0.05) if last else end + hold
            entries = []
            for i in page:
                word = words[i]
                letters = sum(1 for ch in word if ch.isalnum())
                shout = letters > 1 and word.upper() == word and any(ch.isalpha() for ch in word)
                entries.append([word, round(times[i] - times[page[0]], 3)] + ([1] if shout else []))
            self.event(t0, "line", words=entries, dur=round(t1 - t0, 3))
        return end

    def audio(self, voice=None, voice_at=0.0, bed=None, music=None):
        """The shot's own sound (Assets slots, silent while empty): a voiced line `voice` starting at `voice_at` (the
        game stretches the whole shot when the clip is longer than the line's time here), a music `bed` quietly under it,
        or the scene's own `music`."""
        self.sound = {k: v for k, v in (("voice", voice), ("voiceAt", voice_at if voice else None), ("bed", bed),
                                         ("music", music)) if v is not None}
        return self

    def camera_samples(self):
        """Samples (t, pos, quaternion, fov); at a cut, the old view right before it, then the new one."""
        times = self.times()
        cut_times = self.cut_times()
        for c in cut_times:
            times.append(max(0.0, c - 1e-3))
        times = sorted(set(round(t, 6) for t in times))
        out = []
        for t in times:
            p, m, fov = self.camera_at(t)
            out.append((t, p, quat(m), fov))
        for i in range(1, len(out)):  # keep quaternions on one side, so slerp takes the short way
            if np.dot(out[i][2], out[i - 1][2]) < 0:
                out[i] = (out[i][0], out[i][1], -out[i][2], out[i][3])
        return out, cut_times

class _Warped:
    """A path played on a cut-down timeline: its value at new time t is the old path's at old(t)."""

    def __init__(self, track, old):
        self.track = track
        self.old = old
        self.full = track.full

    def value(self, t):
        return self.track.value(self.old(t))

    def rotation(self, t):
        return self.track.rotation(self.old(t))


class _WarpedMotion:
    """An actor's acting seen on a cut-down timeline (for the framing helpers and the lints)."""

    def __init__(self, motion, old, length):
        self.motion = motion
        self.old = old
        self.length = length
        self.name = motion.name

    def __getattr__(self, name):
        return getattr(self.motion, name)

    def sample(self, t, *args):
        return self.motion.sample(self.old(t))


class Retime:
    """Plays pieces of a shot's own timeline back to back: a cutscene cut down to the length of the line spoken in it,
    keeping the acting, the camera and the events of the pieces kept. pieces [(old_t0, old_t1)], in order; each new
    piece is a cut.

        cut = Retime([(4.4, 5.8), (8.0, 10.6)])
        cut.apply(shot, [motion])     # the shot and its actors' clips now run on the new timeline (cut.length)
    """

    def __init__(self, pieces):
        self.pieces = []
        t = 0.0
        for o0, o1 in pieces:
            assert o1 > o0 and (not self.pieces or o0 >= self.pieces[-1][1]), "pieces run forward, apart"
            self.pieces.append((float(o0), float(o1), t))
            t += o1 - o0
        self.length = round(t, 3)

    def old(self, t):
        """New time -> old time."""
        for o0, o1, n0 in self.pieces:
            if t < n0 + (o1 - o0) - 1e-9:
                return o0 + max(0.0, t - n0)
        return self.pieces[-1][1]

    def new(self, t):
        """Old time -> new time, or None when that moment was cut away."""
        for o0, o1, n0 in self.pieces:
            if o0 - 1e-9 <= t <= o1 + 1e-9:
                return round(n0 + (t - o0), 3)
        return None

    def after(self, t):
        """The new time of the first piece kept after old time t (where a state set in a cut-away moment lands)."""
        for o0, _, n0 in self.pieces:
            if o0 >= t:
                return n0
        return None

    def span(self, t0, t1):
        """A window of old time on the new timeline: the first and last new times it covers, or None."""
        lo = hi = None
        for o0, o1, n0 in self.pieces:
            a, b = max(t0, o0), min(t1, o1)
            if a <= b:
                lo = n0 + a - o0 if lo is None else min(lo, n0 + a - o0)
                hi = n0 + b - o0 if hi is None else max(hi, n0 + b - o0)
        return None if lo is None else (round(lo, 3), round(hi, 3))

    def apply(self, shot, motions, carry_sfx=()):
        """Moves the shot onto the new timeline and builds its actors' clips there. Faces (and the looping sounds named
        in carry_sfx) set in a cut-away moment land at the start of the next piece kept; every other event cut away
        is dropped."""
        old_camera = shot.camera_at
        cuts = {round(n0, 3) for _, _, n0 in self.pieces[1:]}
        for c in shot.cut_times():
            n = self.new(c)
            if n is not None and n > 1e-6:
                cuts.add(n)
        cuts = sorted(cuts)
        shot.camera_at = lambda t: old_camera(self.old(t))
        shot.cut_times = lambda: cuts
        from motion import MOTIONS

        for a in shot.actors:
            own = a.motion or MOTIONS.get(a.clip)
            if own is not None and own in motions:
                a.motion = _WarpedMotion(own, self.old, self.length)
            a.path = _Warped(a.path, self.old)
            a.show = self.span(*a.show) or (0.0, 0.0)
            a.silhouette = self.span(*a.silhouette) if a.silhouette else None
            a.eyes = self.span(*a.eyes) if a.eyes else None
            a.held = [(prop, arm, off, rot, *w) for prop, arm, off, rot, t0, t1 in a.held
                      for w in [self.span(t0, t1)] if w]
        kept = []
        for p in shot.props:
            window = self.span(*p.show)
            if window:
                p.path = _Warped(p.path, self.old)
                p.show = window
                kept.append(p)
        shot.props = kept
        events = []
        for t, kind, data in sorted(shot.events, key=lambda e: e[0]):
            n = self.new(t)
            if n is None and (kind == "face" or (kind == "sfx" and data.get("slot") in carry_sfx)):
                n = self.after(t)
            if n is not None:
                events.append((n, kind, data))
        shot.events = events
        shot.subjects = [(*w, slot, back) for t0, t1, slot, back in shot.subjects for w in [self.span(t0, t1)] if w]
        shot.length = self.length
        for motion in motions:
            motion.build_retimed(self.old, self.length)
        return self


def lint(shot, step=0.25, radius=1.3, height=5.0):
    """Warnings for camera moments that would go wrong: the camera inside or right against a body, or a
    body between the camera and what it looks at. Bodies are taken as upright cylinders (radius, height)
    on their paths (lying bodies look bigger to this than they are)."""
    warnings = []
    t = 0.0
    while t <= shot.length + 1e-6:
        group = shot.cam_groups[0]
        for g in shot.cam_groups:
            if g and g[0][0] <= t + 1e-9:
                group = g
        ch = Channel(shot.length, False)
        for key in group:
            ch.add(*key)
        v = ch.value(t)
        cam, look = v[0:3], v[3:6]
        if shot.room is not None:
            x0, z0, x1, z1, h = shot.room
            if not (x0 + 0.4 < cam[0] < x1 - 0.4 and z0 + 0.4 < cam[2] < z1 - 0.4 and 0.3 < cam[1] < h - 0.3):
                warnings.append(f"{t:5.2f}s camera outside the room at ({cam[0]:.1f}, {cam[1]:.1f}, {cam[2]:.1f})")
        for a in shot.actors:
            if not (a.show[0] <= t <= a.show[1]):
                continue
            p = a.path.value(t)[:3]
            r, h = radius, height
            if a.motion is not None and a.motion.offset.keys:
                drop = a.motion.offset.value(t - a.at)[1]
                if drop < -1.5:  # lying down: low and long
                    r, h = 2.4, 1.8
            def within(q):
                return p[1] - 0.2 <= q[1] <= p[1] + h and math.hypot(q[0] - p[0], q[2] - p[2]) < r
            if within(look):
                continue  # the subject itself
            d = look - cam
            length = np.linalg.norm(d)
            near = None
            for k in range(0, 18):
                q = cam + d * (k / 17 * 0.85)
                if within(q):
                    near = k / 17 * 0.85 * length
                    break
            inside = p[1] - 0.2 <= cam[1] <= p[1] + h and math.hypot(cam[0] - p[0], cam[2] - p[2]) < r + 0.6
            if inside:
                warnings.append(f"{t:5.2f}s camera inside/against {a.slot}")
            elif near is not None and near < min(6.0, 0.5 * length):
                warnings.append(f"{t:5.2f}s {a.slot} blocks the view {near:.1f} studs from the camera")
        t += step
    return warnings


# What the player really sees: real avatars wear hair and hats, and the game letterboxes the screen.
HAIR_UP = 1.05  # the top of a head's hair above the head's centre (studs)
CHIN = 0.65  # the chin below it
NEAREST = 3.0  # closer than this to a head, its hair fills the screen
SEEN = 0.78  # the letterbox hides 11% at the top and the bottom
ASPECT = 16 / 9


def _subject(shot, t):
    """(slot, back_ok) of the actor the camera is framing at t: the latest framing that covers t, else
    the latest that started before it (a held frame)."""
    best = None
    for t0, t1, slot, back in shot.subjects:
        if t0 - 1e-6 <= t <= t1 + 1e-6:
            best = (t0, slot, back)
    if best is None:
        for t0, t1, slot, back in shot.subjects:
            if t0 <= t and (best is None or t0 >= best[0]):
                best = (t0, slot, back)
    return (best[1], best[2]) if best else (None, False)


def framing_lint(shot, step=0.25):
    """Warnings, as time ranges, for moments the player would not see the subject's face properly: the
    camera in their hair, their head cut by the letterbox or out of frame, the back or the top of their
    head instead of the face, or another head in the way."""
    from cinema import framing

    found = []
    t = 0.0
    while t <= shot.length + 1e-6:
        slot, back_ok = _subject(shot, t)
        if slot is None:
            t += step
            continue
        group = shot.cam_groups[0]
        for g in shot.cam_groups:
            if g and g[0][0] <= t + 1e-9:
                group = g
        ch = Channel(shot.length, False)
        for key in group:
            ch.add(*key)
        v = ch.value(t)
        cam, fov = v[0:3], v[6]
        m = look_rotation(v[0:3], v[3:6], v[7])
        right, up, fwd = m[:, 0], m[:, 1], -m[:, 2]
        head, facing = framing.head_view(shot, slot, t)
        tan_v = math.tan(math.radians(fov) / 2)

        def screen(p):
            d = p - cam
            depth = d @ fwd
            if depth <= 0.05:
                return None
            return (d @ right) / (depth * tan_v * ASPECT), (d @ up) / (depth * tan_v)

        dist = float(np.linalg.norm(head - cam))
        top, chin = screen(head + np.array([0, HAIR_UP, 0])), screen(head - np.array([0, CHIN, 0]))
        if top is None or chin is None:
            found.append((t, f"{slot} is behind the camera"))
        else:
            if dist < NEAREST:
                found.append((t, f"the camera is in {slot}'s hair (under {NEAREST:g} studs from the head)"))
            if top[1] > SEEN - 0.03 or chin[1] < -SEEN + 0.03:
                found.append((t, f"{slot}'s head is cut by the letterbox"))
            if abs(top[0]) > 0.97:
                found.append((t, f"{slot}'s head is off the side of the frame"))
            if (top[1] - chin[1]) / (2 * SEEN) > 0.62:
                found.append((t, f"{slot}'s head fills the frame"))
            middle = (top[1] + chin[1]) / 2
            if middle < -0.25:
                found.append((t, f"{slot}'s head is low in the frame (empty space above)"))
        to_cam = (cam - head) / max(dist, 1e-6)
        if not back_ok:
            if facing @ to_cam < 0.5:  # past about 60 degrees off the face, real hair hides it
                found.append((t, f"the camera sees {slot}'s hair, not their face (from the side or behind)"))
            elif facing[1] < -0.55:
                found.append((t, f"{slot}'s head is bowed: their hair hides the face"))
        for a in shot.actors:
            if a.slot == slot or not (a.show[0] <= t <= a.show[1]):
                continue
            other, _ = framing.head_view(shot, a.slot, t)
            d = head - cam
            u = float(np.clip((other - cam) @ d / (d @ d), 0.0, 1.0))
            if u < 0.92 and np.linalg.norm(cam + d * u - other) < 1.0:
                found.append((t, f"{a.slot}'s head is in front of {slot}'s"))
        t += step
    # one line per message per run of moments
    runs = {}
    for t, msg in found:
        spans = runs.setdefault(msg, [])
        if spans and t - spans[-1][1] <= step * 1.5:
            spans[-1][1] = t
        else:
            spans.append([t, t])
    lines = []
    for msg, spans in runs.items():
        for t0, t1 in spans:
            lines.append((t0, f"{t0:5.2f}-{t1:5.2f}s {msg}"))
    return [line for _, line in sorted(lines)]


# Export -------------------------------------------------------------------------------------------------


def num(v, digits=3):
    text = f"{v:.{digits}f}".rstrip("0").rstrip(".")
    return "0" if text in ("-0", "") else text


def lua_string(text):
    return '"' + text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n") + '"'


def lua_value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, (int, float)):
        return num(float(v))
    if isinstance(v, str):
        return lua_string(v)
    if isinstance(v, (list, tuple)):
        return "{ " + ", ".join(lua_value(x) for x in v) + " }"
    if isinstance(v, dict):
        return "{ " + ", ".join(f"{k} = {lua_value(x)}" for k, x in v.items()) + " }"
    raise TypeError(type(v))


def _flat(rows, digits):
    return "{ " + ", ".join(num(float(x), digits) for row in rows for x in row) + " }"


def _path_lines(track, length, indent):
    """t, p and rotation of a path, thinned."""
    count = max(2, int(round(length * RATE)))
    times = [length * i / count for i in range(count + 1)]
    values = [track.value(t) for t in times]

    def err(i, j, k):
        f = _lerp_frac(times, i, j, k)
        approx = values[i] + (values[j] - values[i]) * f
        dp = np.linalg.norm(approx[:3] - values[k][:3]) / POS_TOL
        dr = np.max(np.abs(approx[3:] - values[k][3:])) / 0.3
        return max(dp, dr)

    keep = thin(times, values, err)
    rot_key = "r" if track.full else "yaw"
    return [
        f"{indent}t = {_flat([[times[i]] for i in keep], 3)},",
        f"{indent}p = {_flat([values[i][:3] for i in keep], 3)},",
        f"{indent}{rot_key} = {_flat([values[i][3:] for i in keep], 2)},",
    ]


def export(shot):
    samples, cuts = shot.camera_samples()
    times = [s[0] for s in samples]

    def cam_err(i, j, k):
        f = _lerp_frac(times, i, j, k)
        p = samples[i][1] + (samples[j][1] - samples[i][1]) * f
        dp = np.linalg.norm(p - samples[k][1]) / POS_TOL
        qi, qj, qk = samples[i][2], samples[j][2], samples[k][2]
        q = qi + (qj - qi) * f
        q /= np.linalg.norm(q)
        dq = _qangle(q, qk) / ANG_TOL
        fv = samples[i][3] + (samples[j][3] - samples[i][3]) * f
        return max(dp, dq, abs(fv - samples[k][3]) / FOV_TOL)

    keep = thin(times, samples, cam_err)
    for c in cuts:  # never thin a cut away
        for i, t in enumerate(times):
            if abs(t - c) < 1e-6 or abs(t - (c - 1e-3)) < 1e-6:
                keep.append(i)
    keep = sorted(set(keep))
    lines = [
        "--!strict",
        f"-- GENERATED by art/scripts/run_cinema.py from art/scripts/cinema/shots. Do not edit by hand.",
        f"-- {shot.note}" if shot.note else "--",
        "",
        "return {",
        f"\tname = {lua_string(shot.name)},",
        f"\tvenue = {lua_string(shot.venue)},",
        f"\tlength = {num(shot.length)},",
        f"\tletterbox = {lua_value(shot.letterbox)},",
        f"\tskippable = {lua_value(shot.skippable)},",
    ]
    if shot.mood:
        lines.append(f"\tmood = {lua_string(shot.mood)},")
    if shot.sound:
        lines.append(f"\tsound = {lua_value(shot.sound)},")
    lines += [
        "\tcamera = {",
        f"\t\tt = {_flat([[times[i]] for i in keep], 3)},",
        f"\t\tp = {_flat([samples[i][1] for i in keep], 3)},",
        f"\t\tq = {_flat([samples[i][2] for i in keep], 4)},",
        f"\t\tfov = {_flat([[samples[i][3]] for i in keep], 2)},",
        "\t},",
        "\tactors = {",
    ]
    for a in shot.actors:
        lines.append("\t\t{")
        lines.append(f"\t\t\tslot = {lua_string(a.slot)},")
        if a.clip:
            lines.append(f"\t\t\tclip = {lua_string(a.clip)},")
            lines.append(f"\t\t\tat = {num(a.at)},")
        lines.append(f"\t\t\tshow = {lua_value(list(a.show))},")
        if a.extra:
            lines.append("\t\t\textra = true,")
        if a.silhouette:
            lines.append(f"\t\t\tsilhouette = {lua_value(list(a.silhouette))},")
        if a.eyes:
            lines.append(f"\t\t\teyes = {lua_value(list(a.eyes))},")
        if a.outfit:
            lines.append(f"\t\t\toutfit = {lua_string(a.outfit)},")
        lines += _path_lines(a.path, shot.length, "\t\t\t")
        if a.held:
            lines.append("\t\t\tprops = {")
            for prop, arm, off, rot, t0, t1 in a.held:
                lines.append(
                    f"\t\t\t\t{{ model = {lua_string(prop)}, arm = {lua_string(arm)}, offset = {lua_value(list(off))}, "
                    f"rot = {lua_value(list(rot))}, show = {lua_value([t0, t1])} }},"
                )
            lines.append("\t\t\t},")
        lines.append("\t\t},")
    lines.append("\t},")
    lines.append("\tprops = {")
    for p in shot.props:
        lines.append("\t\t{")
        lines.append(f"\t\t\tmodel = {lua_string(p.model)},")
        lines.append(f"\t\t\tshow = {lua_value(list(p.show))},")
        if abs(p.scale - 1.0) > 1e-6:
            lines.append(f"\t\t\tscale = {num(p.scale)},")
        if p.open is not None:
            lines.append(f"\t\t\topen = {num(p.open)},")
        lines += _path_lines(p.path, shot.length, "\t\t\t")
        lines.append("\t\t},")
    lines.append("\t},")
    lines.append("\tevents = {")
    for t, kind, data in sorted(shot.events, key=lambda e: e[0]):
        fields = {"t": t, "kind": kind}
        fields.update(data)
        lines.append(f"\t\t{lua_value(fields)},")
    lines.append("\t},")
    lines.append("}")
    os.makedirs(OUT_DIR, exist_ok=True)
    path = os.path.join(OUT_DIR, shot.name + ".luau")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return path
