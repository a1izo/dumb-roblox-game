"""Every Death's Gambit animation, keyed in the game's joint convention (see animlib.py) on the R6
rig (rig.py).

R6 has six joints: root (moves the whole body and bends the waist), neck, both shoulders and both
hips. Limbs are rigid blocks, so the acting lives in strong silhouettes, held poses and timing.
Style: cutscenes get dramatic anime acting; gameplay clips stay clean and readable.

Movement (idle, walk, run, land) is generated in gait.py. Wherever the hips move here, the legs are
solved so the feet stay where they are (posekit.planted_legs), and every pose that ends on the
ground is fitted to the floor (posekit.on_floor), so nothing sinks or floats.

Rigid arms: shoulder x 0 = hanging, 90 = straight out in front, 180 = overhead. z swings an arm out
to the side (right +, left -) before it is raised, so with the arm raised z spreads it left or right.

Run build() in Blender (see art/README.md) to rebuild the actions on the rig, then export_anims.py
writes src/shared/Anim/Clips.luau.
"""

import math

import gait
from animlib import clip
from posekit import on_floor, planted_legs


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

jump = clip("jump", 0.5, note="Take-off: arms whip up, one leg drives, the other trails.")
stand(jump, 0.0, "smooth", offset=(0, -0.3, 0), root=(-10, 0, 0), neck=(5, 0, 0),
      rShoulder=(40, 0, 12), lShoulder=(40, 0, -12), stance=0.15)
jump.pose(0.12, "overshoot", offset=(0, 0.1, 0), root=(6, 0, 0), neck=(10, 0, 0),
          rShoulder=(168, 0, 22), lShoulder=(160, 0, -28), rHip=(58, 0, 4), lHip=(-14, 0, -6))
jump.pose(0.5, "sine", offset=(0, 0.05, 0), root=(2, 0, 0), neck=(6, 0, 0),
          rShoulder=(128, 0, 36), lShoulder=(120, 0, -40), rHip=(46, 0, 8), lHip=(12, 0, -8))

fall = clip("fall", 0.7, loop=True, note="Arms paddle and legs pedal while falling.")
fall.pose(0.0, "sine", root=(8, 0, 4), neck=(-14, 0, 0), rShoulder=(150, 0, 42), lShoulder=(118, 0, -58),
          rHip=(34, 0, 6), lHip=(-14, 0, -4))
fall.pose(0.35, "sine", root=(8, 0, -4), neck=(-14, 0, 0), rShoulder=(118, 0, 58), lShoulder=(150, 0, -42),
          rHip=(-14, 0, 4), lHip=(34, 0, -6))

# Standing and sitting ----------------------------------------------------------------------------------

sit = clip("sit", 4.0, loop=True, note="Seated (a Seat): thighs level, hands resting, a slow breath.")
for t, b in ((0.0, 0.0), (1.0, 1.0), (2.0, 0.0), (3.0, 1.0)):
    sit.pose(t, "sine", root=(-1 + b, 0, 0), neck=(2 - b, 0, 0), rHip=(88, 0, 3), lHip=(88, 0, -3),
             rShoulder=(34 + b, 0, 9), lShoulder=(34 + b, 0, -9))
sit.pose(4.0, "sine", root=(-1, 0, 0), neck=(2, 0, 0), rHip=(88, 0, 3), lHip=(88, 0, -3),
         rShoulder=(34, 0, 9), lShoulder=(34, 0, -9))

idle_look = clip("idleLook", 2.6, note="A fidget: a slow look round to one side, then the other.")
idle_look.pose(0.0, neck=(0, 0, 0), root=(0, 0, 0))
idle_look.pose(0.7, "sine", neck=(2, 50, 0), root=(0, 14, 0))
idle_look.pose(1.3, "sine", neck=(2, 50, 0), root=(0, 14, 0))
idle_look.pose(1.9, "sine", neck=(1, -38, 0), root=(0, -10, 0))
idle_look.pose(2.6, "sine", neck=(0, 0, 0), root=(0, 0, 0))

idle_watch = clip("idleWatch", 3.0, note="A fidget: a glance at the wrist watch.")
idle_watch.pose(0.0, rShoulder=(1, 0, 6), neck=(0, 0, 0), root=(-1, 0, 0))
idle_watch.pose(0.55, "overshoot", rShoulder=(78, 0, -34), neck=(-26, 8, 0), root=(-4, 8, 0))
idle_watch.pose(1.9, "sine", rShoulder=(76, 0, -34), neck=(-26, 8, 0), root=(-4, 8, 0))
idle_watch.pose(2.5, "sine", rShoulder=(10, 0, 8), neck=(-2, 0, 0), root=(-1, 0, 0))
idle_watch.pose(3.0, "sine", rShoulder=(1, 0, 6), neck=(0, 0, 0))

idle_tie = clip("idleTie", 2.4, note="A fidget: straightening the tie.")
idle_tie.pose(0.0, rShoulder=(1, 0, 6), neck=(0, 0, 0), root=(0, 0, 0))
idle_tie.pose(0.4, "overshoot", rShoulder=(104, 0, -30), neck=(-8, 0, 6), root=(-2, 0, 0))
for t, d in ((0.7, 8), (0.9, -6), (1.1, 8), (1.3, -6)):
    idle_tie.pose(t, "sine", rShoulder=(104 + d, 0, -30), neck=(-8, 0, 6), root=(-2, 0, 0))
idle_tie.pose(1.8, "sine", rShoulder=(10, 0, 8), neck=(-1, 0, 0), root=(0, 0, 0))
idle_tie.pose(2.4, "sine", rShoulder=(1, 0, 6), neck=(0, 0, 0))

# Actions -----------------------------------------------------------------------------------------------

# Everyone alive writes in the Death's Gambit phase: notebook flat at the chest in the left arm, the right
# arm scribbling a line, jumping back for the next line, and a glance up now and then.
write = clip("write", 1.6, loop=True, note="Everyone alive writes in the Death's Gambit phase.")
scribble = [(0.0, -4, 0), (0.1, 6, 1), (0.2, -3, 2), (0.3, 7, 3), (0.4, -2, 4), (0.5, 8, 5),
            (0.62, -1, 6), (0.72, 9, 7), (0.8, 0, 8), (0.9, 10, 9), (1.02, 1, 10), (1.12, 11, 11)]
for t, swing, step in scribble:
    write.pose(t, "sine", root=(-7, 3, 0), neck=(-32, 4 - step * 0.6, 0),
               lShoulder=(58, 0, 24), rShoulder=(56 + swing * 0.5, 0, -6 + swing + step * 0.5))
write.pose(1.26, "snap", root=(-6, 2, 0), neck=(-18, 0, 0), lShoulder=(58, 0, 24), rShoulder=(52, 0, -2))
write.pose(1.42, "sine", root=(-6, -2, 0), neck=(-12, -6, 0), lShoulder=(58, 0, 24), rShoulder=(54, 0, -4))

# One loop per kind of station (Camera, Fingerprint, Phone, Forensics): the body leans over the console,
# each job with its own movement.
work_camera = clip("workCamera", 1.2, loop=True, note="Camera footage: scrubbing a jog dial, a tap on the console.")
for t, r, l, look in ((0.0, 0, 7, 0), (0.15, 9, 0, 0), (0.3, 3, 8, 2), (0.45, 12, 0, 2), (0.6, 4, 6, 0),
                      (0.75, 10, 0, -4), (0.9, 2, 9, -4), (1.05, 8, 0, 0)):
    work_camera.pose(t, "snap", root=(-9, look, 0), neck=(-18, look * 3, 0),
                     rShoulder=(66 + r, 0, -4 + r * 0.5), lShoulder=(62 + l, 0, 10))

work_print = clip("workFingerprint", 1.4, loop=True, note="Fingerprints: dusting in small circles, the other hand steadying.")
for i in range(8):
    a = i / 8 * 2 * math.pi
    work_print.pose(i * 0.175, "linear", root=(-14, 6, 0), neck=(-24, 8, 0),
                    rShoulder=(76 + 9 * math.sin(a), 0, -10 + 12 * math.cos(a)), lShoulder=(64, 0, 12))

work_phone = clip("workPhone", 2.0, loop=True, note="Phone records: handset at the ear, the other hand taking notes.")
for t, w, tilt in ((0.0, 0, 0), (0.25, 5, 1), (0.5, -3, 2), (0.75, 6, 0), (1.0, -2, -1), (1.25, 5, 1), (1.5, -4, 2),
                   (1.75, 4, 0)):
    work_phone.pose(t, "sine", root=(-4, 4, 0), neck=(-8, 0, 10 + tilt),
                    lShoulder=(168, 0, -14), rShoulder=(52 + w * 0.4, 0, -2 + w))
work_phone.pose(2.0, "sine", root=(-4, 4, 0), neck=(-8, 0, 10), lShoulder=(168, 0, -14), rShoulder=(52, 0, -2))

work_lab = clip("workForensics", 1.6, loop=True, note="Forensics: bent over the microscope, turning the focus knob.")
for t, knob, look in ((0.0, 0, 0), (0.2, 6, 1), (0.4, 0, 0), (0.6, 8, -1), (0.8, 0, 0), (1.0, 7, 1),
                      (1.2, 0, 0), (1.4, 6, -1)):
    work_lab.pose(t, "sine", root=(-16, look * 2, 0), neck=(-26, look * 4, 0),
                  rShoulder=(82 + knob, 0, -12), lShoulder=(82, 0, 12))
work_lab.pose(1.6, "sine", root=(-16, 0, 0), neck=(-26, 0, 0), rShoulder=(82, 0, -12), lShoulder=(82, 0, 12))

raise_hand = clip("raiseHand", 0.6, note="A vote is cast: a dip, then the hand shoots up.")
raise_hand.pose(0.0, rShoulder=(0, 0, 6), root=(0, 0, 0), neck=(0, 0, 0))
raise_hand.pose(0.08, "out", rShoulder=(-18, 0, 12), root=(-4, 0, 2), neck=(-4, 0, 0))
raise_hand.pose(0.22, "bigshoot", rShoulder=(176, 0, 8), root=(2, 0, -8), neck=(10, 0, -6))
raise_hand.pose(0.6, "sine", rShoulder=(168, 0, 6), root=(1, 0, -6), neck=(8, 0, -4))

point = clip("point", 1.3, note="Accuse! Wind up, then thrust a pointing arm forward.")
point.pose(0.0, rShoulder=(10, 0, 6), lShoulder=(4, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
point.pose(0.18, "out", rShoulder=(30, -40, -10), lShoulder=(10, 0, -22), root=(-2, 22, 0), neck=(0, 12, 0))
point.pose(0.3, "bigshoot", rShoulder=(92, -8, -4), lShoulder=(-24, 0, -14), root=(-10, -14, 0), neck=(-2, -10, 0))
point.pose(1.3, "sine", rShoulder=(90, -8, -4), lShoulder=(-20, 0, -14), root=(-8, -12, 0), neck=(0, -10, 0))

# Held down ---------------------------------------------------------------------------------------------

cuffed = clip("cuffed", 1.6, loop=True, note="Wrists cuffed behind the back, head down, a shaky breath.")
for t, b in ((0.0, 0.0), (0.8, 1.0), (1.6, 0.0)):
    cuffed.pose(t, "sine", root=(-4 - b, 0, 0), neck=(-22 - b * 2, 0, 0),
                rShoulder=(-24, 0, -10 + b), lShoulder=(-24, 0, 10 - b))

slump = clip("slump", 1.0, note="Voted out: the shoulders drop and the head falls.")
slump.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=(0, 0, 6), lShoulder=(0, 0, -6))
slump.pose(0.25, "out", offset=(0, -0.05, 0), root=(-10, 0, 3), neck=(-32, 0, 5), rShoulder=(10, 0, 4), lShoulder=(8, 0, -4))
slump.pose(1.0, "in", offset=(0, -0.12, 0), root=(-16, 0, 5), neck=(-44, 0, 8), rShoulder=(14, 0, 3), lShoulder=(10, 0, -3))

specter = clip("specterFloat", 2.4, loop=True, note="Deathsingers drift with arms spread and legs trailing.")
specter.pose(0.0, "sine", offset=(0, 0, 0), root=(6, 0, 3), neck=(-4, 0, 0), rShoulder=(18, 0, 28), lShoulder=(18, 0, -28),
             rHip=(-14, 0, 2), lHip=(-8, 0, -2))
specter.pose(1.2, "sine", offset=(0, 0.35, 0), root=(4, 0, -3), neck=(2, 0, 0), rShoulder=(26, 0, 38),
             lShoulder=(26, 0, -38), rHip=(-8, 0, 2), lHip=(-14, 0, -2))
specter.pose(2.4, "sine", offset=(0, 0, 0), root=(6, 0, 3), neck=(-4, 0, 0), rShoulder=(18, 0, 28), lShoulder=(18, 0, -28),
             rHip=(-14, 0, 2), lHip=(-8, 0, -2))


# Deaths: each ends on the floor; the server then locks the final pose into the joints and lets the
# body go limp, so the last frame must be a pose that rests on the ground. Floor keys work out the
# height of the body; a sideways or forward shift (offset_xz = x, z) carries it as it topples.

heart = clip("collapseHeart", 1.6, note="Clutches the chest, staggers, and topples forward.", floor=True)
clutch = dict(rShoulder=(104, 0, -48))
heart.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=(0, 0, 6), lShoulder=(0, 0, -6))
stand(heart, 0.1, "snap", offset=(0, -0.03, 0.05), root=(-14, 0, 0), neck=(-22, 0, 0),
      lShoulder=(24, 0, -34), **clutch)
stand(heart, 0.45, "out", offset=(0.08, -0.05, 0.1), root=(-22, 10, 6), neck=(-14, 0, 12),
      lShoulder=(40, 0, -46), stance=0.1, forward=(0.3, -0.1), **clutch)
floor_key(heart, 0.95, "in", (0.1, -0.4), root=(-58, 8, 8), neck=(-10, 0, 14),
          rShoulder=(70, 0, -30), lShoulder=(50, 0, -50), rHip=(20, 0, 4), lHip=(8, 0, -3))
floor_key(heart, 1.3, "bounce", (0.1, -0.95), root=(-88, 6, 6), neck=(14, 0, 18),
          rShoulder=(150, 0, -16), lShoulder=(110, 0, -62), rHip=(4, 0, 8), lHip=(-4, 0, -8))
floor_key(heart, 1.6, "sine", (0.1, -0.95), root=(-88, 6, 6), neck=(14, 0, 18),
          rShoulder=(152, 0, -14), lShoulder=(112, 0, -64), rHip=(4, 0, 8), lHip=(-4, 0, -8))

ill = clip("collapseDisease", 1.7, note="A racking cough, a stagger, and a slow fall onto the back.", floor=True)
ill.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=(0, 0, 6), lShoulder=(0, 0, -6))
for t, bend in ((0.12, 14), (0.26, 4), (0.4, 16), (0.54, 6)):
    stand(ill, t, "snap", offset=(0, -0.04, 0.08), root=(-bend, 0, 0), neck=(-12, 0, 0),
          rShoulder=(130, 0, -20), lShoulder=(30, 0, 14))
stand(ill, 0.85, "out", offset=(-0.12, -0.05, 0.1), root=(-20, -12, -10), neck=(-18, 0, -12),
      rShoulder=(60, 0, 40), lShoulder=(80, 0, -30), stance=0.12, forward=(0.2, -0.3))
floor_key(ill, 1.3, "in", (-0.2, 0.55), root=(60, -10, -14), neck=(24, 0, -10),
          rShoulder=(40, 0, 70), lShoulder=(86, 0, -20), rHip=(-12, 0, 10), lHip=(-22, 0, -8))
floor_key(ill, 1.7, "bounce", (-0.2, 0.95), root=(88, -8, -16), neck=(26, 0, -14),
          rShoulder=(20, 0, 82), lShoulder=(160, 0, -26), rHip=(-4, 0, 10), lHip=(-10, 0, -12))

acc = clip("collapseAccident", 1.5, note="Struck from the side: thrown off their feet and down on the back.", floor=True)
acc.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), rShoulder=(0, 0, 6), lShoulder=(0, 0, -6))
acc.pose(0.1, "snap", offset=(0.3, 0.15, 0.1), root=(8, 20, 28), neck=(-6, 0, -20),
         rShoulder=(70, 0, 80), lShoulder=(40, 0, -30), rHip=(-30, 0, 20), lHip=(24, 0, -6))
acc.pose(0.38, "out", offset=(0.9, 0.7, 0.4), root=(30, 60, 70), neck=(10, 0, -24),
         rShoulder=(150, 0, 60), lShoulder=(120, 0, -70), rHip=(-30, 0, 26), lHip=(32, 0, -14))
floor_key(acc, 0.95, "in", (1.4, 0.4), root=(78, 36, 24), neck=(18, 0, -14),
          rShoulder=(120, 0, 90), lShoulder=(40, 0, -80), rHip=(-6, 0, 16), lHip=(14, 0, -12))
floor_key(acc, 1.5, "bounce", (1.5, 0.5), root=(86, 30, 12), neck=(12, 0, -10),
          rShoulder=(100, 0, 94), lShoulder=(60, 0, -84), rHip=(-4, 0, 14), lHip=(8, 0, -12))

# Reactions: the table's one-shot reaction to a death, an arrest or a verdict (they hold their last pose).

gasp = clip("reactGasp", 1.2, note="A sharp breath in: the chest lifts, the hands fly up.")
gasp.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
gasp.pose(0.14, "bigshoot", root=(7, 0, 0), neck=(10, 0, 0), rShoulder=(92, 0, 30), lShoulder=(92, 0, -30))
gasp.pose(1.2, "sine", root=(5, 0, 0), neck=(8, 0, 0), rShoulder=(88, 0, 26), lShoulder=(88, 0, -26))

startle = clip("reactStartle", 0.9, note="A jolt: a hop back with the arms thrown wide.")
startle.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
startle.pose(0.08, "snap", offset=(0, 0.25, 0.3), root=(10, 0, 0), neck=(10, 0, 0),
             rShoulder=(60, 0, 62), lShoulder=(60, 0, -62), rHip=(24, 0, 6), lHip=(-12, 0, -6))
startle.pose(0.9, "in", offset=(0, -0.02, 0.3), root=(8, 0, 0), neck=(6, 0, 0),
             rShoulder=(40, 0, 36), lShoulder=(40, 0, -36))

hands_head = clip("reactHandsHead", 1.4, note="Both hands on the head: no, no, no.")
hands_head.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
hands_head.pose(0.2, "bigshoot", root=(-6, 0, 0), neck=(-8, 0, 0), rShoulder=(166, 0, -14), lShoulder=(166, 0, 14))
hands_head.pose(0.6, "sine", root=(-9, 4, 0), neck=(-10, 8, 4), rShoulder=(162, 0, -12), lShoulder=(162, 0, 12))
hands_head.pose(1.0, "sine", root=(-9, -4, 0), neck=(-10, -8, -4), rShoulder=(162, 0, -12), lShoulder=(162, 0, 12))
hands_head.pose(1.4, "sine", root=(-9, 0, 0), neck=(-12, 0, 0), rShoulder=(162, 0, -12), lShoulder=(162, 0, 12))

cover = clip("reactCoverMouth", 1.4, note="A hand to the mouth, eyes wide.")
cover.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
cover.pose(0.2, "overshoot", root=(4, 0, 0), neck=(6, 0, 0), rShoulder=(146, 0, -38), lShoulder=(50, 0, 24))
cover.pose(1.4, "sine", root=(5, 0, 0), neck=(4, 0, 0), rShoulder=(142, 0, -40), lShoulder=(48, 0, 26))

look_away = clip("reactLookAway", 1.2, note="Turns the head and body away, arms held across.")
look_away.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
look_away.pose(0.3, "out", root=(-4, 28, 0), neck=(-6, 62, 0), rShoulder=(46, 0, -32), lShoulder=(40, 0, 30))
look_away.pose(1.2, "sine", root=(-5, 30, 0), neck=(-8, 64, 0), rShoulder=(48, 0, -34), lShoulder=(42, 0, 32))

clap = clip("reactSlowClap", 1.0, loop=True, note="A slow, mocking clap.")
clap.pose(0.0, "snap", root=(0, 0, 0), neck=(2, 0, 0), rShoulder=(88, 0, -34), lShoulder=(88, 0, 34))
clap.pose(0.5, "out", root=(0, 0, 0), neck=(-2, 0, 0), rShoulder=(88, 0, -8), lShoulder=(88, 0, 8))

shrug = clip("shrug", 1.4, note="Palms up, shoulders and eyebrows up: who knows?")
shrug.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
shrug.pose(0.22, "overshoot", root=(-2, 0, 4), neck=(0, 0, 14), rShoulder=(40, 0, 52), lShoulder=(40, 0, -52))
shrug.pose(1.0, "sine", root=(-2, 0, 4), neck=(0, 0, 12), rShoulder=(38, 0, 50), lShoulder=(38, 0, -50))
shrug.pose(1.4, "sine", root=(0, 0, 0), neck=(0, 0, 0), rShoulder=(0, 0, 6), lShoulder=(0, 0, -6))

facepalm = clip("facepalm", 1.8, note="A hand to the forehead and a sigh.")
facepalm.pose(0.0, rShoulder=(0, 0, 6), root=(0, 0, 0), neck=(0, 0, 0))
facepalm.pose(0.3, "overshoot", root=(-8, 0, 0), neck=(-26, 0, 0), rShoulder=(150, 0, -30))
facepalm.pose(1.4, "sine", root=(-9, 0, 0), neck=(-30, 0, 0), rShoulder=(150, 0, -30))
facepalm.pose(1.8, "sine", root=(0, 0, 0), neck=(0, 0, 0), rShoulder=(0, 0, 6))

# Emotes ------------------------------------------------------------------------------------------------

wave = clip("wave", 2.0, note="A friendly wave.")
wave.pose(0.0, rShoulder=(0, 0, 6), root=(0, 0, 0), neck=(0, 0, 0))
wave.pose(0.25, "overshoot", rShoulder=(168, 0, 14), root=(0, 0, -4), neck=(0, 0, -5))
for i in range(4):
    wave.pose(0.5 + i * 0.28, "sine", rShoulder=(168, 0, 14 + (24 if i % 2 == 0 else -4)), root=(0, 0, -4))
wave.pose(1.7, "sine", rShoulder=(150, 0, 12), root=(0, 0, -2), neck=(0, 0, -3))
wave.pose(2.0, "sine", rShoulder=(0, 0, 6), root=(0, 0, 0), neck=(0, 0, 0))

cheer = clip("cheer", 1.8, note="Both arms up and a bounce.")
cheer.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
stand(cheer, 0.18, "out", offset=(0, -0.3, 0), root=(-8, 0, 0), neck=(4, 0, 0),
      rShoulder=(60, 0, 20), lShoulder=(60, 0, -20), stance=0.12)
cheer.pose(0.36, "overshoot", offset=(0, 0.3, 0), root=(6, 0, 0), neck=(12, 0, 0),
           rShoulder=(172, 0, 20), lShoulder=(172, 0, -20), rHip=(10, 0, 6), lHip=(-4, 0, -6))
for i, t in enumerate((0.7, 1.0, 1.3)):
    cheer.pose(t, "sine", offset=(0, 0.16 if i % 2 == 0 else 0.0, 0), root=(4, 0, 0), neck=(10, 0, 0),
               rShoulder=(170 - 10 * (i % 2), 0, 22), lShoulder=(170 - 10 * ((i + 1) % 2), 0, -22),
               rHip=(6, 0, 6), lHip=(-2, 0, -6))
cheer.pose(1.8, "sine", root=(2, 0, 0), neck=(4, 0, 0), rShoulder=(0, 0, 6), lShoulder=(0, 0, -6))

laugh = clip("laugh", 0.6, loop=True, note="Shaking with laughter, head back.")
laugh.pose(0.0, "sine", offset=(0, 0.03, 0), root=(6, 0, 0), neck=(16, 0, 0), rShoulder=(34, 0, 14),
           lShoulder=(78, 0, 26))
laugh.pose(0.3, "sine", offset=(0, -0.03, 0), root=(10, 0, 0), neck=(22, 0, 0), rShoulder=(30, 0, 12),
           lShoulder=(74, 0, 24))
laugh.pose(0.6, "sine", offset=(0, 0.03, 0), root=(6, 0, 0), neck=(16, 0, 0), rShoulder=(34, 0, 14),
           lShoulder=(78, 0, 26))

dance = clip("dance", 1.2, loop=True, note="Arms up and down, hips swaying.")
for i, t in enumerate((0.0, 0.3, 0.6, 0.9, 1.2)):
    sign = 1 if i % 2 == 0 else -1
    stand(dance, t, "sine", offset=(0.14 * sign, -0.08, 0), root=(0, 12 * sign, 6 * sign), stance=0.2,
          neck=(-4, -8 * sign, 0), rShoulder=(110 - 70 * (i % 2), 0, 24), lShoulder=(40 + 70 * (i % 2), 0, -24))

groove = clip("dance2", 0.8, loop=True, note="A side-to-side bounce, arms swinging.")
for i, t in enumerate((0.0, 0.2, 0.4, 0.6, 0.8)):
    s = (1, 0, -1, 0, 1)[i]
    stand(groove, t, "sine", offset=(0.2 * s, -0.14 if i % 2 else 0.0, 0), root=(0, 8 * s, 4 * s), stance=0.25,
          neck=(-6, 4 * s, 0), rShoulder=(30 + 20 * s, 0, 18 + 20 * (1 - s) * 0.5),
          lShoulder=(30 - 20 * s, 0, -18 - 20 * (1 + s) * 0.5))

spin = clip("dance3", 1.2, loop=True, note="Spin with the arms out, one full turn per loop.")
for i, t in enumerate((0.0, 0.3, 0.6, 0.9, 1.2)):
    spin.pose(t, "linear", offset=(0, 0.12 if i % 2 == 0 else 0.02, 0), root=(4, 90 * i, 0), neck=(10, 0, 0),
              rShoulder=(10, 0, 84), lShoulder=(10, 0, -84), rHip=(6, 0, 8), lHip=(-6, 0, -8))

salute = clip("salute", 1.6, note="A crisp Bureau salute.")
salute.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
salute.pose(0.14, "snap", root=(2, 0, 0), neck=(6, 0, 0), rShoulder=(158, 0, -34), lShoulder=(0, 0, -4))
salute.pose(1.0, "sine", root=(2, 0, 0), neck=(6, 0, 0), rShoulder=(158, 0, -34), lShoulder=(0, 0, -4))
salute.pose(1.2, "snap", root=(0, 0, 0), neck=(0, 0, 0), rShoulder=(0, 0, 4), lShoulder=(0, 0, -6))

bow = clip("bow", 2.4, note="A polite bow from the waist.")
bow.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
stand(bow, 0.7, "smooth", root=(-55, 0, 0), neck=(18, 0, 0), rShoulder=(8, 0, 4), lShoulder=(8, 0, -4))
stand(bow, 1.5, "sine", root=(-56, 0, 0), neck=(18, 0, 0), rShoulder=(8, 0, 4), lShoulder=(8, 0, -4))
bow.pose(2.4, "sine", root=(0, 0, 0), neck=(0, 0, 0), rShoulder=(0, 0, 6), lShoulder=(0, 0, -6))

chip = clip("chip", 2.6, note="The dramatic chip: raised high, a long pause, then a crunch.")
chip.pose(0.0, rShoulder=(0, 0, 6), lShoulder=(0, 0, -6), root=(0, 0, 0), neck=(0, 0, 0))
chip.pose(0.35, "overshoot", root=(8, 0, 4), neck=(14, 0, 8), rShoulder=(128, 0, 12), lShoulder=(0, 0, -30))
chip.pose(1.5, "sine", root=(10, 0, 5), neck=(16, 0, 9), rShoulder=(132, 0, 14), lShoulder=(0, 0, -34))
chip.pose(1.7, "snap", root=(-12, 0, 0), neck=(-8, 0, 0), rShoulder=(150, 0, -26), lShoulder=(10, 0, -12))
for t, d in ((1.85, 6), (1.97, -4), (2.09, 6), (2.21, -3)):
    chip.pose(t, "snap", root=(-12 + d, 0, 0), neck=(-8, 0, 0), rShoulder=(150, 0, -26), lShoulder=(10, 0, -12))
chip.pose(2.6, "sine", root=(0, 0, 0), neck=(0, 0, 0), rShoulder=(0, 0, 6), lShoulder=(0, 0, -6))

think = clip("think", 3.0, loop=True, note="Crouched like a detective, a thumb to the lip.")
for t, b in ((0.0, 0.0), (1.5, 1.0), (3.0, 0.0)):
    floor_key(think, t, "sine", (0, 0), root=(-12 + b, 0, 0), neck=(-14 + b * 2, 6 * b, 0),
              rShoulder=(104, 0, -34), lShoulder=(76, 0, 22), rHip=(80, 0, 4), lHip=(80, 0, -4))


def build(arm):
    import animlib

    return animlib.build_all(arm)
