# VFX audit, 2026-11 (the "before" record for the effects rework)

Kept by the tickets of Stage 0 in `docs/handoff/vfx-rework-plan-2026-11-16.md`. Each ticket adds its section; fetch before
you edit, another ticket may have added its own.

## The effect report (ticket V0.5)

How to run it and how to read it: `docs/agent-memory/vfx-effect-report.md`. In a play test, from the client:

```lua
task.spawn(DebugPanel.fx.reportAll) -- every effect, one after another (minutes); prints a Markdown table
```

The table is pasted here after the run (it needs Studio). **Status: not run yet** (the code is written and committed;
the run waits for Studio).

The report is a floor, not a judge: passing it does not make an effect good. Each row's reasons are the checks of the plan's
Part 3 that the recorded layers failed; the last four columns are the peaks against Part 9's budgets.
