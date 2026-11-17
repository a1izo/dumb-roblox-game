---
name: vfx-moment-envelope
description: Vfx/Moment.play(at, {gather, hit, body, residue, lead}) is how a recipe gets the five moments; times, order and cancel rules
---
`Moment.play(at, parts)` (src/client/Presentation/Vfx/Moment.luau) calls `part(at, name)` on the kit's Clock: gather at 0,
hit at `lead` (default 0.2 s), body at hit + 0.05, residue at hit + 0.4 (`bodyAfter` / `residueAfter` override). The hit lands
`lead` seconds AFTER play is called, so start it early enough. Parts due at once run before play returns; ties go gather,
hit, body, residue; one part's error is warned about and the rest go on. It returns a cancel that stops parts not yet run.
`Moment.timeline(parts)` is the pure list of {name, at}, which the spec reads (`VfxMoment.spec.luau`).

**Why:** the plan's Part 3 rule 1 (every effect has gather, hit, break-up, residue) and the probe reads each emitter's time
as it is made, so building recipes on Moment makes the moments real by construction.

**How to apply:** put the dark layer and the break-up in `body`, what stays for 1 to 3 s in `residue`; do not time them
with your own Clock.after calls.
