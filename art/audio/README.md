# Lobby audio (the Grey Realm and its mini-games)

Synthesised by `art/scripts/audio/make_realm_audio.py` (run with Blender's Python; see the script's
header). Nothing here is recorded: wind, drones and rumble are shaped noise and low sine stacks, the
knocks and creaks are damped partials and a little reverb. They are plain placeholders that sound like
the brief (quiet, distant, uneasy); replace any of them with something better and keep the slot.

Upload each file (Studio: View > Asset Manager > Audio > Bulk Import, or the Creator Hub), then put the
numeric id in `src/shared/Assets.luau`, in the `Assets.sfx` slot named below. A slot with no id plays
nothing, so you can fill them in any order.

| File | Slot | What it is | Loops |
| --- | --- | --- | --- |
| `realm_wind.wav` | `realmWind` | low distant wind, slowly swelling | yes (32 s) |
| `realm_drone.wav` | `realmDrone` | very quiet low drone | yes (24 s) |
| `realm_rumble.wav` | `realmRumble` | sub-bass rumble far below | yes (20 s) |
| `realm_rocks.wav` | `realmRocks` | wind whistling through rocks (the two vistas) | yes (20 s) |
| `realm_stone1.wav` | `realmStone1` | a distant stone knock | no |
| `realm_stone2.wav` | `realmStone2` | scree sliding far off | no |
| `realm_metal1.wav` | `realmMetal1` | a faint metallic creak | no |
| `realm_metal2.wav` | `realmMetal2` | a far hollow metallic tone | no |
| `realm_far1.wav` | `realmFar1` | a barely heard whisper | no |
| `realm_far2.wav` | `realmFar2` | a distant unplaceable breath | no |
| `game_rune.wav` | `gameRune` | a glassy tone (played at different pitches for the tiles) | no |
| `game_wrong.wav` | `gameWrong` | a dull stone thud | no |
| `game_checkpoint.wav` | `gameCheckpoint` | a pale bell | no |
| `game_finish.wav` | `gameFinish` | two rising bells | no |
| `game_dice.wav` | `gameDice` | bone dice thrown on stone | no |
| `game_throw.wav` | `gameThrow` | a pebble thrown | no |
| `game_fall.wav` | `gameFall` | a pebble knocking down a very long fall | no |

The beds are meant to be heard only just: their levels are the slot's `volume` in `Assets.sfx` times
the Ambience slider (and the player's own setting). The lobby music is ducked to about a third while the
realm plays (`Mixer.duck("realm")`). All of this is tuned in `src/client/Audio/RealmAmbience.luau`
(`TUNING`), including how often a one-shot comes (every 25 to 70 seconds, from 80 to 220 studs away).
