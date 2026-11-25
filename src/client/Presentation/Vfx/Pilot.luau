--!strict
-- The pilot's switches (the VFX rework, tickets V3.1 to V3.3, docs/handoff/vfx-rework-plan-2026-11-16.md): which of the
-- three piloted effects wear the new kit (Vfx/Fresh) and which still wear the old one. The call sites read this table, so
-- the before and after pictures come from the same code with a flag flipped. Set one to false to go back to the old look
-- of that effect (a script sync picks it up); nothing else reads these.
--
--   impact    the burst of a body hitting the floor (Presentation/DeathFx.burst)
--   menacing  Menacing Pose's own effect (Controllers/EmoteFx/Poses.luau, the first pose only)
--   cover     the highest Manual cover's tell (World/CoverTells.luau, the Black Mirror)
--   aura1, aura2, aura3  the aura an emote wears at level 1, 2 and 3 (Presentation/Aura)
--   materialize   things drawn into being or taken out of it (Presentation/Materialize)

local Pilot = {}

Pilot.on = {
	impact = true,
	-- (stage 3 had it off: a soft white blob and 26 emitters; the stage 4b retry on the rebuilt level-2 aura reads clearly better, 13 emitters)
	menacing = true,
	cover = true,
	-- stage 4a (Presentation/Aura.luau: levels 1, 2 and 3)
	aura1 = true,
	aura3 = true,
	-- stage 4b: level 2 on the same build (Menacing Pose and its kind wear it); false = the old level 2
	aura2 = true,
	-- stage 4b: the four Godhood emotes (Controllers/EmoteFx/Godhood.luau), each its own flag
	finalBreakdown = true,
	justAsPlanned = true,
	reapersEyes = false,
	newWorld = true,
	-- stage 4b, second batch (Controllers/EmoteFx: Duos, Strolls, Props), each its own flag, all on after the booth report (FAIL to PASS or fewer reasons); false = the old build
	cuffedLead = true,
	theLongClimb = true,
	griddy = true,
	mushroomStroll = true,
	preDawnBonk = true,
	diceTower = true,
	-- stage 4b, third batch (Controllers/EmoteFx: Older, Props, Dances), each its own flag, each on after the booth report (fewer reasons than before) and a still; false = the old build
	writeAir = true,
	blindfoldLift = true,
	blindfoldLiftUp = false, -- the LIFT press (never seen in the booth: stays off)
	aceCrouch = true,
	chairPerch = true,
	chipAndPen = true,
	strawberryOnTop = true,
	sugarTower = true,
	bunnyEars = true,
	-- stage 4b, fourth batch (Controllers/EmoteFx: Dances, Poses, Props, Older, Everyone), each its own flag; false = the old build
	twoLeggedBop = true,
	ratDance = true,
	boatAura = true,
	officeParty = true,
	glitchStep = true,
	goalCelebration = false, -- (the landing is a small ring against the old thud's big floor wave and cracks: weaker, so not shipped)
	smilingLord = true,
	excuseMeSir = false, -- (Excuse Me, Sir: the cough; a breath of pale mist, not seen in the dark booth)
	excuseMeSirUp = true, -- (its LOOK UP: the glint of sky)
	animatronicWelcome = false, -- (no visible difference in the booth)
	jackpotShuffle = true,
	lowBattery = true, -- (Low Battery and its CHARGE)
	impossibleLean = true,
	itsYou = true,
	deducing = true,
	reapersCackle = false, -- (dark smoke on a dark booth: not seen)
	menacingPoses = false, -- (the other five poses of Menacing Pose, NEXT POSE: 13 emitters against 12, no better than the old build)
	twoFingerGrip = false, -- (report only, no picture taken)
	furiousScribbling = false, -- (Furious Scribbling and WRITE IT: report only, no picture taken)
	appleTossThrow = false, -- (black feathers on a dark booth: not seen)
	chocolateSnap = false, -- (dark crumbs on a dark booth: not seen)
	fortySeconds = false, -- (the new heartbeat showed a white square and lost the red: worse than the old build)
	appleBite = true,
	puppetDance = false, -- (Puppet Dance and Bye Bye Bye: report only, no picture taken)
	appleToss = true,
	-- stage 4c, cosmetics: the other six Manual covers' tells (World/CoverTells; `cover` above is the Black Mirror's); false = the old tell
	coverOxblood = true,
	coverGilded = true,
	coverBurnt = true,
	coverCasefile = false, -- (the pages did not show in the booth, before or after: not seen)
	coverIron = true,
	coverScale = false, -- (the eye did not show in the booth, before or after: not seen)
	-- stage 4c, the win cuts' fx act kinds (Presentation/WinCinema FX; `light` is a plain lamp flash: nothing to move); false = the old build
	winFxImpact = true,
	winFxGlint = true,
	winFxPillar = true,
	winFxWave = false, -- (rings of the two dummies overlapped in the picture and the report was no better: not shipped)
	winFxBolt = false, -- (not seen: the arc is gone inside a frame of the booth picture)
	winFxSparks = false, -- (only the star showed in the picture, the sparks had left it: not seen)
	winFxBloom = false, -- (not seen)
	winFxRing = false, -- (not seen)
	winFxDust = false, -- (not seen)
	winFxEmbers = false, -- (held kinds are rate emitters, which do not show in booth pictures: not seen)
	winFxMotes = false, -- (not seen, same reason)
	winFxAsh = false, -- (not seen, same reason)
	winFxDrizzle = false, -- (not seen, same reason)
	-- stage 4c, writing styles (Presentation/Styles.write: the marks on the page); false = the old marks
	writeQuill = true,
	writeTypewriter = true,
	writeFire = true,
	writeKnife = true,
	writeChalk = true,
	writeFrost = true,
	-- stage 4c, Deathsinger forms (Presentation/Styles.form: the particles; the marionette has none); false = the old build
	formEmbers = false, -- (retired from sale; the booth picture showed only the shoulder flames, the same in both builds: not seen to differ)
	formVeil = false, -- (not seen)
	formChains = false, -- (not seen)
	formCrows = false, -- (not seen)
	formMoths = false, -- (not seen)
	-- stage 4a: Presentation/Materialize (the smoke and specks, and the glint when whole; callers that ask for quiet are unchanged)
	materialize = true,
	-- stage 4a: the glint where a soul is gathered (Specter/GhostController) and where the dive's string takes the body
	-- (Controllers/DiveController, the string's glint only: the crash is V4d's)
	-- (off until seen in the game: the booth does not play these two)
	glintGhost = false,
	glintDive = false,
	-- stage 4a: the shop cards draw the new texture names (ViewFx.RENAMED); off until the cards are seen
	viewfx = false,
}

return Pilot
