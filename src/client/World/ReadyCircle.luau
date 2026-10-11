--!strict
-- The ring of candles at the middle of the lobby's plaza: one burns for each player who is ready, so anyone
-- can see how near the next case is without reading a word. When the countdown runs, the lit ones flare.
-- The candles are the server's (Maps/LobbyFixtures: Models tagged LReadyCandle, numbered by their Index
-- attribute, each with a "Flame" part holding a PointLight); the lobby state every client already has
-- says how many to light.

local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")

local ClientState = require(script.Parent.Parent.ClientState)
local Settings = require(script.Parent.Parent.UI.Core.Settings)

local ReadyCircle = {}

local TAG = "LReadyCandle"
local CALM = { brightness = 0.9, range = 9 }
local FLARE = { brightness = 2.4, range = 15 }

local candles: { [Model]: number } = {}
local lit: { [Model]: boolean } = {}

local function flameOf(model: Model): (BasePart?, PointLight?)
	local flame = model:FindFirstChild("Flame")
	if not flame or not flame:IsA("BasePart") then
		return nil, nil
	end
	return flame, flame:FindFirstChildOfClass("PointLight")
end

local function set(model: Model, on: boolean, flare: boolean)
	local flame, light = flameOf(model)
	if not flame or not light then
		return
	end
	local look = if flare then FLARE else CALM
	if lit[model] ~= on then
		lit[model] = on
		light.Enabled = on
		if Settings.get("reduceMotion") then
			flame.Transparency = if on then 0 else 1
		else
			TweenService:Create(flame, TweenInfo.new(0.35), { Transparency = if on then 0 else 1 }):Play()
		end
	end
	if on then
		TweenService:Create(light, TweenInfo.new(0.4), { Brightness = look.brightness, Range = look.range }):Play()
	end
end

-- How many candles burn for this lobby state (never more than there are).
function ReadyCircle.count(lobby: any, candleCount: number): number
	if type(lobby) ~= "table" or type(lobby.readyCount) ~= "number" then
		return 0
	end
	return math.clamp(math.floor(lobby.readyCount), 0, candleCount)
end

local function refresh()
	local total = 0
	for _ in pairs(candles) do
		total += 1
	end
	local lobby = ClientState.lobby
	local count = ReadyCircle.count(lobby, total)
	local flare = lobby ~= nil and lobby.countdown ~= nil
	for model, index in pairs(candles) do
		set(model, index <= count, flare)
	end
end

local function register(item: Instance)
	if item:IsA("Model") and candles[item] == nil then
		local index = item:GetAttribute("Index")
		if type(index) == "number" then
			candles[item] = index
			refresh()
		end
	end
end

function ReadyCircle.init()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(register)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(item: Instance)
		candles[item :: Model] = nil
		lit[item :: Model] = nil
	end)
	for _, item in ipairs(CollectionService:GetTagged(TAG)) do
		register(item)
	end
	ClientState.LobbyChanged:Connect(refresh)
	refresh()
end

return ReadyCircle
