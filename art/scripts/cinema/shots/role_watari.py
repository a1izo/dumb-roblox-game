"""The Butler's role cutscene (the briefing, seen only by the Butler): the pantry, late. The Butler sets the
tea things straight on the tray, smooths their tie, checks the time, lifts the tray and carries it to the
door. Through it, in the dark of the next room, someone sits crouched before a wall of glowing screens:
the one the Butler serves, a black shape with no face (the Butler does not know who Ace is).

The pantry (maps/venues/sets/ace.py, Sets scene space, origin x 258): x 251..265, z -6..6; the counter
along the north wall (x 254..264, its front at z -3.4, top 3.5), the kettle at (256.6, -4.4); the trolley
at (260, 1.5); the door at z 0 in the west wall into Ace's room (the chair at (238, -1.8)).

Cut down round the line (2026-10-27; then about 4 s longer, at your word, the same day): the tie smoothed and the watch
checked, the tray lifted and carried to the door, then from the dark room the Butler in the lit doorway asking "Is
something the matter? Hmm? ... What's wrong?" and bowing (10 s). The role card holds after it. Authored on its first
15 s timeline below; RETIME picks the pieces."""

from animlib import J
from cinema import footwork
import numpy as np

import posekit
from cinema.acting import alive, beat, body_reach, facing, keep_arm, seated, soft, walking
from cinema.shot import Retime, Shot
from emotes.kit import reach
from motion import Motion

NAME = "RoleButler"
LENGTH = 15.0
PX = 258.0
TOP = 3.5
COUNTER = (PX + 0.5, -2.3)  # where the Butler stands at the counter (his forearms clear of its front edge)
TRAY_AT = (PX + 0.5, TOP, -4.3)
DOOR = (PX - 6.0, -0.1)  # where they stop, on the pantry's threshold
THRESHOLD = (PX - 6.6, 0.0)
ACE = (238.0, 2.0, -1.6)  # the crouched shape in the chair

# Acting ---------------------------------------------------------------------------------------------

# (2026-11-07: the tie, the watch and the lift were keyed by angle, and the hands went a stud into the counter's front,
# below its top: now each fist is put on its mark. The Butler stands at COUNTER facing the counter (-z); his frame's
# z is the room's z less COUNTER's, and the tray lies 1.9 in front of him on the top.)
UPRIGHT = dict(root=(0, 0, 0))
# (the right fist at the knot, the left resting on the counter's edge: hanging, it swept down through the cupboards)
TIE = dict(rShoulder=body_reach(1, UPRIGHT, (0, 0, 0), (0.15, 3.95, -0.72), direction=(-0.92, 0.15, -0.36)),
           lShoulder=body_reach(-1, UPRIGHT, (0, 0, 0), (-1.05, 4.05, -1.15), direction=(0.1, -0.5, -0.86)))
TUG = body_reach(1, UPRIGHT, (0, 0, 0), (0.15, 3.86, -0.68), direction=(-0.92, 0.0, -0.38))  # (the knot pulled down a touch)
WATCHING = dict(root=(-2, 0, 0))
# (the left forearm across before the chest, the right fist at its cuff; both clear of the counter's top)
WATCH = dict(lShoulder=body_reach(-1, WATCHING, (0, 0, 0), (-0.3, 4.05, -1.0), direction=(0.5, 0.05, -0.86)),
             rShoulder=body_reach(1, WATCHING, (0, 0, 0), (0.15, 4.15, -0.95), direction=(-0.75, 0.15, -0.65)))
TRAY_LOCAL = (TRAY_AT[0] - COUNTER[0], TRAY_AT[1], TRAY_AT[2] - COUNTER[1])  # the tray's bottom middle, his frame
TRAY_ENDS = 1.22  # (ModelCatalog's TeaTray is 2.45 across: the fists take its two ends)
REACHING = dict(root=(-14, 0, 0))
# (setting the cups on the tray: the fists among them, over the top, never under it)
ARRANGE_A = dict(rShoulder=body_reach(1, REACHING, (0, 0, 0), (0.5, 4.05, -1.7), direction=(-0.3, -0.35, -0.9)),
                 lShoulder=body_reach(-1, REACHING, (0, 0, 0), (-0.6, 4.05, -1.5), direction=(0.3, -0.35, -0.9)))
ARRANGE_B = dict(rShoulder=body_reach(1, REACHING, (0, 0, 0), (0.2, 4.05, -1.95), direction=(-0.4, -0.35, -0.85)),
                 lShoulder=body_reach(-1, REACHING, (0, 0, 0), (-0.35, 4.05, -1.65), direction=(0.35, -0.35, -0.87)))
REACH = {key: body_reach(side, REACHING, (0, 0, 0), (TRAY_LOCAL[0] + side * TRAY_ENDS, TRAY_LOCAL[1] + 0.5, TRAY_LOCAL[2]))
         for key, side in (("rShoulder", 1), ("lShoulder", -1))}
# Lifted level: both arms keep their turn in the room as the body straightens, the tray 0.42 up off the top and drawn
# 0.4 in, over the kettle as he turns (a rigid arm turning with the torso tipped it 14 degrees); level through the bow.
LIFT = (0.0, 0.42, 0.4)
TRAY = {key: keep_arm(side, REACHING, REACH[key], UPRIGHT, LIFT) for key, side in (("rShoulder", 1), ("lShoulder", -1))}
BOWING = dict(root=(-16, 0, 0))
BOW = {key: keep_arm(side, UPRIGHT, TRAY[key], BOWING, with_shoulder=True) for key, side in (("rShoulder", 1), ("lShoulder", -1))}
BOWED = dict(root=(-15, 0, 0))
BOW2 = {key: keep_arm(side, UPRIGHT, TRAY[key], BOWED, with_shoulder=True) for key, side in (("rShoulder", 1), ("lShoulder", -1))}
# The tray welded to the right arm just where it lies on the counter when the hands close on it (no jump).
_arm = posekit.fk({**REACHING, "rShoulder": REACH["rShoulder"]})["Right Arm"]
_tray = np.identity(4)
_tray[:3, 3] = TRAY_LOCAL
_local = np.linalg.inv(_arm) @ _tray
TRAY_GRIP = (tuple(round(float(v), 3) for v in _local[:3, 3]), tuple(round(float(v), 2) for v in posekit.euler(_local[:3, :3])))

b = Motion("RoleButler_self", LENGTH, note="The Butler's role cutscene: the tray, the time, the door.")
b.key(0.0, root=(-14, 0, 0), neck=(-26, 0, 0), **ARRANGE_A)
b.key(1.2, root=(-14, 2, 0), neck=(-28, 4, 0), **ARRANGE_B)
b.key(2.3, root=(-13, -2, 0), neck=(-26, -3, 0), **ARRANGE_A)
b.key(3.2, root=(-14, 0, 0), neck=(-27, 0, 0), **ARRANGE_B)
b.key(4.6, root=(0, 0, 0), neck=(-10, 0, 0), **TIE)
b.key(6.2, root=(-2, 0, 0), neck=(-27, -8, 0), **WATCH)
b.key(9.6, root=(-1, 0, 0), neck=(-3, 0, 0), **TRAY)
b.key(10.4, root=(-1, 0, 0), neck=(2, 0, 0), **TRAY)  # stops at the door, looks in
b.key(11.6, root=(-1, 0, 0), neck=(0, 0, 0), **TRAY)
b.key(13.8, root=(-15, 0, 0), neck=(-14, 0, 0), **BOW2)
b.key(LENGTH, root=(-2, 0, 0), neck=(-4, 0, 0), **TRAY)
# The big moves acted: a breath drawn before straightening, the tie tugged, the cuff shot back for the
# watch, the tray's weight taken low before it rises, the bow dipping past and settling.
beat(b, 3.9, 0.5, antic=0.14, over=0.12, root=(0, 0, 0), neck=(-8, 0, 0), **TIE)  # straightens; the tie
b.key(4.32, rShoulder=TUG)
b.key(4.46, rShoulder=TIE["rShoulder"])
beat(b, 5.2, 0.45, antic=0.12, over=0.1, root=(-2, 0, 0), neck=(-26, -8, 0), **WATCH)  # the time
b.key(6.85, root=(-14, 0, 0), neck=(-22, 0, 0), **REACH)  # the hands to the tray's two ends
b.key(7.0, root=(-14, 0, 0), neck=(-22, 0, 0), **REACH)
beat(b, 7.6, 0.6, antic=0.0, over=0.06, root=(0, 0, 0), neck=(-4, 0, 0), **TRAY)  # lifts it, level
beat(b, 12.6, 0.7, antic=0.1, over=0.12, root=(-16, 0, 0), neck=(-14, 0, 0), **BOW)  # a bow to the one in the chair
soft(b, arms=2.6).plant(None, 7.6, stance=0.04).plant(9.9, None, stance=0.04)
walking(b, 7.9, 9.6, arms=0.3)  # (the tray carried, a wall at his right: a small swing)
alive(b, 0.5, seed=3, t1=6.7)
alive(b, 0.4, seed=4, t0=10.0)
b.build()

# (crouched on the seat as in Ace's own cutscene, cinema/shots/role_l.py: the R6 way, the legs out along it)
shape = Motion("RoleButler_ace", LENGTH, note="The Butler's role cutscene: the faceless one in the chair.")
for t, k in ((0.0, 0.0), (5.0, 1.0), (10.0, 0.0), (LENGTH, 1.0)):
    seated(shape, t, seat=0.02 * k, legs=80.0, lean=-8 + k, xz=(0.0, 0.1), neck=(4 + k, 3 * k, 0),
           rShoulder=J((128, 0, -26), (-0.28, 0.25, -0.3)),
           lShoulder=reach(-1, (-0.35, -0.55, -1.5), direction=(0.3, -0.35, -0.9)))
soft(shape, head=1.5, arms=1.5)
shape.build()

# The shot -------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="The Butler's role cutscene: the pantry, the tray, the faceless one.")

# A: from the door, across the galley: the Butler at the counter in the lamplight.
shot.cam(0.0, (PX - 5.6, 5.4, 3.2), (COUNTER[0], 3.8, -3.8), fov=46)
shot.cam(3.6, (PX - 5.0, 5.2, 2.4), (COUNTER[0], 3.8, -3.8), fov=44, ease="linear")
# B: closer from the east: the tie, the watch.
shot.cam(3.6, (PX + 4.4, 5.0, -0.2), (COUNTER[0], 4.2, COUNTER[1]), fov=44, cut=True)
shot.cam(7.0, (PX + 4.2, 4.8, 0.2), (COUNTER[0], 4.0, COUNTER[1]), fov=40, ease="linear")
# C: from the far end: they lift the tray and carry it to the door, the screens' glow beyond.
shot.cam(7.0, (PX + 6.0, 5.6, 4.6), (PX - 7.0, 4.0, 0.0), fov=44, cut=True)
shot.cam(11.0, (PX + 5.0, 5.4, 4.0), (PX - 7.0, 4.0, 0.0), fov=40, ease="linear")
# D: from the dark room, past the faceless one in the chair, to the Butler bowing in the lit doorway.
shot.cam(11.0, (ACE[0] - 1.6, 5.2, -4.8), (THRESHOLD[0], 4.0, 0.0), fov=38, cut=True)
shot.cam(LENGTH, (ACE[0] - 1.4, 5.0, -4.4), (THRESHOLD[0], 4.2, 0.0), fov=32, ease="in")

me = shot.actor("self", b)
me.mark(0.0, (COUNTER[0], 0.0, COUNTER[1]), 0.0)
me.mark(7.6, (COUNTER[0], 0.0, COUNTER[1]), 0.0)
me.mark(7.9, (COUNTER[0], 0.0, COUNTER[1]), facing(COUNTER, DOOR), "linear")
me.mark(9.6, (DOOR[0], 0.0, DOOR[1]), facing(COUNTER, DOOR), "linear")
me.mark(10.2, (DOOR[0], 0.0, DOOR[1]), 90.0)
me.mark(LENGTH, (DOOR[0], 0.0, DOOR[1]), 90.0)
me.hold("TeaTray", "Right Arm", TRAY_GRIP[0], TRAY_GRIP[1], t0=7.0)

tray = shot.prop("TeaTray", show=(0.0, 7.0))
tray.at(0.0, TRAY_AT, (0, 0, 0))
tray.at(7.0, TRAY_AT, (0, 0, 0))

ace = shot.actor("ace", clip="RoleButler_ace", extra=True, silhouette=(0.0, LENGTH))
ace.mark(0.0, ACE, 0.0)
shot.allow = {"ace": ["ClubChair"]}  # crouched on its seat

shot.event(0.0, "sfx", slot="clockTick")
shot.event(5.2, "sfx", slot="clockTick")
shot.event(9.6, "sfx", slot="mapServerHum")
# Cut down round the line: the tie and the watch, the tray carried to the door, then asked from the doorway with a bow
# (the line starts as they reach it).
footwork.apply(shot)  # (the feet planted where they come down, stepping after the body: cinema/footwork.py)
RETIME = Retime([(3.6, 9.6), (11.0, 15.0)])
RETIME.apply(shot, [b, shape])
SAID = RETIME.new(9.5)
shot.audio(voice="voiceButler", voice_at=SAID, bed="bedButler")
shot.line(SAID, "Is something the matter? Hmm? ... What's wrong?")