"""Every Death's Gambit animation on the R6 rig (rig.py), keyed in the game's joint convention
(animlib.py) and built with motion.Motion.

R6 has six joints and rigid limbs, so the motion comes from the R6 toolbox: parts slide as well as
turn (a leg sliding up into the hip is a bent knee, an arm sliding forward and in is a bent elbow),
the head and arms follow the body on soft springs (overlap and follow-through), and keys flow into
each other on smooth curves. Feet stay planted by sliding the legs (Motion.plant).

Style: fluid and natural, with weight. Not cartoon (no bounces, no flailing) and not stiff.

Rigid arms: shoulder x 0 = hanging, 90 = straight out in front, 180 = overhead. z swings an arm out
(right +, left -). A slide moves the arm in its torso's frame: x right, y up, z back. To bring a hand
to the chest or face, raise the arm, turn it across (right -z, left +z) and slide it in and forward.

Run build() in Blender (see art/README.md) to rebuild the actions on the rig, then export_anims.py
writes src/shared/Anim/Clips.luau.
"""

import math

import gait
from animlib import J
from motion import Motion

ARMS = ("rShoulder", "lShoulder")
REST = dict(root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))


def soft(m, head=3.0, arms=2.4, head_damp=0.72, arm_damp=0.62):
    """The usual overlap: the head and the arms trail the body a little."""
    m.follow("neck", head, head_damp)
    m.follow(ARMS, arms, arm_damp)
    return m


# Hands -------------------------------------------------------------------------------------------------
# Common arm poses (angles, slide). r = right arm, l = left arm.

def r_chest(x=68, across=-40):
    return J((x, 0, across), (-0.3, 0.14, -0.22))


def l_chest(x=60, across=36):
    return J((x, 0, across), (0.3, 0.12, -0.22))


def r_face(x=122, across=-32):
    return J((x, 0, across), (-0.28, 0.18, -0.22))


# Locomotion --------------------------------------------------------------------------------------------

gait.build()

idle = Motion("idle", 4.0, loop=True, note="Standing: breathing, the weight settling from foot to foot.")
for i in range(8):
    t = i * 0.5
    breath = math.sin(2 * math.pi * t / 2.0)
    shift = math.sin(2 * math.pi * t / 4.0)
    idle.key(t, offset=(0.05 * shift, 0.018 * breath - 0.02, 0), root=(0.7 * breath, 1.5 * math.sin(2 * math.pi * t / 4 + 0.7), -1.2 * shift),
             neck=(-0.6 * breath, 3 * math.sin(2 * math.pi * t / 4 + 2.0), 0.8 * shift),
             rShoulder=J((1.5 + breath, 0, 3 + 0.8 * breath), (0, 0.02 * breath, 0)),
             lShoulder=J((1.5 + breath, 0, -3 - 0.8 * breath), (0, 0.02 * breath, 0)))
soft(idle).plant(stance=0.04)
idle.build()

land = Motion("land", 0.5, note="Landing: the knees give, the arms float out, then up again.")
land.key(0.0, offset=(0, -0.05, 0), root=(-4, 0, 0), neck=(2, 0, 0), rShoulder=J((25, 0, 18)), lShoulder=J((25, 0, -18)))
land.key(0.1, "out", offset=(0, -0.38, 0.05), root=(-12, 0, 0), neck=(4, 0, 0), rShoulder=J((30, 0, 22), (0, 0.05, 0)),
         lShoulder=J((30, 0, -22), (0, 0.05, 0)))
land.key(0.32, offset=(0, -0.1, 0.02), root=(-4, 0, 0), neck=(1, 0, 0), rShoulder=J((8, 0, 6)), lShoulder=J((8, 0, -6)))
land.key(0.5, offset=(0, -0.02, 0), root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((2, 0, 3)), lShoulder=J((2, 0, -3)))
soft(land, arms=3.0).plant(stance=0.08)
land.build()

jump = Motion("jump", 0.5, note="Take-off: a crouch, then up with one knee driving and the arms swinging.")
jump.key(0.0, offset=(0, -0.3, 0), root=(-12, 0, 0), neck=(6, 0, 0), rShoulder=J((-20, 0, 8)), lShoulder=J((-20, 0, -8)),
         rHip=J((14, 0, 0), (0, 0.3, 0)), lHip=J((14, 0, 0), (0, 0.3, 0)))
jump.key(0.16, "out", offset=(0, 0.1, 0), root=(-3, 0, 0), neck=(4, 0, 0), rShoulder=J((70, 0, 14), (0, 0.1, -0.15)),
         lShoulder=J((55, 0, -14), (0, 0.1, -0.1)), rHip=J((40, 0, 3), (0, 0.6, -0.1)), lHip=J((-12, 0, -2), (0, 0.1, 0)))
jump.key(0.5, offset=(0, 0.05, 0), root=(-1, 0, 0), neck=(2, 0, 0), rShoulder=J((50, 0, 18), (0, 0.06, -0.1)),
         lShoulder=J((40, 0, -18), (0, 0.06, -0.08)), rHip=J((30, 0, 4), (0, 0.45, -0.05)), lHip=J((-4, 0, -3), (0, 0.15, 0)))
soft(jump, arms=3.2)
jump.build()

fall = Motion("fall", 1.2, loop=True, note="Falling: arms out for balance, legs drifting.")
fall.key(0.0, root=(4, 0, 2), neck=(-8, 0, 0), rShoulder=J((60, 0, 40), (0, 0.1, 0)), lShoulder=J((45, 0, -46), (0, 0.1, 0)),
         rHip=J((20, 0, 5), (0, 0.4, -0.05)), lHip=J((-8, 0, -5), (0, 0.1, 0)))
fall.key(0.6, root=(4, 0, -2), neck=(-8, 0, 0), rShoulder=J((45, 0, 46), (0, 0.1, 0)), lShoulder=J((60, 0, -40), (0, 0.1, 0)),
         rHip=J((-8, 0, 5), (0, 0.1, 0)), lHip=J((20, 0, -5), (0, 0.4, -0.05)))
soft(fall, arms=1.6)
fall.build()

sit = Motion("sit", 4.0, loop=True, note="Seated (a Seat): thighs level, hands resting on the lap, breathing.")
for t, b in ((0.0, 0.0), (2.0, 1.0)):
    sit.key(t, root=(-3 + 0.8 * b, 0, 0), neck=(-4 - 0.6 * b, 2 * b, 0), rHip=J((88, 0, 2), (0, 0, 0)), lHip=J((88, 0, -2)),
            rShoulder=J((42 + b, 0, -6), (-0.05, 0.03 * b, -0.15)), lShoulder=J((42 + b, 0, 6), (0.05, 0.03 * b, -0.15)))
soft(sit)
sit.build()

# Fidgets (now and then while standing; played over the idle) -----------------------------------------

look = Motion("idleLook", 3.2, note="A fidget: a look over one shoulder, then the other.")
look.key(0.0, root=(0, 0, 0), neck=(0, 0, 0))
look.key(0.8, root=(0, 10, 0), neck=(-2, 34, 2))
look.key(1.5, root=(0, 10, 0), neck=(-3, 36, 2))
look.key(2.2, root=(0, -6, 0), neck=(-1, -26, -2))
look.key(3.2, root=(0, 0, 0), neck=(0, 0, 0))
look.follow("neck", 2.2, 0.8)
look.build()

watch = Motion("idleWatch", 3.2, note="A fidget: the wrist comes up and the head bends to the watch.")
watch.key(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)))
watch.key(0.7, root=(-3, 6, 0), neck=(-24, 8, 0), rShoulder=J((62, 0, -42), (-0.25, 0.16, -0.25)))
watch.key(2.1, root=(-3, 6, 0), neck=(-25, 9, 0), rShoulder=J((63, 0, -42), (-0.25, 0.16, -0.25)))
watch.key(3.2, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)))
soft(watch)
watch.build()

tie = Motion("idleTie", 2.8, note="A fidget: a tug at the knot of the tie, chin up.")
tie.key(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))
tie.key(0.6, root=(-2, 0, 0), neck=(6, 0, 4), rShoulder=J((96, 0, -42), (-0.3, 0.3, -0.18)), lShoulder=J((22, 0, 20), (0.15, 0.05, -0.1)))
for t, d in ((0.9, 0.06), (1.2, -0.02), (1.5, 0.05)):
    tie.key(t, root=(-2, 0, 0), neck=(7, 0, 5), rShoulder=J((96, 0, -42), (-0.3, 0.3 + d, -0.18)),
            lShoulder=J((22, 0, 20), (0.15, 0.05, -0.1)))
tie.key(2.8, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=J((0, 0, 3)), lShoulder=J((0, 0, -3)))
soft(tie)
tie.build()

# Actions -----------------------------------------------------------------------------------------------

# Everyone alive writes in the Death's Gambit phase: the notebook held up at the chest in the left
# hand, the right hand writing across the page in short strokes, the head bent over it.
write = Motion("write", 2.4, loop=True, note="Writing in the notebook (everyone alive, in the Death's Gambit phase).")
for i in range(12):
    t = i * 0.2
    along = (i % 6) / 5  # the pen travels along the line, then jumps back
    stroke = 1 if i % 2 == 0 else -1
    write.key(t, root=(-6, 3, 0), neck=(-28, 4 - 6 * along, 0),
              lShoulder=J((54, 0, 30), (0.28, 0.1, -0.22)),
              rShoulder=J((50 + stroke, -4 + 8 * along, -16 + 6 * along), (-0.18 + 0.12 * along, 0.06 + 0.015 * stroke, -0.24)))
write.follow("neck", 2.5, 0.75).follow("rShoulder", 6.0, 0.6).follow("lShoulder", 2.0, 0.8)
write.plant(stance=0.03)
write.build()

camera = Motion("workCamera", 2.0, loop=True, note="Camera footage: hands on the console, scrubbing through the tape.")
for i, (dial, look_at) in enumerate(((0, 0), (1, 2), (-1, 3), (1, 1), (0, -2), (-1, -3), (1, -1), (0, 0))):
    camera.key(i * 0.25, root=(-8, look_at, 0), neck=(-14, look_at * 2.5, 0),
               rShoulder=J((54, 8 * dial, -14), (-0.12, 0.08, -0.22 + 0.04 * dial)),
               lShoulder=J((52, 0, 14), (0.12, 0.08, -0.2)))
soft(camera, arms=4.0).plant(stance=0.05)
camera.build()

prints = Motion("workFingerprint", 1.6, loop=True, note="Fingerprints: leaning in, dusting in small circles.")
for i in range(8):
    a = i / 8 * 2 * math.pi
    prints.key(i * 0.2, root=(-13, 5, 0), neck=(-22, 7, 0),
               rShoulder=J((62, 0, -12), (-0.12 + 0.07 * math.cos(a), 0.08, -0.25 + 0.07 * math.sin(a))),
               lShoulder=J((50, 0, 16), (0.12, 0.06, -0.18)))
soft(prints, arms=5.0).plant(stance=0.06, forward=(0.15, -0.1))
prints.build()

phone = Motion("workPhone", 3.0, loop=True, note="Phone records: the handset at the ear, noting things down with the other hand.")
for i, (w, tilt) in enumerate(((0, 0), (1, 1), (-1, 2), (1, 0), (0, -1), (1, 1))):
    phone.key(i * 0.5, root=(-3, 4, 0), neck=(-12, 6, 9 + tilt),
              lShoulder=J((148, 0, 18), (0.3, 0.18, -0.08)),
              rShoulder=J((46 + w, 0, -14 + 3 * w), (-0.12, 0.04, -0.22)))
soft(phone, arms=3.5).plant(stance=0.04)
phone.build()

lab = Motion("workForensics", 2.4, loop=True, note="Forensics: bent over the microscope, turning the focus knob.")
for i, (knob, look_at) in enumerate(((0, 0), (1, 0), (0, 1), (1, 0), (0, -1), (1, 0))):
    lab.key(i * 0.4, root=(-16, look_at, 0), neck=(-24, look_at * 2, 0),
            rShoulder=J((64, 10 * knob, -12), (-0.15, 0.06, -0.24)),
            lShoulder=J((62, 0, 12), (0.15, 0.06, -0.24)))
soft(lab, arms=3.5).plant(stance=0.05, forward=(0.1, -0.1))
lab.build()

raise_hand = Motion("raiseHand", 0.9, note="A vote: the hand goes up and stays there.")
raise_hand.key(0.0, **REST)
raise_hand.key(0.3, "out", root=(1, 0, -3), neck=(3, 0, -2), rShoulder=J((168, 0, 6), (0, 0.24, 0.02)))
raise_hand.key(0.9, root=(1, 0, -3), neck=(3, 0, -2), rShoulder=J((166, 0, 6), (0, 0.22, 0.02)))
soft(raise_hand).plant(stance=0.03)
raise_hand.build()

point = Motion("point", 1.6, note="Accuse: the body turns and an arm is levelled at someone.")
point.key(0.0, **REST)
point.key(0.35, "out", root=(-4, -10, 0), neck=(-3, -6, 0), rShoulder=J((88, -4, -3), (0, 0.1, -0.28)),
          lShoulder=J((-6, 0, -4), (0, 0, 0.06)))
point.key(1.6, root=(-3, -9, 0), neck=(-2, -6, 0), rShoulder=J((86, -4, -3), (0, 0.09, -0.26)), lShoulder=J((-4, 0, -4)))
soft(point).plant(stance=0.05, forward=(0.2, -0.1))
point.build()

# Held down ---------------------------------------------------------------------------------------------

cuffed = Motion("cuffed", 3.0, loop=True, note="Wrists cuffed behind the back, shoulders hunched, head down.")
for t, b in ((0.0, 0.0), (1.5, 1.0)):
    cuffed.key(t, offset=(0, -0.04 * b, 0), root=(-5 - b, 0, 0), neck=(-20 - 2 * b, 0, 0),
               rShoulder=J((-24, 0, -12), (-0.22, 0.06, 0.18)), lShoulder=J((-24, 0, 12), (0.22, 0.06, 0.18)))
soft(cuffed).plant(stance=0.03)
cuffed.build()

slump = Motion("slump", 1.6, note="Voted out: the shoulders roll forward, the head drops, the knees give a little.")
slump.key(0.0, **REST)
slump.key(0.5, "out", offset=(0, -0.08, 0), root=(-8, 0, 2), neck=(-28, 0, 3),
          rShoulder=J((10, 0, 0), (-0.05, -0.06, -0.08)), lShoulder=J((8, 0, 0), (0.05, -0.06, -0.08)))
slump.key(1.6, offset=(0, -0.14, 0), root=(-12, 0, 3), neck=(-36, 0, 4),
          rShoulder=J((12, 0, -1), (-0.06, -0.08, -0.1)), lShoulder=J((10, 0, 1), (0.06, -0.08, -0.1)))
soft(slump).plant(stance=0.03)
slump.build()

specter = Motion("specterFloat", 4.0, loop=True, note="Deathsingers drift: arms loose, legs drawn up and trailing.")
for t, b in ((0.0, 0.0), (2.0, 1.0)):
    specter.key(t, offset=(0, 0.3 * b, 0), root=(5 - 2 * b, 0, 2 - 4 * b), neck=(-4 + 3 * b, 0, 0),
                rShoulder=J((22 + 6 * b, 0, 24 + 6 * b), (0, 0.05, 0)), lShoulder=J((22 + 6 * b, 0, -24 - 6 * b), (0, 0.05, 0)),
                rHip=J((-12 + 4 * b, 0, 3), (0, 0.3, 0.12)), lHip=J((-6 - 4 * b, 0, -3), (0, 0.25, 0.1)))
soft(specter, head=1.2, arms=1.0).follow(("rHip", "lHip"), 1.0, 0.8)
specter.build()

# Deaths: each ends lying on the floor; the server then locks the final pose into the joints and lets
# the body go limp. floor=True keys work out the height so the body rests on the floor.

heart = Motion("collapseHeart", 2.4, note="A hand to the chest, the knees buckle, and down forward.", floor=True)
heart.key(0.0, **REST)
heart.key(0.2, "snap", offset=(0, -0.08, 0.04), root=(-14, 0, 0), neck=(-20, 0, 0), rShoulder=r_chest(64, -42),
          lShoulder=J((10, 0, -6), (0, 0, -0.05)))
heart.key(0.75, offset=(0.06, -0.2, 0.06), root=(-20, 6, 5), neck=(-24, 0, 6), rShoulder=r_chest(66, -42),
          lShoulder=J((34, 0, -12), (0, 0.04, -0.12)))
heart.key(1.2, "in", offset=(0.08, -0.95, -0.05), root=(-30, 6, 6), neck=(-16, 0, 6), rShoulder=r_chest(60, -38),
          lShoulder=J((48, 0, -14), (0, 0.05, -0.15)))
heart.plant(0.0, 1.2, stance=0.05, forward=(0.15, -0.05), tilt=(18, 14))
heart.key(1.75, "in", offset=(0.08, 0, -0.75), floor=True, root=(-74, 5, 6), neck=(4, 0, 10),
          rShoulder=J((80, 0, -20), (0, 0.05, -0.1)), lShoulder=J((110, 0, -24), (0, 0.05, 0)),
          rHip=J((40, 0, 3), (0, 0.4, 0)), lHip=J((36, 0, -3), (0, 0.4, 0)))
heart.key(2.4, "out", offset=(0.08, 0, -1.0), floor=True, root=(-89, 4, 5), neck=(14, 0, 18),
          rShoulder=J((150, 0, -14), (0, 0.04, 0)), lShoulder=J((130, 0, -26), (0, 0.04, 0)),
          rHip=J((4, 0, 3)), lHip=J((-2, 0, -3)))
soft(heart, arms=2.0)
heart.build()

ill = Motion("collapseDisease", 3.0, note="Racking coughs into the fist, a sway, sinking down, then onto the back.", floor=True)
ill.key(0.0, **REST)
for t, bend in ((0.18, 14), (0.4, 6), (0.62, 16), (0.84, 7), (1.06, 13)):
    ill.key(t, "snap", offset=(0, -0.05 - bend * 0.004, 0.03), root=(-bend, 0, 0), neck=(-12, 0, 0),
            rShoulder=r_face(112, -26), lShoulder=J((20, 0, 14), (0.15, 0, -0.08)))
ill.key(1.55, offset=(-0.06, -0.55, 0.05), root=(-10, -8, -6), neck=(-8, 0, -8),
        rShoulder=J((40, 0, 10), (0, 0, -0.1)), lShoulder=J((44, 0, -18), (0, 0, -0.1)))
ill.key(1.9, "in", offset=(-0.08, -1.05, 0.15), root=(4, -8, -6), neck=(-2, 0, -6),
        rShoulder=J((30, 0, 16)), lShoulder=J((32, 0, -20)))
ill.plant(0.0, 1.9, stance=0.06, forward=(0.1, -0.15), tilt=(24, 20))
ill.key(2.4, "in", offset=(-0.12, 0, 0.6), floor=True, root=(55, -6, -8), neck=(16, 0, -6),
        rShoulder=J((26, 0, 30)), lShoulder=J((34, 0, -26)), rHip=J((40, 0, 4), (0, 0.4, 0)), lHip=J((30, 0, -4), (0, 0.35, 0)))
ill.key(3.0, "out", offset=(-0.12, 0, 0.95), floor=True, root=(88, -5, -10), neck=(20, 0, -12),
        rShoulder=J((10, 0, 42)), lShoulder=J((16, 0, -36)), rHip=J((-2, 0, 5)), lHip=J((-6, 0, -5)))
soft(ill, arms=2.2)
ill.build()

acc = Motion("collapseAccident", 1.9, note="Struck from the side: knocked off balance, the knees go, down.", floor=True)
acc.key(0.0, **REST)
acc.key(0.1, "snap", offset=(0.3, -0.05, 0.05), root=(-6, 16, 24), neck=(-4, 0, -18),
        rShoulder=J((30, 0, 40), (0, 0.1, 0)), lShoulder=J((22, 0, -20)))
acc.key(0.45, "in", offset=(0.75, -0.8, 0.2), root=(8, 24, 50), neck=(4, 0, -20),
        rShoulder=J((50, 0, 56), (0, 0.1, 0)), lShoulder=J((30, 0, -30)), rHip=J((-8, 0, 14), (0, 0.3, 0)),
        lHip=J((24, 0, -6), (0, 0.5, 0)))
acc.key(0.95, "in", offset=(1.3, 0, 0.3), floor=True, root=(40, 20, 62), neck=(8, 0, -12),
        rShoulder=J((20, 0, 60)), lShoulder=J((16, 0, -34)), rHip=J((-4, 0, 14), (0, 0.2, 0)), lHip=J((16, 0, -8), (0, 0.3, 0)))
acc.key(1.4, "in", offset=(1.4, 0, 0.4), floor=True, root=(86, 10, 8), neck=(12, 0, -10),
        rShoulder=J((6, 0, 48)), lShoulder=J((12, 0, -30)), rHip=J((-2, 0, 10)), lHip=J((6, 0, -8)))
acc.key(1.9, "out", offset=(1.4, 0, 0.4), floor=True, root=(87, 10, 8), neck=(13, 0, -10),
        rShoulder=J((6, 0, 49)), lShoulder=J((12, 0, -31)), rHip=J((-2, 0, 10)), lHip=J((6, 0, -8)))
soft(acc, arms=2.6)
acc.build()

# Reactions: the table's one-shot reaction to a death, an arrest or a verdict (they hold their last
# pose, then fade out).

gasp = Motion("reactGasp", 1.6, note="A sharp breath in, a half step back, a hand to the chest.")
gasp.key(0.0, **REST)
gasp.key(0.25, "out", offset=(0, 0.03, 0.14), root=(6, 0, 0), neck=(6, 0, 0), rShoulder=r_chest(66, -40),
         lShoulder=J((16, 0, -16), (0, 0.05, -0.05)))
gasp.key(1.6, offset=(0, -0.02, 0.14), root=(3, 0, 0), neck=(2, 0, 0), rShoulder=r_chest(62, -40),
         lShoulder=J((10, 0, -10)))
soft(gasp).plant(stance=0.05, forward=(-0.15, 0.05))
gasp.build()

startle = Motion("reactStartle", 1.2, note="A flinch: the body jerks back, the arms come up to guard.")
startle.key(0.0, **REST)
startle.key(0.12, "snap", offset=(0, -0.12, 0.25), root=(10, 0, 0), neck=(8, 0, 0),
            rShoulder=J((80, 0, -20), (-0.15, 0.15, -0.2)), lShoulder=J((80, 0, 20), (0.15, 0.15, -0.2)))
startle.key(1.2, offset=(0, -0.05, 0.25), root=(4, 0, 0), neck=(2, 0, 0),
            rShoulder=J((36, 0, -10), (-0.05, 0.05, -0.1)), lShoulder=J((36, 0, 10), (0.05, 0.05, -0.1)))
soft(startle, arms=3.2).plant(stance=0.08, forward=(-0.2, -0.25))
startle.build()

hands_head = Motion("reactHandsHead", 2.0, note="Both hands to the head in disbelief, a slow shake.")
hands_head.key(0.0, **REST)
hands_head.key(0.4, "out", root=(-6, 0, 0), neck=(-12, 0, 0),
               rShoulder=J((150, 0, -26), (-0.25, 0.25, -0.05)), lShoulder=J((150, 0, 26), (0.25, 0.25, -0.05)))
for t, s in ((0.9, 1), (1.4, -1), (2.0, 0)):
    hands_head.key(t, root=(-7, 3 * s, 0), neck=(-14, 9 * s, 0),
                   rShoulder=J((150, 0, -26), (-0.25, 0.25, -0.05)), lShoulder=J((150, 0, 26), (0.25, 0.25, -0.05)))
soft(hands_head).plant(stance=0.05)
hands_head.build()

cover = Motion("reactCoverMouth", 1.8, note="A hand flies to the mouth, the other across the stomach.")
cover.key(0.0, **REST)
cover.key(0.3, "out", offset=(0, 0, 0.08), root=(3, 0, 0), neck=(2, 0, 0), rShoulder=r_face(),
          lShoulder=J((44, 0, 30), (0.28, 0, -0.18)))
cover.key(1.8, offset=(0, -0.02, 0.08), root=(1, 0, 0), neck=(-4, 0, 0), rShoulder=r_face(120, -32),
          lShoulder=J((42, 0, 30), (0.28, 0, -0.18)))
soft(cover).plant(stance=0.04, forward=(-0.1, 0.05))
cover.build()

look_away = Motion("reactLookAway", 1.8, note="Turns away from it, arms folded tight.")
look_away.key(0.0, **REST)
look_away.key(0.55, root=(-3, 20, 0), neck=(-10, 42, 0), rShoulder=r_chest(44, -40), lShoulder=l_chest(42, 38))
look_away.key(1.8, root=(-4, 22, 0), neck=(-12, 44, 0), rShoulder=r_chest(44, -40), lShoulder=l_chest(42, 38))
soft(look_away).plant(stance=0.04)
look_away.build()

clap = Motion("reactSlowClap", 1.2, loop=True, note="A slow, deliberate clap.")
clap.key(0.0, root=(0, 0, 0), neck=(2, 0, 0), rShoulder=J((58, 0, -10), (-0.05, 0.08, -0.2)), lShoulder=J((58, 0, 10), (0.05, 0.08, -0.2)))
clap.key(0.45, "in", root=(-1, 0, 0), neck=(2, 0, 0), rShoulder=J((60, 0, -30), (-0.25, 0.1, -0.22)),
         lShoulder=J((60, 0, 30), (0.25, 0.1, -0.22)))
soft(clap, arms=4.0).plant(stance=0.04)
clap.build()

shrug = Motion("shrug", 2.0, note="Palms out, shoulders up: who knows?")
shrug.key(0.0, **REST)
shrug.key(0.35, "out", root=(-2, 0, 3), neck=(0, 0, 8), rShoulder=J((34, -20, 30), (0.05, 0.2, -0.08)),
          lShoulder=J((34, 20, -30), (-0.05, 0.2, -0.08)))
shrug.key(1.2, root=(-2, 0, 3), neck=(0, 0, 7), rShoulder=J((32, -20, 28), (0.05, 0.18, -0.08)),
          lShoulder=J((32, 20, -28), (-0.05, 0.18, -0.08)))
shrug.key(2.0, **REST)
soft(shrug).plant(stance=0.04)
shrug.build()

facepalm = Motion("facepalm", 2.4, note="The head drops into a hand; a long breath out.")
facepalm.key(0.0, **REST)
facepalm.key(0.45, root=(-6, 0, 0), neck=(-24, 0, 0), rShoulder=r_face(128, -30))
facepalm.key(1.7, offset=(0, -0.04, 0), root=(-8, 0, 0), neck=(-28, 0, 0), rShoulder=r_face(126, -30))
facepalm.key(2.4, **REST)
soft(facepalm).plant(stance=0.04)
facepalm.build()

# Emotes ------------------------------------------------------------------------------------------------

wave = Motion("wave", 2.4, note="A raised hand and an easy wave.")
wave.key(0.0, **REST)
wave.key(0.4, root=(0, 0, -3), neck=(2, 0, -4), rShoulder=J((140, 0, 26), (0.05, 0.18, 0)))
for i in range(4):
    wave.key(0.7 + i * 0.3, root=(0, 0, -3), neck=(2, 0, -4), rShoulder=J((140, 0, 26 + (14 if i % 2 == 0 else -6)), (0.05, 0.18, 0)))
wave.key(2.4, **REST)
soft(wave, arms=3.0).plant(stance=0.04)
wave.build()

cheer = Motion("cheer", 2.2, note="A fist pumped twice into the air.")
cheer.key(0.0, **REST)
cheer.key(0.2, "in", offset=(0, -0.15, 0), root=(-6, 0, 0), neck=(-4, 0, 0), rShoulder=J((60, 0, 10), (0, 0, -0.1)))
cheer.key(0.42, "out", offset=(0, 0, 0), root=(4, 0, -3), neck=(10, 0, 0), rShoulder=J((168, 0, 8), (0, 0.3, 0)))
cheer.key(0.7, offset=(0, -0.08, 0), root=(1, 0, -2), neck=(6, 0, 0), rShoulder=J((140, 0, 10), (0, 0.12, 0)))
cheer.key(0.92, "out", offset=(0, 0, 0), root=(4, 0, -3), neck=(10, 0, 0), rShoulder=J((168, 0, 8), (0, 0.3, 0)))
cheer.key(1.5, root=(3, 0, -2), neck=(8, 0, 0), rShoulder=J((165, 0, 8), (0, 0.28, 0)))
cheer.key(2.2, offset=(0, 0, 0), **REST)
soft(cheer, arms=3.0).plant(stance=0.06)
cheer.build()

# The villain's laugh: a hand half over the face, leaning back, the shoulders shaking.
laugh = Motion("laugh", 1.2, loop=True, note="A low, unhinged laugh, a hand over the face.")
for t, s in ((0.0, 0), (0.15, 1), (0.3, 0), (0.45, 1), (0.6, 0), (0.75, 1), (0.9, 0), (1.05, 1)):
    laugh.key(t, offset=(0, 0.02 * s, 0), root=(7 + 1.5 * s, 0, 0), neck=(16 + 2 * s, 0, 2),
              rShoulder=J((124, 0, -30), (-0.26, 0.18 + 0.04 * s, -0.2)), lShoulder=J((6, 0, -6), (0, 0.04 * s, 0)))
soft(laugh, arms=5.0).plant(stance=0.05)
laugh.build()

dance = Motion("dance", 1.6, loop=True, note="A loose two-step: the weight rocks side to side, arms swinging with it.")
for i in range(4):
    s = 1 if i % 2 == 0 else -1
    dance.key(i * 0.4, offset=(0.2 * s, -0.18, 0), root=(-3, 10 * s, 5 * s), neck=(-2, -6 * s, -4 * s),
              rShoulder=J((30 + 20 * s, 0, 10), (0, 0.06, -0.12 * s)), lShoulder=J((30 - 20 * s, 0, -10), (0, 0.06, 0.12 * s)))
soft(dance, arms=2.2).plant(stance=0.25)
dance.build()

groove = Motion("dance2", 1.0, loop=True, note="Bouncing on the beat, shoulders rolling, a head nod.")
for i in range(4):
    beat = 1 if i % 2 == 0 else 0
    side = (1, 1, -1, -1)[i]
    groove.key(i * 0.25, offset=(0.05 * side, -0.22 * beat - 0.05, 0), root=(-4 * beat, 5 * side, 2 * side),
               neck=(-8 * beat, 0, 0), rShoulder=J((22 + 10 * beat, 0, 8), (0, 0.1 * (1 - beat) * (side > 0), -0.08)),
               lShoulder=J((22 + 10 * beat, 0, -8), (0, 0.1 * (1 - beat) * (side < 0), -0.08)))
soft(groove, arms=3.0).plant(stance=0.15)
groove.build()

spin = Motion("dance3", 1.6, loop=True, note="A smooth turn on the spot, arms opening out.")
for i in range(5):  # a full turn: the last key (360) meets the first on the loop
    spin.key(i * 0.4, "linear", root=(0, 90 * i, 0), neck=(0, -10, 0), rShoulder=J((16, 0, 36), (0, 0.08, 0)),
             lShoulder=J((16, 0, -36), (0, 0.08, 0)))
soft(spin, arms=2.0)
spin.build()

salute = Motion("salute", 2.0, note="A crisp Bureau salute.")
salute.key(0.0, **REST)
salute.key(0.28, "out", root=(2, 0, 0), neck=(4, 0, 0), rShoulder=J((148, 0, -34), (-0.2, 0.22, -0.12)))
salute.key(1.3, root=(2, 0, 0), neck=(4, 0, 0), rShoulder=J((148, 0, -34), (-0.2, 0.22, -0.12)))
salute.key(1.6, "in", **REST)
salute.key(2.0, **REST)
soft(salute, arms=4.0).plant(stance=0.02)
salute.build()

bow = Motion("bow", 2.6, note="A polite bow from the waist.")
bow.key(0.0, **REST)
bow.key(0.8, root=(-36, 0, 0), neck=(-10, 0, 0), rShoulder=J((8, 0, 2), (0, 0, -0.05)), lShoulder=J((8, 0, -2), (0, 0, -0.05)))
bow.key(1.6, root=(-37, 0, 0), neck=(-10, 0, 0), rShoulder=J((8, 0, 2), (0, 0, -0.05)), lShoulder=J((8, 0, -2), (0, 0, -0.05)))
bow.key(2.6, **REST)
soft(bow).plant(stance=0.02)
bow.build()

# The anime's chip: raised, held in the light, then eaten in one decisive bite.
chip = Motion("chip", 3.2, note="The dramatic chip: raised, held, then eaten in one move.")
chip.key(0.0, **REST)
chip.key(0.7, root=(5, 0, 3), neck=(8, 0, 5), rShoulder=J((116, 0, 14), (0, 0.18, -0.12)))
chip.key(1.8, root=(6, 0, 3), neck=(10, 0, 5), rShoulder=J((120, 0, 14), (0, 0.2, -0.12)))
chip.key(2.05, "snap", root=(-5, 0, 0), neck=(-6, 0, 0), rShoulder=r_face(130, -30))
chip.key(2.6, root=(-5, 0, 0), neck=(-7, 0, 0), rShoulder=r_face(128, -30))
chip.key(3.2, **REST)
soft(chip, arms=3.0).plant(stance=0.04)
chip.build()

think = Motion("think", 4.0, loop=True, note="Crouched like a detective, a thumb to the lip.")
for t, b in ((0.0, 0.0), (2.0, 1.0)):
    think.key(t, offset=(0, -1.2 + 0.03 * b, 0), root=(-14 + b, 0, 0), neck=(-4 + b, 4 * b, 0),
              rShoulder=J((108, 0, -34), (-0.3, 0.3, -0.25)), lShoulder=J((72, 0, 14), (0.1, 0.1, -0.3)))
soft(think, head=1.5, arms=1.5).plant(stance=0.18, tilt=(28, 28))
think.build()


def build(arm):
    import animlib

    return animlib.build_all(arm)
