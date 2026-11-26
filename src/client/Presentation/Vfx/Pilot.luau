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
	winFxWave = false, -- (2026-11-26 in the lobby light, old and new side by side: the new ring is a thin pale line, the old a wide white band: not clearly better)
	winFxBolt = true, -- (2026-11-26, fired beside a real cut and in the lobby: forked, branching strokes where the old bolt was a stack of pasted white quads)
	winFxSparks = true, -- (2026-11-26: thin hot streaks and a star where the old sparks were short white dashes)
	winFxBloom = false, -- (2026-11-26: floods the whole floor white in the lobby light, too much beside the old soft glow: not shipped)
	winFxRing = false, -- (2026-11-26: a dark smoky rim round the white ring reads heavy against the old clean ring: not shipped)
	winFxDust = true, -- (2026-11-26: a soft shaped puff on the floor where the old dust was nearly invisible)
	winFxEmbers = false, -- (2026-11-26: not seen among the kinds fired side by side, the orange never showed: not shipped)
	winFxMotes = false, -- (2026-11-26: reads as glitter stars, not as dust drifting in a light: not shipped)
	winFxAsh = false, -- (2026-11-26: big black clumps against the old fine flakes: heavier, not better)
	winFxDrizzle = false, -- (2026-11-26: white streaks no different from the old thin ones: not shipped)
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
	-- stage 4d, deaths and gameplay moments (Presentation/Vfx/Fresh/Gameplay), each its own flag; false = the old build
	deathSparks = false, -- (handcuffs, the Manual landing: DeathFx.sparks; the booth picture showed a soft ring with a small star against the old hard spiked star: not better)
	deathChalkDust = false, -- (the dust as the chalk outline cuts in: DeathFx.chalk; the FxChalk picture is not in Fx 4 here, so never seen)
	deathDissolve = false, -- (voted out: the ash off the body, DeathFx.dissolve; report fewer reasons but nothing showed in a booth picture, old or new: the emitters sit inside the black torso)
	deathDust = false, -- (DeathVfx floor dust for the collapses; report only, no picture)
	deathPuff = false, -- (DeathVfx sick breath and the last breath of the heart; report only, no picture)
	deathGlow = false, -- (DeathVfx glow: the heart seizure; report only, no picture)
	deathAccident = false, -- (DeathVfx collapseAccident: the head meeting the floor; report 4 pop reasons to 2, no picture)
	eyeGlow = false, -- (a stare red eyes: a glint as each opens, World/EyeGlow; report only, not photographed)
	hauntMist = false, -- (a Specter Mist haunt, UI/HauntBar; seen once as a thin pale roll along the floor against the old fuller puff, not clearly better; the second try lost to the Governor)
	diveCrash = true, -- (the dive crash into the roof, Controllers/DiveController; report FAIL to PASS, 14 emitters to 8, 25% dots to 0, picture: a clean flat blow with a lit core against the old spiked slab)
	eyesDealEyes = false, -- (the Deathsinger eyes lit, Presentation/EyesDealFx; report only, not photographed)
	eyesDealIgnite = false, -- (your eyes taking fire, Presentation/EyesDealFx; seen: a bright white star in the middle of the face, the deal red is lost, so not shipped)
	manualFire = false, -- (the Manual's red fire, UI/WorldFx; seen 2026-11-25 with the real VfxFire (Fx 5): a fan of white spikes with pink fringes, the danger red lost, bigger than the old flame: not better; 2026-11-26 with the v6 sheet and a smaller, dimmer heart layer: one cohesive flame now, but a flat pink silhouette on the lobby's grey, the red still lost: not better)
	trialWisp = false, -- (the Trial's wisp flame, Onboarding/TrialWisp; seen 2026-11-25 with the real VfxFire: detached white teardrops, the amber lost, the old flame is a single cohesive one: not better; 2026-11-26 v6: a cohesive cream slab, amber lost, twice the old's height: not better)
	-- stage 4e, the world (read when a flame is stood: World/Flames, World/ReadyCircle); false = the old flame
	worldCandle = true, -- (the maps' candle wicks: ON 2026-11-26 with the v6 candle sheet (Fx 6): in the lobby a teardrop with a dark wick against the old tall narrow shard, flickers, report FAIL to PASS (3 to 2 particles, 3 emitters, 2 lights to 0); before v6 it was not better)
	worldBrazier = false, -- (the maps' braziers: 41 to 2 particles; with the v6 sheet (2026-11-26) one cohesive flame, but a flat milky silhouette (additive pale on the lobby's grey) against the old's lit glow, report "no dark layer": not better)
	readyCandles = true, -- (the lobby's ring of ready candles: same call as worldCandle, same lamp, ON for the same reason)
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
