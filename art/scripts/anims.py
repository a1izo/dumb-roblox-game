"""Every Inkbound animation, keyed in the game's joint convention (see animlib.py).

Style: punchy and cartoony, in the spirit of Ink Game. Strong silhouettes, anticipation before
big moves, fast arrivals that overshoot and settle (snap / overshoot eases), bouncy bodies.

Run build() in Blender (see art/README.md) to rebuild the actions on the rig, then
export_anims.py to write src/shared/Anim/Clips.luau.
"""

from animlib import CLIPS, clip


def neutral_arms(x=0, out=6, elbow=10):
    return {"rShoulder": (x, 0, out), "lShoulder": (x, 0, -out), "rElbow": elbow, "lElbow": elbow}


# Locomotion ----------------------------------------------------------------------------------------

idle = clip("idle", 3.0, loop=True, note="Breathing with a slow weight shift.")
idle.pose(0, "sine", offset=(0, 0, 0), waist=(-2, 0, 0), neck=(0, 0, 0), root=(0, 0, 0),
          rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), rElbow=10, lElbow=10, rWrist=(0, 0, 0), lWrist=(0, 0, 0),
          rHip=(0, 0, 3), lHip=(0, 0, -3), rKnee=-4, lKnee=-4, rAnkle=0, lAnkle=0)
idle.pose(0.75, "sine", offset=(0.03, 0.03, 0), waist=(0, 0, -1), neck=(2, 4, 1), root=(0, 0, -1.5),
          rShoulder=(2, 0, 7), lShoulder=(2, 0, -8), rElbow=13, lElbow=12,
          rHip=(0, 0, 4), lHip=(0, 0, -2), rKnee=-2, lKnee=-6)
idle.pose(1.5, "sine", offset=(0, 0.05, 0), waist=(1.5, 0, 0), neck=(4, 0, 0), root=(0, 0, 0),
          rShoulder=(3, 0, 8), lShoulder=(3, 0, -8), rElbow=14, lElbow=14,
          rHip=(0, 0, 3), lHip=(0, 0, -3), rKnee=-3, lKnee=-3)
idle.pose(2.25, "sine", offset=(-0.03, 0.02, 0), waist=(0, 0, 1), neck=(1, -4, -1), root=(0, 0, 1.5),
          rShoulder=(1, 0, 8), lShoulder=(1, 0, -7), rElbow=12, lElbow=13,
          rHip=(0, 0, 2), lHip=(0, 0, -4), rKnee=-6, lKnee=-2)

walk = clip("walk", 1.0, loop=True, note="One stride (two steps) covers about 10 studs.")
for t, s in ((0.0, 1), (0.5, -1)):
    # s = 1: right foot forward on contact. The mirrored half swaps sides.
    front, back = ("r", "l") if s == 1 else ("l", "r")
    walk.pose(t, "sine", offset=(0, -0.08, 0), waist=(-4, -6 * s, 0), neck=(2, 4 * s, 0), root=(0, 3 * s, 0),
              **{front + "Hip": 28, front + "Knee": -6, front + "Ankle": 14,
                 back + "Hip": -20, back + "Knee": -14, back + "Ankle": -16,
                 front + "Shoulder": (-20, 0, 6 if front == "r" else -6),
                 back + "Shoulder": (24, 0, 6 if back == "r" else -6),
                 front + "Elbow": 14, back + "Elbow": 30})
    mid = t + 0.25
    walk.pose(mid, "sine", offset=(0, 0.06, 0), waist=(-4, 0, 0), neck=(2, 0, 0), root=(0, 0, 0),
              **{front + "Hip": 2, front + "Knee": -8, front + "Ankle": 0,
                 back + "Hip": 10, back + "Knee": -52, back + "Ankle": -8,
                 front + "Shoulder": (0, 0, 6 if front == "r" else -6),
                 back + "Shoulder": (2, 0, 6 if back == "r" else -6),
                 front + "Elbow": 18, back + "Elbow": 20})

run = clip("run", 0.66, loop=True, note="One stride at full speed (about 10.5 studs).")
for t, s in ((0.0, 1), (0.33, -1)):
    front, back = ("r", "l") if s == 1 else ("l", "r")
    sign_f = 1 if front == "r" else -1
    sign_b = -sign_f
    run.pose(t, "sine", offset=(0, -0.12, 0), waist=(-14, -10 * s, 0), neck=(8, 8 * s, 0), root=(-4, 4 * s, 0),
             **{front + "Hip": 52, front + "Knee": -22, front + "Ankle": 12,
                back + "Hip": -32, back + "Knee": -80, back + "Ankle": -22,
                front + "Shoulder": (-48, 0, 10 * sign_f), back + "Shoulder": (62, 0, 8 * sign_b),
                front + "Elbow": 86, back + "Elbow": 96,
                front + "Wrist": (0, 0, 0), back + "Wrist": (10, 0, 0)})
    mid = t + 0.165
    run.pose(mid, "sine", offset=(0, 0.12, 0), waist=(-12, 0, 0), neck=(6, 0, 0), root=(-4, 0, 0),
             **{front + "Hip": 8, front + "Knee": -34, front + "Ankle": -10,
                back + "Hip": 30, back + "Knee": -115, back + "Ankle": -6,
                front + "Shoulder": (6, 0, 10 * sign_f), back + "Shoulder": (10, 0, 8 * sign_b),
                front + "Elbow": 92, back + "Elbow": 92})

jump = clip("jump", 0.45, note="Take-off; holds the tucked pose while rising.")
jump.pose(0.0, offset=(0, -0.25, 0), waist=(-10, 0, 0), neck=(0, 0, 0),
          rShoulder=(55, 0, 10), lShoulder=(55, 0, -10), rElbow=40, lElbow=40,
          rHip=20, lHip=20, rKnee=-35, lKnee=-35, rAnkle=-10, lAnkle=-10)
jump.pose(0.14, "overshoot", offset=(0, 0.1, 0), waist=(8, 0, 0), neck=(12, 0, 0),
          rShoulder=(165, 0, 28), lShoulder=(160, 0, -32), rElbow=12, lElbow=18,
          rHip=58, lHip=30, rKnee=-86, lKnee=-40, rAnkle=-20, lAnkle=-25)
jump.pose(0.45, "sine", offset=(0, 0.05, 0), waist=(4, 0, 0), neck=(6, 0, 0),
          rShoulder=(140, 0, 34), lShoulder=(135, 0, -38), rElbow=22, lElbow=26,
          rHip=48, lHip=24, rKnee=-72, lKnee=-36, rAnkle=-15, lAnkle=-20)

fall = clip("fall", 0.6, loop=True, note="Arms flail and legs pedal while falling.")
fall.pose(0.0, "sine", waist=(6, 0, 3), neck=(-12, 0, 0),
          rShoulder=(150, 0, 40), lShoulder=(120, 0, -55), rElbow=30, lElbow=20,
          rHip=24, lHip=-6, rKnee=-50, lKnee=-20, rAnkle=-20, lAnkle=-10)
fall.pose(0.3, "sine", waist=(6, 0, -3), neck=(-12, 0, 0),
          rShoulder=(120, 0, 55), lShoulder=(150, 0, -40), rElbow=20, lElbow=30,
          rHip=-6, lHip=24, rKnee=-20, lKnee=-50, rAnkle=-10, lAnkle=-20)

land = clip("land", 0.4, note="Knee dip on landing; played over the ground pose and faded out.")
land.pose(0.0, "snap", offset=(0, -0.55, 0), waist=(-22, 0, 0), neck=(10, 0, 0),
          rShoulder=(30, 0, 24), lShoulder=(30, 0, -24), rElbow=30, lElbow=30,
          rHip=48, lHip=48, rKnee=-78, lKnee=-78, rAnkle=24, lAnkle=24)
land.pose(0.4, "overshoot", offset=(0, 0, 0), waist=(-2, 0, 0), neck=(0, 0, 0),
          rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), rElbow=10, lElbow=10,
          rHip=0, lHip=0, rKnee=-4, lKnee=-4, rAnkle=0, lAnkle=0)

# Actions ----------------------------------------------------------------------------------------------

write = clip("write", 0.9, loop=True, note="Everyone alive writes in the Grimoire phase.")
for i, (t, wrist, elbow, nod) in enumerate(((0.0, -14, 70, -34), (0.15, 16, 64, -35), (0.3, -10, 72, -34),
                                             (0.45, 14, 62, -36), (0.6, -12, 70, -34), (0.75, 12, 66, -35))):
    # Notebook held flat at the chest in the left hand, the right hand scribbling on it.
    write.pose(t, "sine", neck=(nod, 3 if i % 2 else -2, 0), waist=(-10, 4, 0),
               lShoulder=(30, 0, 26), lElbow=62, lWrist=(-10, 0, -10),
               rShoulder=(24 + (i % 3) * 2, 0, -20 - (i % 2) * 3), rElbow=elbow, rWrist=(-20, 0, wrist))

task_work = clip("taskWork", 1.2, loop=True, note="Working a case-file station (real or faked).")
for t, r, l in ((0.0, 0, 6), (0.3, 8, 0), (0.6, 0, 8), (0.9, 6, 0)):
    # Forearms level over the console, fingers tapping in turn.
    task_work.pose(t, "snap", neck=(-18, 0, 0), waist=(-8, 0, 0),
                   rShoulder=(24 - r, 0, -10), rElbow=62 + r, rWrist=(-10 - r, 0, 0),
                   lShoulder=(24 - l, 0, 10), lElbow=62 + l, lWrist=(-10 - l, 0, 0))

raise_hand = clip("raiseHand", 0.5, note="A vote is cast: the hand shoots up.")
raise_hand.pose(0.0, rShoulder=(-12, 0, 10), rElbow=30, waist=(2, 0, 0))
raise_hand.pose(0.16, "bigshoot", rShoulder=(176, 0, -8), rElbow=4, waist=(0, 0, -6), neck=(8, 0, -4))
raise_hand.pose(0.5, "sine", rShoulder=(166, 0, -4), rElbow=12, waist=(0, 0, -4), neck=(6, 0, -3))

point = clip("point", 1.3, note="Accuse! Pull back, then thrust a pointing arm forward.")
point.pose(0.0, rShoulder=(20, 0, 0), rElbow=40, waist=(0, 0, 0))
point.pose(0.18, "out", rShoulder=(40, 0, -25), rElbow=110, waist=(-2, 18, 0), neck=(0, 10, 0),
           lShoulder=(10, 0, -20), lElbow=30, offset=(0, 0, 0.1))
point.pose(0.3, "bigshoot", rShoulder=(92, -4, 2), rElbow=0, rWrist=(0, 0, 0), waist=(-10, -12, 0),
           neck=(-2, -8, 0), lShoulder=(-20, 0, -12), lElbow=20, offset=(0, -0.05, -0.2))
point.pose(1.3, "sine", rShoulder=(88, -4, 2), rElbow=4, waist=(-8, -10, 0), neck=(0, -8, 0),
           lShoulder=(-16, 0, -12), lElbow=24, offset=(0, -0.03, -0.15))

# Deaths: each ends low; the server then locks the final pose and lets the body go limp.
heart = clip("collapseHeart", 1.5, note="Clutches the chest, staggers, knees give out, falls forward.")
heart.pose(0.0, waist=(0, 0, 0), neck=(0, 0, 0))
heart.pose(0.1, "snap", waist=(12, 0, 0), neck=(20, 0, 0), rShoulder=(44, 0, -34), rElbow=118,
           lShoulder=(24, 0, -30), lElbow=30, offset=(0, 0.05, 0.12))
heart.pose(0.45, "out", waist=(-18, 8, 10), neck=(-14, 0, 12), rShoulder=(56, 0, -38), rElbow=120,
           lShoulder=(36, 0, -42), lElbow=44, rKnee=-18, lKnee=-36, rHip=10, lHip=20,
           offset=(0.08, -0.2, 0.2))
heart.pose(0.8, "in", waist=(-36, 0, 6), neck=(-28, 0, 8), rShoulder=(58, 0, -30), rElbow=112,
           lShoulder=(-6, 0, -42), lElbow=24, rHip=62, rKnee=-96, lHip=50, lKnee=-84,
           rAnkle=20, lAnkle=18, offset=(0.05, -1.05, 0.1))
heart.pose(1.2, "in", root=(-42, 0, 6), waist=(-24, 0, 4), neck=(-20, 0, 10), rShoulder=(70, 0, -20),
           rElbow=80, lShoulder=(40, 0, -60), lElbow=20, rHip=70, rKnee=-100, lHip=60, lKnee=-90,
           offset=(0.05, -1.45, -0.5))
heart.pose(1.5, "bounce", root=(-58, 0, 8), waist=(-18, 0, 4), neck=(-10, 0, 14), rShoulder=(90, 0, -10),
           rElbow=60, lShoulder=(70, 0, -70), lElbow=10, rHip=64, rKnee=-80, lHip=56, lKnee=-70,
           offset=(0.05, -1.6, -0.8))

illness = clip("collapseIllness", 1.5, note="Doubles over coughing three times and sinks down.")
illness.pose(0.0, waist=(0, 0, 0), neck=(0, 0, 0))
for t, depth in ((0.12, -38), (0.3, -22), (0.46, -42), (0.62, -26), (0.8, -46)):
    illness.pose(t, "snap", waist=(depth, 0, 0), neck=(-8 if depth < -30 else 6, 0, 0),
                 rShoulder=(76, 0, -34), rElbow=128, rWrist=(20, 0, 0), lShoulder=(38, 0, 28), lElbow=88,
                 rHip=10, lHip=10, rKnee=-12, lKnee=-12, offset=(0, -0.1, 0))
illness.pose(1.15, "in", waist=(-40, 0, 12), neck=(-18, 0, 14), rShoulder=(50, 0, -20), rElbow=100,
             lShoulder=(10, 0, -30), lElbow=40, rHip=78, lHip=76, rKnee=-110, lKnee=-108,
             rAnkle=30, lAnkle=30, offset=(0, -1.35, 0))
illness.pose(1.5, "bounce", root=(-10, 0, 24), waist=(-30, 0, 18), neck=(-20, 0, 24), rShoulder=(20, 0, -10),
             rElbow=60, lShoulder=(-10, 0, -50), lElbow=10, rHip=76, lHip=74, rKnee=-108, lKnee=-106,
             offset=(-0.3, -1.55, 0.1))

slip = clip("collapseFall", 1.5, note="Cartoon slip: feet fly up, arms windmill, lands flat on the back.")
slip.pose(0.0, waist=(0, 0, 0), neck=(0, 0, 0))
slip.pose(0.1, "snap", rHip=70, lHip=46, rKnee=-12, lKnee=-24, waist=(20, 0, 0), neck=(26, 0, 0),
          rShoulder=(160, 0, 40), lShoulder=(140, 0, -60), rElbow=10, lElbow=20, offset=(0, 0.25, 0))
slip.pose(0.26, "sine", rShoulder=(110, 0, 80), lShoulder=(170, 0, -25), rElbow=30, lElbow=5,
          root=(14, 0, 0), offset=(0, 0.3, 0.2))
slip.pose(0.42, "sine", rShoulder=(170, 0, 25), lShoulder=(110, 0, -80), rElbow=5, lElbow=30,
          root=(28, 0, 0), rHip=80, lHip=62, offset=(0, 0.05, 0.5))
slip.pose(0.8, "in", root=(62, 0, 0), waist=(10, 0, 0), neck=(30, 0, 0), rShoulder=(130, 0, 70),
          lShoulder=(130, 0, -70), rElbow=20, lElbow=20, rHip=86, lHip=70, rKnee=-20, lKnee=-40,
          offset=(0, -1.2, 1.1))
slip.pose(1.1, "bounce", root=(84, 0, 0), waist=(4, 0, 0), neck=(10, 0, 0), rShoulder=(70, 0, 90),
          lShoulder=(70, 0, -90), rElbow=10, lElbow=10, rHip=70, lHip=52, rKnee=-30, lKnee=-50,
          offset=(0, -2.1, 1.5))
slip.pose(1.5, "sine", root=(88, 0, 0), waist=(0, 0, 0), neck=(4, 0, 6), rShoulder=(40, 0, 95),
          lShoulder=(50, 0, -95), rElbow=20, lElbow=10, rHip=40, lHip=30, rKnee=-40, lKnee=-60,
          offset=(0, -2.2, 1.6))

traffic = clip("collapseTraffic", 1.5, note="A violent jolt spins the body; arms fling out; drops.")
traffic.pose(0.0, root=(0, 0, 0), waist=(0, 0, 0))
traffic.pose(0.08, "snap", root=(-6, 40, 12), waist=(12, 30, 0), neck=(24, -36, 0),
             rShoulder=(40, 0, 90), lShoulder=(20, 0, -100), rElbow=10, lElbow=30, offset=(0.4, 0.2, 0))
traffic.pose(0.3, "out", root=(-10, 110, 20), waist=(-6, 20, 10), neck=(-10, 0, 20),
             rShoulder=(60, 0, 70), lShoulder=(80, 0, -60), rElbow=40, lElbow=20,
             rHip=30, lHip=-10, rKnee=-40, lKnee=-10, offset=(0.9, -0.1, 0.2))
traffic.pose(0.8, "in", root=(-30, 150, 40), waist=(-20, 10, 10), neck=(-20, 0, 20),
             rShoulder=(30, 0, 40), lShoulder=(90, 0, -40), rElbow=60, lElbow=10,
             rHip=50, lHip=20, rKnee=-70, lKnee=-30, offset=(1.2, -1.2, 0.3))
traffic.pose(1.5, "bounce", root=(-20, 160, 80), waist=(-10, 0, 14), neck=(-10, 0, 20),
             rShoulder=(20, 0, 70), lShoulder=(60, 0, -80), rElbow=30, lElbow=10,
             rHip=40, lHip=30, rKnee=-60, lKnee=-40, offset=(1.4, -2.0, 0.4))

cuffed = clip("cuffed", 1.6, loop=True, note="Hands cuffed behind the back, head down, a struggle.")
cuffed.pose(0.0, "sine", neck=(-26, 0, 0), waist=(-6, 0, 0), rShoulder=(-40, 0, -14), lShoulder=(-40, 0, 14),
            rElbow=40, lElbow=40, rWrist=(0, 0, 10), lWrist=(0, 0, -10))
cuffed.pose(0.5, "snap", neck=(-20, 10, 0), waist=(-4, 8, 0), rShoulder=(-46, 0, -10), lShoulder=(-44, 0, 12),
            rElbow=36, lElbow=36)
cuffed.pose(0.75, "sine", neck=(-24, -8, 0), waist=(-5, -6, 0), rShoulder=(-42, 0, -13), lShoulder=(-46, 0, 10),
            rElbow=38, lElbow=36)
cuffed.pose(1.1, "sine", neck=(-30, 0, 0), waist=(-7, 0, 0), rShoulder=(-38, 0, -14), lShoulder=(-38, 0, 14),
            rElbow=42, lElbow=42)

slump = clip("slump", 1.0, note="Voted out: the body deflates before it fades away.")
slump.pose(0.0, neck=(0, 0, 0), waist=(0, 0, 0))
slump.pose(0.12, "snap", neck=(10, 0, 0), waist=(4, 0, 0), rShoulder=(10, 0, 12), lShoulder=(10, 0, -12))
slump.pose(0.7, "in", neck=(-48, 0, 6), waist=(-22, 0, 4), rShoulder=(4, 0, 4), lShoulder=(4, 0, -4),
           rElbow=6, lElbow=6, rKnee=-12, lKnee=-12, offset=(0, -0.12, 0))
slump.pose(1.0, "bounce", neck=(-44, 0, 8), waist=(-20, 0, 4), rShoulder=(3, 0, 3), lShoulder=(3, 0, -3),
           rElbow=5, lElbow=5, rKnee=-10, lKnee=-10, offset=(0, -0.1, 0))

kneel = clip("kneel", 1.0, note="Caught: down on one knee, hands behind the back.")
kneel.pose(0.0, lHip=0, rHip=0)
kneel.pose(0.35, "in", neck=(-10, 0, 0), waist=(-14, 0, 0), lHip=70, lKnee=-60, rHip=10, rKnee=-60,
           rShoulder=(-30, 0, -14), lShoulder=(-30, 0, 14), rElbow=30, lElbow=30, offset=(0, -0.7, 0))
kneel.pose(0.6, "bounce", neck=(-32, 0, 0), waist=(-8, 0, 0), lHip=88, lKnee=-88, rHip=-6, rKnee=-104,
           rAnkle=30, rShoulder=(-40, 0, -14), lShoulder=(-40, 0, 14), rElbow=40, lElbow=40,
           offset=(0, -1.3, 0))
kneel.pose(1.0, "sine", neck=(-36, 0, 0), waist=(-10, 0, 0), lHip=88, lKnee=-88, rHip=-6, rKnee=-104,
           rAnkle=30, rShoulder=(-40, 0, -14), lShoulder=(-40, 0, 14), rElbow=40, lElbow=40,
           offset=(0, -1.3, 0))

# Endings --------------------------------------------------------------------------------------------

laugh = clip("laugh", 0.5, loop=True, note="Villain laugh: leaning back, hands on the belly.")
laugh.pose(0.0, "sine", waist=(16, 0, 0), neck=(28, 0, 0), rShoulder=(8, 0, -22), lShoulder=(8, 0, 22),
           rElbow=84, lElbow=84, offset=(0, 0, 0.05))
laugh.pose(0.18, "snap", waist=(24, 0, 0), neck=(40, 0, 0), rShoulder=(12, 0, -26), lShoulder=(12, 0, 26),
           rElbow=80, lElbow=80, offset=(0, 0.08, 0.1))

victory = clip("victory", 0.9, loop=True, note="Both arms up, hopping.")
victory.pose(0.0, "sine", offset=(0, -0.12, 0), rShoulder=(158, 0, 30), lShoulder=(158, 0, -30),
             rElbow=24, lElbow=24, rKnee=-24, lKnee=-24, rHip=12, lHip=12, neck=(8, 0, 0))
victory.pose(0.28, "overshoot", offset=(0, 0.4, 0), rShoulder=(176, 0, 16), lShoulder=(176, 0, -16),
             rElbow=2, lElbow=2, rKnee=-4, lKnee=-4, rHip=2, lHip=2, neck=(18, 0, 0))
victory.pose(0.6, "in", offset=(0, -0.16, 0), rShoulder=(160, 0, 28), lShoulder=(160, 0, -28),
             rElbow=20, lElbow=20, rKnee=-30, lKnee=-30, rHip=16, lHip=16, neck=(8, 0, 0))

fist = clip("victoryFist", 0.7, loop=True, note="Fist pump, other hand on the hip.")
fist.pose(0.0, "sine", rShoulder=(146, 0, 12), rElbow=70, lShoulder=(10, 0, -28), lElbow=96, lWrist=(0, 0, 20),
          waist=(0, -8, 0), neck=(6, -6, 0), offset=(0, -0.05, 0), rKnee=-10, lKnee=-10)
fist.pose(0.18, "bigshoot", rShoulder=(176, 0, 6), rElbow=4, waist=(4, -12, 0), neck=(16, -8, 0),
          offset=(0, 0.12, 0), rKnee=-2, lKnee=-2)

bow = clip("victoryBow", 2.4, note="A theatrical bow, then a proud stance.")
bow.pose(0.0, waist=(0, 0, 0), rShoulder=(0, 0, 8), lShoulder=(0, 0, -8))
bow.pose(0.45, "overshoot", rShoulder=(40, 0, 76), rElbow=10, lShoulder=(-30, 0, -16), lElbow=64,
         waist=(4, 0, 0), neck=(8, 0, 0))
bow.pose(1.0, "in", waist=(-56, 0, 0), neck=(-18, 0, 0), rShoulder=(72, 0, -52), rElbow=96,
         lShoulder=(-32, 0, -14), lElbow=66, rHip=12, lHip=12, offset=(0, 0, 0.25))
bow.pose(1.7, "hold", waist=(-56, 0, 0), neck=(-18, 0, 0), rShoulder=(72, 0, -52), rElbow=96,
         lShoulder=(-32, 0, -14), lElbow=66, rHip=12, lHip=12, offset=(0, 0, 0.25))
bow.pose(2.4, "overshoot", waist=(6, 0, 0), neck=(12, 0, 0), rShoulder=(6, 0, 14), rElbow=10,
         lShoulder=(6, 0, -14), lElbow=10, rHip=0, lHip=0, offset=(0, 0, 0))

defeat = clip("defeat", 1.4, note="Hands to the head, then the arms drop and the head hangs.")
defeat.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), neck=(0, 0, 0))
defeat.pose(0.25, "snap", rShoulder=(146, 0, -36), lShoulder=(146, 0, 36), rElbow=128, lElbow=128,
            neck=(-6, 0, 0), waist=(-4, 0, 0))
defeat.pose(0.7, "sine", rShoulder=(142, 0, -38), lShoulder=(142, 0, 38), rElbow=130, lElbow=130,
            neck=(-16, 12, 0), waist=(-8, 0, 0))
defeat.pose(1.1, "in", rShoulder=(4, 0, 4), lShoulder=(4, 0, -4), rElbow=6, lElbow=6, neck=(-42, 0, 0),
            waist=(-16, 0, 0), rKnee=-12, lKnee=-12, offset=(0, -0.12, 0))
defeat.pose(1.4, "bounce", rShoulder=(3, 0, 3), lShoulder=(3, 0, -3), rElbow=5, lElbow=5, neck=(-40, 0, 0),
            waist=(-14, 0, 0), rKnee=-10, lKnee=-10, offset=(0, -0.1, 0))

specter = clip("specterFloat", 2.4, loop=True, note="Specters drift with arms spread and legs trailing.")
specter.pose(0.0, "sine", offset=(0, 0, 0), waist=(4, 0, 3), neck=(-4, 0, 0),
             rShoulder=(16, 0, 26), lShoulder=(16, 0, -26), rElbow=24, lElbow=24,
             rHip=-12, lHip=-6, rKnee=-26, lKnee=-18, rAnkle=-30, lAnkle=-26)
specter.pose(1.2, "sine", offset=(0, 0.35, 0), waist=(2, 0, -3), neck=(2, 0, 0),
             rShoulder=(24, 0, 36), lShoulder=(24, 0, -36), rElbow=14, lElbow=14,
             rHip=-6, lHip=-12, rKnee=-18, lKnee=-26, rAnkle=-26, lAnkle=-30)

# Emotes ---------------------------------------------------------------------------------------------

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
cheer.pose(0.0, offset=(0, -0.2, 0), rShoulder=(60, 0, 20), lShoulder=(60, 0, -20), rElbow=90, lElbow=90,
           rKnee=-30, lKnee=-30, rHip=16, lHip=16)
for base in (0.18, 0.78):
    cheer.pose(base, "overshoot", offset=(0, 0.55, 0), rShoulder=(172, 0, 20), lShoulder=(172, 0, -20),
               rElbow=8, lElbow=8, rKnee=-20, lKnee=-20, rHip=18, lHip=18, neck=(16, 0, 0))
    cheer.pose(base + 0.35, "in", offset=(0, -0.22, 0), rShoulder=(120, 0, 30), lShoulder=(120, 0, -30),
               rElbow=60, lElbow=60, rKnee=-34, lKnee=-34, rHip=20, lHip=20, neck=(4, 0, 0))
cheer.pose(1.8, "overshoot", offset=(0, 0, 0), rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), rElbow=10,
           lElbow=10, rKnee=-4, lKnee=-4, rHip=0, lHip=0, neck=(0, 0, 0))

dance = clip("dance", 1.2, loop=True, note="Disco point: up-right, down-left, hips swinging.")
for t, s in ((0.0, 1), (0.3, -1), (0.6, 1), (0.9, -1)):
    up = s == 1
    dance.pose(t, "snap",
               offset=(0.25 * s, -0.14, 0), waist=(0, 8 * s, -10 * s), neck=(8 if up else -6, 12 * s, 6 * s),
               rShoulder=(150, 0, 40) if up else (40, 0, -46), rElbow=4 if up else 6,
               lShoulder=(12, 0, -30), lElbow=100, lWrist=(0, 0, 20),
               rHip=(10, 0, 8 * s), lHip=(10, 0, 8 * s), rKnee=-26 if up else -8, lKnee=-8 if up else -26)
    dance.pose(t + 0.15, "sine", offset=(0.1 * s, 0.02, 0), waist=(0, 4 * s, -4 * s))

groove = clip("dance2", 0.8, loop=True, note="Groove: bent-knee bounce with shoulder shrugs.")
for t, s in ((0.0, 1), (0.4, -1)):
    groove.pose(t, "snap", offset=(0, -0.22, 0), neck=(10, 10 * s, 0), waist=(-6, 10 * s, 0),
                rShoulder=(30 + 12 * s, 0, 14 + 6 * s), lShoulder=(30 - 12 * s, 0, -14 + 6 * s),
                rElbow=90, lElbow=90, rWrist=(20, 0, 0), lWrist=(20, 0, 0),
                rHip=18, lHip=18, rKnee=-38, lKnee=-38, rAnkle=12, lAnkle=12)
    groove.pose(t + 0.2, "sine", offset=(0, -0.05, 0), neck=(-6, 4 * s, 0), waist=(-4, 4 * s, 0),
                rShoulder=(30, 0, 18), lShoulder=(30, 0, -18), rElbow=86, lElbow=86,
                rHip=8, lHip=8, rKnee=-16, lKnee=-16, rAnkle=4, lAnkle=4)

spin = clip("dance3", 1.2, loop=True, note="Spin with the arms out, one full turn per loop.")
for i, t in enumerate((0.0, 0.3, 0.6, 0.9)):
    spin.pose(t, "linear", root=(0, 90 * i, 0), rShoulder=(10, 0, 84), lShoulder=(10, 0, -84), rElbow=6, lElbow=6,
              neck=(10, 0, 0), waist=(4, 0, 0), offset=(0, 0.05 if i % 2 == 0 else -0.05, 0),
              rHip=(0, 0, 6), lHip=(0, 0, -6), rKnee=-6, lKnee=-6)
spin.pose(1.2, "linear", root=(0, 360, 0), rShoulder=(10, 0, 84), lShoulder=(10, 0, -84), rElbow=6, lElbow=6,
          neck=(10, 0, 0), waist=(4, 0, 0), offset=(0, 0.05, 0), rHip=(0, 0, 6), lHip=(0, 0, -6),
          rKnee=-6, lKnee=-6)


def build(arm):
    import animlib

    return animlib.build_all(arm)
