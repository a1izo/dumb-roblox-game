"""The meeting intro (everyone, 6 s, before the meeting): the survivors arrive at the war room. Quick cuts:
two come in through the records door, two more along the case wall, two step up to their places on the
west side; then the wide from high over the table, everyone in their place under the one light.

Every actor is the player of one standing place ("seat:k", 0-based like plan.seats()), so the montage
ends where the meeting begins. Players not walking in stand in their places from the start.

The war room (maps/venues/meeting/plan.py, its own origin): 60 x 60, the table in the middle, twelve
places at 17 studs, the records door in the east wall at z -23."""

import math

from cinema.acting import alive, facing, soft, walking
from cinema.shot import Shot
from motion import Motion
from animlib import J

NAME = "MeetingIntro"
LENGTH = 6.0
SEAT_R = 16.1  # (the montage stands everyone just inside the chairs: the meeting seats them in them after)
SPEED = 5.0  # the walk's own speed (studs a second: late to an emergency meeting, they hurry)


def seat(k):
    a = k * 2 * math.pi / 12
    return math.sin(a) * SEAT_R, math.cos(a) * SEAT_R


def ring(angle, r=19.6):
    """A point on the chairs' ring (in the gap between two chairs at an odd multiple of 15 degrees)."""
    a = math.radians(angle)
    return math.sin(a) * r, math.cos(a) * r


# k: (where they come from, the gap between two chairs they come in by; when they set off). Each comes straight in
# through the middle of its gap, then along the inside of the chairs (INSIDE: the outer arm clear of the chairs' fronts,
# the inner clear of the table) to stand before its own place, and steps into it as it turns to the table (2026-11-07:
# cutting across the ring to the place, the outer arm went through the chair at every arrival).
WALKERS = {
    4: ([(27.4, -22.0)], 135, 0.0),
    5: ([(27.6, -23.8)], 135, 0.45),
    3: ([(25.4, -9.6)], 105, 0.0),
    2: ([(24.6, -2.0)], 75, 0.1),
    8: ([], 255, 2.5),
    9: ([], 285, 2.6),
}
OUTSIDE, INSIDE = 23.0, 15.9  # where the way through a gap begins (outside the chairs) and the ring inside them
TURN, STEP = 0.35, 0.35  # at the end of the way, the turn to the table on the spot, then the step out into the place


def arc(a0, a1, r, step=6.0):
    """Points along the ring r from the angle a0 to a1 (degrees), every `step` degrees or so, a0 left out."""
    n = max(1, round(abs(a1 - a0) / step))
    return [ring(a0 + (a1 - a0) * (i + 1) / n, r) for i in range(n)]

STAND = dict(rShoulder=J((4, 0, 2)), lShoulder=J((4, 0, -2)))


def route(k):
    """[(t, (x, z), heading)] at the walk's own speed, from the first point to the place."""
    start, gap, t0 = WALKERS[k]
    points = list(start) + [ring(gap, OUTSIDE), ring(gap, INSIDE)] + arc(gap, k * 30.0, INSIDE)
    out = [(t0, points[0], facing(points[0], points[1]))]
    t = t0
    for a, b in zip(points, points[1:]):
        t += math.hypot(b[0] - a[0], b[1] - a[1]) / SPEED
        out.append((t, b, facing(a, b)))
    return out


def clip(k):
    m = Motion(f"MeetingIntro_seat{k}", LENGTH, note="The meeting intro: arriving at the table.")
    if k in WALKERS:
        way = route(k)
        t0, t1 = way[0][0], way[-1][0]
        done = t1 + TURN + STEP  # (in the place)
        m.key(0.0, root=(-4, 0, 0), neck=(6, 0, 0), **STAND)
        m.key(t1, root=(-4, 0, 0), neck=(4, 0, 0), **STAND)
        m.key(min(LENGTH, done), root=(-1, 0, 0), neck=(-6, 0, 0), **STAND)
        m.key(LENGTH, root=(-1, 0, 0), neck=(-8, 0, 0), **STAND)
        soft(m).plant(None, t0 - 0.05, stance=0.05).plant(done + 0.15, None, stance=0.05)
        # (the legs walk on through the turn and the step: a turn on the spot is stepped round, not slid)
        walking(m, t0, done, arms=0.3)  # (a small swing: the way to the seats runs between the chairs)
        alive(m, 0.4, seed=70 + k, t0=min(LENGTH, done + 0.2))
        return m, way
    look = (k * 37) % 20 - 10
    m.key(0.0, root=(-1, look * 0.3, 0), neck=(-6, look, 0), **STAND)
    m.key(LENGTH * 0.5, root=(-1, 0, 0), neck=(-4, -look * 0.5, 0), **STAND)
    m.key(LENGTH, root=(-1, 0, 0), neck=(-8, 0, 0), **STAND)
    alive(soft(m).plant(stance=0.05), 0.5, seed=70 + k)
    return m, None


shot = Shot(NAME, "Meeting", LENGTH, note="The meeting intro: the survivors arrive at the war room.")

# A: inside by the records door: the first two come in.
shot.cam(0.0, (18.6, 5.6, -25.4), (28.0, 4.2, -20.0), fov=48)
shot.cam(1.5, (18.4, 5.4, -25.0), (25.0, 4.2, -17.0), fov=46, ease="linear")
# B: low along the case wall: two more come towards the table.
shot.cam(1.5, (24.6, 3.4, 5.6), (20.6, 4.2, -6.0), fov=44, cut=True)
shot.cam(3.0, (23.8, 3.4, 4.0), (18.0, 4.2, -2.0), fov=44, ease="linear")
# C: the west side: two step up to their places.
shot.cam(3.0, (-25.0, 4.8, 6.4), (-16.0, 4.0, -4.0), fov=44, cut=True)
shot.cam(4.0, (-24.6, 4.8, 5.6), (-16.0, 4.2, -4.0), fov=42, ease="linear")
# D: high over the table: everyone in their place.
shot.cam(4.0, (0.0, 30.0, 24.0), (0.0, 1.0, 0.0), fov=50, cut=True)
shot.cam(LENGTH, (0.0, 31.0, 20.0), (0.0, 1.0, 0.0), fov=48, ease="linear")

for k in range(12):
    motion, walk = clip(k)
    motion.build()
    a = shot.actor(f"seat:{k}", motion)
    x, z = seat(k)
    centre = facing((x, z), (0.0, 0.0))
    if walk is None:
        a.mark(0.0, (x, 0.0, z), centre)
        continue
    t0, first, heading = walk[0]
    a.mark(0.0, (first[0], 0.0, first[1]), heading)
    for t, (px, pz), h in walk:
        a.mark(t, (px, 0.0, pz), h, "linear")
    t1, last = walk[-1][0], walk[-1][1]
    # (turned to the table where the way ends, before the place, then the step into it: turning while stepping out, the
    # outer arm swept through the chair)
    a.mark(t1 + TURN, (last[0], 0.0, last[1]), centre)
    a.mark(min(LENGTH, t1 + TURN + STEP), (x, 0.0, z), centre)
    if t1 + TURN + STEP < LENGTH:
        a.mark(LENGTH, (x, 0.0, z), centre)

shot.event(0.0, "sfx", slot="mapRainGlass")
shot.event(4.0, "sfx", slot="gavel")
