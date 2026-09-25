"""Every Inkbound animation, keyed in the game's joint convention (see animlib.py) on the real
R15 rig (rig.py).

Style: punchy and cartoony, in the spirit of Ink Game. Strong silhouettes, anticipation before
big moves, fast arrivals that overshoot and settle (snap / overshoot eases), bouncy bodies.
Movement (idle, walk, run, land) is generated with leg IK in gait.py. Wherever the hips move
here, the legs are solved so the feet stay planted (posekit.planted_legs), and every pose that
ends on the ground is fitted to the floor (posekit.on_floor), so nothing sinks or floats.

Run build() in Blender (see art/README.md) to rebuild the actions on the rig, then
export_anims.py writes src/shared/Anim/Clips.luau.
"""

import gait
from animlib import clip
from posekit import fitted_kneel, kneeling_leg, on_floor, planted_legs

# Shorthands for the arm joints (right arm +z is out to the side, left arm -z).


def arms(r=(0, 0, 6), l=(0, 0, -6), re=10, le=10, rw=(0, 0, 0), lw=(0, 0, 0)):
    return {"rShoulder": r, "lShoulder": l, "rElbow": re, "lElbow": le, "rWrist": rw, "lWrist": lw}


def stand(c, t, ease="smooth", offset=(0, 0, 0), root=(0, 0, 0), stance=0.0, forward=(0.0, 0.0), **upper):
    """A key with both feet planted while the hips move by `offset` and turn by `root`."""
    legs = planted_legs(offset, root, stance, forward)
    c.pose(t, ease, offset=offset, root=root, **legs, **upper)


def floor_key(c, t, ease, offset_xz=(0, 0), **joints):
    """A key whose body rests on the floor (the height is worked out)."""
    offset = on_floor(joints, (offset_xz[0], 0, offset_xz[1]))
    c.pose(t, ease, offset=offset, **joints)


# Locomotion --------------------------------------------------------------------------------------------

gait.build()

jump = clip("jump", 0.5, note="Take-off: arms whip up, one knee drives, then a tuck while rising.")
stand(jump, 0.0, "smooth", offset=(0, -0.16, 0), waist=(-8, 0, 0), neck=(4, 0, 0),
      **arms((40, 0, 12), (40, 0, -12), 30, 30))
jump.pose(0.12, "overshoot", offset=(0, 0.12, 0), waist=(6, 0, 0), neck=(10, 0, 0),
          **arms((168, 0, 22), (160, 0, -28), 14, 20),
          rHip=72, lHip=-8, rKnee=-96, lKnee=-22, rAnkle=(-18, 0, 0), lAnkle=(-40, 0, 0))
jump.pose(0.5, "sine", offset=(0, 0.06, 0), waist=(2, 0, 0), neck=(6, 0, 0),
          **arms((128, 0, 36), (120, 0, -40), 30, 34),
          rHip=58, lHip=20, rKnee=-86, lKnee=-54, rAnkle=(-12, 0, 0), lAnkle=(-22, 0, 0))

fall = clip("fall", 0.7, loop=True, note="Arms paddle and legs pedal while falling.")
fall.pose(0.0, "sine", waist=(8, 0, 4), neck=(-14, 0, 0),
          **arms((150, 0, 42), (118, 0, -58), 34, 20),
          rHip=34, lHip=-4, rKnee=-62, lKnee=-24, rAnkle=(-20, 0, 0), lAnkle=(-12, 0, 0))
fall.pose(0.35, "sine", waist=(8, 0, -4), neck=(-14, 0, 0),
          **arms((118, 0, 58), (150, 0, -42), 20, 34),
          rHip=-4, lHip=34, rKnee=-24, lKnee=-62, rAnkle=(-12, 0, 0), lAnkle=(-20, 0, 0))

# Actions -----------------------------------------------------------------------------------------------

# Everyone alive writes in the Grimoire phase: notebook flat at the chest in the left hand, the
# right hand scribbling a line, jumping back for the next line, and a glance up now and then.
write = clip("write", 1.6, loop=True, note="Everyone alive writes in the Grimoire phase.")
scribble = [(0.0, -16, 0), (0.1, 12, 1), (0.2, -14, 2), (0.3, 14, 3), (0.4, -12, 4), (0.5, 16, 5),
            (0.62, -10, 6), (0.72, 12, 7), (0.8, -14, 8), (0.9, 12, 9), (1.02, -12, 10), (1.12, 14, 11)]
for t, wrist, step in scribble:
    reach = step * 1.6  # the pen travels along the line
    write.pose(t, "sine", neck=(-30, 4 - step * 0.6, 0), waist=(-8, 3, 0),
               lShoulder=(38, 0, 22), lElbow=76, lWrist=(-12, 0, -8),
               rShoulder=(30 + reach * 0.4, 0, -22 + reach * 0.9), rElbow=74 - reach * 0.5,
               rWrist=(-24, 0, wrist))
write.pose(1.26, "snap", neck=(-18, 0, 0), waist=(-6, 2, 0), lShoulder=(38, 0, 22), lElbow=76,
           lWrist=(-12, 0, -8), rShoulder=(28, 0, -30), rElbow=84, rWrist=(-10, 0, 0))
write.pose(1.42, "sine", neck=(-12, -6, 0), waist=(-5, 0, 0), lShoulder=(36, 0, 22), lElbow=74,
           lWrist=(-12, 0, -8), rShoulder=(30, 0, -26), rElbow=80, rWrist=(-18, 0, -6))

task_work = clip("taskWork", 1.2, loop=True, note="Working a case-file station (real or faked).")
for t, r, l, look in ((0.0, 0, 7, 0), (0.15, 8, 0, 0), (0.3, 0, 8, 2), (0.45, 7, 0, 2), (0.6, 0, 6, 0),
                      (0.75, 9, 0, -4), (0.9, 0, 8, -4), (1.05, 6, 0, 0)):
    # Forearms level over the console, fingers tapping in turn.
    task_work.pose(t, "snap", neck=(-16, look * 3, 0), waist=(-10, look, 0),
                   rShoulder=(30 - r, 0, -12), rElbow=66 + r, rWrist=(-12 - r, 0, 0),
                   lShoulder=(30 - l, 0, 12), lElbow=66 + l, lWrist=(-12 - l, 0, 0))

raise_hand = clip("raiseHand", 0.6, note="A vote is cast: a dip, then the hand shoots up.")
raise_hand.pose(0.0, rShoulder=(0, 0, 8), rElbow=10, waist=(0, 0, 0), neck=(0, 0, 0))
raise_hand.pose(0.08, "out", rShoulder=(-18, 0, 14), rElbow=40, waist=(-4, 0, 2), neck=(-4, 0, 0))
raise_hand.pose(0.22, "bigshoot", rShoulder=(174, 0, -6), rElbow=6, rWrist=(0, 0, 0), waist=(2, 0, -8),
                neck=(10, 0, -6))
raise_hand.pose(0.6, "sine", rShoulder=(166, 0, -2), rElbow=14, waist=(1, 0, -6), neck=(8, 0, -4))

point = clip("point", 1.3, note="Accuse! Wind up, then thrust a pointing arm forward.")
point.pose(0.0, rShoulder=(10, 0, 6), rElbow=20, waist=(0, 0, 0), neck=(0, 0, 0))
point.pose(0.18, "out", rShoulder=(40, 0, -30), rElbow=118, waist=(-2, 22, 0), neck=(0, 12, 0),
           lShoulder=(14, 0, -22), lElbow=36)
point.pose(0.3, "bigshoot", rShoulder=(94, -6, 4), rElbow=0, rWrist=(0, 0, 0), waist=(-10, -14, 0),
           neck=(-2, -10, 0), lShoulder=(-24, 0, -14), lElbow=24)
point.pose(1.3, "sine", rShoulder=(90, -6, 4), rElbow=4, waist=(-8, -12, 0), neck=(0, -10, 0),
           lShoulder=(-20, 0, -14), lElbow=26)

# Deaths: each ends on the floor; the server then locks the final pose into the joints and lets
# the body go limp, so the last frame must be a pose that rests on the ground.

heart = clip("collapseHeart", 1.6, note="Clutches the chest, staggers, knees give out, falls forward.", floor=True)
clutch = dict(rShoulder=(52, 0, -40), rElbow=122, rWrist=(20, 0, 0))
heart.pose(0.0, waist=(0, 0, 0), neck=(0, 0, 0), root=(0, 0, 0))
stand(heart, 0.1, "snap", offset=(0, 0.04, 0.08), waist=(14, 0, 0), neck=(22, 0, 0),
      lShoulder=(26, 0, -34), lElbow=36, **clutch)
stand(heart, 0.45, "out", offset=(0.1, -0.2, 0.12), root=(0, 8, 4), waist=(-22, 8, 10), neck=(-16, 0, 12),
      lShoulder=(40, 0, -46), lElbow=48, stance=0.1, forward=(0.3, -0.1), **clutch)
knees = kneeling_leg(1, (0.05, -0.68, 0.1), (-6, 0, 4))[0] | kneeling_leg(-1, (0.05, -0.68, 0.1), (-6, 0, 4))[0]
heart.pose(0.85, "in", offset=(0.05, -0.68, 0.1), root=(-6, 0, 4), waist=(-34, 0, 6), neck=(-26, 0, 8),
           lShoulder=(-4, 0, -40), lElbow=26, **clutch, **knees)
floor_key(heart, 1.25, "in", (0.05, -0.6), root=(-60, 0, 6), waist=(-20, 0, 4), neck=(-18, 0, 10),
          rShoulder=(70, 0, -22), rElbow=84, lShoulder=(46, 0, -60), lElbow=20,
          rHip=64, rKnee=-86, lHip=58, lKnee=-80, rAnkle=(20, 0, 0), lAnkle=(20, 0, 0))
floor_key(heart, 1.6, "bounce", (0.05, -1.1), root=(-86, 0, 8), waist=(-8, 0, 4), neck=(8, 0, 22),
          rShoulder=(96, 0, -8), rElbow=40, lShoulder=(72, 0, -74), lElbow=12,
          rHip=24, rKnee=-30, lHip=14, lKnee=-18, rAnkle=(30, 0, 0), lAnkle=(30, 0, 0))

illness = clip("collapseIllness", 1.7, note="Doubles over coughing, sinks to the knees, keels over sideways.", floor=True)
illness.pose(0.0, waist=(0, 0, 0), neck=(0, 0, 0), root=(0, 0, 0))
for t, depth in ((0.12, -38), (0.28, -20), (0.44, -42), (0.6, -24), (0.76, -46)):
    stand(illness, t, "snap", offset=(0, -0.08 if depth < -30 else -0.03, 0.06), waist=(depth, 0, 0),
          neck=(-8 if depth < -30 else 6, 0, 0), rShoulder=(78, 0, -36), rElbow=130, rWrist=(20, 0, 0),
          lShoulder=(40, 0, 30), lElbow=90)
knees = kneeling_leg(1, (0, -0.67, 0.05), (0, 0, 0), 0.1)[0] | kneeling_leg(-1, (0, -0.67, 0.05), (0, 0, 0), 0.1)[0]
illness.pose(1.12, "in", offset=(0, -0.67, 0.05), root=(0, 0, 0), waist=(-40, 0, 12), neck=(-18, 0, 14),
             rShoulder=(50, 0, -22), rElbow=100, lShoulder=(10, 0, -30), lElbow=40, **knees)
floor_key(illness, 1.45, "in", (-0.4, 0.1), root=(-20, 0, 58), waist=(-30, 0, 16), neck=(-16, 0, 24),
          rShoulder=(40, 0, -14), rElbow=80, lShoulder=(20, 0, -60), lElbow=20,
          rHip=70, lHip=66, rKnee=-100, lKnee=-96)
floor_key(illness, 1.7, "bounce", (-0.8, 0.1), root=(-12, 0, 86), waist=(-24, 0, 10), neck=(-12, 0, 30),
          rShoulder=(28, 0, -8), rElbow=60, lShoulder=(10, 0, -84), lElbow=10,
          rHip=64, lHip=58, rKnee=-92, lKnee=-84)

slip = clip("collapseFall", 1.5, note="Cartoon slip: feet fly up, arms windmill, lands flat on the back.", floor=True)
slip.pose(0.0, waist=(0, 0, 0), neck=(0, 0, 0), root=(0, 0, 0))
slip.pose(0.1, "snap", rHip=74, lHip=48, rKnee=-12, lKnee=-24, waist=(20, 0, 0), neck=(28, 0, 0),
          rShoulder=(160, 0, 40), lShoulder=(140, 0, -60), rElbow=10, lElbow=20, offset=(0, 0.25, 0),
          root=(10, 0, 0))
slip.pose(0.26, "sine", rShoulder=(110, 0, 80), lShoulder=(170, 0, -25), rElbow=30, lElbow=5,
          root=(24, 0, 0), offset=(0, 0.2, 0.25))
slip.pose(0.42, "sine", rShoulder=(170, 0, 25), lShoulder=(110, 0, -80), rElbow=5, lElbow=30,
          root=(44, 0, 0), rHip=84, lHip=64, offset=(0, -0.15, 0.55))
floor_key(slip, 0.8, "in", (0, 1.0), root=(70, 0, 0), waist=(10, 0, 0), neck=(28, 0, 0),
          rShoulder=(130, 0, 70), lShoulder=(130, 0, -70), rElbow=20, lElbow=20, rHip=86, lHip=70,
          rKnee=-20, lKnee=-40)
floor_key(slip, 1.1, "bounce", (0, 1.35), root=(86, 0, 0), waist=(4, 0, 0), neck=(10, 0, 0),
          rShoulder=(70, 0, 90), lShoulder=(70, 0, -90), rElbow=10, lElbow=10, rHip=64, lHip=46,
          rKnee=-30, lKnee=-50)
floor_key(slip, 1.5, "sine", (0, 1.4), root=(88, 0, 0), waist=(0, 0, 0), neck=(4, 0, 8),
          rShoulder=(40, 0, 96), lShoulder=(50, 0, -96), rElbow=20, lElbow=10, rHip=34, lHip=24,
          rKnee=-44, lKnee=-64)

traffic = clip("collapseTraffic", 1.5, note="A violent jolt spins the body; arms fling out; it drops.", floor=True)
traffic.pose(0.0, root=(0, 0, 0), waist=(0, 0, 0), neck=(0, 0, 0))
traffic.pose(0.08, "snap", root=(-6, 40, 12), waist=(12, 30, 0), neck=(24, -36, 0),
             rShoulder=(40, 0, 90), lShoulder=(20, 0, -100), rElbow=10, lElbow=30, offset=(0.4, 0.2, 0))
traffic.pose(0.3, "out", root=(-10, 110, 24), waist=(-6, 20, 10), neck=(-10, 0, 20),
             rShoulder=(60, 0, 70), lShoulder=(80, 0, -60), rElbow=40, lElbow=20,
             rHip=30, lHip=-10, rKnee=-40, lKnee=-10, offset=(0.9, -0.2, 0.2))
floor_key(traffic, 0.8, "in", (1.3, 0.3), root=(-40, 150, 50), waist=(-20, 10, 10), neck=(-20, 0, 20),
          rShoulder=(30, 0, 40), lShoulder=(90, 0, -40), rElbow=60, lElbow=10,
          rHip=50, lHip=20, rKnee=-70, lKnee=-30)
floor_key(traffic, 1.5, "bounce", (1.6, 0.4), root=(-86, 160, 20), waist=(-10, 0, 14), neck=(-6, 0, 24),
          rShoulder=(70, 0, 60), lShoulder=(60, 0, -84), rElbow=30, lElbow=10,
          rHip=40, lHip=26, rKnee=-60, lKnee=-40)

behind = dict(rShoulder=(-42, 0, -16), lShoulder=(-42, 0, 16), rElbow=46, lElbow=46,
              rWrist=(0, 0, 12), lWrist=(0, 0, -12))
cuffed = clip("cuffed", 1.6, loop=True, note="Hands cuffed behind the back, head down, a struggle.")
cuffed.pose(0.0, "sine", neck=(-26, 0, 0), waist=(-6, 0, 0), **behind)
cuffed.pose(0.45, "snap", neck=(-18, 12, 0), waist=(-3, 10, 0), rShoulder=(-50, 0, -12), lShoulder=(-46, 0, 14),
            rElbow=40, lElbow=40)
cuffed.pose(0.7, "sine", neck=(-24, -10, 0), waist=(-5, -8, 0), rShoulder=(-44, 0, -15), lShoulder=(-50, 0, 12),
            rElbow=42, lElbow=40)
cuffed.pose(1.1, "sine", neck=(-30, 0, 0), waist=(-7, 0, 0), **behind)

slump = clip("slump", 1.0, note="Voted out: the body deflates before it fades away.")
slump.pose(0.0, neck=(0, 0, 0), waist=(0, 0, 0))
stand(slump, 0.12, "snap", offset=(0, 0.04, 0), neck=(12, 0, 0), waist=(5, 0, 0),
      rShoulder=(10, 0, 14), lShoulder=(10, 0, -14), rElbow=10, lElbow=10)
stand(slump, 0.7, "in", offset=(0, -0.3, 0.05), neck=(-48, 0, 6), waist=(-24, 0, 4),
      rShoulder=(6, 0, 4), lShoulder=(6, 0, -4), rElbow=6, lElbow=6)
stand(slump, 1.0, "bounce", offset=(0, -0.26, 0.05), neck=(-44, 0, 8), waist=(-22, 0, 4),
      rShoulder=(4, 0, 3), lShoulder=(4, 0, -3), rElbow=5, lElbow=5)

kneel = clip("kneel", 1.1, note="Caught: drops onto one knee, hands cuffed behind the back.")
kneel.pose(0.0, root=(0, 0, 0), waist=(0, 0, 0), neck=(0, 0, 0))
stand(kneel, 0.25, "in", offset=(0, -0.35, 0.1), neck=(-10, 0, 0), waist=(-14, 0, 0), forward=(0.7, -0.2),
      **behind)


def kneel_joints(offset):
    joints, _ = kneeling_leg(-1, offset, (0, 0, 0), knee_ahead=-0.35)
    right = planted_legs(offset, (0, 0, 0), forward=(0.95, 0))
    joints.update({k: v for k, v in right.items() if k.startswith("r")})
    joints.update(root=(0, 0, 0), waist=(-8, 0, 0), neck=(-34, 0, 0), **behind)
    return joints


down, kneeling = fitted_kneel((0, -0.66, 0.25), (0, 0, 0), kneel_joints)
kneel.pose(0.55, "bounce", offset=down, **kneeling)
kneeling["neck"] = (-38, 0, 0)
kneeling["waist"] = (-10, 0, 0)
kneel.pose(1.1, "sine", offset=down, **kneeling)

# Endings -----------------------------------------------------------------------------------------------

laugh = clip("laugh", 0.6, loop=True, note="Villain laugh: leaning back, hands on the belly, shaking.")
hands_on_belly = dict(rShoulder=(10, 0, -24), lShoulder=(10, 0, 24), rElbow=86, lElbow=86)
stand(laugh, 0.0, "sine", offset=(0, -0.08, 0.06), waist=(18, 0, 0), neck=(30, 0, 0), **hands_on_belly)
stand(laugh, 0.15, "snap", offset=(0, 0.0, 0.1), waist=(26, 0, 0), neck=(42, 0, 0),
      rShoulder=(14, 0, -28), lShoulder=(14, 0, 28), rElbow=82, lElbow=82)
stand(laugh, 0.3, "sine", offset=(0, -0.08, 0.06), waist=(18, 0, 0), neck=(30, 0, 0), **hands_on_belly)
stand(laugh, 0.45, "snap", offset=(0, 0.0, 0.1), waist=(26, 0, 0), neck=(42, 0, 0),
      rShoulder=(14, 0, -28), lShoulder=(14, 0, 28), rElbow=82, lElbow=82)

victory = clip("victory", 0.9, loop=True, note="Both arms up, hopping.")
stand(victory, 0.0, "sine", offset=(0, -0.3, 0), rShoulder=(150, 0, 34), lShoulder=(150, 0, -34),
      rElbow=30, lElbow=30, neck=(6, 0, 0), waist=(-6, 0, 0))
victory.pose(0.28, "overshoot", offset=(0, 0.55, 0), rShoulder=(176, 0, 16), lShoulder=(176, 0, -16),
             rElbow=2, lElbow=2, rKnee=-18, lKnee=-18, rHip=10, lHip=10, rAnkle=(-20, 0, 0),
             lAnkle=(-20, 0, 0), neck=(18, 0, 0), waist=(6, 0, 0), root=(0, 0, 0))
stand(victory, 0.6, "in", offset=(0, -0.34, 0), rShoulder=(156, 0, 30), lShoulder=(156, 0, -30),
      rElbow=24, lElbow=24, neck=(6, 0, 0), waist=(-8, 0, 0))

fist = clip("victoryFist", 0.7, loop=True, note="Fist pump, other hand on the hip.")
stand(fist, 0.0, "sine", offset=(0, -0.1, 0), rShoulder=(146, 0, 12), rElbow=70, lShoulder=(10, 0, -30),
      lElbow=96, lWrist=(0, 0, 20), waist=(0, -8, 0), neck=(6, -6, 0))
stand(fist, 0.18, "bigshoot", offset=(0, 0.02, 0), rShoulder=(176, 0, 6), rElbow=4, waist=(4, -12, 0),
      neck=(16, -8, 0), lShoulder=(10, 0, -30), lElbow=96)

bow = clip("victoryBow", 2.4, note="A theatrical bow, then a proud stance.")
bow.pose(0.0, waist=(0, 0, 0), rShoulder=(0, 0, 8), lShoulder=(0, 0, -8), root=(0, 0, 0))
bow.pose(0.45, "overshoot", rShoulder=(40, 0, 76), rElbow=10, lShoulder=(-30, 0, -16), lElbow=64,
         waist=(4, 0, 0), neck=(8, 0, 0))
stand(bow, 1.0, "in", offset=(0, -0.05, 0.2), root=(-12, 0, 0), waist=(-48, 0, 0), neck=(-18, 0, 0),
      rShoulder=(72, 0, -52), rElbow=96, lShoulder=(-32, 0, -14), lElbow=66, forward=(0.35, 0))
stand(bow, 1.7, "hold", offset=(0, -0.05, 0.2), root=(-12, 0, 0), waist=(-48, 0, 0), neck=(-18, 0, 0),
      rShoulder=(72, 0, -52), rElbow=96, lShoulder=(-32, 0, -14), lElbow=66, forward=(0.35, 0))
stand(bow, 2.4, "overshoot", offset=(0, 0, 0), root=(0, 0, 0), waist=(6, 0, 0), neck=(12, 0, 0),
      rShoulder=(6, 0, 14), rElbow=10, lShoulder=(6, 0, -14), lElbow=10, forward=(0.35, 0))

defeat = clip("defeat", 1.4, note="Hands to the head, then the arms drop and the head hangs.")
defeat.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), neck=(0, 0, 0))
defeat.pose(0.25, "snap", rShoulder=(146, 0, -36), lShoulder=(146, 0, 36), rElbow=128, lElbow=128,
            neck=(-6, 0, 0), waist=(-4, 0, 0))
defeat.pose(0.7, "sine", rShoulder=(142, 0, -38), lShoulder=(142, 0, 38), rElbow=130, lElbow=130,
            neck=(-16, 12, 0), waist=(-8, 0, 0))
stand(defeat, 1.1, "in", offset=(0, -0.22, 0.05), rShoulder=(4, 0, 4), lShoulder=(4, 0, -4), rElbow=6,
      lElbow=6, neck=(-42, 0, 0), waist=(-16, 0, 0))
stand(defeat, 1.4, "bounce", offset=(0, -0.2, 0.05), rShoulder=(3, 0, 3), lShoulder=(3, 0, -3), rElbow=5,
      lElbow=5, neck=(-40, 0, 0), waist=(-14, 0, 0))

specter = clip("specterFloat", 2.4, loop=True, note="Specters drift with arms spread and legs trailing.")
specter.pose(0.0, "sine", offset=(0, 0, 0), waist=(4, 0, 3), neck=(-4, 0, 0),
             rShoulder=(16, 0, 26), lShoulder=(16, 0, -26), rElbow=24, lElbow=24,
             rHip=-12, lHip=-6, rKnee=-26, lKnee=-18, rAnkle=(-30, 0, 0), lAnkle=(-26, 0, 0))
specter.pose(1.2, "sine", offset=(0, 0.35, 0), waist=(2, 0, -3), neck=(2, 0, 0),
             rShoulder=(24, 0, 36), lShoulder=(24, 0, -36), rElbow=14, lElbow=14,
             rHip=-6, lHip=-12, rKnee=-18, lKnee=-26, rAnkle=(-26, 0, 0), lAnkle=(-30, 0, 0))

# Emotes ------------------------------------------------------------------------------------------------

wave = clip("wave", 2.0, note="A big friendly wave.")
wave.pose(0.0, rShoulder=(0, 0, 8), rElbow=10)
wave.pose(0.22, "overshoot", rShoulder=(150, 0, 30), rElbow=40, rWrist=(0, 0, 0), neck=(4, 8, -4),
          waist=(0, 0, -4))
for i, t in enumerate((0.45, 0.7, 0.95, 1.2, 1.45)):
    swing = 22 if i % 2 == 0 else -18
    wave.pose(t, "sine", rShoulder=(150, 0, 30 + swing * 0.4), rElbow=40 - swing * 0.6, rWrist=(0, 0, swing),
              neck=(4, 8, -4), waist=(0, 0, -4 + swing * 0.05))
wave.pose(2.0, "in", rShoulder=(0, 0, 8), rElbow=10, rWrist=(0, 0, 0), neck=(0, 0, 0), waist=(0, 0, 0))

cheer = clip("cheer", 1.8, note="Two hops with both fists up.")
stand(cheer, 0.0, "smooth", offset=(0, -0.32, 0), rShoulder=(60, 0, 20), lShoulder=(60, 0, -20),
      rElbow=90, lElbow=90)
for base in (0.18, 0.78):
    cheer.pose(base, "overshoot", offset=(0, 0.6, 0), rShoulder=(172, 0, 20), lShoulder=(172, 0, -20),
               rElbow=8, lElbow=8, rKnee=-24, lKnee=-24, rHip=18, lHip=18, rAnkle=(-24, 0, 0),
               lAnkle=(-24, 0, 0), neck=(16, 0, 0), root=(0, 0, 0))
    stand(cheer, base + 0.35, "in", offset=(0, -0.3, 0), rShoulder=(120, 0, 30), lShoulder=(120, 0, -30),
          rElbow=60, lElbow=60, neck=(4, 0, 0))
stand(cheer, 1.8, "overshoot", offset=(0, 0, 0), rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), rElbow=10,
      lElbow=10, neck=(0, 0, 0))

dance = clip("dance", 1.2, loop=True, note="Disco point: up-right, down-left, hips swinging.")
for t, s in ((0.0, 1), (0.3, -1), (0.6, 1), (0.9, -1)):
    up = s == 1
    stand(dance, t, "snap", offset=(0.22 * s, -0.2, 0), root=(0, 0, 6 * s), stance=0.25,
          waist=(0, 8 * s, -12 * s), neck=(8 if up else -6, 12 * s, 6 * s),
          rShoulder=(150, 0, 40) if up else (40, 0, -46), rElbow=4 if up else 6,
          lShoulder=(12, 0, -30), lElbow=100, lWrist=(0, 0, 20))
    stand(dance, t + 0.15, "sine", offset=(0.08 * s, -0.1, 0), root=(0, 0, 2 * s), stance=0.25,
          waist=(0, 4 * s, -4 * s))

groove = clip("dance2", 0.8, loop=True, note="Groove: bent-knee bounce with shoulder shrugs.")
for t, s in ((0.0, 1), (0.4, -1)):
    stand(groove, t, "snap", offset=(0.05 * s, -0.36, 0), root=(0, 6 * s, 0), stance=0.2,
          neck=(10, 10 * s, 0), waist=(-6, 10 * s, 0),
          rShoulder=(30 + 12 * s, 0, 14 + 6 * s), lShoulder=(30 - 12 * s, 0, -14 + 6 * s),
          rElbow=90, lElbow=90, rWrist=(20, 0, 0), lWrist=(20, 0, 0))
    stand(groove, t + 0.2, "sine", offset=(0, -0.14, 0), root=(0, 2 * s, 0), stance=0.2,
          neck=(-6, 4 * s, 0), waist=(-4, 4 * s, 0),
          rShoulder=(30, 0, 18), lShoulder=(30, 0, -18), rElbow=86, lElbow=86)

spin = clip("dance3", 1.2, loop=True, note="Spin with the arms out, one full turn per loop.")
for i, t in enumerate((0.0, 0.3, 0.6, 0.9, 1.2)):
    spin.pose(t, "linear", root=(0, 90 * i, 0), rShoulder=(10, 0, 84), lShoulder=(10, 0, -84), rElbow=6, lElbow=6,
              neck=(10, 0, 0), waist=(4, 0, 0), offset=(0, 0.12 if i % 2 == 0 else 0.02, 0),
              rHip=(0, 0, 6), lHip=(0, 0, -6), rKnee=-6, lKnee=-6, rAnkle=(6, 0, -6), lAnkle=(6, 0, 6))


def build(arm):
    import animlib

    return animlib.build_all(arm)
