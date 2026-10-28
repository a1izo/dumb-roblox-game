"""Diavolo's role cutscene (the briefing, seen only by Diavolo): "I'll take a potato chip... and EAT IT!" Rebuilt from
scratch (2026-10-28, the owner: "completely redo these two"). After the anime's potato chip scene (Death Note, episode
8; art/refs/cinema/RoleDiavolo.toml): a student at his desk at night, studying, eating crisps; between the crisps a
name goes into the Manual; the news on the television flatlines; then a crisp, raised slowly, held... and eaten like a
verdict, the Deathsinger drawn out of the dark behind him laughing with him. Cut through it (the owner, 2026-10-28:
"I like the camera concept, mix it around"), what the hidden cameras in the room see: a good student at his books.

A  0.0-3.2   The hidden camera in the front corner, black and white: a student at his desk at night, writing; a hand
             goes into the bag on the dossier and a crisp is eaten without looking up.
B  3.2-5.4   Low over the desk, the page in the foreground and him beyond: the pen writes a name in hard quick
             strokes and underlines it with a flick.
C  5.4-7.0   Close, from in front on his left: the eyes come up off the page to the television.
S  7.0-8.2   The hidden camera on the side wall: the television flares, the flatline; he only sits and watches the
             news. "I'll take a potato chip..." starts over it.
D  8.2-11.2   Across the desk, pushing in: "I'll take a potato chip..." the hand into the bag, a crisp lifted slowly
             up beside his face, the head turning to it; held.
E  11.2-12.8  Low and close on the crisp's side, tilted, half his face in the dark: "...and EAT IT!" the snap to the
             mouth, the crunch, the frame stopping red, the crumbs flying; he chews, grinning.
F  12.8-15.6 Low and wide from the room, rising: he leans back into the chair laughing, and behind him the
             Deathsinger is drawn out of the dark, eyes first, leaning in over his shoulder, laughing with him.
G  15.6-19.6 The hidden camera in the corner behind him: a student at his desk, writing. Nothing behind him.

The study (maps/venues/sets/study.py, Sets scene space): the room x -12..12, z -10..10, 14 high; the window in the
north wall; the desk before it at (0, -5.4) (x -3.3..3.3, z -7.0..-3.8, top 2.7): its banker's lamp at x -2.3 (on his
right), the pen stand at (1.3, -6.2) and the dossier at (1.4, -5.2) (on his left), the knee hole between the
pedestals; the chair behind it at (0, -8.0); the television across the room at (1, 6.6) facing the desk. He sits
facing south (180), so his right is -x."""

from animlib import J
from cinema import framing
from cinema.acting import body_reach, soft, to_torso
from cinema.shot import Shot
from emotes.kit import basis_angles, hold, reach
from motion import Motion

NAME = "RoleDiavolo"
LENGTH = 19.6
TOP = 2.7  # the desk top
HIP = 2.15  # on the chair's cushion
LEGS = 52  # the thighs sloping under the desk's edge (R6 legs do not bend)
SIT = (0.0, -7.8)  # on the floor under the hips, facing south (180)
MANUAL = 0.55  # Death's Manual at this size
BOOK = (-0.4, -6.05)  # its middle (the written page is centred on it): in front of him, a little to his right
BOOK_Y = TOP + 0.01 + 0.215 * MANUAL  # on the leather inlay (its pivot is its middle)
PAGE_Y = BOOK_Y + 0.139 * MANUAL  # the page's face (ModelCatalog Grimoire.page.at)
BAG = (1.6, -5.72)  # the bag of crisps stood on the dossier, by his left hand (clear of his face from the front)
BAG_SCALE = 1.15
BAG_Y = TOP + 0.12
SINGER = (-2.6, -10.0)
ABOVE = 0.78  # the fist this far over the page puts the nib on it (PEN_GRIP)

# (3-4 s longer, the owner, 2026-10-28: the beats given room, not slowed)
CASUAL = (1.8, 2.8)  # the first crisp: into the bag .. eaten
WRITE = (3.4, 5.1)  # the name
LOOK = (5.6, 7.05)  # the eyes up to the television .. the flatline
SAID = 7.7  # "I'll take a potato chip..."
TAKE = (7.75, 8.35)  # into the bag .. a crisp out
RAISED = 9.6  # up beside the face, held through the pause
BITE = 11.4  # "...and EAT IT!"
BACK = 12.9  # leaning back, laughing
STUDY = 15.35  # back over his books, the good student
CUTS = (3.2, 5.4, 7.0, 8.2, 11.2, 12.8)  # B, C, the side camera, D, E, F


def front(f, right, y):
    """The set's space for a place `f` studs in front of him and `right` studs to his right, `y` high."""
    return (SIT[0] - right, y, SIT[1] + f)


def page(x, d, above=ABOVE):
    """(the character's frame) a place over the page: `x` across it (+ to his right), `d` down it (+ towards him)."""
    return (SIT[0] - BOOK[0] + x, PAGE_Y + above, -(BOOK[1] - SIT[1]) + d)


IN_BAG = (SIT[0] - BAG[0], BAG_Y + 1.06 * BAG_SCALE - 0.1, -(BAG[1] - SIT[1]))  # (the character's frame) its mouth

# Diavolo ---------------------------------------------------------------------------------------------------

PEN_DIR = (-0.3, -0.6, -0.75)
# the crisp, raised up beside the face (the elbow out) and bitten (torso frame: emotes/props.py chipAndPen, mirrored to
# the left hand)
RAISE_AT, RAISE_DIR = (-0.95, 1.75, -0.9), (-0.15, 0.75, -0.55)
BITE_AT, BITE_DIR = (-0.05, 1.0, -0.58), (0.55, 0.55, -0.6)
MOUTH_L = reach(-1, BITE_AT, direction=BITE_DIR)
RAISE_L = reach(-1, RAISE_AT, direction=RAISE_DIR)


def body(lean, turn=0.0, roll=0.0):
    joints = dict(root=(lean, turn, roll), rHip=J((LEGS - lean * 0.5, -turn, 4)), lHip=J((LEGS - lean * 0.5, -turn, -4)))
    return joints, (0.0, HIP - 2.0, 0.0)


def pen_on(joints, off, x, d, above=ABOVE):
    return body_reach(1, joints, off, page(x, d, above), direction=PEN_DIR)


def left_rest(joints, off):
    """The left hand at rest on the desk by the page."""
    return body_reach(-1, joints, off, page(-1.3, 0.35, 0.55), direction=(0.25, -0.5, -0.85))


def bag_hand(joints, off, deep=0.0):
    return body_reach(-1, joints, off, (IN_BAG[0], IN_BAG[1] - deep, IN_BAG[2]), direction=(0.3, -0.45, -0.85))


def key(m, t, ease="smooth", lean=-8.0, turn=0.0, roll=0.0, neck=(0, 0, 0), right=None, left=None):
    joints, off = body(lean, turn, roll)
    r = right(joints, off) if callable(right) else right
    lv = left(joints, off) if callable(left) else (left if left is not None else left_rest(joints, off))
    m.key(round(t, 4), ease, offset=off, neck=neck, rShoulder=r, lShoulder=lv, **joints)


d = Motion("RoleDiavolo_self", LENGTH, note="Diavolo's role cutscene: and eat it.")
WRITING = dict(lean=-8, turn=-2, neck=(-14, 4, 0))
STROKES = [(-0.3, -0.3), (-0.12, -0.32), (0.06, -0.29), (0.22, -0.31), (-0.28, -0.1), (-0.1, -0.12), (0.08, -0.1)]


def write(t0, t1, line=0.0, speed=1.0):
    """Writing: short quick strokes along a line, the head over the page (lifted enough to show the face)."""
    t, k = t0, 0
    while t < t1 - 0.05:
        x, dd = STROKES[k % len(STROKES)]
        key(d, t, "sine", right=lambda j, o, x=x, dd=dd: pen_on(j, o, x, dd + line), **WRITING)
        key(d, t + 0.11 / speed, "sine", right=lambda j, o, x=x, dd=dd: pen_on(j, o, x + 0.07, dd + line + 0.02, ABOVE + 0.07),
            **WRITING)
        t += 0.25 / speed
        k += 1


# A: writing; a crisp from the bag, eaten without looking up.
write(0.0, CASUAL[0])
key(d, CASUAL[0], "sine", right=lambda j, o: pen_on(j, o, 0.1, -0.2, ABOVE + 0.15), **WRITING)
key(d, CASUAL[0] + 0.3, "sine", lean=-8, turn=4, neck=(-14, 6, 0), right=lambda j, o: pen_on(j, o, 0.1, -0.2, ABOVE + 0.15),
    left=lambda j, o: bag_hand(j, o, 0.25))
key(d, CASUAL[0] + 0.45, "out", lean=-8, turn=4, neck=(-14, 6, 0), right=lambda j, o: pen_on(j, o, 0.1, -0.2, ABOVE + 0.15),
    left=lambda j, o: bag_hand(j, o))
key(d, CASUAL[1] - 0.2, "sine", lean=-6, neck=(-10, 2, 0), right=lambda j, o: pen_on(j, o, 0.1, -0.2, ABOVE + 0.15),
    left=MOUTH_L)
for k in range(3):  # chewing, the eyes still on the page
    key(d, CASUAL[1] + 0.15 * k, "sine", lean=-7, neck=(-12 + 2 * (k % 2), 2, 0),
        right=lambda j, o: pen_on(j, o, 0.1, -0.2, ABOVE + 0.15), left=MOUTH_L if k < 1 else None)
# B: the name: hard quick strokes along a fresh line, then the underline: one long stroke, flicked off at its end.
write(WRITE[0], WRITE[1] - 0.45, line=0.25, speed=1.35)
key(d, WRITE[1] - 0.35, "sine", lean=-9, turn=-2, neck=(-16, 4, 0), right=lambda j, o: pen_on(j, o, -0.35, 0.4))
key(d, WRITE[1], "in", lean=-10, turn=-4, neck=(-16, 2, 0), right=lambda j, o: pen_on(j, o, 0.35, 0.42))
key(d, WRITE[1] + 0.1, "out", lean=-8, turn=-4, neck=(-14, 2, 0), right=lambda j, o: pen_on(j, o, 0.6, 0.3, ABOVE + 0.45))
key(d, LOOK[0] - 0.2, "sine", lean=-8, turn=-2, neck=(-14, 2, 0), right=lambda j, o: pen_on(j, o, 0.5, 0.3, ABOVE + 0.4))
# C: the eyes come up off the page to the television ahead, the head following; still. The flatline. The corner of
# the mouth.
key(d, LOOK[0] + 0.35, "sine", lean=-6, turn=-1, neck=(-2, 0, 0), right=lambda j, o: pen_on(j, o, 0.5, 0.3, ABOVE + 0.4))
key(d, LOOK[1], lean=-5, neck=(0, -2, 0), right=lambda j, o: pen_on(j, o, 0.5, 0.3, ABOVE + 0.4))
key(d, SAID - 0.1, "sine", lean=-5, neck=(-1, -2, 5), right=lambda j, o: pen_on(j, o, 0.5, 0.3, ABOVE + 0.4))
REST_R = lambda j, o: body_reach(1, j, o, page(0.95, 0.55, 0.5), direction=(-0.2, -0.5, -0.85))  # noqa: E731
# (the pen hand laid down on the desk to his right, out of the way of the face)
# D: "I'll take a potato chip...": the hand into the bag, a crisp out, raised slowly up beside the face in an arc,
# the elbow out, the head turning to it; held there through the pause.
key(d, TAKE[0] + 0.25, "sine", lean=-6, turn=5, neck=(-6, 8, 4), right=lambda j, o: pen_on(j, o, 0.5, 0.3, ABOVE + 0.4),
    left=lambda j, o: bag_hand(j, o, 0.3))
key(d, TAKE[1], "out", lean=-5, turn=4, neck=(-4, 8, 3), right=lambda j, o: pen_on(j, o, 0.5, 0.3, ABOVE + 0.4),
    left=lambda j, o: bag_hand(j, o, -0.15))
key(d, TAKE[1] + 0.6, "sine", lean=-2, turn=1, neck=(4, 12, 2), right=REST_R,
    left=reach(-1, (-1.1, 1.2, -1.1), direction=(-0.2, 0.6, -0.7)))
key(d, RAISED, "sine", lean=0, turn=-3, neck=(10, 16, -3), right=REST_R,
    left=RAISE_L)
key(d, (RAISED + BITE) / 2, "sine", lean=1, turn=-3, neck=(11, 17, -6), right=REST_R,
    left=reach(-1, (RAISE_AT[0] - 0.01, RAISE_AT[1] + 0.02, RAISE_AT[2]), direction=RAISE_DIR))  # (held: a slow tilt)
key(d, BITE - 0.18, "sine", lean=1, turn=-4, neck=(12, 18, -5), right=REST_R,
    left=reach(-1, (RAISE_AT[0] - 0.02, RAISE_AT[1] + 0.05, RAISE_AT[2]), direction=RAISE_DIR))
# E: "...and EAT IT!": snapped to the mouth, the head meeting it, the body snapping forward into it; the crunch.
key(d, BITE, "snap", lean=-8, turn=2, neck=(-6, 6, 0), right=REST_R, left=MOUTH_L)
key(d, BITE + 0.15, "out", lean=-10, turn=2, neck=(-9, 4, 0), right=REST_R,
    left=reach(-1, (-0.75, 0.9, -1.0)))
for k in range(4):  # chewing, the eyes front, the grin spreading
    key(d, BITE + 0.4 + 0.2 * k, "sine", lean=-6, neck=(-3 - 3 * (k % 2), -2, 3), right=REST_R)
key(d, BACK - 0.6, "sine", lean=-5, neck=(-1, -2, 6), right=REST_R)  # (the grin, held)
# F: back into the chair, laughing (the shoulders shaking, the head thrown back), the arms out on the chair's arms.
ARM_R, ARM_L = J((-4, 0, 24)), J((-4, 0, -24))
key(d, BACK - 0.25, "sine", lean=-2, neck=(4, 0, 0), right=J((30, 0, 30)), left=J((30, 0, -30)))
key(d, BACK, "out", lean=10, neck=(16, 0, 0), right=ARM_R, left=ARM_L)
for k in range(7):
    key(d, BACK + 0.22 * (k + 1), "sine", lean=10 + (3 if k % 2 else 0), neck=(16 + (5 if k % 2 else 0), 0, 0),
        right=ARM_R, left=ARM_L)
# G: snapped back over his books, writing again, the good student (what the hidden camera sees).
key(d, STUDY - 0.65, "sine", lean=4, neck=(6, 0, 0), right=J((10, 0, 72)), left=J((10, 0, -72)))  # (out to the sides...
key(d, STUDY - 0.4, "sine", lean=2, neck=(2, 0, 0), right=J((90, 0, 12)), left=J((92, 0, -14)))  # (up over the desk's edge)
key(d, STUDY - 0.2, "sine", lean=-4, neck=(-6, 0, 0), right=lambda j, o: pen_on(j, o, 0.3, 0.0, ABOVE + 0.6))
write(STUDY, LENGTH, line=0.5, speed=0.9)
key(d, LENGTH, "sine", right=lambda j, o: pen_on(j, o, 0.0, 0.45), **WRITING)
soft(d, head=3.4, arms=3.4, arm_damp=0.6)
d.build()


def pen_grip():
    """The pen in his right fist as he writes (solved on the page's middle): its nib (0.54 below its middle, along its
    -y) on the page under the fist, its top leaning back towards him as a writing pen does."""
    import numpy as np

    joints, off = body(WRITING["lean"], WRITING["turn"])
    arm = pen_on(joints, off, 0.0, 0.0)
    nib = np.array([0.15, -1.0, -0.5])
    nib = nib / np.linalg.norm(nib)
    middle = np.array(page(0.0, 0.0, 0.0)) - nib * 0.54
    pos = to_torso(joints, off, tuple(middle))
    axis = to_torso(joints, off, direction=tuple(-nib))
    return hold("Right Arm", {"rShoulder": arm}, pos, basis_angles(axis, (0.0, 0.0, 1.0)))


PEN_GRIP = pen_grip()
# the crisp between the fingers, above the fist (solved raised beside the face: emotes/props.py, mirrored)
CHIP_GRIP = hold("Left Arm", {"lShoulder": RAISE_L}, (RAISE_AT[0] - 0.02, RAISE_AT[1] + 0.32, RAISE_AT[2] - 0.08),
                 (90, 0, 0))

# The shot -------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="Diavolo's role cutscene: and eat it.")
shot.room = (-12.0, -10.0, 12.0, 10.0, 14.0)
shot.allow = {"self": ["OfficeChair"]}  # in the chair, never into the desk

me = shot.actor("self", d)
me.mark(0.0, (SIT[0], 0.0, SIT[1]), 180.0)
me.hold("Pen", "Right Arm", PEN_GRIP[0]["p"], PEN_GRIP[1]["r"])
me.hold("Chip", "Left Arm", CHIP_GRIP[0]["p"], CHIP_GRIP[1]["r"], t0=CASUAL[0] + 0.45, t1=CASUAL[1] + 0.05)
me.hold("Chip", "Left Arm", CHIP_GRIP[0]["p"], CHIP_GRIP[1]["r"], t0=TAKE[1] - 0.05, t1=BITE + 0.02)

book = shot.prop("Grimoire", scale=MANUAL, open=1.0)
book.at(0.0, (BOOK[0], BOOK_Y, BOOK[1]), (0, 0, 0))
book.at(LENGTH, (BOOK[0], BOOK_Y, BOOK[1]), (0, 0, 0))
bag = shot.prop("ChipBag", scale=BAG_SCALE)
bag.at(0.0, (BAG[0], BAG_Y, BAG[1]), (0, 196, 0))
bag.at(LENGTH, (BAG[0], BAG_Y, BAG[1]), (0, 196, 0))
PAGE = (BOOK[0], PAGE_Y, BOOK[1])

# The Deathsinger: drawn together out of the dark behind him as he leans back laughing, eyes first, leaning in over his
# shoulder, laughing with him; gone before the hidden camera's view (it never shows on a camera).
singer = shot.prop("Specter", show=(BACK - 0.3, STUDY + 0.25))
singer.at(BACK - 0.3, (SINGER[0], 0.2, SINGER[1] + 0.4), (0, 180, 0))
singer.at(BACK + 0.9, (SINGER[0], 0.2, SINGER[1]), (10, 174, 0), "out")
shot.event(BACK - 0.3, "materialize", model="Specter", dur=1.1, r=200, g=30, b=45)
for k in range(6):
    t = BACK + 1.0 + 0.24 * k
    singer.at(t, (SINGER[0], 0.3 + (0.25 if k % 2 else 0.0), SINGER[1] + 0.3), (12 - (5 if k % 2 else 0), 170, 4))

# The hidden cameras (black and white, REC and the time: the "cctv" effect), each high in a corner of the room and
# still: (from, to, where, looking at, fov, label).
CAMS = [(0.0, CUTS[0], (10.6, 12.6, 8.6), (0.0, 3.4, -6.8), 28.0, "CAM 01"),
        (CUTS[2], CUTS[3], (-9.6, 11.0, -3.2), (0.0, 3.8, -7.0), 34.0, "CAM 03"),
        (STUDY + 0.25, LENGTH, (-8.4, 12.2, -9.2), (0.0, 3.4, -6.8), 46.0, "CAM 02")]
for t0, t1, eye, aim, fov, _ in CAMS:
    shot.subjects.append((t0, t1, None, True))
    shot.cam(t0, eye, aim, fov=fov, cut=True)
    shot.cam(t1, eye, aim, fov=fov, ease="linear")
# (Every camera but the hidden ones is held by hand, the owner, 2026-10-28: "the camera feels very stale": a breath of
# drift, and each one moving: a push, a creep, a zoom, a pull out. The hidden cameras stay locked off: that is what
# makes them cameras on a wall.)
# B: low over the desk from in front, the page in the foreground and him bent over it beyond: the pen writes; the
# lens pushing in on the nib.
look_b = (PAGE[0] + 0.05, PAGE[1] + 0.45, PAGE[2] - 0.5)
framing.dolly(shot, CUTS[0], CUTS[1], (PAGE[0] + 0.4, PAGE[1] + 0.85, PAGE[2] + 2.0),
              (PAGE[0] + 0.28, PAGE[1] + 0.72, PAGE[2] + 1.45), look_b, fov0=50, fov1=42, roll0=-4.0, roll1=-7.0,
              shake=0.7, seed=21)
# C: close, from in front on his left, zooming slowly: the eyes come up off the page.
shot.pan(CUTS[1], CUTS[2], "self", front(3.9, -1.0, 4.6), aim="Head", dy=-0.2, fov=46, cut=True, drift=(0.0, 0.0, -0.2),
         operator=True, seed=23, shake=0.5, fov_to=38, ease_move=True)
# D: across the desk, pushing in and zooming through the held pause: the crisp taken and raised.
shot.pan(CUTS[3], CUTS[4], "self", front(6.8, 0.5, 4.4), aim="Head", dy=0.1, fov=46, cut=True, drift=(0.0, 0.0, -2.0),
         roll=-3.0, operator=True, seed=25, shake=0.5, fov_to=36, ease_move=True)
# E: low and close from his right (the crisp comes in from the far side), tilted, half the face in the dark: held by
# hand, creeping; a snap in on the bite, and the frame rattled after it.
eye_e = front(3.5, 1.5, 4.75)
head_e = framing.part(shot, "self", BITE, "Head")
look_e = (float(head_e[0]), float(head_e[1]) - 0.15, float(head_e[2]))
framing.dolly(shot, CUTS[4], BITE - 0.02, (eye_e[0] - 0.1, eye_e[1], eye_e[2] + 0.12),
              (eye_e[0] - 0.05, eye_e[1], eye_e[2] - 0.08), look_e, fov0=43, fov1=41, roll0=-9.0, roll1=-10.0,
              shake=0.6, seed=27, ease_move=False)
shot.subjects.append((CUTS[4], CUTS[5], "self", False))
shot.cam(BITE + 0.08, (eye_e[0] + 0.15, eye_e[1] + 0.05, eye_e[2] - 0.22), look_e, fov=36, roll=-13.0, ease="snap")
for k, (dx, dy) in enumerate(((0.05, -0.04), (-0.04, 0.03), (0.02, -0.01))):  # (rattled by it)
    shot.cam(BITE + 0.16 + 0.08 * k, (eye_e[0] + 0.15 + dx, eye_e[1] + 0.05 + dy, eye_e[2] - 0.23), look_e, fov=36,
             roll=-13.0 + 1.5 * (1 if k % 2 else -1), ease="out")
shot.cam(CUTS[5], (eye_e[0] + 0.2, eye_e[1] + 0.05, eye_e[2] - 0.32), look_e, fov=35, roll=-13.0, ease="sine")
# F: low and wide from the room, rising and zooming out as he leans back and the Deathsinger comes.
shot.pan(CUTS[5], STUDY + 0.25, "self", front(7.6, 0.6, 3.2), aim="Torso", dy=1.6, fov=50, cut=True,
         drift=(0.2, 1.6, 1.4), operator=True, seed=29, shake=0.7, fov_to=58, ease_move=True)
# G: the hidden camera behind him (CAMS).
shot.cam_groups.sort(key=lambda g: g[0][0])  # (the hidden cameras' cuts were added first: in time order)

# The lens: barely soft, only to put the eye where the cut is about.
for t, part, radius in ((CUTS[0], "Right Arm", 2.5), (CUTS[1], "Head", 2.5), (CUTS[3], "Head", 3.0),
                        (CUTS[4], "Head", 2.0), (CUTS[5], "Torso", 6.0)):
    shot.event(t, "fx", name="focus", slot="self", part=part, radius=radius, far=0.12, near=0.06)
for t0, *_ in CAMS:
    shot.event(t0, "fx", name="focus")  # (a security camera sees it all flat)

# The light: night; the desk lamp a warm key from his right, the television's cold light flickering on his face from
# across the room, the moon through the window a cold rim on his back; the red of the Deathsinger from below behind
# him as it comes. The grade: dark, a little cool. His own face throughout.
HEAD = (SIT[0], 4.7, SIT[1])
shot.grade = (0.24, -0.06, -0.04, (238, 236, 255))
shot.light("spot", (-2.6, TOP + 1.7, -6.0), HEAD, color=(255, 186, 120), brightness=2.0, range=10, angle=75)
shot.light("spot", (0.8, 3.8, 5.6), HEAD, color=(190, 210, 255), brightness=1.5, range=20, angle=26, flicker=0.45)
shot.light("spot", (1.6, 9.5, -9.6), HEAD, color=(160, 180, 255), brightness=1.3, range=12, angle=45)
shot.light("spot", (PAGE[0] - 1.0, PAGE[1] + 2.8, PAGE[2] - 1.4), PAGE, color=(255, 214, 170), brightness=1.0, range=5,
           angle=40, shadows=False, show=(CUTS[0], CUTS[1]))  # (the page lit for the insert)
shot.light("spot", (0.8, 3.8, 5.6), HEAD, color=(235, 245, 255), brightness=3.0, range=20, angle=26,
           show=(LOOK[1] - 0.05, LOOK[1] + 0.35), flicker=0.9)  # (the television flaring as the news breaks)
shot.light("spot", (SINGER[0] + 0.5, 0.6, SINGER[1] + 2.0), (SINGER[0], 7.0, SINGER[1]), color=(220, 25, 35),
           brightness=2.2, range=12, angle=50, show=(BACK - 0.3, STUDY + 0.25))
shot.light("point", (SINGER[0], 5.0, SINGER[1] + 1.0), color=(200, 20, 30), brightness=1.2, range=8, shadows=False,
           show=(BACK + 0.2, STUDY + 0.25))

# Sound and effects.
shot.event(0.0, "sfx", slot="mapRainGlass", loop=True)
shot.event(0.2, "sfx", slot="mapNewsRadio")
shot.event(0.0, "sfx", slot="penScratch")
shot.event(WRITE[0], "sfx", slot="penScratch")
shot.event(WRITE[1], "sfx", slot="penStop")
shot.event(LOOK[1], "sfx", slot="screenStatic")
shot.event(LOOK[1] + 0.1, "sfx", slot="flatline")
shot.event(TAKE[0], "sfx", slot="pageTurn")  # (the bag's rustle)
shot.event(BITE, "sfx", slot="winShatter")  # the crunch
shot.event(BITE, "fx", name="still", r=255, g=40, b=50, dur=0.32)
shot.event(BITE, "fx", name="shake", strength=0.35, dur=0.25)
shot.event(BITE + 0.02, "fx", name="burst", pos=[round(float(v), 3) for v in framing.part(shot, "self", BITE, "Head")], r=236, g=196, b=104,
           amount=26)  # (the crumbs)
shot.event(BACK - 0.3, "sfx", slot="wisp")
shot.event(BACK + 0.4, "sfx", slot="hauntWhisper")
# the hidden cameras: black and white, REC and the time
for t0, t1, _, _, _, label in CAMS:
    shot.event(t0, "fx", name="cctv", dur=round(t1 - t0, 3), label=label)
    if t0 > 10.0:  # (the flatline's static covers the side camera)
        shot.event(t0, "sfx", slot="screenStatic")

shot.audio(voice="voiceDiavolo", voice_at=SAID, bed="bedDiavolo")
shot.line(SAID, "I'll take a potato chip... and EAT IT!", times=[0.0, 0.3, 0.62, 0.8, 1.2, BITE - SAID - 0.5,
                                                                  BITE - SAID - 0.22, BITE - SAID])
