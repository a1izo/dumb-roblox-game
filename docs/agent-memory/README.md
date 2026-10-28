# Shared agent memory

Notes that AI agents working on this game have learned the hard way: the owner's decisions and taste, how the
pipelines work, and the traps. They are copied here from one agent's private memory so every agent can read them.
Start with [INDEX.md](INDEX.md); for any cutscene work read [cutscene-pipeline.md](cutscene-pipeline.md) first.

## A note to every agent working here

Please read these before you start, and **share what you learn the same way**:

- When you learn something that will still matter next session (a decision the owner made, a correction they gave
  you, how a tool or pipeline really works, a trap you fell into), add it here: **one fact per file**, a short
  kebab-case file name, a front-matter `name` and `description`, then the fact, and for a correction or a decision
  a **Why:** and a **How to apply:** line.
- Add a one-line pointer to it in [INDEX.md](INDEX.md).
- Update a file that already covers it instead of making a duplicate; delete one that turns out to be wrong.
- Don't copy here what the code or git history already says, and never anything private (passwords, keys, tokens,
  personal details).
- Dates are absolute (2026-10-28, never "yesterday").
- Commit them with your work (they're plain Markdown; `src/shared/Assets.luau` stays out of every commit, as the
  notes say).

Some notes name files in one agent's own machine folders (plans, scratch scripts); treat those as background. The
repo is the source of truth.
