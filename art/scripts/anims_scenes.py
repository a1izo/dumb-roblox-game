"""Animations for the cutscenes: what the players' avatars do when the camera finds them.

  act*     activities for the intro vignettes (loops), seated or standing at a mark
  react*   reactions to a death, a verdict or an arrest (one-shots that hold their last pose)
  reveal*  the private role reveals
  victoryCross / defeatFloor  more endings for the outro line-up

Same conventions as anims.py (angles in degrees in the parent's frame; right arm +z lifts out,
left arm -z; knees bend negative). Seated clips put the hips on a seat SEAT studs high
(posekit.on_seat): the cutscene stage places a chair at every seated mark.
"""

from animlib import clip
from posekit import kneeling_leg, on_floor, on_seat, planted_legs

SEAT = 1.75


def stand(c, t, ease="smooth", offset=(0, 0, 0), root=(0, 0, 0), stance=0.0, forward=(0.0, 0.0), **upper):
    c.pose(t, ease, offset=offset, root=root, **planted_legs(offset, root, stance, forward), **upper)


def seated_legs(spread=5, knee=-86):
    return dict(rHip=(86, 0, -spread), lHip=(86, 0, spread), rKnee=knee, lKnee=knee,
                rAnkle=(-2, 0, 0), lAnkle=(-2, 0, 0))


def sit(c, t, ease="smooth", legs=None, **upper):
    """A key sitting on the chair: legs down the front of the seat, hips on it."""
    joints = dict(legs or seated_legs())
    joints.update(upper)
    joints.setdefault("root", (0, 0, 0))
    c.pose(t, ease, offset=on_seat(joints, (0, 0, 0), SEAT), **joints)


def hang(r=(-4, 0, 4), l=(-4, 0, -4), re=18, le=18):
    return dict(rShoulder=r, lShoulder=l, rElbow=re, lElbow=le)


CROSSED = dict(rShoulder=(26, 0, -44), rElbow=112, rWrist=(0, 0, -10),
               lShoulder=(22, 0, 44), lElbow=108, lWrist=(0, 0, 10))
BEHIND = dict(rShoulder=(-40, 0, -14), lShoulder=(-40, 0, 14), rElbow=44, lElbow=44,
              rWrist=(0, 0, 12), lWrist=(0, 0, -12))
POCKETS = dict(rShoulder=(-8, 0, 10), lShoulder=(-8, 0, -10), rElbow=34, lElbow=34,
               rWrist=(-10, 0, 0), lWrist=(-10, 0, 0))

# Seated ----------------------------------------------------------------------------------------------

seated = clip("sit", 3.0, loop=True, note="Sitting at ease, breathing.")
for t, b in ((0.0, 0), (1.5, 1), (3.0, 0)):
    sit(seated, t, "sine", waist=(-2 + b * 2, 0, 0), neck=(-4 + b * 3, 0, 0),
        rShoulder=(18, 0, 6), lShoulder=(18, 0, -6), rElbow=60, lElbow=60)

typing = clip("actTypeSeated", 1.2, loop=True, note="Typing at a desk, seated.")
for i, t in enumerate((0.0, 0.15, 0.3, 0.45, 0.6, 0.75, 0.9, 1.05)):
    r, l = (6, 0) if i % 2 == 0 else (0, 6)
    sit(typing, t, "snap", waist=(-12, 0, 0), neck=(-14, (i % 3 - 1) * 4, 0),
        rShoulder=(46 - r, 0, -10), rElbow=64 + r, rWrist=(-18 - r, 0, 0),
        lShoulder=(46 - l, 0, 10), lElbow=64 + l, lWrist=(-18 - l, 0, 0))

writing = clip("actWriteSeated", 1.6, loop=True, note="Writing notes at a desk, seated.")
for t, wrist, step in ((0.0, -14, 0), (0.2, 12, 1), (0.4, -12, 2), (0.6, 14, 3), (0.8, -12, 4), (1.0, 12, 5),
                       (1.2, -12, 6)):
    sit(writing, t, "sine", waist=(-16, 4, 0), neck=(-30, 4 - step, 0),
        lShoulder=(40, 0, 16), lElbow=76, lWrist=(-12, 0, -8),
        rShoulder=(40 + step, 0, -18 + step * 1.4), rElbow=70 - step, rWrist=(-24, 0, wrist))
sit(writing, 1.4, "snap", waist=(-10, 0, 0), neck=(-14, -8, 0), lShoulder=(40, 0, 16), lElbow=76,
    rShoulder=(34, 0, -26), rElbow=84, rWrist=(-10, 0, 0))

sleep = clip("actSleepDesk", 3.2, loop=True, note="Asleep on the desk, head on the arms.")
for t, b in ((0.0, 0), (1.6, 1), (3.2, 0)):
    sit(sleep, t, "sine", waist=(-44 - b * 2, 0, 0), neck=(-30, 20, 12),
        rShoulder=(76, 0, -22), lShoulder=(76, 0, 22), rElbow=124, lElbow=124,
        rWrist=(0, 0, -20), lWrist=(0, 0, 20))

paper = clip("actNewspaper", 3.0, loop=True, note="Reading a newspaper held wide, seated.")
for t, turn in ((0.0, 0), (1.2, 6), (2.0, -4), (2.3, 10), (3.0, 0)):
    sit(paper, t, "sine", waist=(2, 0, 0), neck=(-8, turn, 0),
        rShoulder=(66 + (8 if t == 2.3 else 0), 0, -36), lShoulder=(66, 0, 36), rElbow=62, lElbow=62,
        rWrist=(0, 0, -10), lWrist=(0, 0, 10))

perch = clip("actCrouchSweets", 2.4, loop=True, note="Perched on the chair, knees up, thumb at the lip.")
crouch_legs = dict(rHip=(128, 0, -12), lHip=(128, 0, 12), rKnee=-148, lKnee=-148,
                   rAnkle=(24, 0, 0), lAnkle=(24, 0, 0))
for t, nod in ((0.0, 0), (1.0, 1), (1.6, 0), (2.4, 0)):
    joints = dict(crouch_legs, root=(-8, 0, 0), waist=(-18, 0, 0), neck=(4 - nod * 8, nod * 6, 0),
                  rShoulder=(84, 0, -8), rElbow=148, rWrist=(-20, 0, 0),
                  lShoulder=(58, 0, 18), lElbow=40, lWrist=(0, 0, 0))
    perch.pose(t, "sine", offset=on_floor(joints, (0, 0, 0.3), SEAT), **joints)

# Standing --------------------------------------------------------------------------------------------

read = clip("actReadFile", 3.2, loop=True, note="Reading an open case file held at the chest.")
hold_file = dict(rShoulder=(42, 0, -16), rElbow=82, rWrist=(-10, 0, 0),
                 lShoulder=(42, 0, 16), lElbow=82, lWrist=(-10, 0, 0))
stand(read, 0.0, "sine", waist=(-4, 0, 0), neck=(-26, 0, 0), **hold_file)
stand(read, 1.2, "sine", waist=(-4, 2, 0), neck=(-28, 6, 0), **hold_file)
stand(read, 2.0, "snap", waist=(-4, 2, 0), neck=(-26, 4, 0), **dict(hold_file, rShoulder=(48, 0, 22), rElbow=60))
stand(read, 2.4, "out", waist=(-4, 0, 0), neck=(-24, 0, 0), **hold_file)
stand(read, 3.2, "sine", waist=(-4, 0, 0), neck=(-26, 0, 0), **hold_file)

coffee = clip("actCoffee", 4.0, loop=True, note="Sipping coffee, the other hand in a pocket.")
cup_low = dict(rShoulder=(26, 0, -10), rElbow=100, rWrist=(-8, 0, 0))
cup_up = dict(rShoulder=(58, 0, -28), rElbow=146, rWrist=(-18, 0, 0))
pocket_l = dict(lShoulder=(-8, 0, -10), lElbow=34, lWrist=(-10, 0, 0))
stand(coffee, 0.0, "sine", neck=(-6, 0, 0), **cup_low, **pocket_l)
stand(coffee, 1.2, "out", neck=(-6, 8, 0), **cup_low, **pocket_l)
stand(coffee, 1.6, "overshoot", neck=(12, 0, 0), waist=(4, 0, 0), **cup_up, **pocket_l)
stand(coffee, 2.4, "hold", neck=(14, 0, 0), waist=(4, 0, 0), **cup_up, **pocket_l)
stand(coffee, 2.9, "in", neck=(-4, -6, 0), **cup_low, **pocket_l)
stand(coffee, 4.0, "sine", neck=(-6, 0, 0), **cup_low, **pocket_l)

phone = clip("actPhone", 3.0, loop=True, note="Scrolling a phone held low, head down.")
for t, thumb in ((0.0, 0), (0.5, 8), (0.8, 0), (1.6, 8), (1.9, 0), (3.0, 0)):
    stand(phone, t, "sine", neck=(-34, 0, 0), waist=(-4, 0, 0),
          rShoulder=(36, 0, -16), rElbow=112, rWrist=(-24, 0, thumb),
          lShoulder=(26, 0, 14), lElbow=96, lWrist=(-10, 0, 0))

lean = clip("actLeanWall", 4.0, loop=True, note="Leaning back on a wall, arms crossed.")
for t, b in ((0.0, 0), (2.0, 1), (4.0, 0)):
    stand(lean, t, "sine", offset=(0, -0.05, 0.28), root=(8, 0, 0), forward=(0.45, 0.2), stance=0.1,
          waist=(-4, 0, 0), neck=(-6 + b * 3, -12, 0), **CROSSED)

look = clip("actLookAround", 4.0, loop=True, note="Uneasy: hands in pockets, looking left and right.")
for t, yaw, shift in ((0.0, 0, 0), (0.8, 42, 0.06), (1.6, 42, 0.06), (2.2, -38, -0.06), (3.2, -38, -0.06),
                      (4.0, 0, 0)):
    stand(look, t, "smooth", offset=(shift, 0, 0), stance=0.15, waist=(0, yaw * 0.3, 0), neck=(-2, yaw * 0.7, 0),
          **POCKETS)

magnify = clip("actMagnify", 2.4, loop=True, note="Studying the board through a magnifier.")
for t, yaw in ((0.0, -10), (1.2, 10), (2.4, -10)):
    stand(magnify, t, "sine", offset=(0, -0.1, -0.08), waist=(-20, yaw * 0.5, 0), neck=(-8, yaw, 0),
          rShoulder=(76, 0, -12), rElbow=106, rWrist=(-10, 0, 0),
          lShoulder=(-40, 0, 12), lElbow=46, lWrist=(0, 0, -10))

stretch = clip("actStretch", 3.0, loop=True, note="A long stretch, arms up, then relaxed again.")
stand(stretch, 0.0, "sine", **hang())
stand(stretch, 0.8, "out", offset=(0, 0.06, 0), waist=(12, 0, 0), neck=(22, 0, 0),
      rShoulder=(170, 0, 18), lShoulder=(170, 0, -18), rElbow=10, lElbow=10)
stand(stretch, 1.6, "hold", offset=(0, 0.06, 0), waist=(14, 0, 4), neck=(24, 0, 0),
      rShoulder=(172, 0, 14), lShoulder=(172, 0, -14), rElbow=6, lElbow=6)
stand(stretch, 2.3, "in", waist=(0, 0, 0), neck=(-4, 0, 0), **hang())
stand(stretch, 3.0, "sine", **hang())

think = clip("actThink", 3.0, loop=True, note="Chin in hand, the other arm across the belly.")
for t, nod in ((0.0, 0), (1.0, 1), (1.5, 0), (3.0, 0)):
    stand(think, t, "sine", waist=(-2, -6, 0), neck=(-10 - nod * 6, -10, 6),
          rShoulder=(44, 0, -22), rElbow=140, rWrist=(-24, 0, 0),
          lShoulder=(20, 0, 30), lElbow=104, lWrist=(0, 0, 0))

window = clip("actWindow", 4.0, loop=True, note="Hands behind the back, looking out of a window.")
for t, yaw in ((0.0, 0), (2.0, 10), (4.0, 0)):
    stand(window, t, "sine", waist=(2, yaw * 0.3, 0), neck=(10, yaw, 0), **BEHIND)

cabinet = clip("actCabinet", 1.6, loop=True, note="Flicking through the files in an open drawer.")
for t, flick in ((0.0, 0), (0.2, 1), (0.4, 0), (0.6, 1), (0.8, 0), (1.2, 0), (1.4, 1), (1.6, 0)):
    stand(cabinet, t, "snap", offset=(0, -0.1, 0), waist=(-30, 0, 0), neck=(-12, 0, 0),
          rShoulder=(56 + flick * 8, 0, -8), rElbow=32, rWrist=(-flick * 30, 0, 0),
          lShoulder=(50, 0, 8), lElbow=30, lWrist=(0, 0, 0))

umbrella = clip("actUmbrella", 3.0, loop=True, note="Under an umbrella in the rain, shivering a little.")
for t, s in ((0.0, 0), (0.3, 1), (0.6, -1), (0.9, 0), (3.0, 0)):
    stand(umbrella, t, "sine", waist=(0, 0, s * 2), neck=(-6, 0, s * 2),
          rShoulder=(44, 0, -18), rElbow=96, rWrist=(-4, 0, 0), **pocket_l)

# Reactions (one-shots that hold the last pose) ------------------------------------------------------------

gasp = clip("reactGasp", 1.2, note="Hands fly to the face and the body jerks back a step.")
stand(gasp, 0.0, "smooth", **hang())
stand(gasp, 0.12, "snap", offset=(0, 0.05, 0.12), waist=(10, 0, 0), neck=(12, 0, 0),
      rShoulder=(100, 0, -26), lShoulder=(100, 0, 26), rElbow=136, lElbow=136, forward=(-0.25, 0))
stand(gasp, 1.2, "sine", offset=(0, 0, 0.18), waist=(6, 0, 0), neck=(4, 0, 0),
      rShoulder=(96, 0, -24), lShoulder=(96, 0, 24), rElbow=138, lElbow=138, forward=(-0.3, 0))

startle = clip("reactStartle", 0.9, note="A jolt: shoulders up, arms out, a hop.")
stand(startle, 0.0, "smooth", **hang())
startle.pose(0.12, "overshoot", offset=(0, 0.25, 0), rShoulder=(40, 0, 50), lShoulder=(40, 0, -50),
             rElbow=60, lElbow=60, neck=(10, 0, 0), waist=(8, 0, 0), rKnee=-10, lKnee=-10)
stand(startle, 0.9, "in", offset=(0, -0.08, 0), rShoulder=(20, 0, 30), lShoulder=(20, 0, -30),
      rElbow=50, lElbow=50, neck=(2, 0, 0), waist=(2, 0, 0))

hands_head = clip("reactHandsHead", 1.4, note="Both hands to the head in disbelief.")
stand(hands_head, 0.0, "smooth", **hang())
stand(hands_head, 0.25, "overshoot", waist=(-4, 0, 0), neck=(-8, 0, 0), rShoulder=(152, 0, -34),
      lShoulder=(152, 0, 34), rElbow=132, lElbow=132)
stand(hands_head, 1.4, "sine", waist=(-8, 0, 0), neck=(-18, 8, 0), rShoulder=(148, 0, -36),
      lShoulder=(148, 0, 36), rElbow=134, lElbow=134)

cover = clip("reactCoverMouth", 1.4, note="A hand over the mouth, the other arm hugging the body.")
stand(cover, 0.0, "smooth", **hang())
stand(cover, 0.3, "overshoot", waist=(-6, 0, 0), neck=(-16, 0, 0), rShoulder=(84, 0, -32), rElbow=150,
      rWrist=(-10, 0, 0), lShoulder=(24, 0, 34), lElbow=110)
stand(cover, 1.4, "sine", waist=(-10, 0, 0), neck=(-24, -6, 0), rShoulder=(82, 0, -30), rElbow=152,
      rWrist=(-10, 0, 0), lShoulder=(24, 0, 36), lElbow=112)

away = clip("reactLookAway", 1.2, note="Turns away and shields the eyes.")
stand(away, 0.0, "smooth", **hang())
stand(away, 0.3, "out", root=(0, 30, 0), waist=(-4, 30, 0), neck=(-14, 40, 0),
      lShoulder=(120, 0, 10), lElbow=120, lWrist=(0, 0, 10), rShoulder=(0, 0, 10), rElbow=20)
stand(away, 1.2, "sine", root=(0, 34, 0), waist=(-8, 32, 0), neck=(-20, 44, 0),
      lShoulder=(118, 0, 12), lElbow=122, rShoulder=(0, 0, 10), rElbow=20)

clap = clip("reactSlowClap", 1.0, loop=True, note="A slow, deliberate clap.")
stand(clap, 0.0, "sine", neck=(4, 0, 0), rShoulder=(56, 0, 20), lShoulder=(56, 0, -20), rElbow=84, lElbow=84)
stand(clap, 0.35, "in", neck=(4, 0, 0), rShoulder=(58, 0, -4), lShoulder=(58, 0, 4), rElbow=82, lElbow=82)
stand(clap, 1.0, "sine", neck=(4, 0, 0), rShoulder=(56, 0, 20), lShoulder=(56, 0, -20), rElbow=84, lElbow=84)

shrug = clip("reactShrug", 1.2, note="Palms up, a shrug.")
stand(shrug, 0.0, "smooth", **hang())
stand(shrug, 0.3, "overshoot", offset=(0, 0.03, 0), neck=(4, 0, 14), waist=(0, 0, 4),
      rShoulder=(26, 0, 30), lShoulder=(26, 0, -30), rElbow=86, lElbow=86, rWrist=(0, 0, 30), lWrist=(0, 0, -30))
stand(shrug, 1.2, "sine", neck=(0, 0, 10), waist=(0, 0, 3), rShoulder=(22, 0, 26), lShoulder=(22, 0, -26),
      rElbow=84, lElbow=84, rWrist=(0, 0, 26), lWrist=(0, 0, -26))

facepalm = clip("reactFacepalm", 1.6, note="A hand slaps the forehead, the head sags.")
stand(facepalm, 0.0, "smooth", **hang())
stand(facepalm, 0.25, "snap", waist=(-6, 0, 0), neck=(-12, 0, 0), rShoulder=(112, 0, -22), rElbow=148,
      rWrist=(-20, 0, 0), lShoulder=(-2, 0, -6), lElbow=20)
stand(facepalm, 1.6, "sine", waist=(-10, 0, 0), neck=(-26, 0, 10), rShoulder=(106, 0, -20), rElbow=150,
      rWrist=(-20, 0, 0), lShoulder=(-2, 0, -6), lElbow=20)

# Role reveals -----------------------------------------------------------------------------------------

book = clip("revealOpen", 2.4, note="Finds the book in both hands, opens it, and looks up with a grin.")
closed = dict(rShoulder=(40, 0, -14), lShoulder=(40, 0, 14), rElbow=90, lElbow=90)
opened = dict(rShoulder=(44, 0, -30), lShoulder=(44, 0, 30), rElbow=84, lElbow=84,
              rWrist=(0, 0, -20), lWrist=(0, 0, 20))
stand(book, 0.0, "sine", neck=(-30, 0, 0), waist=(-6, 0, 0), **closed)
stand(book, 0.8, "overshoot", neck=(-34, 0, 0), waist=(-8, 0, 0), **opened)
stand(book, 1.5, "hold", neck=(-36, 6, 0), waist=(-8, 0, 0), **opened)
stand(book, 2.0, "out", offset=(0, 0.03, 0), neck=(18, 0, -8), waist=(8, 0, 0), **opened)
stand(book, 2.4, "sine", offset=(0, 0.02, 0), neck=(20, 0, -10), waist=(10, 0, 0), **opened)

pray_offset = (0, -0.68, 0.05)
both_knees = kneeling_leg(1, pray_offset, (0, 0, 0))[0] | kneeling_leg(-1, pray_offset, (0, 0, 0))[0]
pray = clip("revealPray", 2.4, loop=True, note="Kneeling, hands pressed together, head bowed.")
for t, bow in ((0.0, 0), (1.2, 1), (2.4, 0)):
    pray.pose(t, "sine", offset=pray_offset, root=(0, 0, 0), waist=(-10 - bow * 4, 0, 0), neck=(-34 - bow * 6, 0, 0),
              rShoulder=(56, 0, -36), lShoulder=(56, 0, 36), rElbow=112, lElbow=112,
              rWrist=(0, 0, -20), lWrist=(0, 0, 20), **both_knees)

badge = clip("revealBadge", 1.4, note="Flips an ID badge up to show it, chin raised.")
stand(badge, 0.0, "smooth", **hang())
stand(badge, 0.2, "out", rShoulder=(20, 0, -10), rElbow=100, rWrist=(-30, 0, 0), neck=(-6, 0, 0))
stand(badge, 0.4, "overshoot", rShoulder=(84, 0, -18), rElbow=88, rWrist=(10, 0, 0), neck=(6, 0, 0), waist=(2, 0, 0),
      lShoulder=(-6, 0, -10), lElbow=24)
stand(badge, 1.4, "sine", rShoulder=(82, 0, -18), rElbow=90, rWrist=(10, 0, 0), neck=(8, 0, 0), waist=(2, 0, 0),
      lShoulder=(-6, 0, -10), lElbow=24)

tip = clip("revealTip", 2.0, note="A polite bow with a hand to the brim of the hat.")
umbrella_l = dict(lShoulder=(40, 0, 18), lElbow=96, lWrist=(-4, 0, 0))
stand(tip, 0.0, "smooth", rShoulder=(-4, 0, 4), rElbow=18, **umbrella_l)
stand(tip, 0.4, "overshoot", rShoulder=(140, 0, -30), rElbow=150, rWrist=(-10, 0, 0), neck=(-4, 0, 0),
      **umbrella_l)
stand(tip, 1.0, "in", offset=(0, -0.04, 0.1), waist=(-24, 0, 0), neck=(-14, 0, 0), rShoulder=(130, 0, -28),
      rElbow=150, forward=(0.2, 0), **umbrella_l)
stand(tip, 2.0, "sine", waist=(0, 0, 0), neck=(4, 0, 0), rShoulder=(-4, 0, 4), rElbow=18, **umbrella_l)

# Endings --------------------------------------------------------------------------------------------

smug = clip("victoryCross", 2.0, loop=True, note="Arms crossed, chin up: a quiet, smug win.")
for t, b in ((0.0, 0), (1.0, 1), (2.0, 0)):
    stand(smug, t, "sine", stance=0.12, waist=(4, -8, 0), neck=(12 + b * 2, 14, -4), **CROSSED)

slumped = (0, -0.68, 0.05)
knees = kneeling_leg(1, slumped, (0, 0, 0))[0] | kneeling_leg(-1, slumped, (0, 0, 0))[0]
beaten = clip("defeatFloor", 1.6, note="Drops to both knees, fists on the thighs, head hanging.")
stand(beaten, 0.0, "smooth", **hang())
stand(beaten, 0.3, "in", offset=(0, -0.3, 0.02), neck=(-20, 0, 0), waist=(-10, 0, 0), **hang())
beaten.pose(0.8, "bounce", offset=slumped, root=(0, 0, 0), waist=(-18, 0, 0), neck=(-40, 0, 0),
            rShoulder=(20, 0, -8), lShoulder=(20, 0, 8), rElbow=40, lElbow=40, **knees)
beaten.pose(1.6, "sine", offset=slumped, root=(0, 0, 0), waist=(-22, 0, 0), neck=(-48, 0, 0),
            rShoulder=(22, 0, -8), lShoulder=(22, 0, 8), rElbow=44, lElbow=44, **knees)
