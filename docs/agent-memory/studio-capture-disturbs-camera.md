---
name: studio-capture-disturbs-camera
description: In a Studio play test a screen_capture seems to pull a scripted camera back toward the player's own camera right after the still (4 of 4 runs); log numbers in runs without a capture (2026-11-14)
---

Watching the Luau match scenes through the Studio MCP (2026-11-14), every run that included a `screen_capture` showed,
in the camera log taken at 0.1 s steps, the camera position jumping back to within a stud or two of the player's own
camera at the capture (the fov creep carried on, the position did not), so a measurement read after a still is
nonsense (a head 43 studs away, a pillar in front of the target). Every run without a still (about eight) was clean.
The still itself is true at the instant it was taken (except once, when it was already the pulled-back view). Cause not
found; it looks like the capture tool resetting the camera type or CFrame.

**Why it matters:** a log and a still taken in the same run disagree, and one of them looks like a game fault.
**How to apply:** take numbers in runs with no capture and stills in separate runs (one still per run); do not read the
camera after a capture; and do not call a pulled-back camera a fault in the scene until it shows in a run with no still.
Related: [[studio-mcp-play-test-traps]].
