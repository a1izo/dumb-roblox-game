-- One card on Death's table (the shop, "Death's hand"): tarot-shaped, the thing itself as a big picture,
-- its name in Melodrama and its price in a plain coin chip. Rarity is in the frame, never in a colour of
-- the text:
--
--   common     a thin bone line
--   rare       a double line
--   epic       ornate corners
--   legendary  amber gold leaf, a slow shine passing over it (still under reduced motion)
--
-- Objects (hats, ties, trails, Manual covers, Deathsinger forms) are a small 3D view; the rest (titles,
-- styles, gestures) a still: their glyph, or their words. Picked, the card lifts. A card of Today's hand
-- can lie face down (the back of the deck) and be turned over.
--
--   local card = Card.new(item, { Parent = slot, chip = "300", onPick = fn })
--   card:setPicked(true)  card:setChip("Worn")  card:turn(fn)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local CosmeticBuild = require(Shared:WaitForChild("CosmeticBuild"))
local Create = require(Shared:WaitForChild("Create"))

local Kit = require(script.Parent.Parent.Kit)
local Motion = require(script.Parent.Parent.Core.Motion)

local C = Kit.color
local T = Kit.Tokens

local Card = {}
Card.__index = Card

Card.WIDTH = 150
Card.HEIGHT = 236
local LIFT = 10 -- px a picked card rises
local PICTURE = 118 -- the picture's height
local GOLD = Color3.fromRGB(212, 168, 92) -- the legendary card's gold leaf
local FOV = 28

-- The still for kinds with no 3D view: an icon (styles and gestures come in suits of their own).
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
		chipIcon: ImageLabel,
		edge: UIStroke,
		picked: boolean,
		hit: TextButton,
		faceDown: boolean,
	},
	Card
))

local function tier(rarity: string): number
	return ({ common = 1, uncommon = 1, rare = 2, epic = 3, legendary = 4, mythic = 4 })[rarity] or 1
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

-- The thing itself, small, in a 3D view (nil for kinds that have none).
local function picture(item: Cosmetics.Item, parent: GuiObject): GuiObject?
	local kind = item.kind
	if kind ~= "hat" and kind ~= "tie" and kind ~= "trail" and kind ~= "grimoire" then
		return nil
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
	if kind == "hat" then
		-- On a head nobody sees.
		local head = part(holder, Vector3.new(2, 1, 1), CFrame.new(), C.void)
		head.Transparency = 1
		for _, piece in ipairs(CosmeticBuild.hat(item, head.CFrame, head)) do
			piece.Anchored = true
			piece.Parent = holder
		end
		head:Destroy()
		frameView(view, holder, -30)
	elseif kind == "tie" then
		local color = item.color or C.void
		part(holder, Vector3.new(0.32, 0.26, 0.12), CFrame.new(0, 0.62, 0), color, Enum.Material.Fabric)
		part(holder, Vector3.new(0.3, 1.0, 0.06), CFrame.new(0, 0.0, 0), color, Enum.Material.Fabric)
		part(
			holder,
			Vector3.new(0.26, 0.26, 0.06),
			CFrame.new(0, -0.5, 0) * CFrame.Angles(0, 0, math.rad(45)),
			color,
			Enum.Material.Fabric
		)
		frameView(view, holder, -16)
	elseif kind == "trail" then
		-- A ribbon flowing behind, its two colours running along it.
		local colors = item.colors or { C.bone, C.dim }
		local count = 10
		for index = 0, count - 1 do
			local t = index / (count - 1)
			local x = (t - 0.5) * 3.2
			local y = math.sin(t * math.pi * 1.6) * 0.45
			local slope = math.cos(t * math.pi * 1.6) * 0.45 * math.pi * 1.6 / 3.2
			part(
				holder,
				Vector3.new(0.36, 0.5 - t * 0.3, 0.05),
				CFrame.new(x, y, 0) * CFrame.Angles(0, 0, math.atan(slope)),
				colors[1]:Lerp(colors[2], t),
				Enum.Material.Neon
			)
		end
		frameView(view, holder, -8)
	else
		-- A Manual cover: the notebook everyone holds while writing, in its colour.
		part(holder, Vector3.new(1.3, 0.14, 0.95), CFrame.new(), item.color or C.void, Enum.Material.SmoothPlastic)
		part(holder, Vector3.new(1.2, 0.1, 0.88), CFrame.new(0.03, 0.005, 0), Color3.fromRGB(226, 220, 204))
		part(holder, Vector3.new(1.3, 0.03, 0.95), CFrame.new(0, 0.085, 0), item.color or C.void)
		part(holder, Vector3.new(0.06, 0.18, 0.95), CFrame.new(-0.63, 0, 0), item.color or C.void)
		frameView(view, holder, -20)
	end
	return view
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

local function shine(parent: GuiObject)
	if Motion.isReduced() then
		return
	end
	local sheen = Kit.Base.make("Frame", {
		Name = "Shine",
		BackgroundColor3 = GOLD,
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

-- Dresses a card's face in its rarity's frame. Returns the outer edge (it brightens when picked).
local function dress(face: Frame, rarity: string): UIStroke
	local level = tier(rarity)
	local edgeColor = if level == 4 then GOLD else C.bone
	local edge = Kit.Base.stroke(face, edgeColor, if level >= 3 then 1.5 else 1, if level == 1 then 0.62 else 0.3)
	if level >= 2 then
		line(face, 5, edgeColor, if level == 4 then 0.35 else 0.55)
	end
	if level >= 3 then
		corners(face, edgeColor, 9)
	end
	if level == 4 then
		shine(face)
	end
	return edge
end

-- The card ---------------------------------------------------------------------------------------------

-- props: Parent (the slot, sized by its grid), chip (text; "" for none), chipCoin (the chip shows a coin),
-- onPick (clicked), faceDown (lies on its back: onPick still fires, the caller turns it).
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
	local edge = dress(face, item.rarity)
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
	if not picture(item, pictureBox) then
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
	local chipIcon = Kit.icon({ name = "coin", size = 18, color = C.bone, LayoutOrder = 1, Parent = chipFrame })
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
		chipIcon = chipIcon,
		edge = edge,
		picked = false,
		hit = hit,
		faceDown = false,
	}, Card)
	self:setChip(props.chip or "", props.chipCoin == true)
	hit.Activated:Connect(function()
		if props.onPick then
			props.onPick(self)
		end
	end)
	hit.MouseEnter:Connect(function()
		if not self.picked then
			Motion.tween(face, { Position = UDim2.new(0.5, 0, 0, LIFT - 3) }, T.motion.quick)
		end
	end)
	hit.MouseLeave:Connect(function()
		if not self.picked then
			Motion.tween(face, { Position = UDim2.new(0.5, 0, 0, LIFT) }, T.motion.quick)
		end
	end)
	if props.faceDown then
		self:lieDown()
	end
	return self
end

-- The chip's words (and whether a coin goes before them).
function Card.setChip(self: Card, text: string, coin: boolean)
	self.chip.Text = text
	self.chipIcon.Visible = coin
	local frame = self.chip.Parent :: Frame
	frame.Visible = text ~= ""
end

-- Picked: the card lifts and its edge brightens.
function Card.setPicked(self: Card, on: boolean)
	self.picked = on
	Motion.tween(self.face, { Position = UDim2.new(0.5, 0, 0, if on then 0 else LIFT) }, T.motion.quick)
	self.edge.Transparency = if on then 0 elseif tier(self.item.rarity) == 1 then 0.62 else 0.3
end

-- Face down: the back of Death's deck covers it.
function Card.lieDown(self: Card)
	self.faceDown = true
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
		Motion.tween(face, { Size = UDim2.fromOffset(Card.WIDTH, Card.HEIGHT) }, half)
		if after then
			after()
		end
	end)
end

function Card.destroy(self: Card)
	self.slot:Destroy()
end

return Card
