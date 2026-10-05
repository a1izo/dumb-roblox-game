--!strict
-- Small things moving in the wind, only near the camera: the lobby's roots and banners (server
-- Maps/LobbyDecor builds each as a Model tagged LSway: a Hook part and Seg1, Seg2... hanging below it).
-- A gust sweeps through now and then, so the sway swells and eases rather than ticking along like
-- a clock. Nothing here is physical; it only turns parts about their hook, 20 times a second.
-- Reduced motion leaves everything hanging still.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local Settings = require(script.Parent.Parent.UI.Core.Settings)

local WindSway = {}

local TAG = "LSway"
local RADIUS = 170 -- only things within this of the camera move
local MAX_ACTIVE = 56
local STEP = 1 / 20
local GUSTS = { 41, 23, 13 } -- seconds: the wind's own slow rhythm (they never line up)

type Item = {
	model: Model,
	hook: BasePart,
	segments: { BasePart },
	lengths: { number },
	amp: number,
	period: number,
	phase: number,
	cloth: boolean,
	pose: CFrame, -- the hook's CFrame as built
}

local items: { [Model]: Item } = {}
local active: { Item } = {}
local startedAt = os.clock()
local accumulated = 0
local lastPick = 0

local function register(model: Instance)
	if not model:IsA("Model") or items[model] then
		return
	end
	local hook = model:FindFirstChild("Hook")
	if not hook or not hook:IsA("BasePart") then
		return
	end
	local segments, lengths = {}, {}
	local index = 1
	while true do
		local part = model:FindFirstChild("Seg" .. index)
		if not part or not part:IsA("BasePart") then
			break
		end
		table.insert(segments, part)
		table.insert(lengths, part.Size.Y)
		index += 1
	end
	items[model] = {
		model = model,
		hook = hook,
		segments = segments,
		lengths = lengths,
		amp = tonumber(model:GetAttribute("Amp")) or math.rad(4),
		period = tonumber(model:GetAttribute("Period")) or 5,
		phase = tonumber(model:GetAttribute("Phase")) or 0,
		cloth = model:GetAttribute("Cloth") == true,
		pose = hook.CFrame,
	}
end

local function unregister(model: Instance)
	if model:IsA("Model") then
		items[model] = nil
	end
end

-- The wind's strength now, 0.6 to 1.5.
local function gust(t: number): number
	local sum = 0
	for i, period in ipairs(GUSTS) do
		sum += math.sin(2 * math.pi * t / period + i * 1.9)
	end
	return 1.05 + 0.45 * sum / #GUSTS
end

local function pose(item: Item, t: number, g: number)
	local cf = item.pose
	local w = 2 * math.pi / item.period
	for index, part in ipairs(item.segments) do
		local lag = index * 0.55
		local swing = item.amp * g * math.sin(w * t + item.phase - lag)
		local across = item.amp * 0.6 * g * math.sin(w * 0.8 * t + item.phase * 1.3 - lag)
		local twist = if item.cloth then item.amp * 0.5 * g * math.sin(w * 1.7 * t + item.phase) else 0
		cf = cf * CFrame.Angles(across, twist, swing)
		part.CFrame = cf * CFrame.new(0, -item.lengths[index] / 2, 0)
		cf = cf * CFrame.new(0, -item.lengths[index], 0)
	end
end

local function still(item: Item)
	local cf = item.pose
	for index, part in ipairs(item.segments) do
		part.CFrame = cf * CFrame.new(0, -item.lengths[index] / 2, 0)
		cf = cf * CFrame.new(0, -item.lengths[index], 0)
	end
end

-- The things near the camera, nearest first.
local function pick()
	local camera = workspace.CurrentCamera
	table.clear(active)
	if not camera then
		return
	end
	local at = camera.CFrame.Position
	local near = {}
	for _, item in pairs(items) do
		local distance = (item.pose.Position - at).Magnitude
		if distance <= RADIUS then
			table.insert(near, { item = item, distance = distance })
		end
	end
	table.sort(near, function(a, b)
		return a.distance < b.distance
	end)
	for index = 1, math.min(#near, MAX_ACTIVE) do
		table.insert(active, near[index].item)
	end
end

function WindSway.init()
	for _, model in ipairs(CollectionService:GetTagged(TAG)) do
		register(model)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(function(model)
		-- Its parts arrive with it (or just after); register once they have.
		task.defer(register, model)
	end)
	CollectionService:GetInstanceRemovedSignal(TAG):Connect(unregister)
	Settings.Changed:Connect(function(key)
		if key == "reduceMotion" and Settings.get("reduceMotion") then
			for _, item in pairs(items) do
				still(item)
			end
		end
	end)
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated < STEP then
			return
		end
		accumulated = 0
		local now = os.clock()
		if now - lastPick > 0.5 then
			lastPick = now
			pick()
		end
		if #active == 0 or Settings.get("reduceMotion") then
			return
		end
		local t = now - startedAt
		local g = gust(t)
		for _, item in ipairs(active) do
			if item.model.Parent then
				pose(item, t, g)
			end
		end
	end)
end

return WindSway
