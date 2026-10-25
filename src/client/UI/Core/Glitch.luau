--!strict
-- The videotape glitch, kept for a few loud moments of the lobby. An element cuts in (it blinks, jumps
-- sideways, tears, and shows a red and a white ghost of itself); the two that loop (the wordmark and the red
-- "Diavolo" of the quote) glitch again for a moment every few seconds. Everything else stays still.
--
--   local handle = Glitch.attach(canvasGroup, { loop = true })   -- enters now, then blips every ~6 s
--   handle:enter()      -- play the entrance again
--   handle:enter(true)  -- the long entrance (about 1.5 s), used when the lobby comes in
--   handle:pulse()      -- one blip now
--   handle:hover(true)  -- one short blip as the pointer arrives (a hovered button); hover(false) lets it finish
--   handle:destroy()
--
-- The look belongs to the lobby only: Glitch.setEnabled(false) (in a match) stops every element at once and
-- nothing glitches until it is turned back on. Attaching to a target that already has an entry shares it, so a
-- hovered button inside a looping wrapper does not fight the wrapper's own blips.
--
-- While a window is open the lobby behind it goes quiet (Glitch.setQuiet): no blip starts by itself. There is
-- no full-screen scan band any more; a faint film grain shows over the screen only while something cuts in.
-- A hovered button's tear bars are drawn behind it, never across its lettering.
--
-- Parent the target before attaching (an element with no parent is dropped). The target should be a
-- CanvasGroup (it blinks through GroupTransparency); on anything else it only jumps sideways. Ghosts are
-- copies of its children, tinted and shifted, built only for the 0.15 s a blip lasts (not on a target that
-- lays out its children). One Heartbeat connection serves every element, and exists only while there is at
-- least one. Reduced motion turns it all off.

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
-- A hovered button blips once, the same short blip (its tears drawn behind the lettering).
local KEYS = { enter = ENTER, enterLong = ENTER_LONG, blip = BLIP, hoverBlip = BLIP }
local GRAIN_TRANSPARENCY = 0.94

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
}

local entries: { [Entry]: boolean } = {}
local connection: RBXScriptConnection? = nil
local grain: ImageLabel? = nil
local overlayVisible = false
local counter = 0
local enabled = true
local quiet = false
local byTarget: { [GuiObject]: Entry } = setmetatable({}, { __mode = "k" }) :: any

local function overlay(): ImageLabel?
	if grain == nil and Textures.has("UiGrain") then
		local image = Instance.new("ImageLabel")
		image.Name = "GlitchGrain"
		image.BackgroundTransparency = 1
		image.Image = Textures.id("UiGrain")
		image.ScaleType = Enum.ScaleType.Tile
		image.TileSize = UDim2.fromOffset(128, 128)
		image.ImageTransparency = GRAIN_TRANSPARENCY
		image.Size = UDim2.fromScale(1, 1)
		image.Visible = false
		image.ZIndex = 99
		image.Active = false
		image.Parent = Screens.overlay
		grain = image
	end
	return grain
end

local function setOverlay(on: boolean)
	if not on and not overlayVisible then
		return
	end
	overlayVisible = on
	local noise = overlay()
	if noise then
		noise.Visible = on
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
	-- The copies already carry the redrawn letters (FontMirror leaves them be).
	holder:SetAttribute("KeepFont", true)
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
	if Motion.isReduced() or Motion.isLow() or not enabled then
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
			-- Over the element as it cuts in or blips; behind it when it is hovered, so the bars never
			-- cross the lettering of the thing about to be pressed.
			bar.ZIndex = if entry.mode == "hoverBlip" then 0 else 50
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
	for entry in pairs(entries) do
		if not entry.target.Parent then
			entries[entry] = nil
		elseif Motion.isReduced() or Motion.isLow() or not enabled then
			if entry.mode then
				entry.mode = nil
				rest(entry)
			end
		else
			if entry.mode == nil and entry.loop and not quiet and now >= entry.nextBlip and shown(entry.target) then
				start(entry, "blip", now)
			end
			if entry.mode then
				local keys = KEYS[entry.mode] or BLIP
				local elapsed = now - entry.started
				if elapsed >= keys[#keys][1] then
					entry.mode = nil
					rest(entry)
					entry.nextBlip = now + entry.period * (0.9 + 0.2 * ((entry.token * 0.618) % 1))
				else
					apply(entry, keys, elapsed)
					-- The grain shows while something cuts in, or while an element that asks for it blips.
					if entry.mode == "enter" or entry.mode == "enterLong" or (entry.band and entry.mode == "blip") then
						active += 1
					end
				end
			end
		end
	end
	setOverlay(active > 0 and not quiet)
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
	loop: boolean?, -- blip every few seconds (default true)
	band: boolean?, -- its blips also show the film grain over the screen (default true)
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
		setOverlay(false)
	end
end

function Glitch.isEnabled(): boolean
	return enabled
end

-- Quiet (a window is open): no blip starts by itself and the grain stays off. Blips already running play
-- out their fraction of a second.
function Glitch.setQuiet(on: boolean)
	quiet = on
end

-- The pointer arrives: one short blip (unless the element is already glitching). Leaving lets it finish.
local function hover(entry: Entry, on: boolean)
	entry.hovering = on
	if on and entry.mode == nil then
		start(entry, "hoverBlip", os.clock())
	end
end

local function handleFor(entry: Entry, owner: boolean): Handle
	return {
		enter = function(_self: Handle, long: boolean?)
			if entry.mode ~= "hoverBlip" then
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
	-- Every element gets its own rhythm (about 5 to 6.6 s) so they do not fire together.
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
