-- One card on Death's table (the shop, "Death's hand"): tarot-shaped, the thing itself as a big picture,
-- its name in Melodrama and its price in a plain coin chip. Its tier (Shared/Rarity) is in its frame and its
-- colour, and written at the foot of the picture, so it never rests on colour alone:
--
--   Scrawl     a thin ash line
--   Penned     a slate-blue line and a stroke under the picture
--   Sealed     a violet frame inside the edge, ornate corners
--   Condemned  that frame in amber, the grain of an old page, a slow shine passing over it
--   Godhood    a crimson edge glowing in from it, and motes of page drifting up
--   (no shine and no drifting under reduced motion)
--
-- Objects (hats, ties, Manual covers) are a small 3D view, and so are the styles and forms that
-- have a prop of their own once the Core models are imported (a quill, a gavel, a chess king, a crow
-- cloak...); an emote is a small pale mannequin caught in its move (Shop/PoseFigure), with its props; the
-- rest is a still: their glyph, or their words. Picked, the card lifts. A card of Today's hand can lie face
-- down (the back of the deck) and be turned over. A card new to the shop wears a "New" ribbon until it is
-- seen, the day's deal a "25% off" one, and a card not yet owned has a heart to put it on the wishlist.
--
--   local card = Card.new(item, { Parent = slot, chip = "300", onPick = fn, isNew = true, onWish = fn })
--   card:setPicked(true)  card:setChip("Worn")  card:turn(fn)  card:setNew(false)  card:setWished(true)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local CosmeticBuild = require(Shared:WaitForChild("CosmeticBuild"))
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))
local Rarity = require(Shared:WaitForChild("Rarity"))

local Kit = require(script.Parent.Parent.Kit)
local Motion = require(script.Parent.Parent.Core.Motion)
local Textures = require(script.Parent.Parent.Kit.Textures)
local PoseFigure = require(script.Parent.PoseFigure)

local C = Kit.color
local T = Kit.Tokens

local Card = {}
Card.__index = Card

Card.WIDTH = 150
Card.HEIGHT = 236
local LIFT = 10 -- px a picked card rises
local PICTURE = 118 -- the picture's height
local FOV = 28
local HEART_HIT = 40 -- px, the heart's button
local CHIP_ICONS = { "coin", "check", "lock" }

-- The still for kinds with no 3D view: an icon (styles and emotes come in suits of their own).
local STILL_ICON = {
	writing = "quill",
	verdict = "zero",
	death = "skull",
	emote = "palm",
	specter = "ghost",
}

export type Card = typeof(setmetatable(
	{} :: {
		item: Cosmetics.Item,
		slot: Frame,
		face: Frame,
		back: Frame?,
		chip: TextLabel,
		chipIcons: { [string]: GuiObject },
		edge: UIStroke,
		picked: boolean,
		hit: TextButton,
		faceDown: boolean,
		ribbon: Frame?,
		heart: ImageButton?,
		wished: boolean,
		figure: Model?,
		stopLive: (() -> ())?,
		hovered: boolean,
	},
	Card
))

-- How strongly a card's outer edge shows while it is not picked (a Scrawl's faintly).
local function restingEdge(rarity: string): number
	return if Rarity.rank(rarity) == 1 then 0.62 else 0.3
end

-- 3D pictures ------------------------------------------------------------------------------------------

-- Frames a view's camera on everything in it, from a little to the left and above.
local function frameView(view: ViewportFrame, holder: Model, turn: number?)
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = view
	view.CurrentCamera = camera
	local box, size = holder:GetBoundingBox()
	local radius = size.Magnitude / 2
	local distance = radius / math.tan(math.rad(FOV / 2)) * 1.05
	local direction = (CFrame.Angles(0, math.rad(turn or -24), 0) * CFrame.Angles(math.rad(-14), 0, 0)).LookVector
	camera.CFrame = CFrame.lookAt(box.Position - direction * distance, box.Position)
end

local function part(
	holder: Model,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	shape: Enum.PartType?
)
	return Create("Part", {
		Anchored = true,
		Size = size,
		CFrame = cf,
		Color = color,
		Material = material or Enum.Material.SmoothPlastic,
		Shape = shape or Enum.PartType.Block,
		Parent = holder,
	})
end

-- The prop a style or form shows on its card (a Core model; nil when it has none).
local PROP = {
	writing = { quill = "Quill", typewriter = "Typewriter", fire = "Quill", knife = "Knife" },
	verdict = { gavel = "Gavel", cuffs = "Handcuffs", checkmate = "ChessKing", sugar = "SugarCube" },
	specter = { chains = "Chain", crows = "CrowCloak", marionette = "MarionetteBar", veil = "Hood" },
}

local function propOf(item: Cosmetics.Item): string?
	if item.kind == "chair" then
		-- (a chair skin newer than the imported Core set has no model yet: its glyph instead)
		local key = item.model
		return if type(key) == "string" and ModelLibrary.has(key) then key else nil
	end
	local table_ = PROP[item.kind]
	if not table_ then
		return nil
	end
	local key = table_[item.style or item.form or ""]
	return if key and ModelLibrary.has(key) then key else nil
end

-- An emote's mannequin, caught in the move (a stroll in its walk, holding the stroll's props). Posed once
-- per emote; each card gets a copy (the shop deals its cards again whenever the profile changes).
local figures: { [string]: Model | false } = {}
local function figureOf(item: Cosmetics.Item): Model?
	if item.kind == "seat" and type(item.clip) == "string" then
		-- a seat: the mannequin sitting in the war chair
		local seated = figures[item.id]
		if seated == nil then
			seated = PoseFigure.seated(item.clip) or false
			figures[item.id] = seated
		end
		return if seated then seated:Clone() else nil
	end
	-- (a win cutscene's card: its star in the key pose)
	local clip = if item.kind == "win" then item.clip else item.emote
	if (item.kind ~= "emote" and item.kind ~= "win") or not clip then
		return nil
	end
	local figure = figures[item.id]
	if figure == nil then
		local walking = if item.stroll then PoseFigure.build(clip .. "Walk", nil, clip) else nil
		figure = walking or PoseFigure.build(clip, (item :: any).card) or false
		figures[item.id] = figure
	end
	return if figure then figure:Clone() else nil
end

-- The thing itself, small, in a 3D view (nil for kinds that have none), and an emote's mannequin in it.
local function picture(item: Cosmetics.Item, parent: GuiObject): (GuiObject?, Model?)
	local kind = item.kind
	local key = propOf(item)
	local figure = figureOf(item)
	if kind ~= "hat" and kind ~= "grimoire" and not key and not figure then
		return nil, nil
	end
	local view = Create("ViewportFrame", {
		Name = "Picture",
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(150, 152, 160),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1.2, -0.6),
		Size = UDim2.fromScale(1, 1),
		Parent = parent,
	}) :: ViewportFrame
	local holder = Create("Model", { Name = "Thing", Parent = view }) :: Model
	local model = if key then ModelLibrary.get(key) else nil
	if figure then
		-- Seen from the front, a little to its right (the mannequin faces -Z).
		figure.Parent = holder
		frameView(view, holder, 152)
	elseif model then
		model.Parent = holder
		frameView(view, holder, -28)
	elseif kind == "hat" then
		-- On a head nobody sees.
		local head = part(holder, Vector3.new(2, 1, 1), CFrame.new(), C.void)
		head.Transparency = 1
		for _, piece in ipairs(CosmeticBuild.hat(item, head.CFrame, head)) do
			piece.Anchored = true
			piece.Parent = holder
		end
		head:Destroy()
		frameView(view, holder, -30)
	else
		-- A Manual cover: the notebook everyone holds while writing, in its colour.
		part(holder, Vector3.new(1.3, 0.14, 0.95), CFrame.new(), item.color or C.void, Enum.Material.SmoothPlastic)
		part(holder, Vector3.new(1.2, 0.1, 0.88), CFrame.new(0.03, 0.005, 0), Color3.fromRGB(226, 220, 204))
		part(holder, Vector3.new(1.3, 0.03, 0.95), CFrame.new(0, 0.085, 0), item.color or C.void)
		part(holder, Vector3.new(0.06, 0.18, 0.95), CFrame.new(-0.63, 0, 0), item.color or C.void)
		frameView(view, holder, -20)
	end
	return view, figure
end

-- The still for what has no 3D view: a title's words, or the kind's glyph in the item's colour.
local function still(item: Cosmetics.Item, parent: GuiObject)
	if item.kind == "title" then
		Kit.text({
			face = "Head",
			text = item.name,
			size = 24,
			color = C.bone,
			align = "center",
			maxWidth = Card.WIDTH - 28,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Parent = parent,
		})
		return
	end
	Kit.icon({
		name = STILL_ICON[item.kind] or "seal",
		size = 64,
		color = item.color or (item.colors and item.colors[1]) or C.bone,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Parent = parent,
	})
end

-- Frames -------------------------------------------------------------------------------------------------

local function line(parent: Instance, inset: number, color: Color3, transparency: number, thickness: number?)
	local frame = Kit.Base.make("Frame", {
		Name = "Line",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(inset, inset),
		Size = UDim2.new(1, -2 * inset, 1, -2 * inset),
		Parent = parent,
	})
	Kit.Base.corner(frame, math.max(2, 8 - inset))
	Kit.Base.stroke(frame, color, thickness or 1, transparency)
	return frame
end

-- Ornate corners: a bracket and a small diamond in each corner.
local function corners(parent: Instance, color: Color3, inset: number)
	for _, at in ipairs({ { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } }) do
		local sx, sy = at[1], at[2]
		local x = if sx == 0 then inset else -inset
		local y = if sy == 0 then inset else -inset
		local anchor = Vector2.new(sx, sy)
		Kit.Base.make("Frame", {
			Name = "Bracket",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = anchor,
			Position = UDim2.new(sx, x, sy, y),
			Size = UDim2.fromOffset(16, 2),
			Parent = parent,
		})
		Kit.Base.make("Frame", {
			Name = "Bracket",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			AnchorPoint = anchor,
			Position = UDim2.new(sx, x, sy, y),
			Size = UDim2.fromOffset(2, 16),
			Parent = parent,
		})
		Kit.Base.make("Frame", {
			Name = "Diamond",
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			Rotation = 45,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(
				sx,
				if sx == 0 then inset + 8 else -inset - 8,
				sy,
				if sy == 0 then inset + 8 else -inset - 8
			),
			Size = UDim2.fromOffset(5, 5),
			Parent = parent,
		})
	end
end

local function shine(parent: GuiObject, color: Color3)
	if Motion.isReduced() then
		return
	end
	local sheen = Kit.Base.make("Frame", {
		Name = "Shine",
		BackgroundColor3 = color,
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = parent.ZIndex + 6,
		Parent = parent,
	})
	Kit.Base.corner(sheen, 8)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 24
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Parent = sheen
	TweenService:Create(
		gradient,
		TweenInfo.new(4.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, false, 2),
		{ Offset = Vector2.new(1, 0) }
	):Play()
end

-- Penned: a stroke under the picture, thick in the middle and running out at both ends.
local function underline(face: Frame, color: Color3)
	local stroke = Kit.Base.make("Frame", {
		Name = "Underline",
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 14 + PICTURE + 5),
		Size = UDim2.new(0.72, 0, 0, 2),
		Rotation = -1.5,
		Parent = face,
	})
	Kit.Base.make("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.18, 0.25),
			NumberSequenceKeypoint.new(0.6, 0),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Parent = stroke,
	})
end

-- Condemned: the grain of an old page over the card, in its colour (once the UI textures are in).
local function grain(face: Frame, color: Color3)
	local id = Textures.id("UiGrain")
	if id == "" then
		return
	end
	Kit.Base.make("ImageLabel", {
		Name = "PageGrain",
		BackgroundTransparency = 1,
		Image = id,
		ImageColor3 = color,
		ImageTransparency = 0.78,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(128, 128),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 2,
		Parent = face,
	})
end

-- Godhood: a glow coming in from the card's edges (the screen-edge shade in its colour, or two soft lines
-- inside the edge until the UI textures are in), and motes of page drifting up through it.
local function glow(face: Frame, color: Color3)
	local id = Textures.id("UiVignette")
	if id ~= "" then
		Kit.Base.make("ImageLabel", {
			Name = "EdgeGlow",
			BackgroundTransparency = 1,
			Image = id,
			ImageColor3 = color,
			ImageTransparency = 0.2,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
			Parent = face,
		})
	else
		line(face, 3, color, 0.45, 3).Name = "EdgeGlow"
		line(face, 7, color, 0.75, 2).Name = "EdgeGlow"
	end
end

local MOTES = 7
local function motes(face: Frame, color: Color3)
	local random = Random.new(#face:GetFullName())
	for index = 1, MOTES do
		local size = random:NextInteger(2, 3)
		local x = random:NextNumber(0.12, 0.88)
		local from = random:NextNumber(0.35, 0.95)
		local mote = Kit.Base.make("Frame", {
			Name = "Mote",
			BackgroundColor3 = if index % 3 == 0 then color:Lerp(C.bone, 0.5) else C.bone,
			BackgroundTransparency = random:NextNumber(0.35, 0.6),
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(x, from),
			Size = UDim2.fromOffset(size, size),
			ZIndex = 7,
			Parent = face,
		}) :: Frame
		if not Motion.isReduced() then
			-- Up the card and fading, over and over, each at its own pace.
			local seconds = random:NextNumber(5, 9)
			TweenService:Create(
				mote,
				TweenInfo.new(
					seconds,
					Enum.EasingStyle.Sine,
					Enum.EasingDirection.Out,
					-1,
					false,
					random:NextNumber(0, 3)
				),
				{
					Position = UDim2.fromScale(x + random:NextNumber(-0.08, 0.08), from - 0.45),
					BackgroundTransparency = 1,
				}
			):Play()
		end
	end
end

-- The tier's name in small capitals at the foot of the picture, in its colour (never colour alone).
-- A kind's name on a card's tier line (the owner's direction A: "SEALED · EMOTE").
local KIND_WORD: { [string]: string } = {
	hat = "Hat",
	grimoire = "Cover",
	specter = "Form",
	title = "Title",
	writing = "Writing",
	verdict = "Verdict",
	death = "Death",
	emote = "Emote",
	win = "Cutscene",
	seat = "Seat",
	chair = "Chair",
}

local function rarityTag(face: Frame, rarity: string, kind: string?)
	local color = Rarity.color(rarity)
	local holder = Kit.Base.make("Frame", {
		Name = "Rarity",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.25,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 0, 14 + PICTURE - 4),
		Size = UDim2.fromOffset(0, 16),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 4,
		Parent = face,
	})
	Kit.Base.corner(holder, 2)
	Kit.pad(holder, 0, 5)
	Kit.label({
		Text = "◆ " .. string.upper(Rarity.name(rarity)) .. (if kind and KIND_WORD[kind]
			then "  ·  " .. string.upper(KIND_WORD[kind])
			else ""),
		font = "label",
		size = "micro",
		-- (the line work wears the colour itself; the letters a lighter shade of it, to read on the dark)
		color = color:Lerp(C.bone, if Rarity.rank(rarity) == 5 then 0.38 else 0.18),
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 5,
		Parent = holder,
	})
end

-- Dresses a card's face in its tier (Shared/Rarity): Scrawl a plain line; Penned an underline; Sealed a
-- framed edge; Condemned that frame with page grain and a slow sheen; Godhood a glowing edge and
-- motes of page. Returns the outer edge (it brightens when picked).
-- Sealed's wax seal (direction A): a disc of the tier's colour pressed on the picture's corner, an S in it.
local function waxSeal(face: Frame, color: Color3)
	local disc = Kit.Base.make("Frame", {
		Name = "WaxSeal",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 18),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 5,
		Parent = face,
	})
	Kit.Base.corner(disc, 14)
	Kit.Base.stroke(disc, color:Lerp(C.void, 0.45), 2, 0)
	Kit.label({
		Text = "S",
		font = "head",
		size = "body",
		color = color:Lerp(C.void, 0.75),
		TextWrapped = false,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 6,
		Parent = disc,
	})
end

local function dress(face: Frame, rarity: string, kind: string?): UIStroke
	local rank = Rarity.rank(rarity)
	local color = Rarity.color(rarity)
	local edge = Kit.Base.stroke(face, color, if rank >= 3 then 1.5 else 1, restingEdge(rarity))
	if rank == 2 then
		underline(face, color)
	end
	if rank >= 3 then
		line(face, 5, color, if rank >= 4 then 0.35 else 0.5)
		corners(face, color, 9)
	end
	if rank == 3 then
		waxSeal(face, color)
	end
	if rank == 4 then
		grain(face, color)
		shine(face, color)
	end
	if rank == 5 then
		glow(face, color)
		motes(face, color)
	end
	rarityTag(face, rarity, kind)
	return edge
end

-- A small ribbon over the picture: filled (New), or an outline (an offer).
local function tag(face: Frame, name: string, text: string, position: UDim2, filled: boolean): Frame
	local ribbon = Kit.Base.make("Frame", {
		Name = name,
		BackgroundColor3 = if filled then C.bone else C.void,
		BackgroundTransparency = if filled then 0 else 0.1,
		BorderSizePixel = 0,
		Position = position,
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 4,
		Parent = face,
	}) :: Frame
	Kit.Base.corner(ribbon, 2)
	if not filled then
		Kit.Base.stroke(ribbon, C.bone, 1, 0.2)
	end
	Kit.pad(ribbon, 0, 7)
	Kit.label({
		Text = text,
		font = "bodyBold",
		size = "micro",
		color = if filled then C.void else C.bone,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		ZIndex = 5,
		Parent = ribbon,
	})
	return ribbon
end

-- The card ---------------------------------------------------------------------------------------------

-- props: Parent (the slot, sized by its grid), chip (text; "" for none), chipIcon (before it: "coin", "check"
-- or "lock"),
-- onPick (clicked), faceDown (lies on its back: onPick still fires, the caller turns it), isNew (the "New"
-- ribbon), offer (a second ribbon's words, under the picture: the day's deal), onWish (a heart: called with
-- true to wish for it, false to take the wish back) and wished.
function Card.new(item: Cosmetics.Item, props: { [string]: any }): Card
	local slot = Kit.Base.make("Frame", {
		Name = "Card_" .. item.id,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(Card.WIDTH, Card.HEIGHT + LIFT),
		LayoutOrder = props.LayoutOrder or 0,
		Parent = props.Parent,
	}) :: Frame
	local face = Kit.Base.make("Frame", {
		Name = "Face",
		BackgroundColor3 = C.raised,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, LIFT),
		Size = UDim2.fromOffset(Card.WIDTH, Card.HEIGHT),
		ClipsDescendants = true,
		Parent = slot,
	}) :: Frame
	Kit.Base.corner(face, 8)
	local edge = dress(face, item.rarity, item.kind)
	local pictureBox = Kit.Base.make("Frame", {
		Name = "PictureBox",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(12, 14),
		Size = UDim2.new(1, -24, 0, PICTURE),
		Parent = face,
	})
	Kit.Base.corner(pictureBox, 4)
	local view, figure = picture(item, pictureBox)
	if not view then
		still(item, pictureBox)
	end
	Kit.text({
		face = "Head",
		text = item.name,
		size = 22,
		color = C.bone,
		align = "center",
		maxWidth = Card.WIDTH - 20,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, PICTURE + 22),
		Parent = face,
	})
	-- The chip: a coin and the price, or a word (Worn, Owned, Earned...).
	local chipFrame = Kit.Base.make("Frame", {
		Name = "Chip",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.15,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = face,
	})
	Kit.Base.corner(chipFrame, 14)
	Kit.Base.stroke(chipFrame, C.bone, 1, 0.78)
	Kit.list(chipFrame, T.space.xs, true, Enum.HorizontalAlignment.Center)
	Kit.pad(chipFrame, 0, T.space.m)
	-- (a coin before a price, a check when it is yours, a lock when it cannot be bought now)
	local chipIcons: { [string]: GuiObject } = {}
	for _, name in ipairs(CHIP_ICONS) do
		chipIcons[name] = Kit.icon({
			name = name,
			size = if name == "coin" then 18 else 14,
			color = if name == "lock" then C.dim else C.bone,
			LayoutOrder = 1,
			Visible = false,
			Parent = chipFrame,
		})
	end
	local chip = Kit.label({
		Text = "",
		font = "bodyBold",
		size = "body",
		color = C.bone,
		TextWrapped = false,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromScale(0, 1),
		LayoutOrder = 2,
		Parent = chipFrame,
	})
	local hit = Kit.Base.hit({ Name = "Pick", ZIndex = 20, Parent = slot })
	Kit.Controls.focusable(hit)
	local self = setmetatable({
		item = item,
		slot = slot,
		face = face,
		back = nil,
		chip = chip,
		chipIcons = chipIcons,
		edge = edge,
		picked = false,
		hit = hit,
		faceDown = false,
		ribbon = nil,
		heart = nil,
		wished = props.wished == true,
		figure = figure,
		stopLive = nil,
		hovered = false,
	}, Card)
	self:setChip(props.chip or "", props.chipIcon)
	self:setNew(props.isNew == true)
	if props.offer then
		tag(face, "Offer", props.offer, UDim2.fromOffset(12, 14 + PICTURE - 20), false)
	end
	if props.onWish then
		-- Over the picture's top right corner, above the card's own button (so it lifts with the face).
		local heart = Kit.Base.make("ImageButton", {
			Name = "Wish",
			BackgroundTransparency = 1,
			Image = "",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -8, 0, LIFT + 10),
			Size = UDim2.fromOffset(HEART_HIT, HEART_HIT),
			ZIndex = 21,
			Parent = slot,
		}) :: ImageButton
		Kit.Controls.focusable(heart)
		Kit.icon({
			name = "heart",
			size = 20,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			ZIndex = 22,
			Parent = heart,
		})
		self.heart = heart
		self:setWished(self.wished)
		heart.Activated:Connect(function()
			self:setWished(not self.wished)
			props.onWish(self.wished)
		end)
	end
	hit.Activated:Connect(function()
		if props.onPick then
			props.onPick(self)
		end
	end)
	hit.MouseEnter:Connect(function()
		self.hovered = true
		if not self.picked then
			self:rise(LIFT - 3)
		end
		self:setLive(true)
	end)
	hit.MouseLeave:Connect(function()
		self.hovered = false
		if not self.picked then
			self:rise(LIFT)
		end
		self:setLive(self.picked)
	end)
	if props.faceDown then
		self:lieDown()
	end
	return self
end

-- The chip's words, and the icon before them ("coin", "check", "lock"; none when nil or false).
function Card.setChip(self: Card, text: string, icon: (string | boolean)?)
	self.chip.Text = text
	for name, image in pairs(self.chipIcons) do
		image.Visible = icon == name
	end
	local frame = self.chip.Parent :: Frame
	frame.Visible = text ~= ""
end

-- Moves the face (and its heart) to `top` px down the slot.
function Card.rise(self: Card, top: number)
	Motion.tween(self.face, { Position = UDim2.new(0.5, 0, 0, top) }, T.motion.quick)
	if self.heart then
		Motion.tween(self.heart, { Position = UDim2.new(1, -8, 0, top + 10) }, T.motion.quick)
	end
end

-- The "New" ribbon over the picture's top left corner, on or off.
function Card.setNew(self: Card, on: boolean)
	if self.ribbon then
		self.ribbon.Visible = on
		return
	end
	if on then
		self.ribbon = tag(self.face, "New", "NEW", UDim2.fromOffset(12, 14), true)
	end
end

-- The heart, full when the card is on the wishlist.
function Card.setWished(self: Card, on: boolean)
	self.wished = on
	local heart = self.heart
	local icon = heart and heart:FindFirstChildWhichIsA("ImageLabel")
	if icon then
		icon.ImageColor3 = if on then C.bone else C.dim
		icon.ImageTransparency = if on then 0 else 0.45
	end
end

-- Picked: the card lifts and its edge brightens (and an emote's mannequin does its move).
function Card.setPicked(self: Card, on: boolean)
	self.picked = on
	self:rise(if on then 0 else LIFT)
	self.edge.Transparency = if on then 0 else restingEdge(self.item.rarity)
	self:setLive(on or self.hovered)
end

-- An emote card's mannequin doing its move, live (Shop/PoseFigure), while it is under the pointer or picked:
-- one card at a time (the one before stops), and never under reduced motion.
local live: Card? = nil
function Card.setLive(self: Card, on: boolean)
	local figure = self.figure
	if not figure then
		return
	end
	if on and not self.stopLive and not Motion.isReduced() and not self.faceDown then
		if live and live ~= self then
			live:setLive(false)
		end
		self.stopLive = PoseFigure.play(figure)
		live = self
	elseif not on and self.stopLive then
		local stop = self.stopLive
		self.stopLive = nil
		stop()
		if live == self then
			live = nil
		end
	end
end

-- Bought: a seal stamped over the picture in the tier's colour, pressed down from a little above (simply
-- there under reduced motion), fading after a moment.
local SEAL = 78
function Card.seal(self: Card)
	local color = Rarity.color(self.item.rarity)
	local seal = Kit.Base.make("CanvasGroup", {
		Name = "Seal",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, 14 + PICTURE / 2),
		Size = UDim2.fromOffset(SEAL, SEAL),
		Rotation = -12,
		GroupTransparency = if Motion.isReduced() then 0 else 1,
		ZIndex = 8,
		Parent = self.face,
	}) :: CanvasGroup
	local disc = Kit.Base.make("Frame", {
		Name = "Disc",
		BackgroundColor3 = C.void,
		BackgroundTransparency = 0.3,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(3, 3),
		Size = UDim2.new(1, -6, 1, -6),
		ZIndex = 8,
		Parent = seal,
	})
	Kit.Base.corner(disc, SEAL / 2)
	Kit.Base.stroke(disc, color, 3, 0)
	local inner = Kit.Base.make("Frame", {
		Name = "Inner",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(9, 9),
		Size = UDim2.new(1, -18, 1, -18),
		ZIndex = 8,
		Parent = seal,
	})
	Kit.Base.corner(inner, SEAL / 2)
	Kit.Base.stroke(inner, color, 1, 0.3)
	Kit.label({
		Text = "YOURS",
		font = "bodyBold",
		size = "small",
		color = color:Lerp(C.bone, if Rarity.rank(self.item.rarity) == 5 then 0.38 else 0.18),
		TextWrapped = false,
		TextXAlignment = Enum.TextXAlignment.Center,
		AutomaticSize = Enum.AutomaticSize.None,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.9, 0.3),
		ZIndex = 9,
		Parent = seal,
	})
	if not Motion.isReduced() then
		local scale = Instance.new("UIScale")
		scale.Scale = 1.7
		scale.Parent = seal
		TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
			:Play()
		TweenService:Create(seal, TweenInfo.new(0.14), { GroupTransparency = 0 }):Play()
	end
	task.delay(2.6, function()
		if seal.Parent then
			local fade = TweenService:Create(seal, TweenInfo.new(0.6), { GroupTransparency = 1 })
			fade.Completed:Once(function()
				seal:Destroy()
			end)
			fade:Play()
		end
	end)
end

-- Face down: the back of Death's deck covers it.
function Card.lieDown(self: Card)
	self.faceDown = true
	if self.heart then
		self.heart.Visible = false
	end
	if self.back then
		self.back.Visible = true
		return
	end
	local back = Kit.Base.make("Frame", {
		Name = "Back",
		BackgroundColor3 = C.void,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = self.face,
	}) :: Frame
	Kit.Base.corner(back, 8)
	Kit.Base.stroke(back, C.bone, 1, 0.45)
	local inner = line(back, 7, C.bone, 0.7)
	inner.ZIndex = 10
	corners(back, C.dim, 12)
	for _, item in ipairs(back:GetDescendants()) do
		if item:IsA("GuiObject") then
			item.ZIndex = 11
		end
	end
	Kit.icon({
		name = "palm",
		size = 54,
		color = C.dim,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		ZIndex = 12,
		Parent = back,
	})
	self.back = back
end

-- Turns a face-down card over (a flip about its upright middle), then calls `after`.
function Card.turn(self: Card, after: (() -> ())?)
	if not self.faceDown then
		if after then
			after()
		end
		return
	end
	self.faceDown = false
	local face = self.face
	local half = if Motion.isReduced() then 0 else 0.14
	Motion.tween(face, { Size = UDim2.fromOffset(0, Card.HEIGHT) }, half)
	task.delay(half, function()
		if self.back then
			self.back.Visible = false
		end
		if self.heart then
			self.heart.Visible = true
		end
		Motion.tween(face, { Size = UDim2.fromOffset(Card.WIDTH, Card.HEIGHT) }, half)
		if after then
			after()
		end
	end)
end

function Card.destroy(self: Card)
	self:setLive(false)
	self.slot:Destroy()
end

return Card
