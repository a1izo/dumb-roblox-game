-- A small pale mannequin in an emote's pose, for the shop's cards: an R6 body of plain parts (the pale wood
-- of the Academy's puppets) posed from the clip at one moment, the way the game's animator poses a body
-- (each joint's Transform from the clip, the parts placed through the joints from the root out). It holds
-- the emote's props too (Anim/EmoteProps: the Core models, or their stand-ins until they are imported).
--
--   local figure = PoseFigure.build("wave")   -- a Model, or nil for a clip that does not exist
--   PoseFigure.build("griddyWalk", nil, "griddy")   -- a stroll's walk, holding the stroll's props
--   local stop = PoseFigure.play(figure)   -- the move itself, live (the shop's card under the pointer)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = Shared:WaitForChild("Anim")
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local EmoteProps = require(Anim:WaitForChild("EmoteProps"))
local Create = require(Shared:WaitForChild("Create"))

local EmoteController = require(script.Parent.Parent.Parent.Controllers.EmoteController)

local PoseFigure = {}

local WOOD = Color3.fromRGB(214, 200, 176)
local JOINT_WOOD = Color3.fromRGB(176, 160, 134)

-- R6: each part, the part its joint hangs from, its size, and the joint's C0 and C1 (Roblox's own).
local function frame(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
	return CFrame.new(x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22)
end
local BODY = {
	{
		part = "Torso",
		joint = "root",
		from = "HumanoidRootPart",
		size = Vector3.new(2, 2, 1),
		c0 = frame(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		c1 = frame(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	{
		part = "Head",
		joint = "neck",
		from = "Torso",
		size = Vector3.new(2, 1, 1),
		c0 = frame(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
		c1 = frame(0, -0.5, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	},
	{
		part = "Right Arm",
		joint = "rShoulder",
		from = "Torso",
		size = Vector3.new(1, 2, 1),
		c0 = frame(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		c1 = frame(-0.5, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	{
		part = "Left Arm",
		joint = "lShoulder",
		from = "Torso",
		size = Vector3.new(1, 2, 1),
		c0 = frame(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		c1 = frame(0.5, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
	{
		part = "Right Leg",
		joint = "rHip",
		from = "Torso",
		size = Vector3.new(1, 2, 1),
		c0 = frame(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
		c1 = frame(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	},
	{
		part = "Left Leg",
		joint = "lHip",
		from = "Torso",
		size = Vector3.new(1, 2, 1),
		c0 = frame(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
		c1 = frame(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	},
}

local function rotation(cf: CFrame): CFrame
	return cf - cf.Position
end

-- The moment a card shows: an item's own `card` time, else a little way into a loop (or a stroll's walk),
-- or nearer the middle of a one-shot, where most gestures are at their fullest.
function PoseFigure.moment(clip: ClipPlayer.Prepared, at: number?): number
	if at then
		return at
	end
	return clip.length * (if clip.loop then 0.3 else 0.45)
end

-- Builds the figure (its root at the origin, facing -Z), or nil. Its props are `propsOf`'s (the clip's own
-- when nil).
function PoseFigure.build(clipId: string, at: number?, propsOf: string?): Model?
	local clip = ClipPlayer.get(clipId)
	if not clip then
		return nil
	end
	local rotations, offset = ClipPlayer.sample(clip, PoseFigure.moment(clip, at))
	local model = Create("Model", { Name = "PoseFigure" }) :: Model
	local placed: { [string]: CFrame } = { HumanoidRootPart = CFrame.new() }
	local parts: { [string]: BasePart } = {}
	for _, piece in ipairs(BODY) do
		local rot = rotations[piece.joint] or CFrame.identity
		local transform = ClipPlayer.transform(rotation(piece.c0), rot, if piece.joint == "root" then offset else nil)
		local cf = placed[piece.from] * piece.c0 * transform * piece.c1:Inverse()
		placed[piece.part] = cf
		local part = Create("Part", {
			Name = piece.part,
			Anchored = true,
			Size = piece.size,
			CFrame = cf,
			Color = if piece.part == "Torso" then JOINT_WOOD else WOOD,
			Material = Enum.Material.SmoothPlastic,
			Parent = model,
		}) :: BasePart
		if piece.part == "Head" then
			Create(
				"SpecialMesh",
				{ MeshType = Enum.MeshType.Head, Scale = Vector3.new(1.25, 1.25, 1.25), Parent = part }
			)
		end
		parts[piece.part] = part
	end
	-- Its props as they are at that moment (a held thing, a chair under it, the first of a stack).
	local moment = PoseFigure.moment(clip, at)
	for _, spec in ipairs(EmoteProps.of(propsOf or clipId)) do
		local base = if spec.mount == "floor" then CFrame.new(0, -3, 0) else placed[spec.mount]
		if base and (spec.show or 0) <= moment and moment < (spec.hide or math.huge) then
			local prop = EmoteController.propModel(spec)
			prop:PivotTo(base * spec.at)
			prop:SetAttribute("Mount", spec.mount)
			for _, item in ipairs(prop:GetDescendants()) do
				if item:IsA("BasePart") then
					item.Anchored = true
				end
			end
			prop.Parent = model
		end
	end
	model.PrimaryPart = parts.Torso
	model:SetAttribute("Clip", clipId)
	model:SetAttribute("Moment", moment)
	return model
end

-- How long a one-shot holds its last moment before it plays again, in a live card.
local HOLD = 1.0

-- Plays the clip on a figure from build() (or a copy of one), from its moment on: a loop goes round, a one-shot
-- holds its end a while and starts again; its props go with the parts that hold them. Returns a function that
-- stops it and puts it back at its moment.
function PoseFigure.play(model: Model): () -> ()
	local clip = ClipPlayer.get(model:GetAttribute("Clip") :: string? or "")
	local moment = (model:GetAttribute("Moment") :: number?) or 0
	if not clip then
		return function() end
	end
	local parts: { [string]: BasePart } = {}
	for _, piece in ipairs(BODY) do
		local found = model:FindFirstChild(piece.part)
		if found and found:IsA("BasePart") then
			parts[piece.part] = found
		end
	end
	-- each prop where it is now from the part that holds it (the floor: from the root, at the origin)
	local props: { { model: Model, mount: string, offset: CFrame } } = {}
	for _, child in ipairs(model:GetChildren()) do
		local mount = child:GetAttribute("Mount")
		if child:IsA("Model") and type(mount) == "string" then
			local base = if mount == "floor" then CFrame.identity else (parts[mount] and parts[mount].CFrame)
			if base then
				table.insert(props, { model = child, mount = mount, offset = base:ToObjectSpace(child:GetPivot()) })
			end
		end
	end
	local cycle = if clip.loop then clip.length else clip.length + HOLD
	local scratch: { [string]: CFrame } = {}
	local function pose(t: number)
		table.clear(scratch)
		local rotations, offset = ClipPlayer.sample(clip, math.min(t, clip.length), scratch)
		local placed: { [string]: CFrame } = { HumanoidRootPart = CFrame.new() }
		for _, piece in ipairs(BODY) do
			local rot = rotations[piece.joint] or CFrame.identity
			local transform =
				ClipPlayer.transform(rotation(piece.c0), rot, if piece.joint == "root" then offset else nil)
			local cf = placed[piece.from] * piece.c0 * transform * piece.c1:Inverse()
			placed[piece.part] = cf
			local part = parts[piece.part]
			if part then
				part.CFrame = cf
			end
		end
		for _, prop in ipairs(props) do
			local base = if prop.mount == "floor" then CFrame.identity else placed[prop.mount]
			if base then
				prop.model:PivotTo(base * prop.offset)
			end
		end
	end
	local started = os.clock()
	local connection: RBXScriptConnection
	connection = RunService.RenderStepped:Connect(function()
		if not model.Parent then
			-- (the card was dealt away)
			connection:Disconnect()
			return
		end
		pose((moment + os.clock() - started) % cycle)
	end)
	return function()
		connection:Disconnect()
		if model.Parent then
			pose(moment)
		end
	end
end

return PoseFigure
