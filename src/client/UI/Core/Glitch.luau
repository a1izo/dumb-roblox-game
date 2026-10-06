--!strict
-- The videotape glitch for loud elements: titles, the lobby wordmark, windows as they open, the vote
-- header, results. An element cuts in over half a second (it blinks, jumps sideways, tears, and shows a red
-- and a white ghost of itself), then every couple of seconds it glitches again for a moment.
--
--   local handle = Glitch.attach(canvasGroup, { loop = true })   -- enters now, then blips every ~2 s
--   handle:enter()      -- play the entrance again (a window that was shown)
--   handle:enter(true)  -- the long entrance (about 1.5 s), used when the lobby comes in
--   handle:pulse()      -- one blip now (a toast arrived, an objective was done)
--   handle:hover(true)  -- glitch hard and fast until hover(false) (a hovered button)
--   handle:destroy()
--
-- The look belongs to the lobby only: Glitch.setEnabled(false) (in a match) stops every element at once and
-- nothing glitches until it is turned back on. Attaching to a target that already has an entry shares it, so a
-- hovered button inside a looping wrapper does not fight the wrapper's own blips.
--
-- Parent the target before attaching (an element with no parent is dropped). The target should be a
-- CanvasGroup (it blinks through GroupTransparency); on anything else it only jumps sideways. Ghosts are copies of its children, tinted and shifted, built only for the 0.15 s a blip
-- lasts (not on a target that lays out its children). One Heartbeat connection serves every element, and exists only while there is at least one.
-- The HUD does not loop: its elements only pulse when something changes. Reduced motion turns it all off.

local RunService = game:GetService("RunService")

local Motion = require(script.Parent.Motion)
local UiSound = require(script.Parent.UiSound)
local Screens = require(script.Parent.Parent.Screens)
local Textures = require(script.Parent.Parent.Kit.Textures)
local Tokens = require(script.Parent.Parent.Kit.Tokens)

local Glitch = {}

-- { seconds, how visible (1 = fully), px sideways, px of ghost split, tear bars }
local ENTER = {
	{ 0.00, 0, 0, 0, false },
	{ 0.05, 1, -9, 3, true },
	{ 0.11, 0, 0, 0, false },
	{ 0.17, 1, 7, 2, true },
	{ 0.23, 1, -3, 2, false },
	{ 0.29, 0.25, 0, 0, false },
	{ 0.35, 1, 2, 1, false },
	{ 0.50, 1, 0, 0, false },
}
local BLIP = {
	{ 0.00, 1, -7, 3, true },
	{ 0.04, 1, 6, 2, true },
	{ 0.08, 0.55, -2, 2, false },
	{ 0.12, 1, 0, 0, false },
	{ 0.15, 1, 0, 0, false },
}
-- The long entrance: sparse blinks and tears over about 1.5 s that settle.
local ENTER_LONG = {
	{ 0.00, 0, 0, 0, false },
	{ 0.10, 1, -10, 3, true },
	{ 0.16, 0, 0, 0, false },
	{ 0.30, 0.6, 8, 2, true },
	{ 0.38, 0, 0, 0, false },
	{ 0.55, 1, -6, 3, true },
	{ 0.62, 0.3, 0, 0, false },
	{ 0.80, 1, 4, 2, true },
	{ 0.88, 1, 0, 1, false },
	{ 1.05, 0.5, -3, 2, true },
	{ 1.12, 1, 0, 0, false },
	{ 1.30, 1, 2, 1, false },
	{ 1.50, 1, 0, 0, false },
}
-- While hovered: a fast, heavy cycle that repeats until the hover ends. Hard to read, never gone.
local HOVER = {
	{ 0.00, 0.85, -8, 3, true },
	{ 0.05, 1, 6, 4, true },
	{ 0.10, 0.45, -3, 2, false },
	{ 0.15, 1, 9, 3, true },
	{ 0.20, 0.7, -6, 2, true },
	{ 0.25, 1, 2, 4, false },
	{ 0.30, 0.55, -9, 3, true },
	{ 0.35, 1, 5, 2, false },
}
local HOVER_CYCLE = 0.4
local KEYS = { enter = ENTER, enterLong = ENTER_LONG, blip = BLIP, hover = HOVER }
-- Where the scanline band sits (fraction of the screen height) at each blip step.
local BAND = { 0.12, 0.44, 0.76, 1.1 }

type Entry = {
	target: GuiObject,
	canvas: boolean,
	base: UDim2,
	loop: boolean,
	period: number,
	band: boolean,
	mode: string?,
	started: number,
	nextBlip: number,
	ghosts: { Frame },
	tears: { Frame },
	frameIndex: number,
	token: number,
	hovering: boolean,
	lap: number,
}

local entries: { [Entry]: boolean } = {}
local connection: RBXScriptConnection? = nil
local band: Frame? = nil
local grain: ImageLabel? = nil
local overlayVisible = false
local counter = 0
local enabled = true
local byTarget: { [GuiObject]: Entry } = setmetatable({}, { __mode = "k" }) :: any

local function overlay(): (Frame, ImageLabel?)
	if band == nil then
		local frame = Instance.new("Frame")
		frame.Name = "GlitchBand"
		frame.BackgroundColor3 = Tokens.color.white
		frame.BackgroundTransparency = 0.93
		frame.BorderSizePixel = 0
		frame.Size = UDim2.new(1, 0, 0, 70)
		frame.Visible = false
		frame.ZIndex = 100
		frame.Active = false
		frame.Parent = Screens.overlay
		band = frame
	end
	if grain == nil and Textures.has("UiGrain") then
		local image = Instance.new("ImageLabel")
		image.Name = "GlitchGrain"
		image.BackgroundTransparency = 1
		image.Image = Textures.id("UiGrain")
		image.ScaleType = Enum.ScaleType.Tile
		image.TileSize = UDim2.fromOffset(128, 128)
		image.ImageTransparency = 0.88
		image.Size = UDim2.fromScale(1, 1)
		image.Visible = false
		image.ZIndex = 99
		image.Active = false
		image.Parent = Screens.overlay
		grain = image
	end
	return band :: Frame, grain
end

local function setOverlay(on: boolean, step: number)
	if not on and not overlayVisible then
		return
	end
	local bar, noise = overlay()
	overlayVisible = on
	bar.Visible = on
	if noise then
		noise.Visible = on
	end
	if on then
		bar.Position = UDim2.fromScale(0, BAND[math.clamp(step, 1, #BAND)])
	end
end

-- Is the target actually on screen (every ancestor visible, its ScreenGui enabled)?
local function shown(target: GuiObject): boolean
	local node: Instance? = target
	while node do
		if node:IsA("GuiObject") and not node.Visible then
			return false
		elseif node:IsA("ScreenGui") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

local function tint(root: Instance, color: Color3)
	local function paint(item: Instance)
		if item:IsA("ImageLabel") or item:IsA("ImageButton") then
			item.ImageColor3 = color
		end
		if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
			item.TextColor3 = color
		end
		if item:IsA("GuiObject") and item.BackgroundTransparency < 1 then
			item.BackgroundColor3 = color
		end
		if item:IsA("UIStroke") then
			item.Color = color
		end
	end
	paint(root)
	for _, item in ipairs(root:GetDescendants()) do
		paint(item)
	end
end

-- A tinted copy of everything inside the target, drawn behind it.
local function makeGhost(entry: Entry, color: Color3): Frame
	local holder = Instance.new("Frame")
	holder.Name = "GlitchGhost"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromScale(1, 1)
	holder.ZIndex = 0
	holder.Active = false
	for _, child in ipairs(entry.target:GetChildren()) do
		if child:IsA("GuiObject") and child.Name ~= "GlitchGhost" and child.Name ~= "GlitchTear" then
			local copy = child:Clone()
			if copy then
				copy.Parent = holder
			end
		end
	end
	tint(holder, color)
	holder.Parent = entry.target
	return holder
end

local function clearEffects(entry: Entry)
	for _, ghost in ipairs(entry.ghosts) do
		ghost:Destroy()
	end
	table.clear(entry.ghosts)
	for _, tear in ipairs(entry.tears) do
		tear:Destroy()
	end
	table.clear(entry.tears)
end

local function rest(entry: Entry)
	local target = entry.target
	target.Position = entry.base
	if entry.canvas then
		(target :: CanvasGroup).GroupTransparency = 0
	end
	clearEffects(entry)
end

local function start(entry: Entry, mode: string, now: number)
	if Motion.isReduced() or not enabled then
		return
	end
	if entry.mode == nil then
		-- The element may have moved since its last glitch (a new layout): rest where it is now.
		entry.base = entry.target.Position
	end
	rest(entry)
	entry.base = entry.target.Position
	entry.mode = mode
	if entry.canvas and (mode == "enter" or mode == "enterLong") then
		-- An entrance starts from nothing (no frame of the finished element before the first cut).
		(entry.target :: CanvasGroup).GroupTransparency = 1
	end
	UiSound.play("glitch")
	entry.started = now
	entry.frameIndex = 0
	entry.token += 1
end

local function apply(entry: Entry, keys: { { any } }, elapsed: number)
	local index = 1
	for i, key in ipairs(keys) do
		if key[1] <= elapsed then
			index = i
		end
	end
	if index == entry.frameIndex then
		return
	end
	entry.frameIndex = index
	local _, visible, dx, split, tear = table.unpack(keys[index])
	local target = entry.target
	target.Position = entry.base + UDim2.fromOffset(dx, 0)
	if entry.canvas then
		(target :: CanvasGroup).GroupTransparency = 1 - visible
	end
	clearEffects(entry)
	-- Ghosts and tears are added inside the target, so a target that lays out its children only blinks
	-- and jumps (they would be taken for list items, and would make an auto-sized target grow). Only a
	-- CanvasGroup can blink.
	local plain = target:FindFirstChildWhichIsA("UIGridStyleLayout") == nil
		and target.AutomaticSize == Enum.AutomaticSize.None
	if split > 0 and plain then
		local red = makeGhost(entry, Tokens.color.danger)
		red.Position = UDim2.fromOffset(-split, 0)
		local white = makeGhost(entry, Tokens.color.white)
		white.Position = UDim2.fromOffset(split, 0)
		entry.ghosts = { red, white }
	end
	if tear and plain then
		local height = target.AbsoluteSize.Y
		for n = 1, 2 do
			local bar = Instance.new("Frame")
			bar.Name = "GlitchTear"
			bar.BackgroundColor3 = Tokens.color.white
			bar.BackgroundTransparency = 0.3
			bar.BorderSizePixel = 0
			bar.ZIndex = 50
			bar.Active = false
			local at = ((entry.token * 37 + index * 11 + n * 23) % 100) / 100
			bar.Size = UDim2.new(0.3 + (((entry.token + n) * 17) % 7) / 10, 0, 0, 2 + (n * 2))
			bar.Position = UDim2.new(((index * 13 + n * 29) % 40) / 100 - 0.1, dx * 2, 0, math.floor(height * at))
			bar.Parent = target
			table.insert(entry.tears, bar)
		end
	end
end

local function step()
	local now = os.clock()
	local active = 0
	local bandStep = 1
	for entry in pairs(entries) do
		if not entry.target.Parent then
			entries[entry] = nil
		elseif Motion.isReduced() or not enabled then
			if entry.mode then
				entry.mode = nil
				rest(entry)
			end
		else
			if entry.mode == nil and entry.loop and now >= entry.nextBlip and shown(entry.target) then
				start(entry, "blip", now)
			end
			if entry.mode == "hover" and not shown(entry.target) then
				-- The button went away under the pointer (its window closed): stop.
				entry.mode = nil
				entry.hovering = false
				rest(entry)
			elseif entry.mode == "hover" then
				-- The hover cycle repeats; each lap tears in new places.
				local lap = math.floor((now - entry.started) / HOVER_CYCLE)
				if lap ~= entry.lap then
					entry.lap = lap
					entry.token += 1
					entry.frameIndex = 0
				end
				apply(entry, HOVER, (now - entry.started) % HOVER_CYCLE)
			elseif entry.mode then
				local keys = KEYS[entry.mode] or BLIP
				local elapsed = now - entry.started
				if elapsed >= keys[#keys][1] then
					entry.mode = nil
					rest(entry)
					entry.nextBlip = now + entry.period * (0.9 + 0.2 * ((entry.token * 0.618) % 1))
				else
					apply(entry, keys, elapsed)
					if entry.band or entry.mode ~= "blip" then
						active += 1
					end
					bandStep = math.max(bandStep, math.min(#BAND, 1 + math.floor(elapsed / keys[#keys][1] * #BAND)))
				end
			end
		end
	end
	setOverlay(active > 0, bandStep)
	if next(entries) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

export type Handle = {
	enter: (self: Handle, long: boolean?) -> (),
	pulse: (self: Handle) -> (),
	hover: (self: Handle, on: boolean) -> (),
	destroy: (self: Handle) -> (),
}

export type Options = {
	loop: boolean?, -- blip every couple of seconds (default true)
	band: boolean?, -- its blips also roll the full-screen scan band (default true)
	enter: boolean?, -- play the entrance now (default true)
	long: boolean?, -- the long entrance (about 1.5 s) instead of the short one
	period: number?, -- average seconds between blips
	delay: number?, -- seconds to wait before the entrance (to stagger elements)
}

-- Turns every glitch on or off. Off (in a match) also stops whatever is glitching now.
function Glitch.setEnabled(on: boolean)
	if enabled == on then
		return
	end
	enabled = on
	if not on then
		for entry in pairs(entries) do
			if entry.mode then
				entry.mode = nil
				rest(entry)
			end
		end
		setOverlay(false, 1)
	end
end

function Glitch.isEnabled(): boolean
	return enabled
end

local function hover(entry: Entry, on: boolean)
	entry.hovering = on
	if on then
		entry.lap = -1
		start(entry, "hover", os.clock())
	elseif entry.mode == "hover" then
		entry.mode = nil
		rest(entry)
		entry.nextBlip = os.clock() + entry.period * 0.6
	end
end

local function handleFor(entry: Entry, owner: boolean): Handle
	return {
		enter = function(_self: Handle, long: boolean?)
			if entry.mode ~= "hover" then
				start(entry, if long then "enterLong" else "enter", os.clock())
			end
		end,
		pulse = function(_self: Handle)
			if entry.mode == nil then
				start(entry, "blip", os.clock())
			end
		end,
		hover = function(_self: Handle, on: boolean)
			hover(entry, on)
		end,
		destroy = function(_self: Handle)
			if owner then
				entries[entry] = nil
				if byTarget[entry.target] == entry then
					byTarget[entry.target] = nil
				end
				rest(entry)
			elseif entry.hovering then
				-- A shared handle only ever drives the hover; the owner's entry keeps running.
				hover(entry, false)
			end
		end,
	}
end

function Glitch.attach(target: GuiObject, options: Options?): Handle
	local opts = options or {}
	local existing = byTarget[target]
	if existing and entries[existing] then
		return handleFor(existing, false)
	end
	counter += 1
	-- Every element gets its own rhythm (1.8 to 2.3 s) so they do not fire together.
	local period = (opts.period or Tokens.glitch.period) * (0.86 + 0.24 * ((counter * 0.37) % 1))
	local now = os.clock()
	local entry: Entry = {
		target = target,
		canvas = target:IsA("CanvasGroup"),
		base = target.Position,
		loop = opts.loop ~= false,
		band = opts.band ~= false,
		period = period,
		mode = nil,
		started = now,
		nextBlip = now + 0.9 + ((counter * 0.53) % 1.3),
		ghosts = {},
		tears = {},
		frameIndex = 0,
		token = counter,
		hovering = false,
		lap = -1,
	}
	entries[entry] = true
	byTarget[target] = entry
	if not connection then
		connection = RunService.Heartbeat:Connect(step)
	end
	local handle = handleFor(entry, true)
	if opts.enter ~= false then
		local mode = if opts.long then "enterLong" else "enter"
		if opts.delay and opts.delay > 0 then
			task.delay(opts.delay, function()
				if entries[entry] then
					start(entry, mode, os.clock())
				end
			end)
		else
			start(entry, mode, now)
		end
	end
	return handle
end

return Glitch
