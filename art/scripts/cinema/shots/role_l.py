"""Ace's role cutscene (the briefing, seen only by Ace): the dark room of monitors. Ace sits crouched in
the armchair before the wall of screens, a thumb at the lip, and takes a sweet from the table without
looking. The Butler comes in from the pantry with the tea tray (when there is a Butler this match: the
real one), bows and holds it out; Ace takes a cup and sips, eyes back on the screens.

Ace's room (maps/venues/sets/ace.py, Sets scene space, origin x 240): x 228..250, z -9..9, the screens
on the north wall; the armchair at (238, -1.8) facing them (seat about 2 high); the low table with the
sweets at (241.6, -1.4); the door in the east wall at z 0 into the pantry (x 251..265)."""

from animlib import J
from cinema.acting import facing, soft, walking
from cinema.shot import Shot
from motion import Motion

NAME = "RoleAce"
LENGTH = 15.0
AX = 240.0
SEAT = 2.0
ACE = (AX - 2.0, -1.6)
TABLE = (AX + 1.6, -1.4)
START = (AX + 14.0, 0.0)  # the Butler, in the pantry
OFFER = (AX + 3.6, 1.0)  # where the Butler stops, beside the chair

# Acting ---------------------------------------------------------------------------------------------

LIP = J((128, 0, -26), (-0.28, 0.25, -0.3))
KNEES = J((78, 0, 18), (0.12, 0.05, -0.4))
CROUCH = (0, -1.15, 0.25)  # the thinker's crouch, on the seat


def crouch(m, t, ease="smooth", neck=(4, 0, 0), r=LIP, lean=-8):
    m.key(t, ease, offset=CROUCH, root=(lean, 0, 0), neck=neck, rShoulder=r, lShoulder=KNEES)


ace = Motion("RoleAce_self", LENGTH, note="Ace's role cutscene: crouched before the monitors, a sweet, the tea.")
crouch(ace, 0.0)
crouch(ace, 2.4, neck=(6, 4, 0))
crouch(ace, 4.6, neck=(5, 0, 0))
crouch(ace, 5.3, neck=(2, -8, 0), r=J((34, 0, 46), (0.1, 0.1, -0.1)), lean=-10)  # a sweet from the table
crouch(ace, 5.8, neck=(2, -8, 0), r=J((30, 0, 50), (0.1, 0.08, -0.1)), lean=-11)
crouch(ace, 6.6, neck=(5, 0, 0))  # and to the mouth, eyes never off the screens
crouch(ace, 9.4, neck=(6, 2, 0))
crouch(ace, 10.2, neck=(0, -34, 0))  # the Butler: a glance
crouch(ace, 10.9, neck=(-2, -36, 0), r=J((74, 0, 34), (0.05, 0.12, -0.2)), lean=-12)  # reaches for a cup
crouch(ace, 11.6, neck=(-2, -34, 0), r=J((76, 0, 32), (0.05, 0.12, -0.2)), lean=-12)
crouch(ace, 12.4, neck=(4, -6, 0))  # a sip
crouch(ace, 13.4, neck=(6, 0, 0))
crouch(ace, LENGTH, neck=(7, 0, 0))
soft(ace, head=1.8, arms=2.0).plant(stance=0.12, forward=(0.55, 0.55), tilt=(62, 62))
ace.build()

TRAY = dict(rShoulder=J((62, 0, -10), (0, 0.06, -0.16)), lShoulder=J((62, 0, 10), (0, 0.06, -0.16)))
HELD = dict(rShoulder=J((76, 0, -10), (0, 0.06, -0.24)), lShoulder=J((76, 0, 10), (0, 0.06, -0.24)))

butler = Motion("RoleAce_butler", LENGTH, note="Ace's role cutscene: the Butler brings the tea.")
butler.key(0.0, root=(0, 0, 0), neck=(0, 0, 0), **TRAY)
butler.key(7.0, root=(-2, 0, 0), neck=(-2, 0, 0), **TRAY)
butler.key(9.8, root=(-2, 0, 0), neck=(-2, 0, 0), **TRAY)
butler.key(10.5, root=(-14, 0, 0), neck=(-12, 0, 0), **HELD)  # a bow, the tray held out
butler.key(12.4, root=(-12, 0, 0), neck=(-10, 0, 0), **HELD)
butler.key(13.2, root=(0, 0, 0), neck=(-4, 0, 0), **TRAY)
butler.key(LENGTH, root=(0, 0, 0), neck=(-4, 0, 0), **TRAY)
soft(butler, arms=2.6).plant(None, 7.0, stance=0.04).plant(10.0, None, stance=0.04)
walking(butler, 7.2, 9.8)
butler.build()

# The shot -------------------------------------------------------------------------------------------

shot = Shot(NAME, "Sets", LENGTH, note="Ace's role cutscene: the monitors, a sweet, the Butler's tea.")

# A: behind the armchair, wide: the glowing wall of screens, Ace's crouched shape against it.
shot.cam(0.0, (AX - 1.6, 6.4, 7.0), (AX - 1.6, 5.6, -8.6), fov=48)
shot.cam(3.6, (AX - 1.8, 6.0, 4.2), (AX - 1.8, 5.4, -8.6), fov=46, ease="linear")
# B: from the screens' side, low: Ace's face in their light; a sweet from the table, unlooked at.
shot.cam(3.6, (AX - 6.6, 4.4, -4.6), (ACE[0], 4.2, ACE[1]), fov=46, cut=True)
shot.cam(7.0, (AX - 6.2, 4.2, -4.4), (ACE[0] + 0.4, 4.0, ACE[1]), fov=42, ease="linear")
# C: past Ace to the door: the Butler comes in with the tray.
shot.cam(7.0, (AX - 7.6, 5.4, -4.2), (AX + 8.0, 4.0, 0.4), fov=46, cut=True)
shot.cam(10.4, (AX - 7.0, 5.2, -4.4), (AX + 4.0, 4.0, 0.6), fov=44, ease="linear")
# D: a two-shot from the screens' end: the bow, the cup taken.
shot.cam(10.4, (AX + 5.6, 5.8, -4.6), (AX + 0.8, 4.0, -0.2), fov=50, cut=True)
shot.cam(13.0, (AX + 5.4, 5.6, -4.2), (AX + 0.6, 4.2, -0.4), fov=46, ease="linear")
# E: over Ace's shoulder into the screens.
shot.cam(13.0, (ACE[0] + 1.0, 6.4, 2.4), (AX - 2.6, 7.6, -8.6), fov=44, cut=True)
shot.cam(LENGTH, (ACE[0] + 0.6, 6.2, 1.2), (AX - 2.4, 7.8, -8.6), fov=36, ease="in")

me = shot.actor("self", ace)
me.mark(0.0, (ACE[0], SEAT, ACE[1]), 0.0)
me.hold("Teacup", "Right Arm", (0, -1.1, -0.1), (-128, 0, 0), t0=11.6)

bu = shot.actor("butler", butler)
bu.mark(0.0, (START[0], 0.0, START[1]), 90.0)
bu.mark(7.2, (START[0], 0.0, START[1]), facing(START, OFFER), "linear")
bu.mark(9.8, (OFFER[0], 0.0, OFFER[1]), facing(START, OFFER), "linear")
bu.mark(10.4, (OFFER[0], 0.0, OFFER[1]), facing(OFFER, ACE))
bu.mark(LENGTH, (OFFER[0], 0.0, OFFER[1]), facing(OFFER, ACE))
bu.hold("TeaTray", "Right Arm", (-1.0, -1.05, 0.0), (-62, 0, 0))

cup = shot.prop("Teacup")  # the cup Ace has been drinking from, on the table
cup.at(0.0, (TABLE[0] + 0.7, 1.38, TABLE[1] + 0.5), (0, 40, 0))
cup.at(LENGTH, (TABLE[0] + 0.7, 1.38, TABLE[1] + 0.5), (0, 40, 0))

shot.event(0.0, "sfx", slot="mapServerHum")
shot.event(5.6, "sfx", slot="pageTurn")
shot.event(7.4, "sfx", slot="clockTick")
shot.event(1.0, "card", key="role", dur=4.2)
shot.event(5.4, "card", key="win", dur=3.6)
shot.event(9.2, "card", key="move", dur=2.8)
shot.event(12.0, "card", key="names", dur=3.0)
