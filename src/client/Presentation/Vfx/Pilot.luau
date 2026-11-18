--!strict
-- The pilot's switches (the VFX rework, tickets V3.1 to V3.3, docs/handoff/vfx-rework-plan-2026-11-16.md): which of the
-- three piloted effects wear the new kit (Vfx/Fresh) and which still wear the old one. The call sites read this table, so
-- the before and after pictures come from the same code with a flag flipped. Set one to false to go back to the old look
-- of that effect (a script sync picks it up); nothing else reads these.
--
--   impact    the burst of a body hitting the floor (Presentation/DeathFx.burst)
--   menacing  Menacing Pose's own effect (Controllers/EmoteFx/Poses.luau, the first pose only)
--   cover     the highest Manual cover's tell (World/CoverTells.luau, the Black Mirror)
--   aura1, aura3  the aura an emote wears at level 1 and level 3 (Presentation/Aura)
--   materialize   things drawn into being or taken out of it (Presentation/Materialize)

local Pilot = {}

Pilot.on = {
	impact = true,
	-- (off: in the booth the new menace was a soft white blob at the ignition and nothing visible after it, and the effect
	-- report got worse, 26 emitters and 3 lights against 24 and 2; the old haze stays until it is redone)
	menacing = false,
	cover = true,
	-- stage 4a (Presentation/Aura.luau: levels 1 and 3 only; level 2 is still the old build)
	aura1 = true,
	aura3 = true,
	-- stage 4a: Presentation/Materialize (the smoke and specks, and the glint when whole; callers that ask for quiet are unchanged)
	materialize = true,
	-- stage 4a: the glint where a soul is gathered (Specter/GhostController) and where the dive's string takes the body
	-- (Controllers/DiveController, the string's glint only: the crash is V4d's)
	glintGhost = true,
	glintDive = true,
}

return Pilot
