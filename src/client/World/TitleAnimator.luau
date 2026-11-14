--!strict
-- Plays the moving titles (Shared/TitleMotion): every TextLabel tagged TitleMotion.TAG whose TitleId attribute names
-- a title with a motion is moved here, on this screen only (the server draws the tag over the head; the shop card and
-- Your look draw their own). Reduced motion stills them all, back to how they were drawn. A label's look when it is
-- registered is its rest; the motion only ever leans away from it and comes back.
--
--   flicker    a candle: the letters dim and warm unevenly, gutter twice every few seconds
--   chalk      written on letter by letter, held, wiped, written again
--   heartbeat  a double pulse (lub-dub) every beat and a half, the edge warming with it
--   shiver     still, then a cold tremble for half a second, every few seconds
--   afterglow  a slow breath of light: the edge glowing in the tier's colour and fading

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local TitleMotion = require(Shared:WaitForChild("TitleMotion"))
local Motion = require(script.Parent.Parent.UI.Core.Motion)

local TitleAnimator = {}

local WARM = Color3.fromRGB(255, 206, 150)
local COLD = Color3.fromRGB(186, 214, 236)
local WHITE = Color3.new(1, 1, 1)
local SCALE_NAME = "TitleBeat"

type Rest = {
	color: Color3,
	transparency: number,
	stroke: number,
	strokeColor: Color3,
	position: UDim2,
}
type Entry = {
	label: TextLabel,
	kind: TitleMotion.Kind,
	tint: Color3,
	rest: Rest,
	phase: number,
}

local entries: { [TextLabel]: Entry } = {}
local watched: { [TextLabel]: RBXScriptConnection } = {}
local stilled = false

local function rest(label: TextLabel): Rest
	return {
		color = label.TextColor3,
		transparency = label.TextTransparency,
		stroke = label.TextStrokeTransparency,
		strokeColor = label.TextStrokeColor3,
		position = label.Position,
	}
end

-- Puts a label back as it was drawn (keepColour: its owner has just given it a new colour of its own: leave that).
local function settle(e: Entry, keepColour: boolean?)
	local label = e.label
	if not keepColour then
		label.TextColor3 = e.rest.color
	end
	label.TextTransparency = e.rest.transparency
	label.TextStrokeTransparency = e.rest.stroke
	label.TextStrokeColor3 = e.rest.strokeColor
	label.Position = e.rest.position
	label.MaxVisibleGraphemes = -1
	local scale = label:FindFirstChild(SCALE_NAME)
	if scale then
		scale:Destroy()
	end
end

local function register(label: TextLabel)
	local id = label:GetAttribute("TitleId")
	local kind = TitleMotion.of(if type(id) == "string" then id else nil)
	if not kind then
		return
	end
	local item = Cosmetics.byId(id :: string)
	entries[label] = {
		label = label,
		kind = kind,
		tint = Rarity.color(if item then item.rarity else nil),
		rest = rest(label),
		phase = math.random() * 10,
	}
end

local function drop(label: TextLabel, keepColour: boolean?)
	local e = entries[label]
	if e then
		entries[label] = nil
		if label.Parent then
			settle(e, keepColour)
		end
	end
end

local function watch(item: Instance)
	if not item:IsA("TextLabel") or watched[item] then
		return
	end
	local label = item :: TextLabel
	-- (its title changes: whoever changed it has drawn the new one; start again from that)
	watched[label] = label:GetAttributeChangedSignal("TitleId"):Connect(function()
		drop(label, true)
		register(label)
	end)
	register(label)
end

local function unwatch(item: Instance)
	if not item:IsA("TextLabel") then
		return
	end
	local label = item :: TextLabel
	drop(label)
	local connection = watched[label]
	if connection then
		connection:Disconnect()
		watched[label] = nil
	end
end

local function pulse(x: number, at: number, width: number): number
	return math.exp(-((x - at) / width) ^ 2)
end

local function step(e: Entry, t: number)
	local label, r = e.label, e.rest
	if e.kind == "flicker" then
		local n = (math.sin(t * 7.3) + 0.7 * math.sin(t * 11.9 + 1.3) + 0.5 * math.sin(t * 3.1 + 2.2)) / 2.2
		local dip = math.max(0, n) ^ 2 * 0.35
		local g = t % 5.3
		if g < 0.1 or (g > 0.18 and g < 0.25) then
			dip = 0.65 -- (the flame gutters)
		end
		label.TextTransparency = r.transparency + (1 - r.transparency) * dip
		label.TextColor3 = r.color:Lerp(WARM, 0.12 + 0.12 * (n * 0.5 + 0.5))
	elseif e.kind == "chalk" then
		local p = t % 9
		local count = utf8.len(label.ContentText) or #label.ContentText
		if p < 2.2 then
			label.MaxVisibleGraphemes = math.floor(count * p / 2.2)
			label.TextTransparency = r.transparency
		elseif p < 8.3 then
			label.MaxVisibleGraphemes = -1
			label.TextTransparency = r.transparency
		else
			label.MaxVisibleGraphemes = -1
			label.TextTransparency = r.transparency + (1 - r.transparency) * math.clamp((p - 8.3) / 0.6, 0, 1)
		end
	elseif e.kind == "heartbeat" then
		local p = t % 1.5
		local beat = math.max(pulse(p, 0.0, 0.07), pulse(p, 1.5, 0.07)) + 0.6 * pulse(p, 0.24, 0.07)
		local scale = label:FindFirstChild(SCALE_NAME) :: UIScale?
		if not scale then
			local made = Instance.new("UIScale")
			made.Name = SCALE_NAME
			made.Parent = label
			scale = made
		end
		(scale :: UIScale).Scale = 1 + 0.12 * beat
		label.TextStrokeColor3 = r.strokeColor:Lerp(e.tint, 0.55 * beat)
	elseif e.kind == "shiver" then
		local p = t % 3.4
		local env = if p < 0.55 then math.sin(math.pi * p / 0.55) else 0
		-- (pixel offsets are whole pixels: the tremble is two either way, rounded)
		label.Position = r.position
			+ UDim2.fromOffset(math.round(math.sin(t * 95) * 2.4 * env), math.round(math.sin(t * 71 + 1) * 1.2 * env))
		label.TextColor3 = r.color:Lerp(COLD, 0.1 + 0.3 * env)
	elseif e.kind == "afterglow" then
		local g = 0.5 + 0.5 * math.sin(t * math.pi * 2 / 4.2)
		label.TextStrokeColor3 = r.strokeColor:Lerp(e.tint, 0.25 + 0.6 * g)
		label.TextStrokeTransparency = r.stroke * (1 - 0.5 * g)
		label.TextColor3 = r.color:Lerp(WHITE, 0.22 * g)
	end
end

function TitleAnimator.init()
	CollectionService:GetInstanceAddedSignal(TitleMotion.TAG):Connect(watch)
	CollectionService:GetInstanceRemovedSignal(TitleMotion.TAG):Connect(unwatch)
	for _, item in ipairs(CollectionService:GetTagged(TitleMotion.TAG)) do
		watch(item)
	end
	RunService.RenderStepped:Connect(function()
		if Motion.isReduced() then
			if not stilled then
				stilled = true
				for _, e in pairs(entries) do
					settle(e)
				end
			end
			return
		end
		stilled = false
		local now = os.clock()
		for label, e in pairs(entries) do
			if not label.Parent then
				entries[label] = nil
			elseif label.Visible then
				step(e, now + e.phase)
			end
		end
	end)
end

return TitleAnimator
