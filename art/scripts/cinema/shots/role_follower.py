"""The Muerto's role cutscene (the briefing, seen only by that Muerto), 15 s: delete. After the anime's Mikami,
the follower who writes for his god: alone at a desk at night, the red of the city behind him, writing, then
stabbing the pen into the page with each name, faster and faster, until he rises to his god in ecstasy.

A  0.0-2.6   Wide from the room: a black shape at the desk against the red window, writing, steady.
B..H 2.6-6.8 The frenzy, cut to its beat: the pen driven into the page (an impact frame and "DELETE."), his
             face with the red eyes snapping down at the page or whipping aside, the pen again, closer, faster:
             strokes 1.0 s apart, then 0.7, 0.6, 0.5, 0.4.
I  6.8-9.6   In front of him: the last flurry, then the stop; he pants over the page, then lifts his head
             slowly into the camera, the eyes red.
J  9.6-12.6  In front: he throws himself back in the chair, head flung back, arms flung up and wide to the
             window: "Diavolo... I am your hand."
K  12.6-15.0 High, pulling away: the black shape with its arms wide against the red city.

The flat (maps/venues/sets/flat.py, Sets scene space, origin (360, 60)): the room x -9..9, z -7..7, 10 high;
the window across the north wall; the desk at (0, -2.6) (top 3.05, screen on its west half, lamp at the east
end), the chair behind it at (0, -5.0); the writer sits facing south, the window at his back."""

from animlib import J
from cinema.acting import alive, seated, soft
from cinema.shot import Shot
from motion import Motion

NAME = "RoleMuerto"
LENGTH = 15.0
OX, OZ = 360.0, 60.0
TOP = 3.05  # the desk top
SEAT = 2.05  # the office chair's seat
SIT = (1.3, -4.5)  # on the floor under the hips, facing south (180), east of the screen
BOOK = (0.3, -3.25)  # under the right hand


def at(x, y, z):
    return (OX + x, y, OZ + z)


# The strokes, faster and faster; the head snaps down to the page (0) or whips aside (+1 left, -1 right).
STABS = [(3.0, 0), (4.0, 1), (4.7, 0), (5.3, -1), (5.8, 0), (6.2, 1), (6.6, 0), (7.0, -1), (7.3, 0), (7.6, 1),
         (7.9, 0)]

# The Muerto ----------------------------------------------------------------------------------------------

STILL_L = J((50, 0, 20), (0.2, 0.04, -0.3))  # the left hand flat on the desk


def write(m, t0, t1, speed=1.0):
    """Writing steadily: small quick strokes, the head over the page (high enough to see the face)."""
    t, x = t0, -1.0
    while t < t1:
        x += 0.28
        if x > 1.0:
            x = -1.0
        r = J((60 + 4 * x, -4 + 8 * x, -14 + 6 * x), (-0.12 + 0.14 * x, 0.04, -0.3))
        seated(m, t, seat=SEAT, lean=-22, legs=86, neck=(-8, 6 * x, 0), rShoulder=r, lShoulder=STILL_L)
        t += 0.2 / speed


me = Motion("RoleMuerto_self", LENGTH, note="The Muerto's role cutscene: delete.")
write(me, 0.0, 2.75)
for k, (t, whip) in enumerate(STABS):
    gap = (STABS[k + 1][0] - t) if k + 1 < len(STABS) else 0.6
    antic = min(0.14, gap * 0.35)  # the wind-up shortens as the strokes come faster
    rage = min(1.0, 0.55 + 0.05 * k)  # and the body throws more into each
    # Wind up: the pen high over the shoulder, the body rearing back, the head lifting.
    seated(me, t - 0.06, "out", seat=SEAT, lean=-2 + 4 * rage, legs=86, neck=(10 * rage, -whip * 8, 0),
           rShoulder=J((150 + 15 * rage, -10, -24), (0.0, 0.3, -0.1)), lShoulder=STILL_L)
    # The stab: snapped down through the page, past it, the head thrown down or aside with it.
    seated(me, t, "snap", seat=SEAT, lean=-30 * rage, legs=86, neck=(-26 * rage, whip * 38 * rage, whip * 10),
           rShoulder=J((46, -6, -10), (-0.12, 0.04, -0.34)), lShoulder=STILL_L)
    # Settling into the next breath (if there is time before the next wind-up).
    settle = t + min(0.22, gap - antic - 0.1)
    if settle > t + 0.05:
        seated(me, settle, seat=SEAT, lean=-24 * rage, legs=86, neck=(-18 * rage, whip * 26 * rage, whip * 6),
               rShoulder=J((48, -6, -10), (-0.12, 0.04, -0.32)), lShoulder=STILL_L)
# The stop: frozen over the page, panting; then the head comes up, slowly, into the camera.
seated(me, 8.25, seat=SEAT, lean=-28, legs=86, neck=(-20, 0, 0), rShoulder=J((46, -6, -10), (-0.12, 0.04, -0.34)),
       lShoulder=STILL_L)
for k in range(3):  # three hard breaths
    tb = 8.35 + 0.22 * k
    seated(me, tb, "sine", seat=SEAT, lean=-28 + (4 if k % 2 == 0 else 0), legs=86, neck=(-20 + (3 if k % 2 == 0 else 0), 0, 0),
           rShoulder=J((46, -6, -10), (-0.12, 0.04, -0.34)), lShoulder=STILL_L)
seated(me, 9.35, "sine", seat=SEAT, lean=-14, legs=86, neck=(-2, 0, 6), rShoulder=J((50, -6, -10), (-0.12, 0.04, -0.3)),
       lShoulder=STILL_L)
# The release, still in the chair (an R6 body sat here stands lower than it sits): a crouch over the page,
# then he throws himself back, head flung back, arms flung up and wide to the red window behind him.
UP_R = J((168, -18, 46), (0.1, 0.3, 0))
UP_L = J((168, 18, -46), (-0.1, 0.3, 0))
seated(me, 9.75, "in", seat=SEAT, lean=-34, legs=86, neck=(-24, 0, 0), rShoulder=J((40, 0, -16)), lShoulder=J((40, 0, 16)))
seated(me, 10.0, "snap", seat=SEAT, lean=16, legs=80, neck=(40, 0, 0), rShoulder=UP_R, lShoulder=UP_L)
seated(me, 10.3, seat=SEAT, lean=12, legs=82, neck=(34, 0, 0), rShoulder=UP_R, lShoulder=UP_L)
for k in range(10):  # trembling with it, a silent laugh shaking the shoulders
    tk = 10.6 + 0.2 * k
    seated(me, tk, "sine", seat=SEAT, lean=12 + (3 if k % 2 else 0), legs=82, turn=(2 if k % 2 else -2),
           neck=(34 + (5 if k % 2 else 0), 0, 0), rShoulder=UP_R, lShoulder=UP_L)
seated(me, LENGTH, seat=SEAT, lean=14, legs=82, neck=(38, 0, 0), rShoulder=UP_R, lShoulder=UP_L)
soft(me, head=3.6, arms=3.2, head_damp=0.6, arm_damp=0.5)
alive(me, 0.6, seed=7, t1=2.7)
alive(me, 0.5, seed=8, t0=12.6)
me.build()

# The shot ------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Muerto's role cutscene: delete.")
shot.room = (OX - 9.0, OZ - 7.0, OX + 9.0, OZ + 7.0, 10.0)
shot.allow = {"self": ["Desk", "OfficeChair"]}  # sat at the desk, in the chair

a = shot.actor("self", me, eyes=(3.3, LENGTH))
a.mark(0.0, at(SIT[0], 0.0, SIT[1]), 180.0)
a.hold("Pen", "Right Arm", (0, -1.0, -0.15), (60, 0, 0))

book = shot.prop("NotebookOpen")
book.at(0.0, at(BOOK[0], TOP, BOOK[1]), (0, 180, 0))
book.at(LENGTH, at(BOOK[0], TOP, BOOK[1]), (0, 180, 0))


def page(t0, t1, eye, look_dy=0.05, fov=30.0):
    """A cut to the page: the pen and the hand on the notebook."""
    shot.subjects.append((t0, t1, None, True))
    target = at(BOOK[0], TOP + look_dy, BOOK[1])
    shot.cam(t0, eye, target, fov=fov, cut=True)
    shot.cam(t1, (eye[0] - 0.1, eye[1] - 0.1, eye[2] - 0.15), target, fov=fov - 1.0, ease="linear")


# A: wide from the room, a slow push: the black shape writing against the red window.
shot.pan(0.0, 2.6, "self", at(6.9, 4.6, 5.0), aim="Torso", dy=0.6, fov=44, drift=(-1.2, -0.3, -1.4), back=True)
# The frenzy, cut to the strokes.
page(2.6, 3.45, at(3.2, 5.7, -1.3))  # B
shot.pan(3.45, 4.4, "self", at(2.0, 5.5, 0.9), aim="Head", dy=-0.3, fov=40, cut=True)  # C: the face, over the lamp
page(4.4, 4.95, at(0.8, 5.9, -1.5), fov=28)  # D
shot.subjects.append((4.95, 5.55, "self", False))  # E: a tilted close from the screen's side
shot.cam(4.95, at(-1.8, 5.9, 0.5), at(1.3, 4.8, -4.2), fov=44, roll=12.0, cut=True)
shot.cam(5.55, at(-1.7, 5.8, 0.3), at(1.3, 4.7, -4.2), fov=43, roll=14.0, ease="linear")
page(5.55, 6.0, at(2.8, 5.1, -2.0), fov=27)  # F
shot.pan(6.0, 6.4, "self", at(0.6, 5.0, 0.4), aim="Head", dy=-0.2, fov=44, cut=True)  # G: low, the head whipping
page(6.4, 6.8, at(-0.2, 6.2, -1.3), look_dy=0.0, fov=32)  # H: down on the page, from in front
# I: in front of him, pushing in: the last flurry, the stop, the head coming up into the camera.
shot.pan(6.8, 9.6, "self", at(1.9, 5.4, 2.0), aim="Head", dy=-0.4, fov=40, cut=True, drift=(-0.3, 0.0, -0.6))
# J: straight on over the desk, the screen to one side and the lamp to the other, pulling back as he rises.
shot.pan(9.6, 12.6, "self", at(1.3, 4.6, 1.8), aim="Head", dy=0.5, fov=60, cut=True, drift=(0.0, 0.2, 1.2),
         back=True)  # the head thrown back: the face to the ceiling is the point
# K: high, pulling away from the black shape against the red city.
shot.subjects.append((12.6, LENGTH, None, True))
shot.cam(12.6, at(5.5, 6.4, 4.2), at(1.3, 4.6, -4.6), fov=46, cut=True)
shot.cam(LENGTH, at(6.7, 7.2, 5.8), at(1.3, 4.6, -4.6), fov=48, ease="linear")

# Faces
shot.face(0.0, "self", "Stern")
shot.face(2.9, "self", "Crazed")
shot.face(9.8, "self", "Laugh")
shot.face(12.6, "self", "Devoted")

# Sound, light and the words, on the strokes.
shot.event(0.0, "sfx", slot="penScratch")
for k, (t, _) in enumerate(STABS):
    shot.event(t, "sfx", slot="slam")
    if k < 7:  # the strokes we cut to; the last flurry is one blur
        shot.event(t, "fx", name="impact", r=255, g=40 + 20 * (k % 2), b=60, strength=0.45, dur=0.2)
        shot.event(t, "subtitle", text="DELETE." if k < 4 else "DELETE!", dur=min(0.9, (STABS[k + 1][0] - t) - 0.05))
    else:
        shot.event(t, "fx", name="flash", r=255, g=30, b=50, strength=0.3, dur=0.15)
    shot.event(t, "fx", name="shake", strength=0.12 + 0.03 * k, dur=0.15)
shot.event(9.5, "sfx", slot="hauntWhisper")
shot.event(10.0, "fx", name="impact", r=255, g=20, b=40, strength=0.6, dur=0.4)
shot.event(10.0, "sfx", slot="heartbeat")
shot.event(10.2, "subtitle", text="Diavolo... I am your hand.", dur=2.2)
# The role card, as captions over the calmer moments (the game fills them in).
shot.event(0.4, "card", key="role", dur=2.1)
shot.event(7.0, "card", key="win", dur=2.4)
shot.event(10.6, "card", key="names", dur=1.9)
shot.event(12.7, "card", key="move", dur=2.2)
