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
