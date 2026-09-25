-- Game pass ownership, looked up once per player (with retries) and cached. A purchase made
-- during the session counts at once. Passes with id 0 are not set up and never owned
-- (except the ones listed in Config.STUDIO_PASSES while testing in Studio).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Products = require(Shared:WaitForChild("Products"))
local Signal = require(Shared:WaitForChild("Signal"))

local PassService = {}

-- Fired as (player, passKey) when a player gains a pass.
PassService.Changed = Signal.new()

local owned: { [Player]: { [string]: boolean } } = {}

local function lookup(player: Player, pass: Products.Pass): boolean
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
		end)
		if ok then
			return result == true
		end
		task.wait(attempt)
	end
	return false
end

local function load(player: Player)
	local set = {}
	owned[player] = set
	if RunService:IsStudio() then
		for _, key in ipairs(Config.STUDIO_PASSES or {}) do
			set[key] = true
		end
	end
	for _, pass in ipairs(Products.PASSES) do
		if pass.id ~= 0 and not set[pass.key] then
			task.spawn(function()
				if lookup(player, pass) and owned[player] == set then
					set[pass.key] = true
					PassService.Changed:Fire(player, pass.key)
				end
			end)
		end
	end
end

-- Debug panel: gives or takes a pass for this session (nothing is bought or saved).
function PassService.debugSet(player: Player, key: string, on: boolean)
	local set = owned[player]
	if not set then
		set = {}
		owned[player] = set
	end
	set[key] = if on then true else nil
	if on then
		PassService.Changed:Fire(player, key)
	end
end

function PassService.owns(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end

-- The keys of every pass the player owns.
function PassService.list(player: Player): { string }
	local keys = {}
	for key, has in pairs(owned[player] or {}) do
		if has then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	return keys
end

function PassService.init()
	Players.PlayerAdded:Connect(load)
	for _, player in ipairs(Players:GetPlayers()) do
		load(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
	end)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local pass = Products.passById(passId)
		if purchased and pass and owned[player] then
			owned[player][pass.key] = true
			PassService.Changed:Fire(player, pass.key)
		end
	end)
end

return PassService
