-- Paper notes: blank sheets spawn at fixed spots, a player types a note by hand, then
-- drops it or hides it at a drop point. Anyone can pick up and read notes. A team member
-- who finds a note with a living player's real name confiscates it: it goes to the
-- evidence board with the name hidden and the named player is warned. Kira can burn
-- notes; the smoke is visible and raises suspicion on everyone close by.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))
local Util = require(Shared:WaitForChild("Util"))

local CharacterService = require(script.Parent.CharacterService)
local EventLog = require(script.Parent.EventLog)
local EvidenceService = require(script.Parent.EvidenceService)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)
local SuspicionService = require(script.Parent.SuspicionService)
local TextFilter = require(script.Parent.TextFilter)

local NoteRequest = Net.event("NoteRequest")
local NoteViewRemote = Net.event("NoteView")
local DropPointViewRemote = Net.event("DropPointView")

local NoteService = {}

local notes = {} -- id -> note record
local sheets = {} -- id -> sheet spot
local drops = {} -- id -> { info, notes = { noteId } }
local folder: Folder? = nil
local nextNoteId = 0

local PAPER = Color3.fromRGB(250, 250, 248)
local WRITTEN = Color3.fromRGB(245, 238, 215)

local function setCarry(ps, carrying)
	ps.carrying = carrying
	CharacterService.setCarry(ps.player, if carrying then carrying.kind else nil)
	Match.pushPrivate(ps)
end

local function near(ps, position: Vector3, range: number): boolean
	local own = Match.position(ps)
	return own ~= nil and (own - position).Magnitude <= range
end

local function notePosition(note): Vector3?
	if note.state == "world" and note.part then
		return note.part.Position
	elseif note.state == "held" and note.holder then
		return Match.position(note.holder)
	elseif note.state == "drop" and drops[note.dropId] then
		return drops[note.dropId].info.position
	end
	return nil
end

-- Floor position under a player, found with a short downward ray.
local function floorUnder(ps): Vector3?
	local root = Match.rootPart(ps)
	if not root then
		return nil
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local characters = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	params.FilterDescendantsInstances = characters
	local result = workspace:Raycast(root.Position, Vector3.new(0, -12, 0), params)
	if result then
		return result.Position + Vector3.new(0, 0.04, 0)
	end
	return root.Position - Vector3.new(0, 3, 0)
end

-- Unparented paper part; callers set attributes and tags, then parent it.
local function paperPart(name: string, position: Vector3, color: Color3): Part
	local part = Create("Part", {
		Name = name,
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		Size = Vector3.new(1.1, 0.06, 1.5),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CFrame = CFrame.new(position) * CFrame.Angles(0, Match.rng:NextNumber() * math.pi * 2, 0),
	})
	ModelLibrary.dress(part, if name == "BlankSheet" then "PaperSheet" else "PaperNote", CFrame.new(0, -0.03, 0))
	return part
end

local function spawnSheet(sheet)
	if sheet.part or not folder then
		return
	end
	local part = paperPart("BlankSheet", sheet.position, PAPER)
	part:SetAttribute("SheetId", sheet.id)
	part:AddTag("LSheet")
	part.Parent = folder
	sheet.part = part
end

local function placeInWorld(note, position: Vector3)
	note.state = "world"
	note.holder = nil
	note.dropId = nil
	local part = paperPart("PaperNote", position, WRITTEN)
	Create("Part", {
		Name = "Ink",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Size = Vector3.new(0.7, 0.02, 0.08),
		Color = Color3.fromRGB(25, 25, 25),
		Material = Enum.Material.SmoothPlastic,
		CFrame = part.CFrame * CFrame.new(0, 0.04, -0.2),
		Parent = part,
	})
	part:SetAttribute("NoteId", note.id)
	part:AddTag("LNote")
	part.Parent = folder
	note.part = part
end

local function removeFromDrop(note)
	local drop = drops[note.dropId]
	if drop then
		local index = table.find(drop.notes, note.id)
		if index then
			table.remove(drop.notes, index)
		end
	end
	note.dropId = nil
end

local function destroyNote(note)
	if note.part then
		note.part:Destroy()
		note.part = nil
	end
	if note.state == "held" and note.holder then
		local holder = note.holder
		if holder.carrying and holder.carrying.noteId == note.id then
			setCarry(holder, nil)
		end
	elseif note.state == "drop" then
		removeFromDrop(note)
	end
	note.state = "gone"
	notes[note.id] = nil
end

-- Returns true when a team member found a note naming a living player (the note is taken).
local function confiscateIfNamed(finder, note): boolean
	if Match.isKiraSide(finder) then
		return false
	end
	local named = {}
	for _, ps in ipairs(Match.living()) do
		if NameUtil.containsFullName(note.text, ps.first, ps.last) then
			table.insert(named, ps)
		end
	end
	if #named == 0 then
		return false
	end
	local position = notePosition(note) or Match.position(finder) or Vector3.zero
	local area = Match.nearestArea(position)
	local writer = Match.getByUserId(note.writerUserId)
	destroyNote(note)
	finder.stats.notesFound += 1
	EvidenceService.post(
		finder.alias,
		"Paper note",
		"A note with a real name on it was found near "
			.. area
			.. ". The name is withheld; the named player has been warned."
	)
	Match.notify(
		finder.player,
		"This note names a real player. It went to the evidence board with the name hidden.",
		"good"
	)
	local aliases = {}
	for _, ps in ipairs(named) do
		table.insert(aliases, ps.alias)
		ps.hoodNextRound = true
		Match.notify(
			ps.player,
			"Warning: someone wrote your real name on a paper note! You will wear a hood next round.",
			"bad"
		)
	end
	EventLog.add(
		string.format(
			"%s found a note naming %s (written by %s).",
			finder.alias,
			table.concat(aliases, ", "),
			if writer then writer.alias else "someone"
		),
		"note"
	)
	return true
end

-- Actions ------------------------------------------------------------------------------

local function takeSheet(ps, sheetId)
	local sheet = sheets[sheetId]
	if not sheet or not sheet.part or not near(ps, sheet.position, Config.INTERACT_RANGE + 2) then
		return
	end
	if ps.carrying then
		Match.notify(ps.player, "You can only carry one sheet of paper at a time.", "bad")
		return
	end
	sheet.part:Destroy()
	sheet.part = nil
	local matchId = Match.id
	task.delay(Config.SHEET_RESPAWN_TIME, function()
		if Match.id == matchId and Match.active then
			spawnSheet(sheet)
		end
	end)
	setCarry(ps, { kind = "blank" })
	EventLog.sighting(ps, "took a blank sheet of paper", sheet.position)
end

local function write(ps, text)
	if type(text) ~= "string" or not ps.carrying or ps.carrying.kind ~= "blank" then
		return
	end
	local cleaned = Util.cleanText(text, Config.NOTE_MAX_LENGTH)
	if #cleaned == 0 then
		return
	end
	nextNoteId += 1
	local note = {
		id = "N" .. nextNoteId,
		text = cleaned,
		writerUserId = ps.userId,
		state = "held",
		holder = ps,
		dropId = nil,
		part = nil,
		burning = false,
	}
	notes[note.id] = note
	setCarry(ps, { kind = "note", noteId = note.id })
	EventLog.print(ps)
	Match.notify(ps.player, "Note written. Drop it where someone will find it, or hide it at a drop point.", "info")
end

local function drop(ps)
	local carrying = ps.carrying
	if not carrying then
		return
	end
	if carrying.kind == "blank" then
		setCarry(ps, nil)
		Match.notify(ps.player, "You threw the blank sheet away.", "info")
		return
	end
	local note = notes[carrying.noteId]
	local position = floorUnder(ps)
	if not note or not position then
		setCarry(ps, nil)
		return
	end
	setCarry(ps, nil)
	placeInWorld(note, position)
	EventLog.sighting(ps, "dropped a paper note", position)
end

local function read(ps, noteId)
	local note = notes[noteId]
	if not note or note.burning then
		return
	end
	if note.state == "held" then
		if note.holder ~= ps then
			return
		end
	else
		local position = notePosition(note)
		if Match.phase ~= "Investigation" or not position or not near(ps, position, Config.INTERACT_RANGE + 2) then
			return
		end
		if confiscateIfNamed(ps, note) then
			return
		end
	end
	local text = TextFilter.forUser(note.text, note.writerUserId, ps.userId)
	if not text then
		Match.notify(ps.player, "The writing is illegible.", "bad")
		return
	end
	NoteViewRemote:FireClient(ps.player, {
		noteId = note.id,
		text = text,
		location = note.state,
		canTake = note.state ~= "held" and ps.carrying == nil,
		canBurn = ps.role == "Kira" and Match.phase == "Investigation",
	})
end

local function take(ps, noteId)
	local note = notes[noteId]
	if not note or note.burning or note.state == "held" then
		return
	end
	local position = notePosition(note)
	if not position or not near(ps, position, Config.INTERACT_RANGE + 2) then
		return
	end
	if ps.carrying then
		Match.notify(ps.player, "Your hands are full. Drop what you carry first.", "bad")
		return
	end
	if confiscateIfNamed(ps, note) then
		return
	end
	if note.part then
		note.part:Destroy()
		note.part = nil
	end
	if note.state == "drop" then
		removeFromDrop(note)
	end
	note.state = "held"
	note.holder = ps
	setCarry(ps, { kind = "note", noteId = note.id })
	EventLog.print(ps)
	EventLog.sighting(ps, "picked up a paper note", position)
end

local function leave(ps, dropId)
	local dropPoint = drops[dropId]
	local carrying = ps.carrying
	if not dropPoint or not carrying or carrying.kind ~= "note" then
		return
	end
	if not near(ps, dropPoint.info.position, Config.INTERACT_RANGE) then
		return
	end
	if #dropPoint.notes >= Config.DROP_POINT_CAPACITY then
		Match.notify(ps.player, "There is no room left here.", "bad")
		return
	end
	local note = notes[carrying.noteId]
	if not note then
		setCarry(ps, nil)
		return
	end
	note.state = "drop"
	note.holder = nil
	note.dropId = dropId
	table.insert(dropPoint.notes, note.id)
	setCarry(ps, nil)
	EventLog.sighting(ps, "crouched at a hidden spot", dropPoint.info.position)
	Match.notify(ps.player, "Note hidden: " .. dropPoint.info.name .. ".", "secret")
end

local function check(ps, dropId)
	local dropPoint = drops[dropId]
	if not dropPoint or not near(ps, dropPoint.info.position, Config.INTERACT_RANGE) then
		return
	end
	DropPointViewRemote:FireClient(ps.player, {
		dropId = dropId,
		name = dropPoint.info.name,
		notes = table.clone(dropPoint.notes),
		canLeave = ps.carrying ~= nil and ps.carrying.kind == "note" and #dropPoint.notes < Config.DROP_POINT_CAPACITY,
	})
end

local function smokeAt(position: Vector3, duration: number)
	local emitter = Create("Part", {
		Name = "BurnSmoke",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new(position + Vector3.new(0, 0.5, 0)),
		Parent = folder or workspace,
	})
	Create("Smoke", {
		Color = Color3.fromRGB(90, 90, 95),
		Opacity = 0.45,
		RiseVelocity = 6,
		Size = 4,
		Parent = emitter,
	})
	local fire = Create("Fire", {
		Color = Color3.fromRGB(255, 140, 40),
		SecondaryColor = Color3.fromRGB(255, 60, 20),
		Heat = 6,
		Size = 2,
		Parent = emitter,
	})
	task.delay(Config.BURN_TIME, function()
		fire.Enabled = false
	end)
	task.delay(duration, function()
		emitter:Destroy()
	end)
end

local function burn(ps, noteId)
	local note = notes[noteId]
	if ps.role ~= "Kira" or not note or note.burning then
		return
	end
	local position = notePosition(note)
	if not position then
		return
	end
	if note.state ~= "held" or note.holder ~= ps then
		if not near(ps, position, Config.INTERACT_RANGE + 2) then
			return
		end
	end
	note.burning = true
	smokeAt(position, 12)
	Match.notify(ps.player, "Burning...", "secret")
	local matchId = Match.id
	task.delay(Config.BURN_TIME, function()
		if Match.id ~= matchId or not Match.active then
			return
		end
		if notes[note.id] ~= note or not ps.alive then
			note.burning = false
			return
		end
		local burnPosition = notePosition(note) or position
		destroyNote(note)
		for _, other in ipairs(Match.living()) do
			local otherPosition = Match.position(other)
			if otherPosition and (otherPosition - burnPosition).Magnitude <= Config.BURN_SMOKE_RANGE then
				SuspicionService.add(other, Config.SUSPICION.NEAR_BURN)
			end
		end
		EventLog.sighting(ps, "burned something", burnPosition)
		EventLog.add(Terms.f("{Hand} ({alias}) burned a paper note.", { alias = ps.alias }), "burn")
		Match.notify(ps.player, "The note is ash.", "secret")
	end)
end

local function onRequest(player: Player, payload)
	if type(payload) ~= "table" or type(payload.action) ~= "string" then
		return
	end
	if not RateLimit.allow(player, "note", 0.3) then
		return
	end
	local ps = Match.getLiving(player)
	if not ps then
		return
	end
	local action = payload.action
	if action == "read" then
		read(ps, payload.noteId)
		return
	end
	if Match.phase ~= "Investigation" then
		return
	end
	if action == "takeSheet" then
		takeSheet(ps, payload.sheetId)
	elseif action == "write" then
		write(ps, payload.text)
	elseif action == "drop" then
		drop(ps)
	elseif action == "take" then
		take(ps, payload.noteId)
	elseif action == "leave" then
		leave(ps, payload.dropId)
	elseif action == "check" then
		check(ps, payload.dropId)
	elseif action == "burn" then
		burn(ps, payload.noteId)
	end
end

-- The note a player carried falls to the floor when they leave the living.
local function onEliminated(ps)
	local carrying = ps.carrying
	if not carrying then
		return
	end
	local position = floorUnder(ps)
	ps.carrying = nil
	CharacterService.setCarry(ps.player, nil)
	if carrying.kind == "note" then
		local note = notes[carrying.noteId]
		if note and position then
			placeInWorld(note, position)
		elseif note then
			destroyNote(note)
		end
	end
end

function NoteService.onMatchStart(map)
	notes = {}
	sheets = {}
	drops = {}
	nextNoteId = 0
	folder = Create("Folder", { Name = "Notes", Parent = map.model })
	for _, spot in ipairs(map.sheets) do
		local sheet = { id = spot.id, position = spot.position, part = nil }
		sheets[sheet.id] = sheet
		spawnSheet(sheet)
	end
	for _, info in ipairs(map.dropPoints) do
		drops[info.id] = { info = info, notes = {} }
	end
end

function NoteService.onMatchEnd()
	for _, ps in ipairs(Match.list) do
		if ps.carrying then
			ps.carrying = nil
			CharacterService.setCarry(ps.player, nil)
		end
	end
	notes = {}
	sheets = {}
	drops = {}
	folder = nil
end

function NoteService.init()
	NoteRequest.OnServerEvent:Connect(onRequest)
	Match.Eliminated:Connect(onEliminated)
	CharacterService.CharacterSpawned:Connect(function(player)
		local ps = Match.getLiving(player)
		if ps and ps.carrying then
			CharacterService.setCarry(player, ps.carrying.kind)
		end
	end)
end

return NoteService
