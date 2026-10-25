--!strict
-- The ring of candles at the middle of the lobby's plaza: one burns for each player who is ready, so anyone
-- can see how near the next case is without reading a word. A candle catches with a small flare at its wick, and
-- goes out with a curl of smoke; when the countdown runs, the lit ones burn taller and brighter.
-- The candles are the server's (Maps/LobbyFixtures: Models tagged LReadyCandle, numbered by their Index
-- attribute, each with an unseen "Flame" part at its wick, its attribute Height the flame's); the flames are this
-- client's own (Presentation/Vfx Recipes.flame); the lobby state every client already has says how many to light.

local CollectionService = game:GetService("CollectionService")

local ClientState = require(script.Parent.Parent.ClientState)
local Vfx = require(script.Parent.Parent.Presentation.Vfx)

local ReadyCircle = {}

local TAG = "LReadyCandle"

type Candle = { index: number, flame: any, lit: boolean, flaring: boolean }

local candles: { [Model]: Candle } = {}

local function set(candle: Candle, on: boolean, flare: boolean)
	if candle.lit ~= on then
		candle.lit = on
		if on then
			candle.flame.set(1, 0.4)
		else
			candle.flame.out()
		end
	end
	local burning = on and flare
	if candle.flaring ~= burning then
		candle.flaring = burning
		candle.flame.flare(burning)
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
	for _, candle in pairs(candles) do
		set(candle, candle.index <= count, flare)
	end
end

local function register(item: Instance)
	if not item:IsA("Model") or candles[item] ~= nil then
		return
	end
	local index = item:GetAttribute("Index")
	local wick = item:WaitForChild("Flame", 10)
	if type(index) ~= "number" or not wick or not wick:IsA("BasePart") or candles[item] ~= nil then
		return
	end
	local height = wick:GetAttribute("Height")
	candles[item] = {
		index = index,
		flame = Vfx.Recipes.flame(wick, {
			kind = "candle",
			scale = if type(height) == "number" then height else 0.55,
			lit = false,
			lightRange = 10,
			lightBrightness = 0.75,
		}),
		lit = false,
		flaring = false,
	}
	refresh()
end

-- (for checks: the candles lit now)
function ReadyCircle.lit(): number
	local n = 0
	for _, candle in pairs(candles) do
		if candle.lit then
			n += 1
		end
	end
	return n
end

function ReadyCircle.init()
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(item)
		task.spawn(register, item)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(item: Instance)
		local candle = candles[item :: Model]
		if candle then
			candle.flame.destroy()
			candles[item :: Model] = nil
		end
	end)
	for _, item in ipairs(CollectionService:GetTagged(TAG)) do
		task.spawn(register, item)
	end
	ClientState.LobbyChanged:Connect(refresh)
	refresh()
end

return ReadyCircle
