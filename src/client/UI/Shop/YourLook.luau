-- "Your look" in the shop: a still copy of your own character in a 3D view, facing you at three
-- quarters, wearing what you have equipped plus the item you are looking at. The copy is taken once
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
local CosmeticBuild = require(Shared:WaitForChild("CosmeticBuild"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))
local Models = require(Shared:WaitForChild("Models"))

local Motion = require(script.Parent.Parent.Core.Motion)
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
	local self = setmetatable({
		viewport = viewport,
		world = nil,
		copy = nil,
		extras = {},
		camera = camera,
		item = nil,
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

-- Builds the item you are looking at onto the copy (hats, ties, the Manual's cover).
local function dress(self: YourLook)
	clearExtras(self)
	local copy, world, item = self.copy, self.world, self.item
	if not copy or not world then
		return
	end
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
	if not item then
		return
	end
	local holder = Create("Model", { Name = "Trying", Parent = copy })
	table.insert(self.extras, holder)
	if item.kind == "hat" and head and head:IsA("BasePart") then
		for _, part in ipairs(CosmeticBuild.hat(item, head.CFrame, head)) do
			part.Anchored = true
			part.Parent = holder
		end
	elseif item.kind == "tie" and torso and torso:IsA("BasePart") then
		local top = torso.Size.Y / 2
		Create("Part", {
			Anchored = true,
			Size = Vector3.new(0.2, 0.95, 0.05),
			Color = item.color,
			Material = Enum.Material.Fabric,
			CFrame = torso.CFrame * CFrame.new(0, top - 0.75, -torso.Size.Z / 2 - 0.05),
			Parent = holder,
		})
	elseif item.kind == "grimoire" and torso and torso:IsA("BasePart") then
		-- A Manual cover colours the notebook everyone holds while writing (CharacterService.setWriting),
		-- held as it is there: a coloured plate over its front cover.
		local held = torso.CFrame * CFrame.new(0, -0.35, -1.05) * CFrame.Angles(math.rad(35), 0, 0)
		local notebook = Models.notebook()
		if notebook then
			for _, part in ipairs(notebook:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Anchored = true
				end
			end
			notebook:PivotTo(held)
			notebook.Parent = holder
			Create("Part", {
				Anchored = true,
				Size = Vector3.new(1.26, 0.02, 0.9),
				Color = item.color,
				Material = Enum.Material.SmoothPlastic,
				CFrame = held * CFrame.new(0, 0.115, 0),
				Parent = holder,
			})
		else
			Create("Part", {
				Anchored = true,
				Size = Vector3.new(1.3, 0.12, 0.95),
				Color = item.color,
				Material = Enum.Material.SmoothPlastic,
				CFrame = held,
				Parent = holder,
			})
			Create("Part", {
				Anchored = true,
				Size = Vector3.new(1.2, 0.06, 0.88),
				Color = Color3.fromRGB(240, 236, 225),
				Material = Enum.Material.SmoothPlastic,
				CFrame = held * CFrame.new(0, 0.09, 0),
				Parent = holder,
			})
		end
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

-- Shows `item` on the copy (nil = just what you wear).
function YourLook.show(self: YourLook, item: Cosmetics.Item?)
	self.item = item
	dress(self)
end

-- The profile changed: take a new copy only if what you wear changed (after the server has
-- dressed your character), otherwise leave the view alone.
function YourLook.profileChanged(self: YourLook, profile)
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
