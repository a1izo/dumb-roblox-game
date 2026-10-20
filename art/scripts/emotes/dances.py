"""Looping dances, each copied from its reference (art/refs/emotes/<clip>.toml): the source, the segment
copied, its tempo and the beats the keys below land on.

Dances keep time with one another in the game (a loop starts on the server's beat), and each loop is a whole
number of beats of its own song's tempo, so the owner can put the right music under it.
"""

from emotes import mocap
from emotes.kit import Clock, beats
from motion import Motion

# Bye Bye Bye (clip puppetPop, item emote_puppet_pop) ------------------------------------------------------
# The chorus routine of the 2000 music video (choreography by Darrin Henson), as the 2024 trend dances it:
# "hey" arm flicks, the arms crossed at the face and flung open, the head tilt, the hands pulled to the chest
# and pushed out palms first (bye, bye, bye) and spread wide, then hands on the hips with knee pops and a
# look over the shoulder, the wide-stance bounce, and the swing up to the raised fist with stomping knees.
# Motion-captured (2026-10-17, owner's note: real weight, fluid legs, arms not pulled in) from the mirrored
# front-facing breakdown (refs: puppetPop.toml, mocap/puppetPop.json), 4.00-10.94 s at 15 frames a second,
# 173 bpm: 20 beats of the routine, then two beats easing home into the first pose.
B = beats(173)
clock = Clock(4.0, 173)
at = clock.at
bye = Motion("puppetPop", 22 * B, loop=True, note="Bye Bye Bye: the chorus routine (arm flicks, palms out, hips, the fist).", unwrap=True)
mocap.capture(bye, "puppetPop", clock.start, 0.0, at(4.0 + 20 * B))
bye.build()

# The Classic (clip theClassic, item emote_the_classic) ---------------------------------------------------------
# Fortnite's Default Dance, the game's own animation filmed on green screen (refs: theClassic.toml,
# mocap/theClassic.json, 10 frames a second over 0-7.2 s): the arms pumping across the body by turns as the feet
# step, the elbows rolling, the hands thrown up by the head, the arms swinging down and back, the hand on the hip
# with the thumb out, a point. The whole routine (0.3-5.6 s, up to the point; after it the arms fold back across
# the chest, the game's outro) at 100 bpm, then 0.7 s easing home into its first pose.
clock = Clock(0.3, 100)
at = clock.at
classic = Motion("theClassic", 10 * beats(100), loop=True, note="Fortnite's Default Dance: the pumping arms, the "
                 "rolls, the hands up, the swing, the thumb.", unwrap=True, floor=True)
mocap.capture(classic, "theClassic", clock.start, 0.0, at(5.6))
classic.build()

# Take the L (clip takeTheL, item emote_take_the_l) ---------------------------------------------------------
# Fortnite's Take the L, the game's own animation filmed on green screen (refs: takeTheL.toml, mocap/takeTheL.json,
# 10 frames a second over 0-2.4 s): the right hand up at the forehead in an L the whole time, hopping from foot
# to foot, the free leg kicked out to the side on every other hop. Its cycle is 0.8 s (a kick each way), and it
# loops as the game's does: two cycles, 4 beats at 150 bpm, the last frame flowing back into the first.
take_l = Motion("takeTheL", 4 * beats(150), loop=True, note="Fortnite's Take the L: the L at the forehead, hopping "
                "foot to foot, kicking out.", unwrap=True, floor=True)
mocap.capture(take_l, "takeTheL", 0.0, 0.0, 1.5)
take_l.build()
