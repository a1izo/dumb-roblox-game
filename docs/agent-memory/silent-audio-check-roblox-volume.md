---
name: silent-audio-check-roblox-volume
description: "When the game seems silent, check Roblox's own Esc-menu volume before the code"
metadata:
  node_type: memory
  type: reference
  originSessionId: 56c4afb0-d6ce-494a-831b-30a81e6f83a1
  modified: 2026-10-18T13:14:50.457Z
---

On 2026-10-18 "all sound is gone" turned out to be Roblox's own Esc > Settings > Volume at 1/10. It is stored as MasterVolume in %LOCALAPPDATA%\Roblox\GlobalBasicSettings_13.xml (Player) and GlobalBasicSettings_13_Studio.xml (Studio play tests). The code and the audio ids were fine (AudioCheck 32/32).

**How to apply:** read MasterVolume in those files first. To prove where it goes quiet, compare Sound.PlaybackLoudness from the command bar during a play test with the Windows per-app peak meter. Related: [[map-remake-project]]
