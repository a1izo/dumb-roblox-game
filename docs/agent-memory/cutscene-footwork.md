---
name: cutscene-footwork
description: Since 2026-11-07 a cutscene actor's feet are planned from its whole path (art/scripts/cinema/footwork.py, footwork.apply at the end of every shot module): soles never slide, starts, stops, step-backs and turns are steps; how it works, what it costs, and the check that found the skating
metadata:
  type: project
---

Asked 2026-11-07 ("make all the cutscenes and animations 100x better ... so that movements dont look stiff and ai
made"). A sole check over every shot (scratch skate.py: the middle of a leg's bottom face on the floor and moving along
it) measured 258 studs of sliding: every walk's start and end (acting.walking ran its cycle on the clock while the path
eased in and out), people moved one or two studs with standing legs (the Operative's step back from the lockers, the
HQ replay figure's step off the counter), turns on the spot pivoting on flat soles, the meeting intro's walkers on a
walk of 4 studs a second moving at 5, and two of them spinning 270 degrees the long way round (yaw keys either side of
180). After: 0 everywhere, but for the Tokyo victim's knees folding (eased over 0.15 s) and the train rider (carried).

- **cinema/footwork.py**: `footwork.apply(shot)` after a module's marks (before a Retime). Every actor whose own clip
  has plant windows or acting.walking windows gets a Plan: feet fixed in the set; a foot lifts when its spot under the
  hip a step's time ahead is too far off (0.38 standing, a walk's measure at speed) or turned more than 24 degrees; it
  lands where the body will be `lead` seconds after landing (half a stance's time on a walk), read off the path (never
  past where the body stops); steps sized by the speed the body reaches in the next 0.6 s (a walk's first step is a
  walk's step), never faster than 1.3x the gait's own swing, at most 1.25 strides; feet take turns; a body moving when
  the plan takes over starts mid-stride; once still for 0.3 s a sole 0.16 off its spot steps home. Steady walks match
  gait.WALK (cadence, stride, lift); legs lean to a sole well off the hip instead of sliding out of it; the body bobs;
  on a walk the arms swing from the feet as they are (walking's `arms` scales it; walking's own legs and swing give
  way). `carried={slot: [(t0, t1)]}` keeps feet on a moving floor (IntroTokyo's car). Where it adds nothing (sole on
  its spot, nothing stepping, no walk) the clip's own planted legs stand, so still bystanders keep one key.
- **cinema/shot.py Track.key** turns a heading the short way to the next key (a half turn exactly goes as keyed).
- **Cost**: about 11 s of the 70 s it takes to import the shots. Acting sizes after: IntroTokyo 172k, IntroAgency
  164k, MeetingIntro 123k (Roblox's limit is about 200k): solving still legs against alive()'s sway took IntroTokyo
  to 234k before the "adds nothing" rule.

**Why:** foot skating is the plainest tell of fake motion; the user asked for movement that does not look stiff or
made by a machine.
**How to apply:** after changing any path or walk, rebuild the shot's clips (`run_anims.py -- --add <clips>`; every
planned clip changes) and check the acting file sizes; keep footwork.apply the last thing before cameras that aim at
bodies (framing.part) so they aim at the planned body. Two walkers in single file need about 4.5 studs between them at
a hurried walk's stride. Related: [[cutscene-life-layer]], [[cutscene-pipeline]].
