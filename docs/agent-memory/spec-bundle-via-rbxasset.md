---
name: spec-bundle-via-rbxasset
description: "Run the repo's pure specs (CrowdSim, MapContract) and the crowd watcher in a running Studio with no write into the shared place: rojo build into Studio's content folder, load with GetObjects(rbxasset://)"
metadata:
  type: reference
---

The place's scripts are older than main and `execute_luau` writes into the shared Team Create place are refused
([[studio-shared-place-write-blocked]]), and there is no Luau interpreter on this machine (no lune, no luau). What works,
found 2026-11-13:

1. `python scripts/crowd/bundle.py` runs `rojo build` of a small project (the repo's `CrowdSim`, `MapContract`, the
   generated Layout modules, `ScrambleCycle`, the specs and `scripts/crowd/run.luau` / `watch.luau`) straight to
   `<newest Studio>\content\dg_specs.rbxm`. (`$path` to an `init.luau` file fails in Rojo: map the directory.)
2. In any Studio's Edit datamodel, `execute_luau`:
   `local root = game:GetObjects("rbxasset://dg_specs.rbxm")[1]` returns the tree unparented (nothing enters the
   place). `require(root.Tools.run)(root)` runs every spec in `root.Server.Tests` with the repo's own `TestRunner` and
   returns the summary and failures; `require(root.Tools.watch)(root, seed, seconds)` steps the sim over the real graph
   and prints the crowd's numbers. `root:Destroy()` when done.
3. `MapContract.spec` needs the three map modules: the bundle stubs them (`layout()` returns the venue's Layout). A spec
   that reaches more of the game (SceneBuilder, Services) is not in the bundle: add its modules to `bundle.py` or run it
   in a play test after the owner's Rojo sync.

Rebuild the bundle after every edit to a bundled file; delete a stale `dg_specs_old.rbxm` style scratch file from the
content folder when done (it lives outside the repo). A negative control is cheap: bundle the OLD data (`git show
HEAD:<file>` into a scratch folder) and the new rule must fail on it.

Related: [[tokyo-crowd-2026-11]], [[studio-mcp]].
