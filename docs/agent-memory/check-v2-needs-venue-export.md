---
name: check-v2-needs-venue-export
description: check_v2 reads a gitignored sidecar, so a fresh worktree must export the venue first, and that re-export's binary noise stays out of the commit
metadata:
  type: project
---

`art/scripts/maps/check_v2.py <Venue>` reads `art/export/scenes/<Venue>.json`, which `.gitignore` keeps out of git.
A fresh worktree has none, and the check reports "no export yet". Running
`run_maps.py -- <Venue> --export` writes it.

That export also rewrites `art/blend/Maps_<Venue>.blend`, `art/export/DeathsGambitMaps_<Venue>.fbx` and
`art/export/previews/light_<Venue>.png`. When the scene did not change, the version and mesh digest stay the same
(the Agency stayed v27 on 2026-11-04), but the binary files still differ by a few kilobytes.

**Why:** committing them would put a different FBX on main under the same version number. The user has nothing to
import, and the history gets confusing.

**How to apply:** stage only the files your change made. If `src/shared/ImportVersions.luau` still shows the venue's
old Maps version, leave the venue's blend, FBX and light map out of the commit.
