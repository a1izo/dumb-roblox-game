-- Hoods block the shinigami eyes for one round. One hood spawns at a random spot each
-- round; a player whose name was found on a note gets one automatically next round.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Net = require(Shared:WaitForChild("Net"))
local Terms = require(Shared:WaitForChild("Terms"))

local CharacterService = require(script.Parent.CharacterService)
local EventLog = require(script.Parent.EventLog)
local Match = require(script.Parent.Match)

local HoodRequest = Net.event("HoodRequest")

local HoodService = {}

local hoods = {} -- id -> part
local spawnPoints = {}
local folder: Folder? = nil
local nextId = 0

local function spawnHood()
	if not folder or #spawnPoints == 0 then
		return
	end
	nextId += 1
	local id = "H" .. nextId
	local position = spawnPoints[Match.rng:NextInteger(1, #spawnPoints)]
	local part = Create("Part", {
		Name = "Hood",
		Anchored = true,
		CanCollide = false,
		CanTouch = false,
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1.4, 1.4, 1.4),
		Color = Color3.fromRGB(28, 26, 32),
		Material = Enum.Material.Fabric,
		CFrame = CFrame.new(position),
	})
	Create("Part", {
		Name = "Drape",
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
		Size = Vector3.new(1.3, 0.25, 1.6),
		Color = Color3.fromRGB(28, 26, 32),
		Material = Enum.Material.Fabric,
		CFrame = CFrame.new(position - Vector3.new(0, 0.55, 0)),
		Parent = part,
	})
	if ModelLibrary.dress(part, "HoodPickup", CFrame.new(0, -0.6, 0)) then
		local drape = part:FindFirstChild("Drape")
		if drape and drape:IsA("BasePart") then
			drape.Transparency = 1
		end
	end
	part:SetAttribute("HoodId", id)
	part:AddTag("LHood")
	part.Parent = folder
	hoods[id] = part
end

local function wear(ps)
	ps.hoodRound = Match.round
	CharacterService.setHood(ps.player, true)
	Match.pushPrivate(ps)
end

local function onRequest(player: Player, hoodId)
	if type(hoodId) ~= "string" then
		return
	end
	local ps = Match.getLiving(player)
	local part = hoods[hoodId]
	if not ps or not part or Match.phase ~= "Investigation" then
		return
	end
	local position = Match.position(ps)
	if not position or (position - part.Position).Magnitude > Config.INTERACT_RANGE + 2 then
		return
	end
	if Match.hasHood(ps) then
		Match.notify(player, "You are already wearing a hood.", "bad")
		return
	end
	hoods[hoodId] = nil
	part:Destroy()
	wear(ps)
	EventLog.add(string.format("%s put on a hood.", ps.alias), "hood")
	Match.notify(player, Terms.f("Hood on. {Eyes} cannot read your name this round."), "good")
end

function HoodService.onRoundStart(round: number)
	for _, ps in ipairs(Match.living()) do
		if ps.hoodNextRound then
			ps.hoodNextRound = false
			wear(ps)
			Match.notify(ps.player, Terms.f("You wear a hood this round. {Eyes} cannot read your name."), "good")
		end
	end
	if next(hoods) == nil and round >= 1 then
		spawnHood()
	end
end

function HoodService.onRoundEnd(round: number)
	for _, ps in ipairs(Match.list) do
		if ps.hoodRound == round then
			ps.hoodRound = 0
			CharacterService.setHood(ps.player, false)
			Match.pushPrivate(ps)
		end
	end
end

function HoodService.onMatchStart(map)
	hoods = {}
	spawnPoints = map.hoods
	folder = Create("Folder", { Name = "Hoods", Parent = map.model })
end

function HoodService.onMatchEnd()
	hoods = {}
	spawnPoints = {}
	folder = nil
end

function HoodService.init()
	HoodRequest.OnServerEvent:Connect(onRequest)
	CharacterService.CharacterSpawned:Connect(function(player)
		local ps = Match.getLiving(player)
		if ps and Match.hasHood(ps) then
			CharacterService.setHood(player, true)
		end
	end)
end

return HoodService
