"""Ace's role cutscene (the briefing, seen only by Ace): "I had to test this just in case, but I, I never thought it would
actually happen. Kira... it seems you can kill people without having to be there in person."

1  0.0-3.2   Behind the armchair: the wall of glowing screens and Ace's crouched shape against it.
2  3.2-5.6   Close on Ace in the screens' light: the eyes jump from screen to screen; a sweet from the
             table, popped in without looking.
3  5.6-8.4   Low past Ace's shoulder to the door: the Butler comes in with the tea tray.
4  8.4-10.8  From the side, both: the Butler bows and holds out the tray; Ace, eyes still on the screens,
             lifts a cup by its rim between finger and thumb.
5  10.8-12.8 Close: a sip.
6  12.8-17.5 Over Ace's shoulder, pushing in to the screens, the eyes still jumping from one to the next.

The line said over the whole scene (2026-10-27 it was cut to the line, from 1.5 s on; then about 4 s longer, at your
word, the same day: all of it from the first beat, and the last push into the screens 2.5 s longer). The role card
holds after it.

When there is no Butler this match the butler part is empty: cut 3 watches an empty doorway and Ace reaches
out to no one (the cup still appears in the hand).

Ace's room (maps/venues/sets/ace.py, Sets scene space, origin x 240): x 228..250, z -9..9, 12 high; the
screens and CRT banks along the north wall (the banks reach out to z -5.7); the armchair at (238, -1.8)
facing north (seat about 2 high); the low table with the sweets at (241.6, -1.4); the door in the east
wall at z 0 into the pantry (x 251..265)."""

from animlib import J
from cinema import framing
from cinema.acting import alive, beat, facing, hold, seated, soft, walking
from cinema.shot import Shot
from emotes.kit import reach
from motion import Motion

NAME = "RoleAce"
LENGTH = 17.5
AX = 240.0
SEAT = 2.0
ACE = (AX - 2.0, -1.6)
TABLE = (AX + 1.6, -1.4)
PANTRY = (AX + 13.0, 0.0)
OFFER = (AX + 2.6, 1.8)  # where the Butler stops, beside the chair
WALK_IN = (6.0, 6.0 + ((PANTRY[0] - OFFER[0]) ** 2 + (PANTRY[1] - OFFER[1]) ** 2) ** 0.5 / 4.0)

# Ace: crouched on the seat the R6 way (the owner's drawing, 2026-10-20: the legs out in front along the seat, the
# torso upright on their back ends), a thumb at the lip, the other arm over the knees ------------------------------

LIP = J((128, 0, -26), (-0.28, 0.25, -0.3))
KNEES = reach(-1, (-0.35, -0.55, -1.5), direction=(0.3, -0.35, -0.9))  # the left arm laid over the legs
CROUCH = dict(seat=0.0, legs=80.0, lean=-8.0, xz=(0.0, 0.1))  # (the actor stands on the cushion, 2 high)
SWEET = J((40, 0, 44), (0.1, 0.08, -0.12))  # down to the table on the right
CUP = J((84, 0, 30), (0.04, 0.14, -0.22))  # out to the tray


def flick(m, t, yaw, pitch=4.0):
    """The eyes (the head) jump to another screen: fast, a little past, settle."""
    beat(m, t, 0.16, antic=0.05, over=0.18, neck=(pitch, yaw, 0))


ace = Motion("RoleAce_self", LENGTH, note="Ace's role cutscene: the screens, a sweet, the tea.")
seated(ace, 0.0, **CROUCH, neck=(4, 0, 0), rShoulder=LIP, lShoulder=KNEES)
seated(ace, LENGTH, **CROUCH)
for t, yaw in ((1.4, 14), (2.3, -10), (3.0, 22), (3.7, 4), (4.1, -16), (5.6, 10), (6.4, -4), (7.4, 12)):
    flick(ace, t, yaw)
beat(ace, 4.7, 0.3, antic=0.1, rShoulder=SWEET)  # a sweet, snatched off the table...
beat(ace, 5.2, 0.3, antic=0.1, rShoulder=LIP)  # ...and into the mouth
hold(ace, 9.0)
beat(ace, 9.5, 0.35, neck=(0, -10, 0), rShoulder=CUP)  # out to the tray, eyes not leaving the screens
hold(ace, 10.1)
beat(ace, 10.7, 0.45, neck=(6, 6, 0), rShoulder=J((118, 0, -20), (-0.2, 0.24, -0.3)))  # the cup to the lips
for t, yaw in ((12.0, -14), (12.9, 8), (13.8, -2), (14.9, 12), (15.8, -10), (16.7, 3)):
    flick(ace, t, yaw)
soft(ace, head=4.0, arms=2.6)
alive(ace, 0.3, seed=81)  # (still as a cat at the screens, but breathing)
ace.build()

# The Butler -----------------------------------------------------------------------------------------------

TRAY = dict(rShoulder=J((62, 0, -10), (0, 0.06, -0.16)), lShoulder=J((62, 0, 10), (0, 0.06, -0.16)))
HELD = dict(rShoulder=J((76, 0, -10), (0, 0.06, -0.24)), lShoulder=J((76, 0, 10), (0, 0.06, -0.24)))

b = Motion("RoleAce_butler", LENGTH, note="Ace's role cutscene: the Butler brings the tea.")
b.key(0.0, root=(0, 0, 0), neck=(-2, 0, 0), **TRAY)
b.key(WALK_IN[1], root=(-2, 0, 0), neck=(-2, 0, 0), **TRAY)
beat(b, 9.1, 0.5, antic=0.2, root=(-22, 0, 0), neck=(-16, 0, 0), **HELD)  # a deep bow, the tray held out
hold(b, 10.6)
beat(b, 11.3, 0.5, root=(0, 0, 0), neck=(-6, 0, 0), **TRAY)  # straightens
b.key(LENGTH, root=(0, 0, 0), neck=(-6, 0, 0))
soft(b, arms=2.6).plant(None, WALK_IN[0] - 0.1, stance=0.04).plant(WALK_IN[1] + 0.1, None, stance=0.04)
walking(b, *WALK_IN)
alive(b, 0.4, seed=82, t1=WALK_IN[0] - 0.2)
alive(b, 0.4, seed=83, t0=WALK_IN[1] + 0.3, t1=8.5)
alive(b, 0.4, seed=84, t0=11.9)
b.build()

# The shot --------------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="Ace's role cutscene: the monitors, a sweet, the Butler's tea.")
shot.room = (228.0, -9.0, 250.0, 9.0, 12.0)
shot.allow = {"self": ["ClubChair"]}  # crouched on its seat, against its back

me = shot.actor("self", ace, silhouette=(0.0, 3.2))
me.mark(0.0, (ACE[0], SEAT, ACE[1]), 0.0)
me.hold("Teacup", "Right Arm", (0, -1.1, -0.1), (-84, 0, 0), t0=9.9)

bu = shot.actor("butler", b)
heading = facing(PANTRY, OFFER)
bu.mark(0.0, (PANTRY[0], 0.0, PANTRY[1]), heading)
bu.mark(WALK_IN[0], (PANTRY[0], 0.0, PANTRY[1]), heading, "linear")
bu.mark(WALK_IN[1], (OFFER[0], 0.0, OFFER[1]), heading, "linear")
bu.mark(WALK_IN[1] + 0.5, (OFFER[0], 0.0, OFFER[1]), facing(OFFER, ACE))
bu.mark(LENGTH, (OFFER[0], 0.0, OFFER[1]), facing(OFFER, ACE))
bu.hold("TeaTray", "Right Arm", (-1.0, -1.05, 0.0), (-62, 0, 0))

# 1: behind the armchair: the screens, Ace's shape against them.
shot.cam(0.0, (ACE[0] + 0.4, 6.4, 6.4), (ACE[0], 5.2, -8.0), fov=46)
shot.cam(3.2, (ACE[0] + 0.3, 6.0, 4.0), (ACE[0], 5.2, -8.0), fov=44, ease="linear")
# 2: close on Ace in the screens' light, from between the chair and the screens.
shot.pan(3.2, 5.6, "self", (ACE[0] - 2.6, 4.4, -4.6), aim="Head", dy=-0.3, fov=34, cut=True, drift=(0.2, 0.0, 0.0))
# 3: low past Ace to the door: the Butler comes in.
shot.pan(5.6, 8.4, "butler", (ACE[0] - 3.6, 3.4, -4.8), aim="Torso", dy=0.6, fov=40, cut=True)
# 4: from the side, both: the bow, the cup.
shot.frame(8.4, "self", "two", other="butler", height=0.4, dist=0.8, cut=True)
shot.frame(10.8, "self", "two", other="butler", height=0.2, dist=0.7, ease="linear")
# 5: close: a sip, from the screens' side.
shot.frame(10.8, "self", "close", angle=-30, height=-0.2, cut=True)
shot.frame(12.8, "self", "close", angle=-24, height=-0.3, dist=0.9, ease="linear")
# 6: over Ace's shoulder into the screens.
shot.cam(12.8, framing.spot(shot, 12.8, "self", "close", angle=160, height=0.6), (AX - 2.0, 7.4, -8.6), fov=44, cut=True)
shot.cam(LENGTH, framing.spot(shot, LENGTH, "self", "close", angle=168, height=0.8, dist=0.75), (AX - 2.0, 8.0, -8.6),
         fov=34, ease="in")

shot.event(0.0, "sfx", slot="mapServerHum")
shot.event(4.7, "sfx", slot="pageTurn")
shot.event(6.0, "sfx", slot="clockTick")
# The line said over the scene from its second beat on. ({Hand}: the game's own name for the one the line is about,
# filled in by Shared/Terms: no source name is ever shown to a player.)
shot.audio(voice="voiceAce", voice_at=2.5, bed="bedAce")
shot.line(2.5, "I had to test this just in case, but I, I never thought it would actually happen. {Hand}... it seems you "
               "can kill people without having to be there in person.")