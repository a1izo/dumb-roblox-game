-- The Muerto's sabotage, in free roam only. Three kinds share one cooldown per Muerto
-- (SABOTAGE_COOLDOWN seconds):
--   blackout  : the whole map goes dark for BLACKOUT_TIME seconds and name tags hide (cover for a
--               hack or a writing).
--   jam       : the case-file stations in the Muerto's area lock for JAM_TIME seconds.
--   barricade : a barrier drops right in front of the Muerto for BARRICADE_TIME seconds, across the
--               way they face. Anyone watching sees who put it there.
-- Diavolo cannot sabotage; nothing works during a meeting.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local CaseFileService = require(script.Parent.CaseFileService)
local CharacterService = require(script.Parent.CharacterService)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local SabotageRemote = Net.event("Sabotage")

local SabotageService = {}

SabotageService.KINDS = { "blackout", "jam", "barricade" }

local blackoutToken = 0
local blackoutOn = false
local barricades: { BasePart } = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function hideNames(hidden: boolean)
	for _, ps in ipairs(Match.list) do
		local character = ps.player.Character
		if character then
			CharacterService.setNameHidden(character, "blackout", hidden and ps.alive == true)
		end
	end
end

local function endBlackout()
	blackoutToken += 1
	if not blackoutOn then
		return
	end
	blackoutOn = false
	hideNames(false)
	local map = Match.map
	if map and map.model and map.model.Parent then
		map.model:SetAttribute("BlackoutUntil", nil)
	end
end

local function blackout(ps): boolean
	local map = Match.map
	if not map or not map.model then
		return false
	end
	blackoutToken += 1
	local mine = blackoutToken
	local matchId = Match.id
	blackoutOn = true
	map.model:SetAttribute("BlackoutUntil", now() + Config.BLACKOUT_TIME)
	hideNames(true)
	EventLog.add(Terms.f("{alias} ({cultist}) blacked out the map.", { alias = ps.alias }), "sabotage")
	task.delay(Config.BLACKOUT_TIME, function()
		if blackoutToken == mine and Match.id == matchId then
			endBlackout()
		end
	end)
	return true
end

local function jam(ps): boolean
	local position = Match.position(ps)
	if not position then
		return false
	end
	local names = CaseFileService.jamNear(position, Config.JAM_TIME)
	if #names == 0 then
		Match.notify(ps.player, "There are no stations near you to jam.", "bad")
		return false
	end
	EventLog.add(
		Terms.f("{alias} ({cultist}) jammed {stations}.", { alias = ps.alias, stations = table.concat(names, ", ") }),
		"sabotage"
	)
	Match.notify(ps.player, "Jammed: " .. table.concat(names, ", ") .. ".", "secret")
	return true
end

-- Police tape strung between two posts, across the way the Muerto faces, a few studs ahead.
local function barricade(ps): boolean
	local root = Match.rootPart(ps)
	local map = Match.map
	if not root or not map or not map.model then
		return false
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.1 then
		return false
	end
	look = look.Unit
	local ground = root.Position - Vector3.new(0, 3, 0)
	local base = CFrame.lookAt(ground + look * 4, ground + look * 5)
	local wall = Create("Part", {
		Name = "Barricade",
		Anchored = true,
		CanCollide = true,
		Size = Vector3.new(12, 9, 0.6),
		CFrame = base * CFrame.new(0, 4.5, 0),
		Color = Color3.fromRGB(32, 30, 28),
		Material = Enum.Material.DiamondPlate,
		Transparency = 0.15,
		Parent = map.model,
	})
	for i, height in ipairs({ 2.2, 5.6 }) do
		Create("Part", {
			Name = "Tape" .. i,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			Size = Vector3.new(12.4, 0.5, 0.7),
			CFrame = base * CFrame.new(0, height, 0),
			Color = Color3.fromRGB(240, 200, 30),
			Material = Enum.Material.Neon,
			Parent = wall,
		})
	end
	table.insert(barricades, wall)
	EventLog.add(
		Terms.f("{alias} ({cultist}) barricaded the way near {area}.", {
			alias = ps.alias,
			area = Match.nearestArea(root.Position),
		}),
		"sabotage"
	)
	local matchId = Match.id
	task.delay(Config.BARRICADE_TIME, function()
		if Match.id == matchId then
			local index = table.find(barricades, wall)
			if index then
				table.remove(barricades, index)
			end
		end
		wall:Destroy()
	end)
	return true
end

local RUN: { [string]: (any) -> boolean } = {
	blackout = blackout,
	jam = jam,
	barricade = barricade,
}

-- Why this player cannot sabotage right now (nil: they can).
function SabotageService.problem(ps): string?
	if not ps.alive or ps.role ~= "Follower" then
		return "role"
	elseif Match.phase ~= "Investigation" or Match.meetingCall ~= nil then
		return "phase"
	elseif ps.ritual then
		return "busy"
	elseif now() < ps.sabotageReadyAt then
		return "cooldown"
	end
	return nil
end

function SabotageService.run(ps, kind: string, force: boolean?): boolean
	local run = RUN[kind]
	if not run then
		return false
	end
	if not force then
		local problem = SabotageService.problem(ps)
		if problem == "cooldown" then
			Match.notify(ps.player, "Your sabotage is not ready yet.", "bad")
			return false
		elseif problem then
			return false
		end
	end
	if not run(ps) then
		return false
	end
	ps.sabotageReadyAt = now() + Config.SABOTAGE_COOLDOWN
	Match.pushPrivate(ps)
	return true
end

local function onRequest(player: Player, payload)
	if type(payload) ~= "table" or type(payload.kind) ~= "string" then
		return
	end
	local ps = Match.getLiving(player)
	if not ps or not RateLimit.allow(player, "sabotage", 0.5) then
		return
	end
	SabotageService.run(ps, payload.kind)
end

-- Free roam is over (a meeting or the end): the lights come back and the barriers go.
function SabotageService.clear()
	endBlackout()
	for _, wall in ipairs(barricades) do
		wall:Destroy()
	end
	barricades = {}
end

function SabotageService.init()
	SabotageRemote.OnServerEvent:Connect(onRequest)
end

return SabotageService
