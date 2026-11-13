---
name: studio-frame-rate-measure
description: "Frame rate through the Studio MCP: a Studio parked off screen runs at ~15 fps, so measure with it foreground, activated right before each 2 s count"
metadata:
  type: reference
---

2026-11-13. `RenderStepped` counted over 2 s: 14.9 fps with the place's Studio parked off screen (-1960, 0), 60 fps with
it on screen and activated. The foreground is lost again after about 8 s (something else takes focus), after which it
reads 15 again, so one measurement per call: a PowerShell call that runs
`(New-Object -ComObject WScript.Shell).AppActivate(<studio pid>)` and sleeps 600 ms, then the execute_luau that sets the
state, waits 1 s and counts for 2 s. Park it again afterwards (scratch script: SetWindowPlacement showCmd 4, then
SetWindowPos to (-1960, 0)). A number of exactly 60 means "at the cap", not the cost; compare 15 against 60 only
when the window had focus the whole count.

Also: the first `screen_capture` after a change often times out; wait 3 s inside the execute_luau and capture once.
Related: [[studio-mcp]], [[studio-no-screen]].
