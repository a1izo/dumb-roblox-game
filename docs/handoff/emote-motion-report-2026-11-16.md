# Emote motion report, 2026-11-16

Stage 4 of the animation plan (docs/handoff/animation-cutscene-plan-2026-11-13.md): every emote clip in the game through the motion report (`art/scripts/check_motion.py --emotes`, Tool 1), run on the committed clips after Parade March and Not My Problem were removed and Griddy was rebuilt (main 1fd1b3e0 and later). Read-only: no clip was changed by this pass except Griddy (its own commit).

**68 emote clips measured: 61 PASS, 7 FAIL.** Run line (Blender's Python, numpy only):

```
"C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/check_motion.py --emotes --detail --table --json out.json
```

What it measures and what it does not: the standing clip of each emote only (a stroll's walk cycle, a duo's partner clip and the press-to-do branches such as menacingPose2 to 6, chipEat or coinFlipAgain are not in the list). It is a floor: PASS says no dead limb over 8 s, torso over 4 percent of the motion, no repeats on one timing, and so on (see docs/agent-memory/motion-report.md). It cannot see a missing prop, a hand off its target or a pose that reads as nothing; for that the failing clips were also looked at by eye, on the sheets listed below.

Columns: tier = shop rarity (free for the eleven everyone has); torso = the torso's share of the motion (limit 4 percent); dead limb = the longest one joint stays still (limit 8 s); frozen = the longest the whole body is still.

## Everyone's (free) (11: 10 pass, 1 fail)

| clip | tier | length s | verdict | failing | torso | dead limb s | frozen s |
|---|---|---|---|---|---|---|---|
| bow | free | 2.6 | PASS |  | 50% | 0.7 lShoul | 0.2 |
| cheer | free | 2.2 | PASS |  | 10% | 0.3 root | 0.0 |
| dance | free | 1.6 | PASS |  | 12% | 0.9 root | 0.0 |
| facepalm | free | 2.4 | PASS |  | 7% | 0.9 rShoul | 0.1 |
| handshake | free | 2.4 | PASS |  | 9% | 1.8 lShoul | 0.1 |
| highFive | free | 2.0 | PASS |  | 9% | 0.6 root | 0.1 |
| laugh | free | 1.2 | PASS |  | 19% | 0.2 root | 0.0 |
| point | free | 1.6 | PASS |  | 13% | 0.4 root | 0.1 |
| salute | free | 2.0 | PASS |  | 11% | 0.3 neck | 0.1 |
| shrug | free | 2.0 | PASS |  | 19% | 0.3 root | 0.1 |
| wave | free | 2.4 | FAIL | torso | 2% | 1.9 neck | 0.0 |

Failing, with the reason the report gives and the eye's call:

- **wave**: torso: the torso is 2% of the motion (18 of 803 degrees; limit 4%): only the limbs act **fine as is.** a classic /e copy; its length is frozen, only the arm moves by design.

## Poses (19: 17 pass, 2 fail)

| clip | tier | length s | verdict | failing | torso | dead limb s | frozen s |
|---|---|---|---|---|---|---|---|
| aceCrouch | Sealed | 4.0 | PASS |  | 40% | 0.6 rShoul | 0.2 |
| chip | Scrawl | 3.4 | PASS |  | 11% | 3.4 lShoul | 0.7 |
| deducing | Penned | 4.0 | PASS |  | 22% | 4.0 lShoul | 0.5 |
| finalBreakdown | Godhood | 5.4 | FAIL | same; metronome | 20% | 1.0 rShoul | 0.1 |
| footScratch | Scrawl | 2.0 | PASS |  | 57% | 2.0 rShoul | 0.3 |
| hairTwirl | Scrawl | 2.4 | PASS |  | 55% | 2.4 rShoul | 0.3 |
| impossibleLean | Penned | 4.2 | PASS |  | 35% | 3.1 lShoul | 0.6 |
| itsYou | Penned | 2.6 | PASS |  | 11% | 1.7 root | 0.8 |
| jawlineCheck | Scrawl | 3.2 | PASS |  | 5% | 2.7 lShoul | 0.0 |
| justAsPlanned | Godhood | 9.2 | FAIL | anticipation | 14% | 1.6 lShoul | 0.5 |
| lowBattery | Penned | 4.6 | PASS |  | 41% | 1.2 rShoul | 0.4 |
| menacingPose | Sealed | 4.0 | PASS |  | 38% | 4.0 rShoul | 0.8 |
| nahIdWin | Scrawl | 4.0 | PASS |  | 49% | 4.0 rShoul | 0.3 |
| newWorld | Godhood | 6.5 | PASS |  | 6% | 2.2 root | 1.1 |
| reapersCackle | Penned | 1.6 | PASS |  | 16% | 0.1 root | 0.0 |
| reapersEyes | Godhood | 3.2 | PASS |  | 6% | 2.9 lShoul | 0.0 |
| theEyebrow | Scrawl | 3.4 | PASS |  | 16% | 2.6 rShoul | 0.3 |
| think | Scrawl | 4.0 | PASS |  | 29% | 4.0 lShoul | 0.7 |
| writeAir | Sealed | 3.0 | PASS |  | 17% | 2.6 lShoul | 0.1 |

Failing, with the reason the report gives and the eye's call:

- **finalBreakdown**: same: 10 of 13 rShoulder moves take 0.12 s: the same timing every time / metronome: rShoulder makes 5 moves of 8 degrees every 0.24 s (2.4 to 3.5) **fine as is.** a private cutscene emote; the arm poses read clearly (arms crossed, T, hands to head); the repeats are the story's beats.
- **justAsPlanned**: anticipation: 0 of 10 big moves are drawn back first (limit 15%) / no wind-up before: neck 1.42-2.30, neck 2.48-3.58, rShoulder 2.48-3.12, rShoulder 3.25-3.60, neck 4.63-5.23, rShoulder 4.68-6.27, lShoulder 4.68-6.27, rShoulder 6.27-7.12 ... **fine as is.** a Godhood private cutscene; the open-arm spread reads; it only lacks a wind-up before the spread.

## Dances (19: 18 pass, 1 fail)

| clip | tier | length s | verdict | failing | torso | dead limb s | frozen s |
|---|---|---|---|---|---|---|---|
| animatronicWelcome | Penned | 9.6 | PASS |  | 9% | 4.2 lShoul | 0.6 |
| boatAura | Penned | 6.4 | PASS |  | 6% | 1.2 neck | 0.4 |
| bouncePump | Scrawl | 6.5 | PASS |  | 22% | 0.1 neck | 0.0 |
| bunnyEars | Penned | 1.5 | PASS |  | 20% | 0.1 root | 0.0 |
| dance2 | Scrawl | 2.2 | PASS |  | 12% | 0.6 neck | 0.0 |
| dance3 | Scrawl | 1.6 | PASS |  | 46% | 0.8 rShoul | 0.0 |
| excuseMeSir | Penned | 1.6 | PASS |  | 27% | 0.2 root | 0.0 |
| glitchStep | Penned | 2.4 | PASS |  | 13% | 0.4 root | 0.4 |
| goalCelebration | Penned | 3.0 | PASS |  | 28% | 0.9 root | 0.4 |
| jackpotShuffle | Penned | 2.8 | PASS |  | 33% | 0.2 root | 0.1 |
| officeParty | Penned | 6.4 | PASS |  | 27% | 0.1 root | 0.0 |
| puppetDance | Penned | 2.0 | PASS |  | 9% | 0.3 rShoul | 0.1 |
| puppetPop | Penned | 7.6 | PASS |  | 23% | 0.1 neck | 0.0 |
| ratDance | Penned | 1.1 | PASS |  | 17% | 0.1 root | 0.0 |
| smilingLord | Penned | 4.8 | PASS |  | 36% | 0.9 lShoul | 0.3 |
| takeTheL | Scrawl | 1.6 | PASS |  | 25% | 0.1 lShoul | 0.0 |
| theClassic | Scrawl | 6.0 | PASS |  | 14% | 0.1 rShoul | 0.0 |
| twoLeggedBop | Penned | 2.4 | PASS |  | 23% | 0.1 root | 0.0 |
| twoWeeksNotice | Scrawl | 3.2 | FAIL | same | 9% | 0.3 lShoul | 0.2 |

Failing, with the reason the report gives and the eye's call:

- **twoWeeksNotice**: same: 7 of 10 root moves take 0.18 s: the same timing every time **fine as is.** busy, reads (arms out, wave, shrug); the root moves repeat one timing, small.

## Strolls (3: 2 pass, 1 fail)

| clip | tier | length s | verdict | failing | torso | dead limb s | frozen s |
|---|---|---|---|---|---|---|---|
| griddy | Condemned | 2.0 | PASS |  | 14% | 0.2 root | 0.0 |
| mushroomStroll | Condemned | 3.0 | PASS |  | 22% | 3.0 rShoul | 0.4 |
| theLongClimb | Condemned | 1.8 | FAIL | torso | 3% | 1.8 root | 0.1 |

Failing, with the reason the report gives and the eye's call:

- **theLongClimb**: torso: the torso is 3% of the motion (14 of 403 degrees; limit 4%): only the limbs act **redo (low).** the standing loop keeps the torso still (3 percent); the walk cycle players see is the game's own and is not in this report. If redone: lean and rise with each knee.

## Duos (2: 2 pass, 0 fail)

| clip | tier | length s | verdict | failing | torso | dead limb s | frozen s |
|---|---|---|---|---|---|---|---|
| cuffedLead | Condemned | 2.0 | PASS |  | 0% | 2.0 root | 0.6 |
| matchPointServe | Condemned | 0.8 | PASS |  | 74% | 0.8 rShoul | 0.0 |

## Prop emotes (14: 12 pass, 2 fail)

| clip | tier | length s | verdict | failing | torso | dead limb s | frozen s |
|---|---|---|---|---|---|---|---|
| appleBite | Penned | 2.8 | PASS |  | 17% | 1.1 rShoul | 0.1 |
| appleToss | Penned | 3.6 | PASS |  | 11% | 3.2 lShoul | 0.3 |
| blindfoldLift | Sealed | 4.0 | PASS |  | 48% | 4.0 rShoul | 0.2 |
| chairPerch | Sealed | 4.0 | PASS |  | 59% | 4.0 rShoul | 0.3 |
| chipAndPen | Sealed | 10.4 | PASS |  | 14% | 4.5 lShoul | 0.3 |
| chocolateSnap | Penned | 3.2 | PASS |  | 12% | 2.9 lShoul | 0.1 |
| coinFlip | Scrawl | 3.0 | PASS |  | 12% | 1.1 lShoul | 0.2 |
| diceTower | Sealed | 6.0 | FAIL | metronome; anticipation | 20% | 6.0 lShoul | 0.3 |
| fortySeconds | Penned | 4.6 | PASS |  | 7% | 4.2 rShoul | 0.3 |
| furiousScribbling | Penned | 2.4 | PASS |  | 17% | 2.4 lShoul | 0.0 |
| preDawnBonk | Sealed | 3.6 | FAIL | same; anticipation | 12% | 0.3 neck | 0.1 |
| strawberryOnTop | Sealed | 4.0 | PASS |  | 10% | 4.0 lShoul | 0.2 |
| sugarTower | Sealed | 6.0 | PASS |  | 20% | 6.0 lShoul | 0.1 |
| twoFingerGrip | Penned | 3.0 | PASS |  | 45% | 3.0 lShoul | 0.3 |

Failing, with the reason the report gives and the eye's call:

- **diceTower**: metronome: root makes 5 moves of 11 degrees every 0.71 s (0.4 to 3.7) / anticipation: 1 of 12 big moves are drawn back first (limit 15%) / no wind-up before: rShoulder 0.93-1.20, rShoulder 1.20-1.63, rShoulder 1.63-1.90, rShoulder 1.90-2.33, rShoulder 2.33-2.60, rShoulder 2.60-3.03, rShoulder 3.03-3.37, rShoulder 3.37-3.77 ... **redo (low).** seated on the floor with the left arm dead for the whole 6 s and five repeats of the same stack beat; reads as one arm working, which is the idea, but the repeats are a metronome.
- **preDawnBonk**: same: 6 of 9 rShoulder moves take 0.25 s: the same timing every time / anticipation: 1 of 9 big moves are drawn back first (limit 15%) / no wind-up before: rShoulder 0.00-0.53, rShoulder 0.53-0.77, rShoulder 0.77-1.03, rShoulder 1.03-1.27, rShoulder 1.27-1.53, rShoulder 1.53-1.77, rShoulder 1.77-2.30, rShoulder 3.13-3.60 **redo (low).** the bonk reads but the swings share one timing (the same 0.18 s); vary them and add a wind-up.

## The eye on the failing clips

Sheets: 12 frames over each clip, 35 degrees round, rendered by `review_anims.py` (kept off the repo): `diceTower`, `finalBreakdown`, `justAsPlanned`, `preDawnBonk` in one sheet and `theLongClimb`, `twoWeeksNotice`, `wave` in another. Looked at 2026-11-16 by the agent that wrote this; the owner has not seen them.

None of the seven looks wrong in the way the cutscenes did (a dead body with one arm moving). Every one reads as a pose or gesture from its frames: the dice tower sits on the floor and stacks, the final breakdown goes through crossed arms, a T and hands to the head, Just As Planned opens the arms into a spread, the bonk raises and swings an arm, the notice goes arms out then a wave, the wave is a wave. The report fails them on repeats, a missing wind-up or a still torso, which a viewer feels as small stiffness, not as a broken pose.

## Redo list, ranked

Nothing here is urgent and nothing was redone in this pass. If the owner wants any, in this order:

1. **theLongClimb** (Condemned, stroll): the torso is 3 percent of the motion; the standing loop is all limbs. It is also the stroll with the most going on (escalator, grin, rain), so the body under it should act. The Walk cycle (the one seen while strolling) was not measured.
2. **diceTower** (prop): left arm dead for the whole clip and five repeats on one rhythm; a one-armed stacker reads as a mannequin over six seconds.
3. **preDawnBonk** (prop): the swings share one timing and have no wind-up.
4. **twoWeeksNotice** (Scrawl dance): small timing repeats, reads fine. **justAsPlanned** (Godhood, a cutscene): a missing wind-up before its spread; fix only together with its cutscene.
5. **finalBreakdown** (Godhood): repeats are the beats of its story; fine.
6. **wave**: leave it (a classic emote, length frozen).

Passing clips nearest a limit, worth a glance if the owner says an emote feels stiff: `theLongClimb` aside, see the torso and dead-limb columns above (a seated or held pose such as chairPerch, think, twoFingerGrip and blindfoldLift passes with a dead limb because it is held on purpose).

## What was not checked

- Nothing in the game: no emote was played in Studio; no stroll was watched walking.
- Strolls' Walk cycles, duo partner clips and press-to-do branches are outside the list.
- Props, effects, sound and camera of each emote (they are measured by other checks, `check_props.py`, not here).
