---
name: debug-cutscene-gallery
description: The debug panel's cutscene gallery (Show tab, 2026-11-08): every shop cutscene playable anywhere, the lobby too; and the hooks a harness probe uses to drive the panel
---

Asked 2026-11-08: "a button to see all cutscenes in the debug menu even if you're in lobby". The Show tab (F2) opens
with a **Cutscene gallery**: Play all, The 8 new deaths, Stop, and a button per scene grouped as custom deaths, death
styles, win cutscenes and others (the grave). It plays what the shop's Preview plays (`WinCinema.preview`), on this
screen only, so it needs no match; the panel hides while a run plays and comes back when it ends or is stopped (F2
reopens it mid-run). The match cutscenes (intro, verdict, arrest, outro, the Blender shots) still need a running match:
they are server cues.

`WinCinema.preview` now returns whether it started, `WinCinema.stopPreview()` stops it without going on into the
scene after it (the grave after "A true patriot"), and a grave previewed on its own has someone else saluting with
the player's name on the stone.

Harness hooks (nothing can click in a play test): `DebugPanel.openTab(name)`, `DebugPanel.gallery` (list / play /
stop / new), `DebugPanel.shown()`. The Gallery probe in the scratchpad harness uses them.
