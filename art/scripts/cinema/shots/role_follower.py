"""The Muerto's role cutscene (the briefing, seen only by that Muerto): "Delete. Delete. DELETE." Rebuilt from scratch
(2026-10-28, the owner: "completely redo these two"; "the stabs are slashes, not pressure points"). After Mikami's
"delete" (Death Note, episode 36; art/refs/cinema/RoleMuerto.toml): he writes a name neatly, then raises the pen and
SLASHES it out, the arm sweeping right across the page and on up into the air, the whole body thrown into it, the
head whipping; again and again, faster, forehand and backhand, until the page is red with slashes; a breath; then
he throws himself back with his arms wide, in ecstasy, against the red city.

A  0.0-2.6   Wide and low from the room, creeping in: a black shape at the desk against the red window, writing
             neatly.
B  2.6-4.3   High over the page from his left: the pen finishes a name, rises out of the frame... and slashes down
             across it (DELETE, 3.4).
C  4.3-6.5   Low from in front, over the desk's edge, hand-held and tilted: the whole body in the swings, a
             backhand, a forehand, a backhand.
D  6.5-8.0   Close on his face, tilted the other way: the stare, the head jerking with each
             of three faster slashes, the arm tearing through the edge of the frame.
E  8.0-9.6   Straight down on the page: the last and biggest slash rips the whole way across; the pen stops,
             pressed into the page, trembling. Red slashes everywhere.
F  9.6-11.6  In front of him, creeping in: panting over the page; the head comes up slowly into the camera, staring,
             a smile.
G  11.6-14.4 Low and wide from the room, pulling back and rising: he throws himself back in the chair, arms flung
             wide, head back, the red flooding in behind him.

The flat (maps/venues/sets/flat.py, Sets scene space, origin (360, 60)): the room x -9..9, z -7..7, 10 high; the
window across the north wall; the desk at (0, -2.6) (6.7 by 3.4, top 3.42, screen on its west half); the chair at
(1.3, -5.5); the writer sits facing south (180), the window at his back, so his right is -x."""

from animlib import J
from cinema.acting import body_reach, seat_offset, soft, to_torso
from cinema.shot import Shot
from emotes.kit import basis_angles, hold
from motion import Motion

NAME = "RoleMuerto"
LENGTH = 14.4
OX, OZ = 360.0, 60.0
TOP = 3.05 * 1.12  # the desk top (flat.DESK_SCALE)
SEAT = 1.76  # the office chair's seat (the chair is set at 0.85 scale)
LEGS = 88  # level thighs, low enough to pass under the desk top (R6 legs do not bend)
SIT = (1.3, -5.0)  # on the floor under the hips, facing south (180)
MANUAL = 0.55  # Death's Manual at this size
BOOK = (0.7, -3.35)  # its middle (the written page is centred on it), a little to his right
BOOK_Y = TOP + 0.06 + 0.215 * MANUAL  # on the desk's loose papers (its pivot is its middle)
PAGE_Y = BOOK_Y + 0.139 * MANUAL  # the page's face (ModelCatalog Grimoire.page.at)
ABOVE = 0.78  # the fist this far over the page puts the nib on it (PEN_GRIP)


def at(x, y, z):
    return (OX + x, y, OZ + z)


def front(f, right, y):
    """The set's space for a place `f` studs in front of him and `right` studs to his right, `y` high."""
    return at(SIT[0] - right, y, SIT[1] + f)


def page(x, d, above=ABOVE):
    """(the character's frame) a place over the page: `x` across it (+ to his right), `d` down it (+ towards him)."""
    return (SIT[0] - BOOK[0] + x, PAGE_Y + above, -(BOOK[1] - SIT[1]) + d)


# The slashes: (the moment the nib crosses the page's middle, forehand +1 / backhand -1). Forehand: from high over
# the right shoulder, down across the page from its far right to its near left, and on up across the body to the
# left. Backhand: the other way. They come faster and faster; the last is the biggest.
SLASHES = [(3.4, 1), (4.7, -1), (5.35, 1), (5.95, -1), (6.85, 1), (7.3, -1), (7.7, 1), (8.5, -1)]  # (the last ends on his right: the arm never lies across him)
WRITE_T = (0.0, 2.95)  # writing neatly
STOP = 8.75  # the pen stops on the page after the last
UP_T = (10.0, 11.3)  # the head comes up into the camera
THROW = 11.95  # thrown back in the chair

# The Muerto ----------------------------------------------------------------------------------------------

PEN_DIR = (-0.3, -0.6, -0.75)  # the forearm writing: forward and down, the fist turned in a little
DESK_L = None  # (the left hand flat on the desk, left of the book: solved per body)


def body(lean, turn=0.0, roll=0.0, legs=LEGS):
    """The seated body: the hips on the seat, leaning `lean` (- forward), turned `turn` (+ to his left); the thighs
    stay level however he leans (sloping, they rise into the desk's top)."""
    hip = legs - lean
    turn = max(-11.0, min(11.0, turn))  # (twisted further, a knee swings into the desk)
    joints = dict(root=(lean, turn, roll), rHip=J((hip, -turn, 3), (0, -0.05, 0)),
                  lHip=J((hip, -turn, -3), (0, -0.05, 0)))
    return joints, seat_offset(joints, SEAT)


def flat_left(joints, off):
    """The left hand flat on the desk beside the book, holding the page down (it stays put as the body throws)."""
    return body_reach(-1, joints, off, (page(0, 0)[0] - 1.25, TOP + 0.75, page(0, 0.3)[2]),
                      direction=(0.25, -0.55, -0.8))


def pen_on(joints, off, x, d, above=ABOVE, direction=PEN_DIR):
    return body_reach(1, joints, off, page(x, d, above), direction=direction)


def key(m, t, ease, lean, turn=0.0, roll=0.0, neck=(0, 0, 0), right=None, left=None, legs=LEGS):
    """A key: the body, the head, the right arm as a function of the body (or a value), the left on the desk."""
    joints, off = body(lean, turn, roll, legs)
    r = right(joints, off) if callable(right) else right
    lv = (left(joints, off) if callable(left) else left) if left is not None else flat_left(joints, off)
    m.key(round(t, 4), ease, offset=off, neck=neck, rShoulder=r, lShoulder=lv, **joints)


me = Motion("RoleMuerto_self", LENGTH, note="The Muerto's role cutscene: delete.")

# A: writing a name, neat and quick: short strokes along a line, the head bowed over it (lifted enough to show the
# face), the body still.
strokes = [(-0.32, -0.3), (-0.16, -0.32), (0.0, -0.29), (0.14, -0.31), (0.28, -0.3), (-0.3, -0.1), (-0.12, -0.12),
           (0.06, -0.1), (0.22, -0.11)]
t = WRITE_T[0]
k = 0
while t < WRITE_T[1]:
    x, d = strokes[k % len(strokes)]
    key(me, t, "sine", -16, turn=-3, neck=(-16, 4, 0), right=lambda j, o, x=x, d=d: pen_on(j, o, x, d))
    key(me, t + 0.12, "sine", -16, turn=-3, neck=(-16, 4, 0),
        right=lambda j, o, x=x, d=d: pen_on(j, o, x + 0.07, d + 0.02, ABOVE + 0.06))
    t += 0.27
    k += 1

# The slashes. Each: the pen drawn up and back (the wind-up, held a hair), snapped down onto the far end of the line,
# dragged hard across the page in two frames, and flung on up and out the other side (the follow-through), the body
# rearing up for it and thrown down through it, the head whipping the way the arm goes.
FAR, NEAR = -0.55, 0.45  # down the page: where a slash starts and ends
for n, (t, side) in enumerate(SLASHES):
    nxt = SLASHES[n + 1][0] if n + 1 < len(SLASHES) else STOP + 0.4
    prev = SLASHES[n - 1][0] if n else WRITE_T[1]
    rage = min(1.0, 0.6 + 0.07 * n)
    big = 1.35 if n == len(SLASHES) - 1 else 1.0
    antic = min(0.32, (t - prev) * 0.45)
    s = side
    # the wind-up: forehand, the fist high over the right shoulder; backhand, up by the left ear
    wind = (1.5, 6.9, -0.35) if s > 0 else (-1.9, 6.4, 0.0)  # (beside the head, never in front of the face)
    key(me, t - 0.06 - antic, "sine", -4 * rage, turn=-14 * s * rage, roll=-3 * s, neck=(10 * rage, -18 * s, -6 * s),
        right=lambda j, o, w=wind: body_reach(1, j, o, w))
    key(me, t - 0.075, "out", -2 * rage, turn=-17 * s * rage * big, roll=-4 * s, neck=(14 * rage, -22 * s, -8 * s),
        right=lambda j, o, w=wind: body_reach(1, j, o, (w[0] + 0.1 * s, w[1] + 0.25, w[2] + 0.05)))
    # onto the line's far end, and across it (the nib on the page)
    x0, x1 = (0.42, -0.42) if s > 0 else (-0.42, 0.42)
    key(me, t - 0.035, "in", -16 * rage, turn=-6 * s, neck=(2, -8 * s, 0),
        right=lambda j, o, x0=x0: pen_on(j, o, x0 * big, FAR))
    # (the body throws forward through it but the head stays up, whipping round: a bowed head is only hair)
    key(me, t + 0.035, "linear", -22 * rage, turn=8 * s, neck=(4, 18 * s, 8 * s),
        right=lambda j, o, x1=x1: pen_on(j, o, x1 * big, NEAR))
    # the follow-through: off the page and flung out low past its edge, the head thrown the same way
    follow = (-2.3, 4.6, -1.2) if s > 0 else (2.8, 4.8, -1.0)  # (under the face: never across it)
    if n == len(SLASHES) - 1:
        break  # (the last one stays on the page)
    key(me, t + 0.13, "out", -15 * rage, turn=16 * s * rage, roll=1.5 * s, neck=(6, 34 * s * rage, 12 * s),
        right=lambda j, o, f=follow: body_reach(1, j, o, f))
    if nxt - t > 0.5:  # time to breathe before the next wind-up: the arm sags back towards the page
        key(me, t + 0.3, "sine", -15 * rage, turn=10 * s, neck=(2, 22 * s, 6 * s),
            right=lambda j, o, f=follow: body_reach(1, j, o, (f[0] * 0.6 + 0.6, f[1] - 0.1, f[2])))

# The last slash ends with the pen ground into the page: pressed there, trembling, the eyes on it.
for k in range(5):
    tt = 8.62 + 0.09 * k
    key(me, tt, "linear", -22, turn=4 + (2 if k % 2 else -1), neck=(-2, 10 + (3 if k % 2 else 0), 4),
        right=lambda j, o, k=k: pen_on(j, o, 0.42 * 1.35 + 0.02 * (k % 2), NEAR, ABOVE - 0.04))
# F: panting over the page, three heaves; then the head comes up, slowly, into the camera.
for k in range(4):
    tt = STOP + 0.3 + 0.36 * k
    up = k % 2
    key(me, tt, "sine", -22 + 5 * up, turn=3, neck=(-6 + 4 * up, 6, 3),
        right=lambda j, o: pen_on(j, o, 0.5, NEAR, ABOVE + 0.05))
key(me, UP_T[0], "sine", -21, turn=2, neck=(-6, 4, 3), right=lambda j, o: pen_on(j, o, 0.5, NEAR, ABOVE + 0.1))
key(me, UP_T[1], "sine", -12, turn=0, neck=(12, 0, 9), right=lambda j, o: pen_on(j, o, 0.45, NEAR, ABOVE + 0.25))
key(me, THROW - 0.3, "sine", -13, turn=0, neck=(13, 0, 11), right=lambda j, o: pen_on(j, o, 0.45, NEAR, ABOVE + 0.25))
# G: a crouch down over it... then thrown back in the chair, the head flung back, the arms flung up and wide (the pen
# still in his fist), trembling with a silent laugh.
key(me, THROW - 0.12, "in", -26, neck=(0, 0, 0), right=lambda j, o: pen_on(j, o, 0.3, NEAR - 0.2, ABOVE + 0.4),
    left=lambda j, o: body_reach(-1, j, o, (-1.1, 4.6, -1.0)))


def wide(j, o, side, lift=0.0):
    return body_reach(side, j, o, (side * 3.1, 6.6 + lift, -0.6))


key(me, THROW, "snap", 18, neck=(42, 0, 0), right=lambda j, o: wide(j, o, 1, 0.3),
    left=lambda j, o: wide(j, o, -1, 0.3))
key(me, THROW + 0.3, "out", 14, neck=(36, 0, 0), right=lambda j, o: wide(j, o, 1),
    left=lambda j, o: wide(j, o, -1))
for k in range(9):
    tt = THROW + 0.55 + 0.21 * k
    key(me, tt, "sine", 14 + (3 if k % 2 else 0), turn=(2 if k % 2 else -2),
        neck=(36 + (5 if k % 2 else 0), 0, 0), right=lambda j, o, k=k: wide(j, o, 1, 0.12 * (k % 2)),
        left=lambda j, o, k=k: wide(j, o, -1, 0.12 * (k % 2)))
key(me, LENGTH, "sine", 15, neck=(40, 0, 0), right=lambda j, o: wide(j, o, 1, 0.2),
    left=lambda j, o: wide(j, o, -1, 0.2))
soft(me, head=4.2, arms=5.0, head_damp=0.55, arm_damp=0.55)
me.build()


def pen_grip():
    """The pen in his right fist as he writes (solved on the page's middle): its nib (0.54 below its middle, along its
    -y) on the page under the fist, its top leaning back towards him as a writing pen does."""
    import numpy as np

    joints, off = body(-16, -3)
    arm = pen_on(joints, off, 0.0, 0.0)
    nib = np.array([0.15, -1.0, -0.5])
    nib = nib / np.linalg.norm(nib)
    tip = np.array(page(0.0, 0.0, 0.0))
    middle = tip - nib * 0.54
    pos = to_torso(joints, off, tuple(middle))
    axis = to_torso(joints, off, direction=tuple(-nib))
    return hold("Right Arm", {"rShoulder": arm}, pos, basis_angles(axis, (0.0, 0.0, 1.0)))


PEN_GRIP = pen_grip()

# The shot ------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Muerto's role cutscene: delete.")
shot.room = (OX - 9.0, OZ - 7.0, OX + 9.0, OZ + 7.0, 10.0)
shot.allow = {"self": ["OfficeChair"]}  # in the chair (never into the desk)

a = shot.actor("self", me)  # (his own eyes: no glowing blocks, the owner, 2026-10-28)
a.mark(0.0, at(SIT[0], 0.0, SIT[1]), 180.0)
a.hold("Pen", "Right Arm", PEN_GRIP[0]["p"], PEN_GRIP[1]["r"])

book = shot.prop("Grimoire", scale=MANUAL, open=1.0)
book.at(0.0, at(BOOK[0], BOOK_Y, BOOK[1]), (0, 0, 0))
book.at(LENGTH, at(BOOK[0], BOOK_Y, BOOK[1]), (0, 0, 0))
PAGE = at(BOOK[0], PAGE_Y, BOOK[1])

# (The desk's screen stands 2.5 studs to his right and its lamp 1.4 to his left, both at head height and in front
# of him: from the front they frame him; from either side they hide him. The cameras keep to the front, or go high.)
# A: wide and low from the room, creeping in: the black shape writing against the red window, the screen's glow on
# one side of him, the lamp on the other.
shot.pan(0.0, 2.6, "self", front(9.4, 0.4, 3.7), aim="Torso", dy=0.5, fov=44, drift=(0.0, 0.25, -1.8))
# B: low over the far side of the desk, the page filling the foreground and him bent over it beyond: the name
# finished, the pen up out of the frame... and the nib tearing across the page (the anime's shot of the pen).
shot.subjects.append((2.6, 4.3, None, True))
look_b = (PAGE[0] - 0.05, PAGE[1] + 0.35, PAGE[2] - 0.45)
shot.cam(2.6, (PAGE[0] + 0.55, PAGE[1] + 0.75, PAGE[2] + 1.75), look_b, fov=50, roll=-5.0, cut=True)
shot.cam(4.3, (PAGE[0] + 0.5, PAGE[1] + 0.7, PAGE[2] + 1.5), look_b, fov=48, roll=-7.0, ease="linear")
# C: low in front, over the desk's edge, hand-held and tilted: the whole body in the swings.
shot.pan(4.3, 6.5, "self", front(5.4, 0.5, TOP + 0.95), aim="Head", dy=-0.5, fov=62, cut=True, drift=(0.0, 0.1, 0.4),
         roll=-11.0, operator=True, seed=3)
# D: closer, from a little to his right, tilted the other way: the face jerking with each slash.
shot.pan(6.5, 8.0, "self", front(4.3, -0.2, 4.9), aim="Head", dy=-0.15, fov=46, cut=True, drift=(0.0, 0.0, -0.3),
         roll=12.0, operator=True, seed=5)
# E: low over the desk again, from the other side, tilted the other way and creeping in: the last slash rips the
# whole way across the page in the foreground, the pen ground into it, his face beyond staring down at it.
shot.subjects.append((8.0, 9.6, None, True))
look_e = (PAGE[0] + 0.1, PAGE[1] + 0.6, PAGE[2] - 0.7)
shot.cam(8.0, (PAGE[0] + 0.45, PAGE[1] + 0.85, PAGE[2] + 1.9), look_e, fov=52, roll=9.0, cut=True)
shot.cam(9.6, (PAGE[0] + 0.4, PAGE[1] + 0.8, PAGE[2] + 1.5), look_e, fov=48, roll=11.0, ease="linear")
# F: in front, creeping in: panting, then the head comes up into the camera.
shot.pan(9.6, 11.6, "self", front(7.2, -0.1, 4.7), aim="Head", dy=-0.3, fov=36, cut=True, drift=(0.0, 0.0, -0.9))
# G: low and wide from the room, pulling back and rising as he throws himself back.
shot.pan(11.6, LENGTH, "self", front(6.2, 0.4, 4.4), aim="Torso", dy=1.4, fov=60, cut=True, drift=(0.0, 1.6, 2.6),
         back=True)  # (the head thrown back: the face to the ceiling is the point)

# The lens: barely soft, only to put the eye where the cut is about.
for t, part, radius in ((0.0, "Torso", 8.0), (2.6, "Right Arm", 2.5), (4.3, "Head", 4.0), (6.5, "Head", 2.5),
                        (8.0, "Right Arm", 3.0), (9.6, "Head", 3.0), (11.6, "Torso", 6.0)):
    shot.event(t, "fx", name="focus", slot="self", part=part, radius=radius, far=0.12, near=0.06)

# The light: the red city through the window behind him a hard rim; the screen's cold light flickering up into his
# face from his right; the desk lamp a low warm fill from his left; once he throws himself back the red floods in
# and a white-hot glare burns behind him (the anime's). The grade: dark, pushed red. His own face and
# eyes throughout.
HEAD = at(SIT[0], 4.6, SIT[1])
shot.grade = (0.26, 0.06, -0.05, (255, 226, 226))
shot.light("spot", at(1.3, 7.5, -6.9), HEAD, color=(255, 45, 55), brightness=2.6, range=10, angle=70)
shot.light("spot", at(-0.8, TOP + 1.0, -2.4), HEAD, color=(150, 200, 255), brightness=1.5, range=7, angle=60,
           flicker=0.35)
shot.light("spot", at(3.6, TOP + 1.1, -2.4), at(1.3, 4.0, -4.6), color=(255, 180, 110), brightness=0.8, range=6,
           angle=70)
shot.light("spot", (PAGE[0], PAGE[1] + 3.0, PAGE[2] + 0.4), PAGE, color=(255, 236, 220), brightness=1.2, range=5,
           angle=40, shadows=False, show=(2.6, 9.6))  # (the page lit for the inserts)
shot.light("point", at(1.3, 5.0, -6.5), color=(255, 40, 50), brightness=1.6, range=12, shadows=False,
           show=(THROW, LENGTH))
shot.light("spot", at(1.3, 6.0, -6.8), HEAD, color=(255, 210, 220), brightness=3.0, range=9, angle=80,
           show=(THROW, LENGTH))

# Sound and effects, on the slashes: the scrape of the pen tearing across, a red slash cut into the page, the
# streaks bursting off the nib along the stroke (harder each time), the frame jolting.
shot.event(0.0, "sfx", slot="penScratch")
for n, (t, side) in enumerate(SLASHES):
    last = n == len(SLASHES) - 1
    shot.event(t - 0.03, "sfx", slot="knifeScrape")
    shot.event(t + 0.02, "fx", name="inkslash", seed=n + 1)
    # one line slashed across the screen along the stroke (the owner: "one line travelling the screen")
    x0, x1 = (0.42, -0.42) if side > 0 else (-0.42, 0.42)
    big = 1.35 if last else 1.0
    ends = [[round(v, 3) for v in at(BOOK[0] - x * big, PAGE_Y, BOOK[1] - dd)] for x, dd in ((x0, -0.55), (x1, 0.45))]
    shot.event(t - 0.02, "fx", name="slash", p0=ends[0], p1=ends[1], r=255, g=40 + 15 * (n % 2), b=60,
               strength=0.55 + 0.04 * n + (0.2 if last else 0), dur=0.3 + (0.15 if last else 0))
    shot.event(t, "fx", name="shake", strength=0.14 + 0.03 * n + (0.2 if last else 0), dur=0.16)
shot.event(SLASHES[-1][0], "fx", name="still", r=255, g=30, b=45, dur=0.28)
shot.event(SLASHES[-1][0], "sfx", slot="slam")
shot.event(UP_T[0], "sfx", slot="hauntWhisper")
shot.event(THROW, "fx", name="flash", r=255, g=60, b=70, strength=0.45, dur=0.5)
shot.event(THROW, "sfx", slot="heartbeat")
shot.event(THROW, "fx", name="shake", strength=0.3, dur=0.3)

SAID = SLASHES[0][0]
shot.audio(voice="voiceMuerto", voice_at=SAID, bed="bedMuerto")
shot.line(SAID, "Delete. Delete. Delete. DELETE. DELETE. DELETE. DELETE. DELETE!",
          times=[round(t - SAID, 3) for t, _ in SLASHES])
