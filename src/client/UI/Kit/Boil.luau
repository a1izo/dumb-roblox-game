--!strict
-- Line boil (OMORI's hand-drawn wobble): a drawn thing redraws a hair differently 8 times a second, cycling
-- three states. Each attached object gets its own three small offsets (and a hair of rotation), so a screen
-- full of frames never moves in step. Only drawn lines and big lettering boil, never small text: it would
-- read as a smear (the owner's call, 2026-10-29).
--
--   Boil.attach(frame)          -- 1 px, the default for frames, rules and the hand
--   Boil.attach(title, 2, 0.4)  -- 2 px and up to 0.4 degrees, for big lettering
--
-- When other code moves the object (a layout, a tween), its new place becomes the one it boils around.

local Motion = require(script.Parent.Parent.Core.Motion)

local Boil = {}

local FPS = 8
local STATES = 3

type Entry = {
	base: UDim2,
	rot: number,
	offsets: { Vector2 },
	turns: { number },
	-- what Boil itself last wrote: change events arrive after the change (deferred), so a flag set around the
	-- write is gone by then; an event carrying the value Boil wrote is its own and is ignored, or the wobble would
	-- become the new home and the thing would walk off
	wrotePosition: UDim2?,
	wroteRotation: number?,
}

local entries: { [GuiObject]: Entry } = setmetatable({}, { __mode = "k" }) :: any
local frame = 0

local function place(gui: GuiObject, entry: Entry)
	local index = frame + 1
	local offset = if Motion.isReduced() then Vector2.zero else entry.offsets[index]
	local turn = if Motion.isReduced() then 0 else entry.turns[index]
	local position = entry.base + UDim2.fromOffset(offset.X, offset.Y)
	local rotation = entry.rot + turn
	entry.wrotePosition = position
	entry.wroteRotation = rotation
	gui.Position = position
	gui.Rotation = rotation
end

-- Makes `gui` boil: `amount` px of wander (default 1) and `turn` degrees of tilt at most (default 0).
function Boil.attach(gui: GuiObject, amount: number?, turn: number?)
	if entries[gui] then
		return
	end
	local px = amount or 1
	local tilt = turn or 0
	local random = Random.new()
	local offsets, turns = {}, {}
	for index = 1, STATES do
		-- (the first state sits home, so a still frame is where the layout put it)
		if index == 1 then
			offsets[index] = Vector2.zero
			turns[index] = 0
		else
			offsets[index] = Vector2.new(random:NextInteger(-px, px), random:NextInteger(-px, px))
			turns[index] = random:NextNumber(-tilt, tilt)
		end
	end
	local entry: Entry = { base = gui.Position, rot = gui.Rotation, offsets = offsets, turns = turns }
	entries[gui] = entry
	gui:GetPropertyChangedSignal("Position"):Connect(function()
		if gui.Position ~= entry.wrotePosition then
			entry.base = gui.Position
		end
	end)
	gui:GetPropertyChangedSignal("Rotation"):Connect(function()
		-- (a rotation reads back at lower precision than it was written: compare loosely)
		local wrote = entry.wroteRotation
		if wrote == nil or math.abs(gui.Rotation - wrote) > 1e-3 then
			entry.rot = gui.Rotation
		end
	end)
	gui.Destroying:Once(function()
		entries[gui] = nil
	end)
end

-- Stops `gui` boiling and puts it back where it belongs.
function Boil.detach(gui: GuiObject)
	local entry = entries[gui]
	if entry then
		entries[gui] = nil
		gui.Position = entry.base
		gui.Rotation = entry.rot
	end
end

task.spawn(function()
	while true do
		task.wait(1 / FPS)
		frame = (frame + 1) % STATES
		for gui, entry in pairs(entries) do
			if gui.Parent and gui.Visible then
				place(gui, entry)
			end
		end
	end
end)

return Boil
