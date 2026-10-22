-- "Your look" in the shop: a still copy of your own character in a 3D view, facing you at three
-- quarters, wearing what you have equipped plus the item you are looking at: a hat, a tie or a Manual
-- cover on the copy, a Deathsinger form as the copy turned to a
-- tinted ghost wearing its form, a title over its head (the words over the view: a 3D view draws no
-- billboards). Styles and emotes play once when picked (again when picked again): an emote on the
-- copy, all of it (with its props, sound and face, if it has them), a writing style writing a name on a strip of page, a verdict's little scene, a death style on
-- the copy (which is taken again afterwards). The copy is taken once
-- when the shop opens (and again only when what you wear changes), and it is always put back into
-- its rest pose: whatever you were doing (walking, a fidget, an emote) never shows. It sways a
-- little on its own; drag it to turn it, and it comes back to face you a few seconds later.
--
--   local look = YourLook.new(holder)
--   look:open()  look:show(item)  look:close()

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ClipPlayer = require(Shared:WaitForChild("Anim"):WaitForChild("ClipPlayer"))
local CosmeticBuild = require(Shared:WaitForChild("CosmeticBuild"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))
local Models = require(Shared:WaitForChild("Models"))
local Seating = require(Shared:WaitForChild("Seating"))

local Motion = require(script.Parent.Parent.Core.Motion)
local Tokens = require(script.Parent.Parent.Kit.Tokens)
local EmoteController = require(script.Parent.Parent.Parent.Controllers.EmoteController)
local PoseController = require(script.Parent.Parent.Parent.Anim.PoseController)
local Styles = require(script.Parent.Parent.Parent.Presentation.Styles)
local Stage = require(script.Parent.Parent.Parent.Presentation.Stage)

local LocalPlayer = Players.LocalPlayer

local YourLook = {}
YourLook.__index = YourLook

local FACING = math.rad(-20) -- three quarters: the copy looks a little to your left
local SWAY = math.rad(14) -- how far it sways either side on its own
local SWAY_SPEED = 0.45 -- radians of sway phase a second
local DRAG_TURN = 0.012 -- radians per pixel dragged
local SETTLE_AFTER = 3 -- seconds after a drag before it turns back to face you
local FOV = 30

export type YourLook = typeof(setmetatable(
	{} :: {
		viewport: ViewportFrame,
		world: WorldModel?,
		copy: Model?,
		extras: { Instance },
		camera: Camera,
		item: Cosmetics.Item?,
		profile: any,
		titleLabel: TextLabel,
		stopPreview: (() -> ())?,
		wearing: string,
		spin: number,
		lastDrag: number,
		phase: number,
		dragging: boolean,
		connections: { RBXScriptConnection },
	},
	YourLook
))

-- Puts every part back where its joints say it belongs with no animation applied (the rest pose),
-- walking out from the root, then anchors everything so nothing in the view ever moves on its own.
local function restPose(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root or not root:IsA("BasePart") then
		return
	end
	local links: { [BasePart]: { { other: BasePart, offset: CFrame } } } = {}
	local function link(a: BasePart, b: BasePart, offset: CFrame)
		links[a] = links[a] or {}
		table.insert(links[a], { other = b, offset = offset })
		links[b] = links[b] or {}
		table.insert(links[b], { other = a, offset = offset:Inverse() })
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("JointInstance") then
			-- Part0.CFrame * C0 * Transform == Part1.CFrame * C1, with Transform left at rest.
			local part0, part1 = item.Part0, item.Part1
			if part0 and part1 then
				link(part0, part1, item.C0 * item.C1:Inverse())
			end
		elseif item:IsA("WeldConstraint") then
			-- Rigid pieces (a hat, a prop): keep them where they sit on their body part.
			local part0, part1 = item.Part0, item.Part1
			if part0 and part1 then
				link(part0, part1, part0.CFrame:ToObjectSpace(part1.CFrame))
			end
		end
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Anchored = true
		end
	end
	local placed: { [BasePart]: boolean } = { [root] = true }
	local queue = { root }
	local index = 1
	while index <= #queue do
		local part = queue[index]
		index += 1
		for _, edge in ipairs(links[part] or {}) do
			if not placed[edge.other] then
				placed[edge.other] = true
				edge.other.CFrame = part.CFrame * edge.offset
				table.insert(queue, edge.other)
			end
		end
	end
end

-- What you wear, as a string: the copy is taken again only when this changes.
local function wearingKey(profile): string
	if not profile or not profile.equipped then
		return ""
	end
	local parts = {}
	for kind, id in pairs(profile.equipped) do
		table.insert(parts, kind .. "=" .. tostring(id))
	end
	table.sort(parts)
	return table.concat(parts, ";")
end

function YourLook.new(holder: GuiObject, props: { [string]: any }?): YourLook
	local viewport = Create("ViewportFrame", {
		Name = "YourLook",
		BackgroundColor3 = (props and props.background) or Color3.new(0, 0, 0),
		BackgroundTransparency = 0,
		Ambient = Color3.fromRGB(150, 155, 165),
		LightColor = Color3.fromRGB(255, 255, 255),
		LightDirection = Vector3.new(-1, -1, 0.6),
		Size = (props and props.Size) or UDim2.fromScale(1, 1),
		Position = props and props.Position,
		Active = true,
		Parent = holder,
	})
	local camera = Instance.new("Camera")
	camera.FieldOfView = FOV
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local titleLabel = Create("TextLabel", {
		Name = "Title",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.new(1, -20, 0, 28),
		FontFace = Tokens.font.bodyBold,
		Text = "",
		TextColor3 = Color3.fromRGB(244, 245, 247),
		TextSize = 22,
		TextStrokeTransparency = 0.4,
		TextWrapped = true,
		ZIndex = 5,
		Parent = viewport,
	}) :: TextLabel
	local self = setmetatable({
		viewport = viewport,
		world = nil,
		copy = nil,
		extras = {},
		camera = camera,
		item = nil,
		profile = nil,
		titleLabel = titleLabel,
		stopPreview = nil,
		wearing = "",
		spin = 0,
		lastDrag = 0,
		phase = 0,
		dragging = false,
		connections = {},
	}, YourLook)
	viewport.InputBegan:Connect(function(input: InputObject)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			self.dragging = true
			self.lastDrag = os.clock()
		end
	end)
	return self
end

local function clearExtras(self: YourLook)
	for _, extra in ipairs(self.extras) do
		extra:Destroy()
	end
	table.clear(self.extras)
end

-- Frames the camera on the copy: the whole figure, hat included, with a little room.
local function frame(self: YourLook)
	local copy = self.copy
	if not copy then
		return
	end
	local box, size = copy:GetBoundingBox()
	local height = math.max(size.Y, 4)
	local distance = (height * 0.5 + 0.6) / math.tan(math.rad(FOV / 2))
	local focus = box.Position + Vector3.new(0, 0.1, 0)
	-- The copy faces -Z (its look vector); the camera stands on that side, looking back at it.
	self.camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0.6, -distance), focus)
end

local function turnTo(self: YourLook, yaw: number)
	local copy = self.copy
	if copy then
		copy:PivotTo(CFrame.new(0, 0, 0) * CFrame.Angles(0, yaw, 0))
	end
end

-- Hides a part of the copy, or gives it back the transparency it was copied with.
local function hide(part: BasePart, hidden: boolean)
	if part:GetAttribute("LookBase") == nil then
		part:SetAttribute("LookBase", part.Transparency)
	end
	part.Transparency = if hidden then 1 else part:GetAttribute("LookBase") :: number
end

-- The copy as a Deathsinger in that form (a translucent ghost in its colour), or back as it was.
local function ghost(copy: Model, color: Color3?)
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not part:FindFirstAncestor("Trying") then
			if part:GetAttribute("LookColor") == nil then
				part:SetAttribute("LookColor", part.Color)
				part:SetAttribute("LookMaterial", part.Material.Name)
			end
			if part:GetAttribute("LookBase") == nil then
				part:SetAttribute("LookBase", part.Transparency)
			end
			local base = part:GetAttribute("LookBase") :: number
			if color then
				part.Color = (part:GetAttribute("LookColor") :: Color3):Lerp(color, 0.75)
				part.Material = Enum.Material.Neon
				part.Transparency = math.max(base, 0.45)
			else
				part.Color = part:GetAttribute("LookColor") :: Color3
				part.Material = (Enum.Material :: any)[part:GetAttribute("LookMaterial")] or part.Material
				part.Transparency = base
			end
		end
	end
end

-- Builds what you wear that the copy cannot show by itself (a title) and the item you are
-- looking at onto it (hats, ties, the Manual's cover, a Deathsinger form, a title).
local function dress(self: YourLook)
	clearExtras(self)
	local copy, world, item = self.copy, self.world, self.item
	if not copy or not world then
		return
	end
	local equipped = (self.profile and self.profile.equipped) or {}
	local looking = item and item.kind
	local title = if looking == "title" then item else Cosmetics.byId(equipped.title)
	self.titleLabel.Text = if title then title.name else ""
	ghost(copy, if looking == "specter" and item then item.color else nil)
	Styles.form(copy, if looking == "specter" and item then item.form else nil, if item then item.color else nil)
	local head = copy:FindFirstChild("Head")
	local torso = copy:FindFirstChild("Torso")
	local equippedHat = copy:FindFirstChild("LCosmeticHat")
	local previewingHat = item ~= nil and item.kind == "hat"
	-- A hat you are trying on replaces the one you wear (and hides your own hat accessories).
	if equippedHat then
		for _, part in ipairs(equippedHat:GetDescendants()) do
			if part:IsA("BasePart") then
				hide(part, previewingHat)
			end
		end
	end
	for _, accessory in ipairs(copy:GetChildren()) do
		if accessory:IsA("Accessory") and accessory.AccessoryType == Enum.AccessoryType.Hat then
			local handle = accessory:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				hide(handle, previewingHat)
			end
		end
	end
	local holder = Create("Model", { Name = "Trying", Parent = copy })
	table.insert(self.extras, holder)
	if not item then
		return
	end
	if item.kind == "hat" and head and head:IsA("BasePart") then
		for _, part in ipairs(CosmeticBuild.hat(item, head.CFrame, head)) do
			part.Anchored = true
			part.Parent = holder
		end
	elseif item.kind == "grimoire" and torso and torso:IsA("BasePart") then
		-- A Manual cover colours the open Death's Manual everyone holds while writing
		-- (CharacterService.setWriting), held as it is there.
		local held = torso.CFrame * CFrame.new(0, -0.35, -1.05) * CFrame.Angles(math.rad(35), 0, 0)
		Models.heldManual(held, item.color).Parent = holder
	end
end

-- Takes the copy of your character (again), in its rest pose, at the origin facing the camera.
function YourLook.capture(self: YourLook, profile)
	if self.world then
		self.world:Destroy()
		self.world = nil
		self.copy = nil
		table.clear(self.extras)
	end
	self.wearing = wearingKey(profile)
	self.profile = profile
	local character = LocalPlayer.Character
	if not character then
		return
	end
	local copy = Stage.copyOf(character)
	if not copy then
		return
	end
	-- Billboards (the title over your head) do not draw in a 3D view.
	local tag = copy:FindFirstChild("LTitleTag", true)
	if tag then
		tag:Destroy()
	end
	for _, item in ipairs(copy:GetDescendants()) do
		if item:IsA("Trail") or item:IsA("ParticleEmitter") or item:IsA("BillboardGui") then
			item:Destroy()
		end
	end
	restPose(copy)
	local root = copy:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		copy.PrimaryPart = root
		-- Start from a clean facing: the root's own turn is thrown away.
		copy:PivotTo(CFrame.new())
	end
	local world = Instance.new("WorldModel")
	world.Parent = self.viewport
	copy.Parent = world
	self.world = world
	self.copy = copy
	turnTo(self, FACING)
	frame(self)
	dress(self)
end

local SAMPLE_NAME = "Kenji Mori" -- (a name from the pools, nobody's in a case)

local function stopPreview(self: YourLook)
	local stop = self.stopPreview
	self.stopPreview = nil
	if stop then
		stop()
	end
end

-- A name written on a strip of page at the foot of the view, in a writing style.
local function writePreview(self: YourLook, style: string): () -> ()
	local page = Create("Frame", {
		Name = "Page",
		BackgroundColor3 = Color3.fromRGB(172, 98, 36),
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.new(0.86, 0, 0, 58),
		ZIndex = 6,
		Parent = self.viewport,
	})
	local colour, font = Styles.pen(style)
	local clip = Create("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.fromOffset(0, 46),
		ZIndex = 7,
		Parent = page,
	}) :: Frame
	local label = Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(240, 46),
		Text = SAMPLE_NAME,
		FontFace = font,
		TextSize = 30,
		TextColor3 = colour,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		ZIndex = 7,
		Parent = clip,
	}) :: TextLabel
	label:SetAttribute("KeepFont", true)
	task.spawn(function()
		task.wait()
		local shown = math.min(240, (if label.TextBounds.X > 1 then label.TextBounds.X else 160) + 6)
		Styles.write(clip, label, shown, 0.08, style)
	end)
	return function()
		page:Destroy()
	end
end

-- How long a try-on lasts: all of a one-shot emote and its held last pose, or one whole loop of a dance (a
-- short walk cycle a few times over).
local function tryOnLength(clip: string): number
	local prepared = ClipPlayer.get(clip)
	if not prepared then
		return 3.4
	end
	if prepared.loop then
		return math.max(prepared.length, 3.4)
	end
	return prepared.length + 0.6
end
-- (the emote wheel's preview puts its own copy of you at rest the same way)
YourLook.restPose = restPose

-- An emote on the copy, all of it: its joints let go for as long as it plays, and it is put back at rest
-- after. `held`: the emote whose props, face and sound go with it (a stroll previews its walk, with the
-- stroll's stick).
local function emotePreview(self: YourLook, clip: string, held: string?): () -> ()
	local copy = self.copy
	if not copy then
		return function() end
	end
	for _, part in ipairs(copy:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" and not part:FindFirstAncestor("Trying") then
			part.Anchored = false
		end
	end
	local seconds = tryOnLength(clip)
	PoseController.bindWhenReady(copy, 1)
	PoseController.play(copy, clip, { fadeIn = 0.1, fadeOut = 0.2, duration = seconds })
	local own = held or clip
	local function alive(): boolean
		return PoseController.isPlaying(copy, clip)
	end
	local removeProp = EmoteController.dress(copy, own, alive)
	local stopSound = EmoteController.previewSound(own, seconds)
	local undoFace = EmoteController.face(copy, own, alive)
	local stopEffect = EmoteController.effect(copy, own, true)
	local done = false
	local function stop()
		if done then
			return
		end
		done = true
		removeProp()
		stopSound()
		undoFace()
		stopEffect()
		PoseController.stop(copy, clip, 0)
		if copy.Parent then
			restPose(copy)
		end
	end
	task.delay(seconds + 0.2, stop)
	return stop
end

-- A seat or a chair tried on (Shared/Seating): the copy sits a while in the chair picked (or the one you wear, or
-- the war chair) in the seat picked (or the one you wear, or everyone's).
local function seatPreview(self: YourLook, item: Cosmetics.Item): () -> ()
	local copy = self.copy
	local root = copy and copy:FindFirstChild("HumanoidRootPart")
	if not copy or not root or not root:IsA("BasePart") then
		return function() end
	end
	local equipped = (self.profile and self.profile.equipped) or {}
	local seat = if item.kind == "seat" then item else Cosmetics.byId(equipped.seat)
	local chairItem = if item.kind == "chair" then item else Cosmetics.byId(equipped.chair)
	local clip = if seat and type(seat.clip) == "string" then seat.clip else Seating.DEFAULT
	local chair = Seating.chairModel(chairItem)
	if chair then
		-- (the copy is an R6 body standing at rest: its root 3 above the floor)
		chair:PivotTo(Seating.chairUnder(root.CFrame, 3))
		for _, part in ipairs(chair:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored = true
			end
		end
		chair.Parent = copy.Parent
	end
	local stop = emotePreview(self, clip)
	return function()
		stop()
		if chair then
			chair:Destroy()
		end
	end
end

-- Plays a style or an emote once, for the item picked (nothing for other kinds).
local function preview(self: YourLook, item: Cosmetics.Item)
	stopPreview(self)
	if item.kind == "seat" or item.kind == "chair" then
		self.stopPreview = seatPreview(self, item)
	elseif item.kind == "emote" and type(item.emote) == "string" then
		local walk = item.emote .. "Walk"
		self.stopPreview = if item.stroll and PoseController.exists(walk)
			then emotePreview(self, walk, item.emote)
			else emotePreview(self, item.emote)
	elseif item.kind == "writing" and type(item.style) == "string" then
		self.stopPreview = writePreview(self, item.style)
	elseif item.kind == "verdict" and type(item.style) == "string" then
		self.stopPreview =
			Styles.verdict(item.style, self.viewport, UDim2.fromScale(0.5, 0.62), UDim2.fromScale(0.95, 0.6))
	elseif item.kind == "death" and type(item.style) == "string" and self.copy then
		local style = item.style
		Styles.death(style, self.copy)
		local alive = true
		task.delay(3.2, function()
			if alive and self.world and self.item == item then
				self:capture(self.profile)
			end
		end)
		self.stopPreview = function()
			alive = false
		end
	end
end

-- Shows `item` on the copy (nil = just what you wear), and plays it if it is a style or an emote.
function YourLook.show(self: YourLook, item: Cosmetics.Item?)
	stopPreview(self)
	if self.item ~= item and self.item and self.item.kind == "death" and self.world then
		-- (A death style left the copy as it left it: take it again.)
		self.item = item
		self:capture(self.profile)
	end
	self.item = item
	dress(self)
	if item then
		preview(self, item)
	end
end

-- The profile changed: take a new copy only if what you wear changed (after the server has
-- dressed your character), otherwise leave the view alone.
function YourLook.profileChanged(self: YourLook, profile)
	self.profile = profile
	if wearingKey(profile) == self.wearing then
		return
	end
	self.wearing = wearingKey(profile)
	task.delay(0.4, function()
		if self.world then
			self:capture(profile)
		end
	end)
end

function YourLook.open(self: YourLook, profile)
	self.item = nil
	self.spin = 0
	self.phase = 0
	self:capture(profile)
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	table.clear(self.connections)
	table.insert(
		self.connections,
		UserInputService.InputChanged:Connect(function(input: InputObject)
			if not self.dragging then
				return
			end
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseMovement or kind == Enum.UserInputType.Touch then
				self.spin += input.Delta.X * DRAG_TURN
				self.lastDrag = os.clock()
			end
		end)
	)
	table.insert(
		self.connections,
		UserInputService.InputEnded:Connect(function(input: InputObject)
			local kind = input.UserInputType
			if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
				self.dragging = false
			end
		end)
	)
	table.insert(
		self.connections,
		RunService.RenderStepped:Connect(function(dt: number)
			if not self.copy then
				return
			end
			if not self.dragging and os.clock() - self.lastDrag > SETTLE_AFTER then
				-- Turn back the short way round to face you.
				local wrapped = (self.spin + math.pi) % (2 * math.pi) - math.pi
				self.spin = wrapped * math.exp(-dt * 2.5)
			end
			local sway = 0
			if not Motion.isReduced() then
				self.phase += dt * SWAY_SPEED
				sway = math.sin(self.phase) * SWAY
			end
			turnTo(self, FACING + sway + self.spin)
		end)
	)
end

function YourLook.close(self: YourLook)
	stopPreview(self)
	for _, connection in ipairs(self.connections) do
		connection:Disconnect()
	end
	table.clear(self.connections)
	self.dragging = false
	if self.world then
		self.world:Destroy()
	end
	self.world = nil
	self.copy = nil
	table.clear(self.extras)
end

return YourLook
