"""The nine free emotes (everyone has them: Shared/QuickChat). Wave, Point, Cheer, Laugh and Dance copy Roblox's
classic R6 /e emotes as they are (emotes/classic.py: recorded from Roblox's own animations, so the timing and
the poses are Roblox's, not a likeness). Their lengths are frozen (the owner's call: cutscenes, the tableaux and
the note hand-off reuse them), and they rest on the floor (a frame that dips a foot into it is lifted), so where Roblox's clip is shorter it is played at its own speed and a stretch of
it repeats, picked where the poses line up (no jump at the seam), except the Dance, a loop, played a little
slower to fill its loop. Salute, Bow, Shrug and Facepalm come from real footage (see their notes below).
"""

from emotes import classic
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
