--!strict
-- The owner's sounds and faces for emotes, by id. Every slot starts empty: an empty sound plays nothing,
-- an empty face leaves the player's own face on. To fill one, upload the file to Roblox (a sound you made
-- or have a licence for; Roblox removes copyrighted songs) and paste its number between the quotes,
-- for example `wave = "1234567890",`.
--
-- A sound plays around the dancer for as long as the emote does (looped for a looping emote), heard
-- within about 40 studs; players can mute other players' emote music in Settings. Never in a meeting or
-- a cutscene. A face is put on the head while an emote with that `face` plays (Shared/Cosmetics).

local EmoteMedia = {}

-- [clip id] = sound asset id
EmoteMedia.SOUNDS = {
	-- Everyone's
	wave = "",
	point = "",
	cheer = "",
	laugh = "",
	dance = "",
	salute = "",
	bow = "",
	shrug = "",
	facepalm = "",
	highFive = "",
	handshake = "",
	-- From the shop
	dance2 = "",
	dance3 = "",
	chip = "",
	think = "",
	coinFlip = "",
	appleBite = "",
	puppetDance = "",
	writeAir = "",
	aceCrouch = "",
	-- The emote pack: dances
	officeParty = "",
	twoLeggedBop = "",
	boatAura = "",
	jackpotShuffle = "",
	theClassic = "",
	smilingLord = "",
	bouncePump = "",
	ratDance = "",
	bunnyEars = "",
	puppetPop = "",
	excuseMeSir = "",
	glitchStep = "",
	goalCelebration = "",
	takeTheL = "",
	twoWeeksNotice = "",
	-- The emote pack: poses
	impossibleLean = "",
	nahIdWin = "",
	jawlineCheck = "",
	theEyebrow = "",
	itsYou = "",
	menacingPose = "",
	animatronicWelcome = "",
	lowBattery = "",
	deducing = "",
	justAsPlanned = "",
	reapersCackle = "",
	finalBreakdown = "",
	newWorld = "",
	reapersEyes = "",
	footScratch = "",
	hairTwirl = "",
	-- The emote pack: with props
	preDawnBonk = "",
	blindfoldLift = "",
	chairPerch = "",
	twoFingerGrip = "",
	sugarTower = "",
	chipAndPen = "",
	furiousScribbling = "",
	appleToss = "",
	strawberryOnTop = "",
	diceTower = "",
	chocolateSnap = "",
	fortySeconds = "",
	-- The emote pack: strolls (heard for as long as the stroll lasts)
	theLongClimb = "",
	paradeMarch = "",
	griddy = "",
	mushroomStroll = "",
	notMyProblem = "",
	-- The emote pack: duos
	matchPointServe = "",
	cuffedLead = "",
	-- After a press of Y (the part a press plays: its own sound takes over from the emote's; empty plays nothing)
	excuseMeSirUp = "", -- Excuse Me, Sir: LOOK UP
	coinFlipAgain = "", -- Coin Flip: FLIP again
	chipEat = "", -- Potato Chip: EAT
	blindfoldLiftUp = "", -- Blindfold Lift: LIFT
	furiousScribblingSlash = "", -- Furious Scribbling: WRITE IT
	appleTossThrow = "", -- Apple Toss: TOSS
	lowBatteryCharge = "", -- Low Battery: CHARGE
	sugarTowerAdd = "", -- Sugar Tower: ADD ONE, and it holds
	sugarTowerTopple = "", -- Sugar Tower: ADD ONE, and it falls
	diceTowerAdd = "", -- Dice Tower: ADD ONE, and it holds
	diceTowerTopple = "", -- Dice Tower: ADD ONE, and it falls
	-- (Menacing Pose: each NEXT POSE plays the next pose's; the 6th's press goes back to the 1st and its sound)
	menacingPose2 = "", -- Menacing Pose: NEXT POSE, the 2nd pose
	menacingPose3 = "", -- Menacing Pose: NEXT POSE, the 3rd pose
	menacingPose4 = "", -- Menacing Pose: NEXT POSE, the 4th pose
	menacingPose5 = "", -- Menacing Pose: NEXT POSE, the 5th pose
	menacingPose6 = "", -- Menacing Pose: NEXT POSE, the 6th pose
} :: { [string]: string }

-- [expression] = decal asset id (a face drawn in art/textures/faces, uploaded as a Decal)
EmoteMedia.FACES = {
	deadpan = "",
	smirk = "",
	smug = "",
	raisedBrow = "",
	wideGrin = "",
	stare = "",
	-- not worn by the dancer: the grin on the giant image behind The Long Climb (Controllers/EmoteFx)
	manicGrin = "",
} :: { [string]: string }

-- An emote's sound cues, besides its music above: short sounds at moments of the clip (a pen's scratch, the
-- crunch of a bite, a stamp), each fired from the emote's own clock (on every turn of a loop). The list for each
-- emote is in its notes (art/refs/emotes/<clip>.toml, [sound]); fill a cue's id as for the music.
--   at      seconds into the clip
--   id      the sound asset id ("" plays nothing)
--   volume  0 to 1, times VOLUME (1 when left out)
--   own     heard by the dancer alone (a cue that would give something away, or only matters to them)
--   loud    a prominent cue: kept quiet in a case
export type Cue = { at: number, id: string, volume: number?, own: boolean?, loud: boolean? }

-- [clip id] = its cues, in order
EmoteMedia.CUES = {} :: { [string]: { Cue } }

-- How loud an emote's sound plays (0 to 1).
EmoteMedia.VOLUME = 0.5

-- How far it carries (studs).
EmoteMedia.RANGE = 40

local function content(id: string?): string?
	if type(id) ~= "string" or id == "" then
		return nil
	end
	return if string.find(id, "^rbx") then id else "rbxassetid://" .. id
end

-- The sound for an emote, as a content id, or nil.
function EmoteMedia.sound(clip: string): string?
	return content(EmoteMedia.SOUNDS[clip])
end

-- The slot a clip's sound comes from. The part a press of Y plays (`from`: the clip the press was in) has a slot
-- of its own, and a press that plays the same clip again (Coin Flip's FLIP) has "<clip>Again"; anything else
-- plays its emote's (`emote`: the clip of the shop item it belongs to).
function EmoteMedia.slot(clip: string, emote: string, from: string?): string
	if from ~= nil then
		local key = if from == clip then clip .. "Again" else clip
		if EmoteMedia.SOUNDS[key] ~= nil then
			return key
		end
	end
	return emote
end

-- An emote's cues that have a sound, in order of their moment, each with its content id.
function EmoteMedia.cues(clip: string): { Cue }
	local filled = {}
	for _, cue in ipairs(EmoteMedia.CUES[clip] or {}) do
		local id = content(cue.id)
		if id then
			table.insert(filled, { at = cue.at, id = id, volume = cue.volume, own = cue.own, loud = cue.loud })
		end
	end
	table.sort(filled, function(a, b)
		return a.at < b.at
	end)
	return filled
end

-- The face for an expression, as a content id, or nil.
function EmoteMedia.face(expression: string?): string?
	return if expression then content(EmoteMedia.FACES[expression]) else nil
end

return EmoteMedia
