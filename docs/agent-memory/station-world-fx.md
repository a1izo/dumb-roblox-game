---
name: station-world-fx
description: "What the room sees at a case-file station (screens, light, sounds, acting) is client-side and driven only by public desk attributes, so a hack looks like work"
metadata:
  type: project
---

Since 2026-11-01 a station's in-world feel lives on the client:
- **World/StationFx** draws every LStationScreen's glass (idle Standby, and per type: CCTV feeds, a print scan,
  a call log, a scope and spectrum), a SurfaceLight, and the work's quiet sounds from existing Sfx keys. It hides
  the server's SurfaceGui locally (the Builder label is only a fallback). It is started from InteractionController.init.
- **Anim/WorkActing** acts the worker: the type's Blender clip (work<Type>) underneath, spring-eased beats on top
  (lean in, sit back, glance, nod), root turns taken back at the hips. The local body also steps up and squares to
  the desk (LWorkingAt).
- The server's CaseFileService.setScreen sets desk Busy + BusySince, and markWorking sets LWorking + LWorkingAt.
  HackService goes through the same calls.

**Why:** the owner found the stations low quality, and a hack must stay impossible to tell from real work.
**How to apply:** never feed the screen or acting anything from the puzzle, the worker's role or progress, and
never show a "done" or "match" state (a hack never finishes a case file, so that would give it away). Seed only from
StationId and BusySince.
