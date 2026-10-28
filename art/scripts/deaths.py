"""The custom deaths' actings (Shared/Cosmetics kind "reason", the cause written in the Manual; the user's call of
2026-10-27: one acting for each, matched to its effect). anims.py imports this file near its end, so its helpers are
ready. Each plays instead of the heart attack's collapse when its cause is the one written (Shared/Anim/Causes) and,
like the collapses, ends lying still on the floor: the server then locks the last pose into the joints.

The death cutscene starts each effect (Presentation/CustomDeaths) 0.9 s in, as the body begins to go, so each
acting's big moment lands on its effect's: the floor's slam, the heart's two beats, the frost breaking off, the
chandelier landing, the bolt, the pages, the flame, the crunch, the clock's tick, the dark closing over.

Angles as everywhere here: root (pitch, yaw, roll), a negative pitch bends forward (face down at -90), a positive one
back (on the back at +88); offset z negative is forward. Keys with floor=True rest the body on the floor."""

from anims import REST, r_chest, r_face, soft
from animlib import J
from motion import Motion

L_CHEST = J((60, 0, 36), (0.3, 0.12, -0.22))
L_FACE = J((118, 0, 30), (0.28, 0.18, -0.22))
# Lying face down, arms thrown out over the head, the legs straight.
DOWN = dict(rHip=J((2, 0, 4)), lHip=J((-2, 0, -4)))
# Lying on the back, the legs straight.
BACK = dict(rHip=J((-2, 0, 5)), lHip=J((-4, 0, -5)))


def lie_down(m, t, ease="in", z=-1.0, roll=4, yaw=0, neck=(12, 0, 14), r=J((150, 0, -16)), l=J((140, 0, 22))):
    m.key(t, ease, offset=(0.05, 0, z), floor=True, root=(-89, yaw, roll), neck=neck, rShoulder=r, lShoulder=l, **DOWN)


def lie_back(m, t, ease="in", z=0.95, roll=-6, yaw=0, neck=(18, 0, -10), r=J((14, 0, 40)), l=J((18, 0, -36))):
    m.key(t, ease, offset=(-0.1, 0, z), floor=True, root=(88, yaw, roll), neck=neck, rShoulder=r, lShoulder=l, **BACK)


# A long fall: the floor goes from under them; arms flung up, they drop and slam flat (the floor's slam at 1.15 s).
fall = Motion("deathFall", 2.4, note="The floor goes: arms flung up, a drop, slammed flat on the face.", floor=True)
fall.key(0.0, **REST)
fall.key(0.18, "snap", offset=(0, 0.12, 0.05), root=(8, 0, 0), neck=(18, 0, 0),
         rShoulder=J((150, 0, 34), (0, 0.15, 0)), lShoulder=J((150, 0, -34), (0, 0.15, 0)))
fall.key(0.55, "in", offset=(0, -0.5, -0.25), root=(-24, 0, 4), neck=(10, 0, 0),
         rShoulder=J((165, 0, 24)), lShoulder=J((160, 0, -26)), rHip=J((14, 0, 6)), lHip=J((-10, 0, -6)))
fall.plant(0.0, 0.3, stance=0.05)
lie_down(fall, 1.1, "in", z=-1.1, r=J((168, 0, 24)), l=J((166, 0, -22)))
fall.key(1.25, "out", offset=(0.05, 0.25, -1.1), floor=True, root=(-82, 0, 4), neck=(20, 0, 10),
         rShoulder=J((160, 0, 28)), lShoulder=J((158, 0, -26)), **DOWN)
lie_down(fall, 1.5, "in", z=-1.1, r=J((166, 0, 26)), l=J((164, 0, -24)))
lie_down(fall, 2.4, "out", z=-1.1, neck=(14, 0, 16), r=J((165, 0, 25)), l=J((163, 0, -23)))
soft(fall, arms=2.6)
fall.build()

# A broken heart: both hands to the heart, a jolt on each of its two beats (0.9, 1.22 s), and they crumple forward.
heart = Motion("deathHeart", 2.8, note="Both hands to the heart, two jolts on its beats, a crumple onto the face.",
               floor=True)
heart.key(0.0, **REST)
heart.key(0.5, offset=(0, -0.05, 0), root=(-8, 0, 0), neck=(-16, 0, 0), rShoulder=r_chest(66, -42), lShoulder=L_CHEST)
heart.key(0.9, "snap", offset=(0, -0.12, 0.08), root=(-18, 0, 4), neck=(-28, 0, 4), rShoulder=r_chest(70, -44),
          lShoulder=J((64, 0, 40), (0.3, 0.12, -0.22)))
heart.key(1.08, offset=(0, -0.1, 0.04), root=(-12, 0, 2), neck=(-20, 0, 2), rShoulder=r_chest(66, -42), lShoulder=L_CHEST)
heart.key(1.22, "snap", offset=(0, -0.3, 0.1), root=(-24, 0, 6), neck=(-30, 0, 6), rShoulder=r_chest(70, -44),
          lShoulder=J((64, 0, 40), (0.3, 0.12, -0.22)))
heart.key(1.65, "in", offset=(0.05, -0.95, -0.05), root=(-34, 4, 8), neck=(-20, 0, 8), rShoulder=r_chest(62, -40),
          lShoulder=J((56, 0, 34), (0.3, 0.1, -0.2)))
heart.plant(0.0, 1.65, stance=0.05, forward=(0.15, -0.05), tilt=(18, 14))
lie_down(heart, 2.2, "in", r=J((70, 0, -40), (-0.2, 0.08, -0.1)), l=J((66, 0, 36), (0.2, 0.08, -0.1)))
lie_down(heart, 2.8, "out", neck=(10, 0, 18), r=J((72, 0, -42), (-0.2, 0.08, -0.1)), l=J((68, 0, 38), (0.2, 0.08, -0.1)))
soft(heart, arms=2.2)
heart.build()

# Frozen where they stood: a shiver as the cold climbs, then held rigid (the frost climbing, 0.9-1.7 s), and they
# topple stiff like a plank, arms where the cold caught them.
frost = Motion("deathFrost", 2.6, note="A shiver, frozen rigid mid-pose, then toppling stiff like a plank.", floor=True)
frost.key(0.0, **REST)
for k, t in enumerate((0.15, 0.3, 0.45, 0.6, 0.75)):
    s = 1 if k % 2 else -1
    frost.key(t, "snap", offset=(0.02 * s, -0.06, 0), root=(-6, 0, 2 * s), neck=(-10, 3 * s, 0),
              rShoulder=J((40, 0, -46), (-0.3, 0.12, -0.2)), lShoulder=J((40, 0, 46), (0.3, 0.12, -0.2)))
FROZEN = dict(rShoulder=J((42, 0, -44), (-0.3, 0.12, -0.2)), lShoulder=J((42, 0, 44), (0.3, 0.12, -0.2)))
frost.key(0.9, "snap", offset=(0, -0.06, 0), root=(-6, 0, 0), neck=(-8, 0, 0), **FROZEN)
frost.key(1.7, offset=(0, -0.06, 0), root=(-7, 0, 0), neck=(-8, 0, 0), **FROZEN)
frost.plant(0.0, 1.7, stance=0.04)
frost.key(2.05, "in", offset=(0, -1.6, -1.6), root=(-48, 0, 0), neck=(-8, 0, 0), rHip=J((0, 0, 3)), lHip=J((0, 0, -3)),
          **FROZEN)
frost.key(2.25, "in", offset=(0, 0, -2.4), floor=True, root=(-90, 0, 0), neck=(-8, 0, 0), **FROZEN, **DOWN)
frost.key(2.6, "out", offset=(0, 0, -2.4), floor=True, root=(-89, 0, 1), neck=(-7, 0, 0), **FROZEN, **DOWN)
soft(frost, head=0.6, arms=0.6)
frost.build()

# The chandelier: a look up at a sound above (0.5 s), arms coming up too late, and crushed flat (it lands at 1.4 s).
chand = Motion("deathChandelier", 2.4, note="A look up, the arms coming up too late, crushed flat.", floor=True)
chand.key(0.0, **REST)
chand.key(0.5, "out", offset=(0, 0, 0.1), root=(6, 0, 0), neck=(40, 0, 0), rShoulder=J((14, 0, -10)),
          lShoulder=J((14, 0, 10)))
chand.key(1.3, "in", offset=(0, -0.15, 0.1), root=(4, 0, 0), neck=(30, 0, 0), rShoulder=J((150, 0, -30), (0, 0.1, 0)),
          lShoulder=J((150, 0, 30), (0, 0.1, 0)))
chand.plant(0.0, 1.3, stance=0.05)
chand.key(1.42, "snap", offset=(0, -1.8, -0.4), root=(-50, 0, 6), neck=(-20, 0, 0), rShoulder=J((120, 0, -60)),
          lShoulder=J((120, 0, 60)), rHip=J((40, 0, 10)), lHip=J((36, 0, -10)))
lie_down(chand, 1.6, "in", z=-0.9, neck=(4, 0, 20), r=J((100, 0, -80)), l=J((100, 0, 80)))
lie_down(chand, 2.4, "out", z=-0.9, neck=(6, 0, 20), r=J((98, 0, -82)), l=J((98, 0, 82)))
soft(chand, arms=2.4)
chand.build()

# Drowned on dry land: hands clawing at the throat, a struggling sway, and a slow sinking as if under water, onto the
# back, the arms drifting up a little (the rings and bubbles from 0.9 s).
drown = Motion("deathDrown", 3.2, note="Clawing at the throat, a struggling sway, a slow sink onto the back.",
               floor=True)
drown.key(0.0, **REST)
for k, t in enumerate((0.3, 0.6, 0.9, 1.2)):
    s = 1 if k % 2 else -1
    drown.key(t, offset=(0.04 * s, -0.05 - 0.04 * k, 0), root=(4 + 2 * k, 6 * s, 4 * s), neck=(18, 8 * s, 0),
              rShoulder=r_face(126 + 6 * s, -34), lShoulder=J((124 - 6 * s, 0, 32), (0.28, 0.18, -0.22)))
drown.key(1.8, "out", offset=(0, -0.7, 0.1), root=(10, 0, -4), neck=(20, 0, 0), rShoulder=J((60, 0, -30)),
          lShoulder=J((64, 0, 30)), rHip=J((30, 0, 4), (0, 0.3, 0)), lHip=J((26, 0, -4), (0, 0.3, 0)))
drown.plant(0.0, 1.8, stance=0.05, forward=(-0.1, -0.1), tilt=(-10, -8))
drown.key(2.5, "in", offset=(-0.1, 0, 0.7), floor=True, root=(70, 0, -4), neck=(20, 0, -6), rShoulder=J((60, 0, 30)),
          lShoulder=J((64, 0, -30)), rHip=J((30, 0, 4), (0, 0.3, 0)), lHip=J((24, 0, -4), (0, 0.3, 0)))
lie_back(drown, 3.2, "out", neck=(20, 0, -8), r=J((50, 0, 34)), l=J((54, 0, -30)))
soft(drown, head=2.0, arms=1.6, arm_damp=0.8)
drown.build()

# Struck by lightning: rigid on the bolt (0.9 s), arched back, arms flung out stiff, shaking, then dropped stiff onto
# the back.
bolt = Motion("deathLightning", 2.4, note="Rigid on the bolt: arched back, arms out stiff, shaking, dropped flat.",
              floor=True)
bolt.key(0.0, **REST)
bolt.key(0.85, offset=(0, 0, 0), root=(0, 0, 0), neck=(-2, 0, 0), rShoulder=J((4, 0, -4)), lShoulder=J((4, 0, 4)))
for k, t in enumerate((0.92, 1.0, 1.08, 1.16, 1.24, 1.32)):
    s = 1 if k % 2 else -1
    bolt.key(t, "snap", offset=(0.02 * s, 0.1, 0.05), root=(12 + 2 * s, 0, 2 * s), neck=(34 + 3 * s, 0, 0),
             rShoulder=J((20 + 4 * s, 0, 84)), lShoulder=J((20 - 4 * s, 0, -84)))
bolt.plant(0.0, 1.35, stance=0.06)
bolt.key(1.7, "in", offset=(0, -1.4, 1.3), root=(55, 0, 0), neck=(30, 0, 0), rShoulder=J((16, 0, 84)),
         lShoulder=J((16, 0, -84)), rHip=J((0, 0, 6)), lHip=J((0, 0, -6)))
lie_back(bolt, 1.95, "in", z=2.1, neck=(20, 0, 0), r=J((10, 0, 84)), l=J((10, 0, -84)))
lie_back(bolt, 2.4, "out", z=2.1, neck=(18, 0, -4), r=J((10, 0, 82)), l=J((10, 0, -82)))
soft(bolt, head=0.8, arms=0.8)
bolt.build()

# A thousand paper cuts: arms up over the face against the whirl, flinching this way and that, staggering half round,
# and down on the face.
pages = Motion("deathPages", 2.8, note="Arms up over the face against the whirl, flinching, staggering, down.",
               floor=True)
pages.key(0.0, **REST)
for k, t in enumerate((0.3, 0.6, 0.9, 1.15, 1.4, 1.65)):
    s = 1 if k % 2 else -1
    pages.key(t, "snap", offset=(0.08 * s, -0.08, 0.05), root=(-10, 20 * s + 10 * k, 6 * s), neck=(-14, -10 * s, 0),
              rShoulder=r_face(130, -40), lShoulder=L_FACE)
pages.plant(0.0, 1.8, stance=0.05)
pages.key(2.0, "in", offset=(0.1, -1.0, -0.3), root=(-40, 90, 10), neck=(-10, 0, 0), rShoulder=r_face(110, -40),
          lShoulder=J((100, 0, 30)), rHip=J((30, 0, 6), (0, 0.3, 0)), lHip=J((20, 0, -6), (0, 0.3, 0)))
lie_down(pages, 2.4, "in", yaw=90, neck=(8, 0, 18), r=J((140, 0, -50)), l=J((150, 0, 30)))
lie_down(pages, 2.8, "out", yaw=90, neck=(8, 0, 20), r=J((140, 0, -52)), l=J((150, 0, 32)))
soft(pages, arms=2.4)
pages.build()

# Burned from within: doubled over, hands at the stomach as the glow comes (0.9 s), the head thrown back as it takes
# them, and a fall forward onto the face as the flame licks up (1.9 s).
burn = Motion("deathBurn", 2.8, note="Doubled over, hands at the stomach, head thrown back, down on the face.",
              floor=True)
burn.key(0.0, **REST)
burn.key(0.6, "in", offset=(0, -0.15, 0.1), root=(-30, 0, 0), neck=(-20, 0, 0), rShoulder=J((40, 0, -40), (-0.3, 0, -0.2)),
         lShoulder=J((40, 0, 40), (0.3, 0, -0.2)))
burn.key(1.2, "out", offset=(0, -0.1, 0.25), root=(12, 0, 0), neck=(40, 0, 0), rShoulder=J((60, 0, -60)),
         lShoulder=J((60, 0, 60)))
burn.key(1.6, "in", offset=(0, -0.6, 0.1), root=(-24, 0, 4), neck=(-10, 0, 0), rShoulder=J((40, 0, -40), (-0.3, 0, -0.2)),
         lShoulder=J((40, 0, 40), (0.3, 0, -0.2)), rHip=J((24, 0, 4), (0, 0.3, 0)), lHip=J((20, 0, -4), (0, 0.3, 0)))
burn.plant(0.0, 1.6, stance=0.05, forward=(0.1, 0.0), tilt=(14, 12))
lie_down(burn, 2.2, "in", r=J((90, 0, -40)), l=J((96, 0, 40)))
lie_down(burn, 2.8, "out", neck=(10, 0, 16), r=J((92, 0, -42)), l=J((98, 0, 42)))
soft(burn, arms=2.2)
burn.build()

# Choked on a potato chip: a hand up to the mouth (a bite), frozen at the crunch (0.9 s), both hands to the throat,
# staggering back, and over onto the back.
chip = Motion("deathChip", 2.6, note="A bite, frozen at the crunch, hands to the throat, staggering back, over.",
              floor=True)
chip.key(0.0, **REST)
chip.key(0.45, "out", root=(0, 0, 0), neck=(4, 0, 0), rShoulder=r_face(128, -30), lShoulder=J((8, 0, 4)))
chip.key(0.9, "snap", offset=(0, 0.04, 0), root=(-4, 0, 0), neck=(-6, 0, 0), rShoulder=r_face(126, -30),
         lShoulder=J((8, 0, 4)))
chip.key(1.25, "out", offset=(0, -0.05, 0.2), root=(10, 0, -4), neck=(22, 0, 0), rShoulder=r_face(122, -36),
         lShoulder=J((120, 0, 36), (0.28, 0.18, -0.22)))
chip.key(1.6, offset=(0, -0.1, 0.5), root=(14, -8, 6), neck=(26, 0, 0), rShoulder=r_face(118, -36),
         lShoulder=J((116, 0, 36), (0.28, 0.18, -0.22)))
chip.plant(0.0, 1.6, stance=0.05, forward=(-0.1, 0.0), tilt=(-14, -12))
chip.key(1.95, "in", offset=(0, -1.2, 1.0), root=(56, -8, 6), neck=(22, 0, 0), rShoulder=J((110, 0, -30)),
         lShoulder=J((110, 0, 30)), rHip=J((30, 0, 6), (0, 0.3, 0)), lHip=J((26, 0, -6), (0, 0.3, 0)))
lie_back(chip, 2.2, "in", z=1.4, r=J((60, 0, 34)), l=J((56, 0, -32)))
lie_back(chip, 2.6, "out", z=1.4, neck=(16, 0, -10), r=J((30, 0, 40)), l=J((26, 0, -38)))
soft(chip, arms=2.2)
chip.build()

# Their time ran out: everything slows; the back bows as if the years came at once, the knees go slower and slower,
# and they settle onto the side and are still (the stopwatch turns under them, 0.9-3.1 s).
clock = Motion("deathClock", 3.4, note="Slowing: the back bowing as if old, the knees going slower and slower, down.",
               floor=True)
clock.key(0.0, **REST)
clock.key(0.8, offset=(0, -0.08, 0.04), root=(-10, 0, 0), neck=(-14, 0, 0), rShoulder=J((10, 0, -4)),
          lShoulder=J((10, 0, 4)))
clock.key(1.8, offset=(0, -0.35, 0.1), root=(-24, 0, 2), neck=(-24, 0, 2), rShoulder=J((22, 0, -6), (0, -0.05, -0.1)),
          lShoulder=J((26, 0, 6), (0, -0.05, -0.1)))
clock.key(2.6, offset=(0.05, -0.9, 0.05), root=(-32, 4, 6), neck=(-22, 0, 6), rShoulder=J((34, 0, -10)),
          lShoulder=J((40, 0, 8)))
clock.plant(0.0, 2.6, stance=0.05, forward=(0.1, -0.05), tilt=(14, 12))
lie_down(clock, 3.1, "in", z=-0.8, roll=12, neck=(8, 0, 22), r=J((60, 0, -30)), l=J((70, 0, 30)))
lie_down(clock, 3.4, "out", z=-0.8, roll=12, neck=(8, 0, 22), r=J((60, 0, -30)), l=J((70, 0, 30)))
soft(clock, head=4.0, arms=3.6, head_damp=0.85, arm_damp=0.8)
clock.build()

# Taken by the dark: pulled backwards by something unseen (as the shadow rises, 0.9 s), reaching out, dragged down onto
# the back as it closes over them (1.45 s), one hand still up a moment.
dark = Motion("deathDark", 2.6, note="Pulled backwards by something unseen, reaching out, dragged down.", floor=True)
dark.key(0.0, **REST)
dark.key(0.7, offset=(0, -0.05, 0), root=(-4, 0, 0), neck=(-6, 20, 0), rShoulder=J((8, 0, -6)), lShoulder=J((8, 0, 6)))
dark.key(0.95, "snap", offset=(0, -0.1, 0.5), root=(18, 0, 0), neck=(-20, 0, 0), rShoulder=J((90, 0, -10)),
         lShoulder=J((96, 0, 10)))
dark.key(1.2, "in", offset=(0, -0.7, 1.0), root=(34, 0, 0), neck=(-24, 0, 0), rShoulder=J((100, 0, -14)),
         lShoulder=J((104, 0, 12)), rHip=J((40, 0, 4), (0, 0.3, 0)), lHip=J((44, 0, -4), (0, 0.3, 0)))
dark.plant(0.0, 0.95, stance=0.05)
lie_back(dark, 1.5, "in", z=1.6, neck=(-10, 0, 0), r=J((110, 0, -10)), l=J((150, 0, 10)))
lie_back(dark, 2.0, "in", z=1.9, neck=(4, 0, -6), r=J((60, 0, 20)), l=J((140, 0, -6)))
lie_back(dark, 2.6, "out", z=2.0, neck=(14, 0, -8), r=J((20, 0, 36)), l=J((30, 0, -30)))
soft(dark, arms=2.0)
dark.build()
