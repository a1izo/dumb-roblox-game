"""Every Death's Gambit animation, keyed in the game's joint convention (see animlib.py) on the R6
rig (rig.py).

R6 has six joints: root (moves the whole body and bends the waist), neck, both shoulders and both
hips. Limbs are rigid blocks, so a little goes a long way: a 10 degree change already reads.

Style: grounded and restrained, to suit a noir mystery. Arms hang close to the body, motion is
small and weighted, nothing bounces, overshoots or flails. Moves ease in and out ("smooth", "sine",
"in", "out"); "snap" is kept for the few real jolts (a cough, an impact).

Movement (idle, walk, run, land) is generated in gait.py. Wherever the hips move here, the legs are
solved so the feet stay where they are (posekit.planted_legs), and every pose that ends on the
ground is fitted to the floor (posekit.on_floor), so nothing sinks or floats.

Rigid arms: shoulder x 0 = hanging, 90 = straight out in front, 180 = overhead. z swings an arm out
to the side (right +, left -) before it is raised, so with the arm raised z spreads it left or right
(right arm -z / left arm +z bring it across the body).

Run build() in Blender (see art/README.md) to rebuild the actions on the rig, then export_anims.py
writes src/shared/Anim/Clips.luau.
"""

import math

import gait
from animlib import clip
from posekit import on_floor, planted_legs

# Arms hanging naturally at the sides.
REST = dict(rShoulder=(0, 0, 1.5), lShoulder=(0, 0, -1.5))


def stand(c, t, ease="smooth", offset=(0, 0, 0), root=(0, 0, 0), stance=0.0, forward=(0.0, 0.0), **upper):
    """A key with both feet planted while the hips move by `offset` and turn by `root`."""
    legs = planted_legs(offset, root, stance, forward)
    c.pose(t, ease, offset=offset, root=root, **legs, **upper)


def floor_key(c, t, ease, offset_xz=(0, 0), **joints):
    """A key whose body rests on the floor (the height is worked out)."""
    offset = on_floor(joints, (offset_xz[0], 0, offset_xz[1]))
    c.pose(t, ease, offset=offset, **joints)


def rest_key(c, t, ease="smooth", **extra):
    """Back to standing still with the arms at the sides."""
    joints = dict(root=(0, 0, 0), neck=(0, 0, 0), **REST)
    joints.update(extra)
    c.pose(t, ease, **joints)


# Locomotion --------------------------------------------------------------------------------------------

gait.build()

jump = clip("jump", 0.5, note="Take-off: a short dip, then up with the arms lifting a little.")
stand(jump, 0.0, "smooth", offset=(0, -0.08, 0), root=(-5, 0, 0), neck=(2, 0, 0),
      rShoulder=(-8, 0, 3), lShoulder=(-8, 0, -3), stance=0.03)
jump.pose(0.14, "out", offset=(0, 0.04, 0), root=(2, 0, 0), neck=(3, 0, 0),
          rShoulder=(38, 0, 8), lShoulder=(34, 0, -8), rHip=(18, 0, 2), lHip=(-6, 0, -2))
jump.pose(0.5, "sine", offset=(0, 0.02, 0), root=(1, 0, 0), neck=(2, 0, 0),
          rShoulder=(30, 0, 10), lShoulder=(26, 0, -10), rHip=(14, 0, 3), lHip=(-2, 0, -3))

fall = clip("fall", 1.2, loop=True, note="Falling: arms a little out for balance, legs apart, a slow drift.")
fall.pose(0.0, "sine", root=(3, 0, 1), neck=(-6, 0, 0), rShoulder=(28, 0, 22), lShoulder=(22, 0, -24),
          rHip=(10, 0, 4), lHip=(-6, 0, -4))
fall.pose(0.6, "sine", root=(3, 0, -1), neck=(-6, 0, 0), rShoulder=(22, 0, 24), lShoulder=(28, 0, -22),
          rHip=(-6, 0, 4), lHip=(10, 0, -4))

# Standing and sitting ----------------------------------------------------------------------------------

sit = clip("sit", 6.0, loop=True, note="Seated (a Seat): thighs level, hands resting on the lap, a slow breath.")
for t, b in ((0.0, 0.0), (2.0, 1.0), (4.0, 0.0)):
    sit.pose(t, "sine", root=(-2 + 0.6 * b, 0, 0), neck=(-3 - 0.5 * b, 0, 0), rHip=(88, 0, 2), lHip=(88, 0, -2),
             rShoulder=(36 + b, 0, -4), lShoulder=(36 + b, 0, 4))
sit.pose(6.0, "sine", root=(-2, 0, 0), neck=(-3, 0, 0), rHip=(88, 0, 2), lHip=(88, 0, -2),
         rShoulder=(36, 0, -4), lShoulder=(36, 0, 4))

idle_look = clip("idleLook", 4.0, note="A fidget: a glance over one shoulder, then the other.")
idle_look.pose(0.0, neck=(0, 0, 0), root=(0, 0, 0))
idle_look.pose(0.9, "smooth", neck=(-2, 34, 0), root=(0, 6, 0))
idle_look.pose(1.8, "smooth", neck=(-2, 34, 0), root=(0, 6, 0))
idle_look.pose(2.7, "smooth", neck=(-1, -26, 0), root=(0, -4, 0))
idle_look.pose(4.0, "smooth", neck=(0, 0, 0), root=(0, 0, 0))

idle_watch = clip("idleWatch", 3.6, note="A fidget: a look at the wrist watch.")
idle_watch.pose(0.0, rShoulder=(0, 0, 1.5), neck=(0, 0, 0), root=(0, 0, 0))
idle_watch.pose(0.7, "smooth", rShoulder=(58, 0, -26), neck=(-22, 6, 0), root=(-2, 4, 0))
idle_watch.pose(2.2, "sine", rShoulder=(58, 0, -26), neck=(-22, 6, 0), root=(-2, 4, 0))
idle_watch.pose(3.0, "smooth", rShoulder=(4, 0, 0), neck=(-2, 0, 0), root=(0, 0, 0))
idle_watch.pose(3.6, "sine", rShoulder=(0, 0, 1.5), neck=(0, 0, 0), root=(0, 0, 0))

idle_tie = clip("idleTie", 3.2, note="A fidget: straightening the tie.")
idle_tie.pose(0.0, rShoulder=(0, 0, 1.5), neck=(0, 0, 0), root=(0, 0, 0))
idle_tie.pose(0.6, "smooth", rShoulder=(70, 0, -30), neck=(-14, 0, 3), root=(-1, 0, 0))
for t, d in ((0.95, 3), (1.3, -2), (1.65, 3)):
    idle_tie.pose(t, "sine", rShoulder=(70 + d, 0, -30), neck=(-14, 0, 3), root=(-1, 0, 0))
idle_tie.pose(2.4, "smooth", rShoulder=(3, 0, 0), neck=(-1, 0, 0), root=(0, 0, 0))
idle_tie.pose(3.2, "sine", rShoulder=(0, 0, 1.5), neck=(0, 0, 0))

# Actions -----------------------------------------------------------------------------------------------

# Everyone alive writes in the Death's Gambit phase: the notebook held low at the chest in the left
# arm, the right arm writing in small strokes, the head bent over the page.
write = clip("write", 2.4, loop=True, note="Everyone alive writes in the Death's Gambit phase.")
for i in range(12):
    t = i * 0.2
    stroke = 2.5 if i % 2 == 0 else -1.5
    line = (i % 6) * 0.8  # the pen moves along the line, then back for the next one
    write.pose(t, "sine", root=(-5, 2, 0), neck=(-26, 3 - line * 0.5, 0),
               lShoulder=(42, 0, 16), rShoulder=(40 + stroke * 0.4, 0, -10 + stroke + line))
write.pose(2.4, "sine", root=(-5, 2, 0), neck=(-26, 3, 0), lShoulder=(42, 0, 16), rShoulder=(41, 0, -7.5))

# One loop per kind of station (Camera, Fingerprint, Phone, Forensics): the body leans in over the
# console a little; each job has its own small movement.
work_camera = clip("workCamera", 2.4, loop=True, note="Camera footage: hands on the console, scrubbing through the tape.")
for i, (r, look) in enumerate(((0, 0), (3, 1), (1, 2), (4, 1), (0, 0), (2, -2), (4, -3), (1, -1))):
    work_camera.pose(i * 0.3, "sine", root=(-6, look, 0), neck=(-14, look * 2, 0),
                     rShoulder=(48 + r, 0, -6), lShoulder=(46, 0, 8))
work_camera.pose(2.4, "sine", root=(-6, 0, 0), neck=(-14, 0, 0), rShoulder=(48, 0, -6), lShoulder=(46, 0, 8))

work_print = clip("workFingerprint", 2.0, loop=True, note="Fingerprints: dusting in small circles, the other hand steadying.")
for i in range(8):
    a = i / 8 * 2 * math.pi
    work_print.pose(i * 0.25, "linear", root=(-10, 4, 0), neck=(-20, 6, 0),
                    rShoulder=(54 + 4 * math.sin(a), 0, -8 + 5 * math.cos(a)), lShoulder=(44, 0, 10))
work_print.pose(2.0, "linear", root=(-10, 4, 0), neck=(-20, 6, 0), rShoulder=(54, 0, -3), lShoulder=(44, 0, 10))

work_phone = clip("workPhone", 3.2, loop=True, note="Phone records: the handset at the ear, the other hand taking notes.")
for i, (w, tilt) in enumerate(((0, 0), (2, 1), (-1, 1), (3, 0), (0, -1), (2, 1), (-1, 0), (2, 0))):
    work_phone.pose(i * 0.4, "sine", root=(-3, 3, 0), neck=(-10, 4, 7 + tilt),
                    lShoulder=(150, 0, -22), rShoulder=(38 + w * 0.5, 0, -8 + w))
work_phone.pose(3.2, "sine", root=(-3, 3, 0), neck=(-10, 4, 7), lShoulder=(150, 0, -22), rShoulder=(38, 0, -8))

work_lab = clip("workForensics", 2.4, loop=True, note="Forensics: bent over the microscope, turning the focus knob.")
for i, (knob, look) in enumerate(((0, 0), (3, 0), (0, 1), (4, 0), (0, -1), (3, 0))):
    work_lab.pose(i * 0.4, "sine", root=(-12, look, 0), neck=(-22, look * 2, 0),
                  rShoulder=(56 + knob, 0, -8), lShoulder=(54, 0, 8))
work_lab.pose(2.4, "sine", root=(-12, 0, 0), neck=(-22, 0, 0), rShoulder=(56, 0, -8), lShoulder=(54, 0, 8))

raise_hand = clip("raiseHand", 0.8, note="A vote is cast: the hand goes up and stays.")
raise_hand.pose(0.0, rShoulder=(0, 0, 1.5), root=(0, 0, 0), neck=(0, 0, 0))
raise_hand.pose(0.35, "out", rShoulder=(160, 0, 6), root=(0, 0, -2), neck=(2, 0, -2))
raise_hand.pose(0.8, "sine", rShoulder=(158, 0, 6), root=(0, 0, -2), neck=(2, 0, -2))

point = clip("point", 1.6, note="Accuse: a turn of the body and an arm levelled at someone.")
point.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
point.pose(0.4, "out", rShoulder=(84, -4, -2), lShoulder=(0, 0, -2), root=(-2, -8, 0), neck=(-2, -6, 0))
point.pose(1.6, "sine", rShoulder=(82, -4, -2), lShoulder=(0, 0, -2), root=(-2, -8, 0), neck=(-2, -6, 0))

# Held down ---------------------------------------------------------------------------------------------

cuffed = clip("cuffed", 3.0, loop=True, note="Wrists cuffed behind the back, head down.")
for t, b in ((0.0, 0.0), (1.5, 1.0), (3.0, 0.0)):
    cuffed.pose(t, "sine", root=(-3 - b * 0.5, 0, 0), neck=(-18 - b, 0, 0),
                rShoulder=(-16, 0, -5), lShoulder=(-16, 0, 5))

slump = clip("slump", 1.4, note="Voted out: the shoulders drop and the head goes down.")
slump.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
slump.pose(1.4, "smooth", offset=(0, -0.04, 0), root=(-8, 0, 1), neck=(-32, 0, 3), rShoulder=(5, 0, 0), lShoulder=(4, 0, 0))

specter = clip("specterFloat", 4.0, loop=True, note="Deathsingers drift slowly, arms loose, legs trailing.")
specter.pose(0.0, "sine", offset=(0, 0, 0), root=(3, 0, 1), neck=(-3, 0, 0), rShoulder=(8, 0, 12), lShoulder=(8, 0, -12),
             rHip=(-6, 0, 1), lHip=(-4, 0, -1))
specter.pose(2.0, "sine", offset=(0, 0.25, 0), root=(2, 0, -1), neck=(0, 0, 0), rShoulder=(12, 0, 16),
             lShoulder=(12, 0, -16), rHip=(-4, 0, 1), lHip=(-6, 0, -1))
specter.pose(4.0, "sine", offset=(0, 0, 0), root=(3, 0, 1), neck=(-3, 0, 0), rShoulder=(8, 0, 12), lShoulder=(8, 0, -12),
             rHip=(-6, 0, 1), lHip=(-4, 0, -1))

# Deaths: each ends on the floor; the server then locks the final pose into the joints and lets the
# body go limp, so the last frame must be a pose that rests on the ground. Floor keys work out the
# height of the body; a sideways or forward shift (offset_xz = x, z) carries it as it goes down.

heart = clip("collapseHeart", 2.2, note="A hand to the chest, a half step, then down forward.", floor=True)
heart.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
stand(heart, 0.25, "out", offset=(0, -0.02, 0.03), root=(-10, 0, 0), neck=(-18, 0, 0),
      rShoulder=(56, 0, -34), lShoulder=(6, 0, -3))
stand(heart, 0.9, "sine", offset=(0.04, -0.04, 0.06), root=(-16, 4, 3), neck=(-22, 0, 4),
      rShoulder=(58, 0, -36), lShoulder=(24, 0, -10), stance=0.04, forward=(0.15, -0.05))
floor_key(heart, 1.45, "in", (0.05, -0.35), root=(-52, 4, 4), neck=(-8, 0, 6),
          rShoulder=(60, 0, -30), lShoulder=(46, 0, -14), rHip=(14, 0, 2), lHip=(8, 0, -2))
floor_key(heart, 1.85, "in", (0.05, -0.9), root=(-88, 3, 4), neck=(10, 0, 14),
          rShoulder=(120, 0, -10), lShoulder=(150, 0, -24), rHip=(2, 0, 3), lHip=(-2, 0, -3))
floor_key(heart, 2.2, "out", (0.05, -0.9), root=(-89, 3, 4), neck=(12, 0, 16),
          rShoulder=(122, 0, -10), lShoulder=(152, 0, -24), rHip=(2, 0, 3), lHip=(-2, 0, -3))

ill = clip("collapseDisease", 2.6, note="A hard cough into the fist, a sway, and down onto the back.", floor=True)
ill.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
for t, bend in ((0.2, 10), (0.4, 4), (0.6, 12), (0.8, 5), (1.0, 11)):
    stand(ill, t, "snap", offset=(0, -0.02, 0.04), root=(-bend, 0, 0), neck=(-10, 0, 0),
          rShoulder=(110, 0, -24), lShoulder=(16, 0, 6))
stand(ill, 1.45, "smooth", offset=(-0.06, -0.04, 0.05), root=(-8, -6, -6), neck=(-6, 0, -8),
      rShoulder=(30, 0, 8), lShoulder=(36, 0, -16), stance=0.06, forward=(0.1, -0.15))
floor_key(ill, 1.95, "in", (-0.15, 0.5), root=(55, -6, -8), neck=(16, 0, -6),
          rShoulder=(26, 0, 30), lShoulder=(40, 0, -26), rHip=(-8, 0, 4), lHip=(-14, 0, -4))
floor_key(ill, 2.35, "in", (-0.15, 0.95), root=(88, -5, -10), neck=(18, 0, -10),
          rShoulder=(14, 0, 40), lShoulder=(20, 0, -34), rHip=(-2, 0, 5), lHip=(-6, 0, -5))
floor_key(ill, 2.6, "out", (-0.15, 0.95), root=(89, -5, -10), neck=(20, 0, -12),
          rShoulder=(14, 0, 42), lShoulder=(20, 0, -36), rHip=(-2, 0, 5), lHip=(-6, 0, -5))

acc = clip("collapseAccident", 1.6, note="Struck from the side: knocked off balance and down.", floor=True)
acc.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
acc.pose(0.1, "snap", offset=(0.25, 0.02, 0.05), root=(-4, 14, 22), neck=(-4, 0, -16),
         rShoulder=(20, 0, 34), lShoulder=(14, 0, -18), rHip=(-6, 0, 10), lHip=(8, 0, -4))
acc.pose(0.45, "in", offset=(0.8, -0.4, 0.2), root=(10, 26, 52), neck=(4, 0, -18),
         rShoulder=(40, 0, 50), lShoulder=(30, 0, -30), rHip=(-8, 0, 16), lHip=(12, 0, -6))
floor_key(acc, 0.85, "in", (1.3, 0.3), root=(40, 20, 62), neck=(8, 0, -12),
          rShoulder=(20, 0, 60), lShoulder=(16, 0, -34), rHip=(-4, 0, 14), lHip=(10, 0, -8))
floor_key(acc, 1.25, "in", (1.4, 0.4), root=(86, 10, 8), neck=(12, 0, -10),
          rShoulder=(6, 0, 48), lShoulder=(12, 0, -30), rHip=(-2, 0, 10), lHip=(6, 0, -8))
floor_key(acc, 1.6, "out", (1.4, 0.4), root=(87, 10, 8), neck=(13, 0, -10),
          rShoulder=(6, 0, 49), lShoulder=(12, 0, -31), rHip=(-2, 0, 10), lHip=(6, 0, -8))

# Reactions: the table's one-shot reaction to a death, an arrest or a verdict (they hold their last
# pose, then fade out). Quiet and human, not cartoon.

gasp = clip("reactGasp", 1.4, note="A sharp breath in: a half step back, a hand to the chest.")
gasp.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
stand(gasp, 0.3, "out", offset=(0, 0, 0.12), root=(4, 0, 0), neck=(4, 0, 0),
      rShoulder=(52, 0, -32), lShoulder=(6, 0, -4), forward=(-0.1, -0.1))
stand(gasp, 1.4, "sine", offset=(0, 0, 0.12), root=(3, 0, 0), neck=(2, 0, 0),
      rShoulder=(50, 0, -32), lShoulder=(5, 0, -4), forward=(-0.1, -0.1))

startle = clip("reactStartle", 1.0, note="A flinch: the body jerks back, the arms come up a little.")
startle.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
stand(startle, 0.12, "snap", offset=(0, 0.02, 0.15), root=(6, 0, 0), neck=(6, 0, 0),
      rShoulder=(30, 0, 10), lShoulder=(30, 0, -10), forward=(-0.15, -0.15))
stand(startle, 1.0, "smooth", offset=(0, 0, 0.15), root=(3, 0, 0), neck=(2, 0, 0),
      rShoulder=(16, 0, 6), lShoulder=(16, 0, -6), forward=(-0.15, -0.15))

hands_head = clip("reactHandsHead", 1.8, note="Both hands to the head in disbelief.")
hands_head.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
hands_head.pose(0.45, "out", root=(-5, 0, 0), neck=(-10, 0, 0), rShoulder=(140, 0, -18), lShoulder=(140, 0, 18))
hands_head.pose(1.1, "sine", root=(-6, 3, 0), neck=(-12, 5, 0), rShoulder=(140, 0, -18), lShoulder=(140, 0, 18))
hands_head.pose(1.8, "sine", root=(-6, 0, 0), neck=(-14, 0, 0), rShoulder=(140, 0, -18), lShoulder=(140, 0, 18))

cover = clip("reactCoverMouth", 1.6, note="A hand to the mouth.")
cover.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
cover.pose(0.35, "out", root=(2, 0, 0), neck=(2, 0, 0), rShoulder=(120, 0, -30), lShoulder=(34, 0, 18))
cover.pose(1.6, "sine", root=(2, 0, 0), neck=(1, 0, 0), rShoulder=(118, 0, -30), lShoulder=(34, 0, 18))

look_away = clip("reactLookAway", 1.6, note="Turns away from it, arms folded.")
look_away.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
look_away.pose(0.5, "smooth", root=(-2, 16, 0), neck=(-8, 40, 0), rShoulder=(34, 0, -30), lShoulder=(30, 0, 28))
look_away.pose(1.6, "sine", root=(-2, 18, 0), neck=(-10, 42, 0), rShoulder=(34, 0, -30), lShoulder=(30, 0, 28))

clap = clip("reactSlowClap", 1.4, loop=True, note="A slow, deliberate clap.")
clap.pose(0.0, "in", root=(0, 0, 0), neck=(2, 0, 0), rShoulder=(56, 0, -26), lShoulder=(56, 0, 26))
clap.pose(0.7, "out", root=(0, 0, 0), neck=(2, 0, 0), rShoulder=(56, 0, -8), lShoulder=(56, 0, 8))

shrug = clip("shrug", 1.8, note="A small shrug: who knows?")
shrug.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
shrug.pose(0.4, "out", root=(-1, 0, 2), neck=(0, 0, 7), rShoulder=(26, 0, 22), lShoulder=(26, 0, -22))
shrug.pose(1.1, "sine", root=(-1, 0, 2), neck=(0, 0, 6), rShoulder=(25, 0, 21), lShoulder=(25, 0, -21))
rest_key(shrug, 1.8)

facepalm = clip("facepalm", 2.2, note="A hand over the eyes and a slow breath out.")
facepalm.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
facepalm.pose(0.45, "smooth", root=(-5, 0, 0), neck=(-22, 0, 0), rShoulder=(128, 0, -28))
facepalm.pose(1.6, "sine", root=(-6, 0, 0), neck=(-24, 0, 0), rShoulder=(128, 0, -28))
rest_key(facepalm, 2.2)

# Emotes ------------------------------------------------------------------------------------------------

wave = clip("wave", 2.4, note="A raised hand, a small wave.")
wave.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
wave.pose(0.4, "out", rShoulder=(140, 0, 18), root=(0, 0, -2), neck=(0, 0, -2))
for i in range(4):
    wave.pose(0.7 + i * 0.3, "sine", rShoulder=(140, 0, 18 + (10 if i % 2 == 0 else -2)), root=(0, 0, -2))
wave.pose(2.0, "smooth", rShoulder=(10, 0, 4), root=(0, 0, 0), neck=(0, 0, 0))
wave.pose(2.4, "sine", rShoulder=(0, 0, 1.5), root=(0, 0, 0), neck=(0, 0, 0))

cheer = clip("cheer", 2.0, note="A fist raised in triumph.")
cheer.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
cheer.pose(0.35, "out", root=(3, 0, -2), neck=(8, 0, 0), rShoulder=(158, 0, 6), lShoulder=(6, 0, -4))
cheer.pose(1.3, "sine", root=(3, 0, -2), neck=(8, 0, 0), rShoulder=(156, 0, 6), lShoulder=(6, 0, -4))
rest_key(cheer, 2.0)

# The villain's laugh: head tilted back, a hand half over the face, shoulders shaking.
laugh = clip("laugh", 1.2, loop=True, note="A low, unhinged laugh, a hand over the face.")
for t, s in ((0.0, 0), (0.15, 1), (0.3, 0), (0.45, 1), (0.6, 0), (0.75, 1), (0.9, 0), (1.05, 1), (1.2, 0)):
    laugh.pose(t, "sine", offset=(0, 0.015 * s, 0), root=(6 + s, 0, 0), neck=(14 + s * 2, 0, 0),
               rShoulder=(122, 0, -26), lShoulder=(2 + s, 0, -3))

dance = clip("dance", 1.6, loop=True, note="An easy side-to-side step with the shoulders.")
for i, t in enumerate((0.0, 0.4, 0.8, 1.2, 1.6)):
    sgn = (1, 0, -1, 0, 1)[i]
    stand(dance, t, "sine", offset=(0.08 * sgn, -0.04 if i % 2 else 0.0, 0), root=(0, 6 * sgn, 2 * sgn), stance=0.06,
          neck=(-2, -4 * sgn, 0), rShoulder=(18 + 10 * sgn, 0, 4), lShoulder=(18 - 10 * sgn, 0, -4))

groove = clip("dance2", 1.0, loop=True, note="A head nod and a shoulder roll to the beat.")
for i, t in enumerate((0.0, 0.25, 0.5, 0.75, 1.0)):
    beat = 1 if i % 2 == 0 else 0
    stand(groove, t, "sine", offset=(0, -0.03 * beat, 0), root=(-2 * beat, 4 * (1, 1, -1, -1, 1)[i], 0),
          stance=0.05, neck=(-6 * beat, 0, 0), rShoulder=(20 + 6 * beat, 0, 4), lShoulder=(20 + 6 * beat, 0, -4))

spin = clip("dance3", 1.6, loop=True, note="A slow turn on the spot, arms a little out.")
for i, t in enumerate((0.0, 0.4, 0.8, 1.2, 1.6)):
    spin.pose(t, "linear", root=(0, 90 * i, 0), neck=(0, 0, 0), rShoulder=(10, 0, 26), lShoulder=(10, 0, -26))

salute = clip("salute", 2.0, note="A crisp Bureau salute.")
salute.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
salute.pose(0.3, "out", root=(1, 0, 0), neck=(3, 0, 0), rShoulder=(146, 0, -30), lShoulder=(0, 0, -1))
salute.pose(1.3, "sine", root=(1, 0, 0), neck=(3, 0, 0), rShoulder=(146, 0, -30), lShoulder=(0, 0, -1))
rest_key(salute, 1.7, "in")
rest_key(salute, 2.0, "sine")

bow = clip("bow", 2.6, note="A polite bow from the waist.")
bow.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
stand(bow, 0.8, "smooth", root=(-32, 0, 0), neck=(-8, 0, 0), rShoulder=(4, 0, 1), lShoulder=(4, 0, -1))
stand(bow, 1.6, "sine", root=(-33, 0, 0), neck=(-8, 0, 0), rShoulder=(4, 0, 1), lShoulder=(4, 0, -1))
rest_key(bow, 2.6)

# The dramatic chip (the anime's "I'll take a potato chip... and eat it"): raised slowly, held, then
# brought to the mouth in one decisive move.
chip = clip("chip", 3.2, note="The dramatic chip: raised, held, then eaten in one move.")
chip.pose(0.0, root=(0, 0, 0), neck=(0, 0, 0), **REST)
chip.pose(0.7, "smooth", root=(4, 0, 2), neck=(6, 0, 4), rShoulder=(112, 0, 10), lShoulder=(0, 0, -2))
chip.pose(1.8, "sine", root=(5, 0, 2), neck=(8, 0, 4), rShoulder=(116, 0, 10), lShoulder=(0, 0, -2))
chip.pose(2.05, "out", root=(-4, 0, 0), neck=(-4, 0, 0), rShoulder=(128, 0, -26), lShoulder=(0, 0, -2))
chip.pose(2.6, "sine", root=(-4, 0, 0), neck=(-5, 0, 0), rShoulder=(126, 0, -26), lShoulder=(0, 0, -2))
rest_key(chip, 3.2)

think = clip("think", 4.0, loop=True, note="Crouched like a detective, a thumb to the lip.")
for t, b in ((0.0, 0.0), (2.0, 1.0), (4.0, 0.0)):
    floor_key(think, t, "sine", (0, 0), root=(-10 + b * 0.5, 0, 0), neck=(-10 + b, 3 * b, 0),
              rShoulder=(96, 0, -30), lShoulder=(70, 0, 18), rHip=(80, 0, 3), lHip=(80, 0, -3))


def build(arm):
    import animlib

    return animlib.build_all(arm)
