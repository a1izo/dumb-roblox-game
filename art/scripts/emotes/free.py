"""The nine free emotes (everyone has them: Shared/QuickChat). Wave, Point, Cheer, Laugh and Dance copy Roblox's
classic R6 /e emotes as they are (emotes/classic.py: recorded from Roblox's own animations, so the timing and
the poses are Roblox's, not a likeness). Their lengths are frozen (the owner's call: cutscenes, the tableaux and
the note hand-off reuse them), and they rest on the floor (a frame that dips a foot into it is lifted), so where Roblox's clip is shorter it is played at its own speed and a stretch of
it repeats, picked where the poses line up (no jump at the seam), except the Dance, a loop, played a little
slower to fill its loop. Salute, Bow, Shrug and Facepalm come from real footage (see their notes below).
"""

import math

import numpy as np

from emotes import classic, mocap
from emotes.kit import reach
from motion import Motion


def _fit(name, clip, length, window, loop=False, note=""):
    """Roblox's clip `clip` on Motion `name`, `length` seconds long: played at its own speed, with the stretch
    from t_a to t_a + (length - its length) played twice (t_a picked in `window` where the poses line up)."""
    _, own = classic.frames(clip)
    m = Motion(name, length, loop=loop, note=note, unwrap=True, floor=True)
    inserted = length - own
    if inserted <= 1e-6:
        classic.key_span(m, clip, 0.0, own + 1e-3, 0.0)
        return m, None
    start, miss = classic.best_repeat(clip, inserted, window)
    at = classic.key_span(m, clip, 0.0, start + inserted, 0.0)
    classic.key_span(m, clip, start, own + 1e-3, at)
    return m, (start, miss)


# Wave: the right arm swung up over the head and waved side to side, then lowered (Roblox's 1.50 s); the waving
# goes on 0.9 s longer to fill the 2.4 s.
wave, _ = _fit("wave", "wave", 2.4, (0.3, 0.6), note="Roblox's classic wave: the arm up over the head, waving.")
wave.build()

# Point: the body turns away, the head looks back the other way and the left arm is levelled straight out
# (Roblox's 1.13 s); the held point lasts 0.48 s longer (the note hand-off plays its first 0.7 s and a lobby
# tableau holds it at 0.8 s: the arm is out from 0.4 s).
point, _ = _fit("point", "point", 1.6, (0.4, 0.55), note="Roblox's classic point: turned away, the arm levelled.")
point.build()

# Cheer: a dip, then a jump with both arms thrown up over the head (Roblox's 1.04 s), twice; the last 0.12 s is
# standing still.
cheer = Motion("cheer", 2.2, note="Roblox's classic cheer: a jump with both arms thrown up, twice.", unwrap=True, floor=True)
_, own = classic.frames("cheer")
at = classic.key_span(cheer, "cheer", 0.0, own, 0.0)
at = classic.key_span(cheer, "cheer", 0.0, own + 1e-3, at)
cheer.key(2.2, **{j: (0, 0, 0) for j in classic.JOINTS}, offset=(0, 0, 0))
cheer.build()

# Laugh: leaning back with a hand over the face, the body bobbing with each laugh. Roblox's is a one-shot; the
# game's laugh loops (Diavolo laughs over the ending), so one bob of the held laugh (0.4 s) repeats three times.
laugh = Motion("laugh", 1.2, loop=True, note="Roblox's classic laugh: leaning back, a hand over the face.", unwrap=True, floor=True)
start, _miss = classic.best_repeat("laugh", 0.4, (0.2, 0.47))
at = 0.0
for _ in range(3):
    at = classic.key_span(laugh, "laugh", start, start + 0.4, at)
# Each "ha" lifts Roblox's body while its feet stay down, so its R6 legs slide down out of the hips (a gap that
# shows). The same bob is kept, but under the standing height instead of over it: the legs slide up into the hips
# (a bent knee) and the soles stay planted.
top = max(v[1] for _, v, _ in laugh.offset.keys) + 0.12  # (and 0.12 lower: the lean back stretches the planted legs)
laugh.offset.keys = [(t, v - [0.0, top, 0.0], ease) for t, v, ease in laugh.offset.keys]
laugh.plant(stance=0.05)
laugh.build()

# Dance: Roblox's classic loop (the right arm up, a kick out to each side), 1.15 s, played at 0.72 speed to fill
# the game's 1.6 s loop.
dance = Motion("dance", 1.6, loop=True, note="Roblox's classic dance: an arm up, kicking out.", unwrap=True, floor=True)
_, own = classic.frames("dance")
classic.key_span(dance, "dance", 0.0, own, 0.0, speed=own / 1.6)
dance.build()

# Salute: a US Army drill sergeant's hand salute (art/refs/emotes/salute.toml), motion-captured from the front: from
# attention the right hand swings out and up to the brim, held, then cut straight down to the side. The raise
# (source 54.20-55.53 s) starts the clip, the held salute carries it, and the drop (82.80-83.20 s) lands it at 2.0 s.
salute = Motion("salute", 2.0, note="A drill sergeant's hand salute: up to the brim, held, cut down.", unwrap=True)
mocap.capture(salute, "salute_up", 54.2, 0.0, 1.33, loop=False)
mocap.capture(salute, "salute_down", 82.8 - 1.6, 1.4, 2.0, loop=False)
salute.build()


def _side_view(m, clip, lead, t0, t1):
    """A take filmed from the side (the body faces across the picture): the hips' drift across the picture is
    their travel forward and back, not to the side, so it goes to the body's z; the hips are kept at their
    standing height while the torso pitches about its middle (R6's root); the legs, often out of frame, are
    planted by the caller."""
    frames, _ = mocap.solve(mocap.Take(clip).smooth(), lead=lead)
    frames = mocap.between(frames, t0, t1)
    for f in frames:
        # Side on, the tracker's depth is a guess: the torso's twist and roll come back as noise (some 17 degrees
        # of roll in a bow that has none), so the root and the head keep only their pitch, which the picture shows.
        f["joints"]["root"] = (f["joints"]["root"][0], 0.0, 0.0)
        f["joints"]["neck"] = (f["joints"]["neck"][0], 0.0, 0.0)
        pitch = math.radians(f["joints"]["root"][0])
        f["offset"] = np.array([0.0, -(1.0 - math.cos(pitch)), float(f["offset"][0])])
    mocap.steady_arms(frames, loop=False)
    mocap.keys(m, frames)
    return frames


# Bow: a Japanese keirei (the 30-degree bow of respect), filmed from the side (art/refs/emotes/bow.toml): the back
# straight, bending from the hips, a held moment, then up again, each at its own speed: the bow down (source
# 53.0-53.8 s) and its hold (to 54.45 s) start the clip, the rise (55.8-56.8 s) ends it at 2.6 s.
bow = Motion("bow", 2.6, note="A Japanese keirei: a 30-degree bow from the hips, held, then up.", unwrap=True)
_side_view(bow, "bow_down", 52.85, 0.0, 1.6)
_side_view(bow, "bow_up", 55.8 - 1.6, 1.65, 2.6)
bow.plant(stance=0.0)
bow.build()


def _upper_body(m, clip, lead, t0, t1, sway=True):
    """A take filmed from the waist (or thighs) up: the torso, head and arms as captured; the legs are not in it,
    so the soles are planted by the caller and only the hips' sway across the picture moves the body."""
    frames, _ = mocap.solve(mocap.Take(clip).smooth(), lead=lead)
    frames = mocap.between(frames, t0, t1)
    for f in frames:
        f["offset"] = np.array([float(f["offset"][0]) if sway else 0.0, 0.0, 0.0])
        for leg in ("rHip", "lHip"):
            f["joints"].pop(leg, None)
    mocap.steady_arms(frames, loop=False)
    mocap.keys(m, frames)
    return frames


# Shrug: shoulders up, the arms turned out with the palms up and the head tilted (who knows?), then down again
# (art/refs/emotes/shrug.toml), motion-captured from the front, at its own speed: source 9.25-11.25 s.
shrug = Motion("shrug", 2.0, note="A shrug: shoulders up, palms out, the head tilted, then down.", unwrap=True)
_upper_body(shrug, "shrug", 9.25, 0.0, 2.0)
shrug.plant(stance=0.04)
shrug.build()

# Facepalm: Captain Picard's, the meme's own (art/refs/emotes/facepalm.toml), motion-captured from the green-screen
# cut of the scene: his left hand comes up and the face sinks into it, the head bowing further into the hand while
# it is held (source 3.55-5.5 s). He never takes it away in the scene; here the hand drops and the body straightens
# over the last 0.45 s, so the emote ends standing. He sits in the scene: standing, the legs stay planted.
# The capture (mocap/facepalm.json) gives the timing and the line of the arm, but Picard bows so far that his face
# sinks to his shoulders, which an R6 neck cannot follow: the tracked hand would stop at the chest. So the poses
# are keyed on the capture's beats, with the fist put on the R6 forehead (kit.reach, torso frame).
facepalm = Motion("facepalm", 2.4, note="Picard's facepalm: the hand comes up and the face sinks into it.")
REST = {j: (0, 0, 0) for j in ("root", "neck", "rShoulder", "lShoulder")}
facepalm.key(0.0, "smooth", **REST)
# a breath in: the head lifts a little as the left hand leaves the side (source 3.55-3.9 s)
facepalm.key(0.35, "smooth", root=(1, 0, 0), neck=(4, 0, 0), rShoulder=(4, 0, 2),
             lShoulder=reach(-1, (-0.75, 0.15, -0.85), direction=(0.4, 0.7, -0.6)))
# the hand passing the chest, the head starting down to meet it (4.2 s)
facepalm.key(0.65, "smooth", root=(-4, 2, 0), neck=(-10, 3, 0), rShoulder=(6, 0, 2),
             lShoulder=reach(-1, (-0.4, 0.95, -1.05), direction=(0.5, 0.8, -0.3)))
# the palm on the forehead (4.5 s): contact
facepalm.key(0.95, "out", root=(-8, 3, 0), neck=(-22, 6, -2), rShoulder=(6, 0, 3),
             lShoulder=reach(-1, (-0.12, 1.62, -1.0), direction=(0.6, 0.75, -0.2)))
# the head sinks into the hand, a slow weary turn of it (4.95-5.5 s)
facepalm.key(1.45, "smooth", root=(-11, 4, 0), neck=(-30, 9, -3), rShoulder=(7, 0, 3),
             lShoulder=reach(-1, (-0.1, 1.5, -1.05), direction=(0.6, 0.75, -0.2)))
facepalm.key(1.95, "smooth", root=(-12, 2, 0), neck=(-33, 4, -2), rShoulder=(7, 0, 3),
             lShoulder=reach(-1, (-0.1, 1.46, -1.07), direction=(0.6, 0.75, -0.2)))
# let go: the hand drops and the body straightens
facepalm.key(2.4, "smooth", **REST)
facepalm.follow(("lShoulder", "rShoulder"), 3.2, 0.8)
facepalm.plant(stance=0.04)
facepalm.build()
