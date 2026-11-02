---
name: props-blend-can-be-stale
description: art/blend/Props.blend may lag the builders, and a --export writes the whole catalog from it, so an export can undo someone's prop change
metadata:
  type: project
---

`run_props.py -- --export` rebuilds nothing, and writes all of `src/shared/ModelCatalog.luau` from the objects in
`art/blend/Props.blend`. A commit can change a builder and the catalog without committing the blend (Props.blend is big
and binary, so it often stays out). Exporting on top of that puts the blend's older values back in the catalog, for any
prop in any set.

Found 2026-11-03: f9d59aa changed CampusLamp's light in `props_campus.py` and the catalog, not in the blend. Exporting a
new batch of props quietly restored the old, brighter lamp on the University's 48 lamp posts.

**Why:** a lamp's light, an anchor or a screen slot lives in the catalog only, so no mesh diff shows it going back.

**How to apply:** before a props export, compare `git log -1 -- art/blend/Props.blend` with
`git log -- art/scripts/props*.py art/scripts/propkit.py art/scripts/modelkit.py art/scripts/stationkit.py` and rebuild
every prop whose builder changed since. After it, read `git diff src/shared/ModelCatalog.luau`: every line that changed
should be one you meant to change.
