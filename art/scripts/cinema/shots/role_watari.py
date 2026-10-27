"""The Butler's role cutscene (the briefing, seen only by the Butler): the pantry, late. The Butler sets the
tea things straight on the tray, smooths their tie, checks the time, lifts the tray and carries it to the
door. Through it, in the dark of the next room, someone sits crouched before a wall of glowing screens:
the one the Butler serves, a black shape with no face (the Butler does not know who Ace is).

The pantry (maps/venues/sets/ace.py, Sets scene space, origin x 258): x 251..265, z -6..6; the counter
along the north wall (x 254..264, its front at z -3.4, top 3.5), the kettle at (256.6, -4.4); the trolley
at (260, 1.5); the door at z 0 in the west wall into Ace's room (the chair at (238, -1.8)).

Cut down to the line (2026-10-27: each voiced cutscene lasts its line plus a beat before it; the role card holds after
it): the tray carried to the door, then from the dark room the Butler in the lit doorway asking "Is something the
matter? Hmm? ... What's wrong?" and bowing. Authored on its first 15 s timeline below; RETIME picks the pieces."""

from animlib import J
from cinema.acting import alive, beat, facing, seated, soft, walking
from cinema.shot import Retime, Shot
from emotes.kit import reach
from motion import Motion

NAME = "RoleButler"
LENGTH = 15.0
PX = 258.0
TOP = 3.5
COUNTER = (PX + 0.5, -2.5)  # where the Butler stands at the counter
TRAY_AT = (PX + 0.5, TOP, -4.4)
DOOR = (PX - 6.0, -0.1)  # where they stop, on the pantry's threshold
THRESHOLD = (PX - 6.6, 0.0)
ACE = (238.0, 2.0, -1.6)  # the crouched shape in the chair

# Acting ---------------------------------------------------------------------------------------------

ARRANGE_A = dict(rShoulder=J((58, 0, -6), (-0.04, 0.06, -0.26)), lShoulder=J((54, 0, 10), (0.06, 0.06, -0.24)))
ARRANGE_B = dict(rShoulder=J((54, 6, -12), (-0.1, 0.06, -0.24)), lShoulder=J((60, 0, 4), (0.02, 0.06, -0.28)))
TIE = dict(rShoulder=J((62, 0, -52), (-0.36, 0.18, -0.2)), lShoulder=J((4, 0, -4)))
WATCH = dict(rShoulder=J((58, 0, -40), (-0.28, 0.12, -0.24)), lShoulder=J((76, 0, 30), (0.24, 0.12, -0.28)))
TRAY = dict(rShoulder=J((62, 0, -10), (0, 0.06, -0.16)), lShoulder=J((62, 0, 10), (0, 0.06, -0.16)))

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
b.key(13.8, root=(-15, 0, 0), neck=(-14, 0, 0), **TRAY)
b.key(LENGTH, root=(-2, 0, 0), neck=(-4, 0, 0), **TRAY)
# The big moves acted: a breath drawn before straightening, the tie tugged, the cuff shot back for the
# watch, the tray's weight taken low before it rises, the bow dipping past and settling.
beat(b, 3.9, 0.5, antic=0.14, over=0.12, root=(0, 0, 0), neck=(-8, 0, 0), **TIE)  # straightens; the tie
b.key(4.32, rShoulder=J((66, 0, -50), (-0.36, 0.14, -0.2)))
b.key(4.46, rShoulder=J((62, 0, -52), (-0.36, 0.18, -0.2)))
beat(b, 5.2, 0.45, antic=0.12, over=0.1, root=(-2, 0, 0), neck=(-26, -8, 0), **WATCH)  # the time
b.key(6.9, root=(-14, 0, 0), neck=(-20, 0, 0), **TRAY)  # lifts the tray
beat(b, 7.5, 0.6, antic=0.0, over=0.06, root=(0, 0, 0), neck=(-4, 0, 0))
beat(b, 12.6, 0.7, antic=0.1, over=0.12, root=(-16, 0, 0), neck=(-14, 0, 0))  # a bow to the one in the chair
soft(b, arms=2.6).plant(None, 7.6, stance=0.04).plant(9.9, None, stance=0.04)
walking(b, 7.9, 9.6)
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
me.hold("TeaTray", "Right Arm", (-1.0, -1.05, 0.0), (-62, 0, 0), t0=7.0)

tray = shot.prop("TeaTray", show=(0.0, 7.0))
tray.at(0.0, TRAY_AT, (0, 0, 0))
tray.at(7.0, TRAY_AT, (0, 0, 0))

ace = shot.actor("ace", clip="RoleButler_ace", extra=True, silhouette=(0.0, LENGTH))
ace.mark(0.0, ACE, 0.0)
shot.allow = {"ace": ["ClubChair"]}  # crouched on its seat

shot.event(0.0, "sfx", slot="clockTick")
shot.event(5.2, "sfx", slot="clockTick")
shot.event(9.6, "sfx", slot="mapServerHum")
# Cut down to the line: carried to the door, then asked from the doorway with a bow.
RETIME = Retime([(7.6, 9.6), (11.0, 15.0)])
RETIME.apply(shot, [b, shape])
shot.audio(voice="voiceButler", voice_at=1.9, bed="bedButler")
shot.line(1.9, "Is something the matter? Hmm? ... What's wrong?")