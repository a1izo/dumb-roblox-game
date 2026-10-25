-- Small profile changes a player makes from the menus, all through one remote
-- (ProfileRequest): settings now, and later hints seen, the custom alias, streak claims,
-- title choice and training progress. Every action is validated and rate-limited here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared:WaitForChild("Bindings"))
local Config = require(Shared:WaitForChild("Config"))
local Hints = require(Shared:WaitForChild("Hints"))
local Net = require(Shared:WaitForChild("Net"))
local Trial = require(Shared:WaitForChild("Trial"))

local Analytics = require(script.Parent.Analytics)
local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local ProfileRequest = Net.event("ProfileRequest")

local ProfileService = {}

-- Allowed settings: numbers are clamped to their range, booleans must be booleans.
local SETTINGS = {
	music = { min = 0, max = 1 },
	sfx = { min = 0, max = 1 },
	ambience = { min = 0, max = 1 },
	ui = { min = 0, max = 1 },
	uiScale = { min = 0.8, max = 1.25 },
	reduceMotion = "boolean",
	cameraShake = "boolean",
	hints = "boolean",
	lowGraphics = "boolean",
	emoteMusic = "boolean",
	emoteCamera = "boolean",
	emoteCutscenes = "boolean",
	master = { min = 0, max = 1 },
	fov = { min = 60, max = 100 },
	brightness = { min = -0.3, max = 0.3 },
	screenFlashes = "boolean",
	showFps = "boolean",
	showHud = "boolean",
	weather = "boolean",
	nameTags = "boolean",
	chatBubbles = "boolean",
	otherAuras = "boolean",
	otherEmoteFx = "boolean",
}

local function setSettings(player: Player, payload)
	local data = DataService.get(player)
	if not data or type(payload.values) ~= "table" then
		return
	end
	local changed = false
	for key, rule in pairs(SETTINGS) do
		local value = payload.values[key]
		if value ~= nil then
			if rule == "boolean" then
				if type(value) == "boolean" then
					data.settings[key] = value
					changed = true
				end
			elseif type(value) == "number" and value == value then
				data.settings[key] = math.clamp(value, rule.min, rule.max)
				changed = true
			end
		end
	end
	if changed then
		DataService.push(player)
		DataService.saveSoon(player)
	end
end

-- A one-time hint was shown; remember it so it never shows again.
local function hintSeen(player: Player, payload)
	local data = DataService.get(player)
	if not data or type(payload.id) ~= "string" or not Hints.BY_ID[payload.id] then
		return
	end
	if not data.tipsSeen[payload.id] then
		data.tipsSeen[payload.id] = true
		DataService.push(player)
		DataService.saveSoon(player)
	end
end

local function resetHints(player: Player)
	local data = DataService.get(player)
	if data then
		data.tipsSeen = {}
		DataService.push(player)
		DataService.saveSoon(player)
	end
end

-- An Academy drill was finished. The drills run on the client. Finishing all seven earns the title
-- Trainee; the Academy's coins are paid for the Trial (below), once per profile.
local function drillDone(player: Player, payload)
	local data = DataService.get(player)
	if not data or type(payload.drill) ~= "string" or not table.find(Config.TRAINING_DRILLS, payload.drill) then
		return
	end
	if Match.getLiving(player) then
		return
	end
	data.training.drills[payload.drill] = true
	if not data.training.done then
		local all = true
		for _, drill in ipairs(Config.TRAINING_DRILLS) do
			if not data.training.drills[drill] then
				all = false
			end
		end
		if all then
			Trial.drillsFinished(data)
			Analytics.step(player, "academy")
			data.titles.trainee = true
			Match.notify(player, "Every drill done: the title Trainee is yours.", "good")
		end
	end
	DataService.push(player)
	DataService.saveSoon(player)
end

-- The Trial (Shared/Trial): its steps run on the client, like the drills, so the reward is small and paid
-- once per profile. event "skip": the offer was turned down; "done": it was finished.
local function trialEvent(player: Player, payload)
	local data = DataService.get(player)
	if not data or Match.getLiving(player) then
		return
	end
	if payload.event == "skip" then
		if not Trial.skip(data) then
			return
		end
	elseif payload.event == "done" then
		local first = not data.trial.done
		local paid = Trial.finish(data, Config.TRAINING_REWARD)
		if paid > 0 then
			Analytics.coins(player, paid, data.coins, "Onboarding", "Trial")
			Match.notify(player, string.format("The Trial is done. +%d coins.", paid), "good")
		elseif first then
			Match.notify(player, "The Trial is done.", "good")
		end
	else
		return
	end
	DataService.push(player)
	DataService.saveSoon(player)
end

-- How far the Trial got (payload.step: steps done), saved so a rejoin carries on from there. Quietly: the
-- client already knows, so nothing is pushed back. Its own action, so it never eats the "done" event's turn.
local function trialStep(player: Player, payload)
	local data = DataService.get(player)
	if not data or Match.getLiving(player) then
		return
	end
	if Trial.advance(data, payload.step) then
		DataService.saveSoon(player)
	end
end

-- action -> { cooldown in seconds, handler }
local ACTIONS: { [string]: { cooldown: number, handler: (Player, any) -> () } } = {
	settings = { cooldown = 0.5, handler = setSettings },
	hint = { cooldown = 0.2, handler = hintSeen },
	resetHints = { cooldown = 2, handler = resetHints },
	training = { cooldown = 1, handler = drillDone },
	trial = { cooldown = 1, handler = trialEvent },
	trialStep = { cooldown = 0.5, handler = trialStep },
	-- ProfileRequest "keybinds": { keybinds = { keyboard = { [action] = { key names } }, gamepad = ... } }, the
	-- player's whole set (Settings sends it once a change is made); cleaned by Shared/Bindings, so only known
	-- actions, real keys and no reserved ones are kept. An empty set means the defaults.
	keybinds = {
		cooldown = 0.5,
		handler = function(player: Player, payload)
			local data = DataService.get(player)
			if not data then
				return
			end
			data.keybinds = Bindings.clean(payload.keybinds)
			DataService.push(player)
			DataService.saveSoon(player)
		end,
	},
}

-- Other services add their actions here (for example hints or the custom alias).
function ProfileService.register(action: string, cooldown: number, handler: (Player, any) -> ())
	ACTIONS[action] = { cooldown = cooldown, handler = handler }
end

function ProfileService.init()
	ProfileRequest.OnServerEvent:Connect(function(player: Player, payload)
		if type(payload) ~= "table" or type(payload.action) ~= "string" then
			return
		end
		local entry = ACTIONS[payload.action]
		if not entry or not RateLimit.allow(player, "profile:" .. payload.action, entry.cooldown) then
			return
		end
		entry.handler(player, payload)
	end)
end

return ProfileService
