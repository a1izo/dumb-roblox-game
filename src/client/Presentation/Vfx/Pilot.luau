--!strict
-- The pilot's switches (the VFX rework, tickets V3.1 to V3.3, docs/handoff/vfx-rework-plan-2026-11-16.md): which of the
-- three piloted effects wear the new kit (Vfx/Fresh) and which still wear the old one. The call sites read this table, so
-- the before and after pictures come from the same code with a flag flipped. Set one to false to go back to the old look
-- of that effect (a script sync picks it up); nothing else reads these.
--
--   impact    the burst of a body hitting the floor (Presentation/DeathFx.burst)
--   menacing  Menacing Pose's own effect (Controllers/EmoteFx/Poses.luau, the first pose only)
--   cover     the highest Manual cover's tell (World/CoverTells.luau, the Black Mirror)

local Pilot = {}

Pilot.on = {
	impact = true,
	menacing = true,
	cover = true,
}

return Pilot
