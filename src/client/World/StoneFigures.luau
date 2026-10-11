--!strict
-- Stone figures for the lobby: grey, faceless R6 bodies that stand on the tableaux' bases and sit on the
-- throne, built on this client only (every client builds the same ones from the same scene). They are
-- posed from the game's own animation clips (Shared/Anim), a little larger than life, and can play a clip
-- on a loop or hold one moment of it.
--
--   local figure = StoneFigures.new({ parent = folder, feet = cframe, scale = 1.4 })
--   StoneFigures.pose(figure, "point", 0.8)               -- one moment of a clip, held
--   StoneFigures.play(figure, "write")                    -- the clip, over and over
--   StoneFigures.play(figure, "collapseHeart", { cycle = 6 })   -- once every 6 s, holding its end between
--   StoneFigures.hold(figure)                             -- stop where it is
--
-- A body can also be made from someone's avatar (StoneFigures.adopt): its shape stays, everything else
-- turns to stone.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Anim = Shared:WaitForChild("Anim")
local ClipPlayer = require(Anim:WaitForChild("ClipPlayer"))
local Create = require(Shared:WaitForChild("Create"))
local Joints = require(Anim:WaitForChild("Joints"))

local StoneFigures = {}

StoneFigures.STONE = Color3.fromRGB(116, 116, 122)
StoneFigures.DARK = Color3.fromRGB(52, 52, 58)

export type Figure = {
	model: Model,
	root: BasePart,
	scale: number,
	motors: { [string]: any },
	basis: { [string]: CFrame },
	clip: ClipPlayer.Prepared?,
	started: number,
	cycle: number?,
	-- Whether the clip may move the whole body (a collapse sinks to the floor; a seated figure stays put).
	travel: boolean,
}

export type Options = {
	cycle: number?, -- seconds from one start of the clip to the next (it holds its last moment between)
	phase: number?, -- seconds already into the cycle when it starts (so figures do not move as one)
	travel: boolean?, -- default true
}

local playing: { [Figure]: boolean } = {}
local connection: RBXScriptConnection? = nil
local scratch: { [string]: CFrame } = {}
local IDENTITY = CFrame.identity

local function still(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
end

-- R6 by hand: the six parts and the six joints the clips move. No face.
local function plainRig(): Model
	local model = Instance.new("Model")
	local function part(name: string, size: Vector3, at: Vector3): Part
		local p = Create("Part", {
			Name = name,
			Size = size,
			CFrame = CFrame.new(at),
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			Parent = model,
		}) :: Part
		return p
	end
	local root = part("HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	root.Transparency = 1
	local torso = part("Torso", Vector3.new(2, 2, 1), Vector3.new(0, 3, 0))
	local head = part("Head", Vector3.new(2, 1, 1), Vector3.new(0, 4.5, 0))
	Create("SpecialMesh", { MeshType = Enum.MeshType.Head, Scale = Vector3.new(1.25, 1.25, 1.25), Parent = head })
	local limb = Vector3.new(1, 2, 1)
	local rightArm = part("Right Arm", limb, Vector3.new(1.5, 3, 0))
	local leftArm = part("Left Arm", limb, Vector3.new(-1.5, 3, 0))
	local rightLeg = part("Right Leg", limb, Vector3.new(0.5, 1, 0))
	local leftLeg = part("Left Leg", limb, Vector3.new(-0.5, 1, 0))
	local function joint(name: string, home: BasePart, moved: BasePart, c0: CFrame, c1: CFrame)
		Create("Motor6D", { Name = name, Part0 = home, Part1 = moved, C0 = c0, C1 = c1, Parent = home })
	end
	local up = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0)
	local right = CFrame.new(0, 0, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0)
	local left = CFrame.new(0, 0, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0)
	joint("RootJoint", root, torso, up, up)
	joint("Neck", torso, head, CFrame.new(0, 1, 0) * up, CFrame.new(0, -0.5, 0) * up)
	joint("Right Shoulder", torso, rightArm, CFrame.new(1, 0.5, 0) * right, CFrame.new(-0.5, 0.5, 0) * right)
	joint("Left Shoulder", torso, leftArm, CFrame.new(-1, 0.5, 0) * left, CFrame.new(0.5, 0.5, 0) * left)
	joint("Right Hip", torso, rightLeg, CFrame.new(1, -1, 0) * right, CFrame.new(0.5, 1, 0) * right)
	joint("Left Hip", torso, leftLeg, CFrame.new(-1, -1, 0) * left, CFrame.new(-0.5, 1, 0) * left)
	Create("Humanoid", { RigType = Enum.HumanoidRigType.R6, Parent = model })
	model.PrimaryPart = root
	return model
end

-- Everything about a body that is not its shape, gone: one grey stone.
function StoneFigures.petrify(model: Model, color: Color3?)
	local stone = color or StoneFigures.STONE
	-- First whatever paints a body (an avatar's body colours would put its skin back over the stone), then
	-- the stone itself.
	for _, item in ipairs(model:GetDescendants()) do
		if
			item:IsA("Decal")
			or item:IsA("Clothing")
			or item:IsA("ShirtGraphic")
			or item:IsA("SurfaceAppearance")
			or item:IsA("LuaSourceContainer")
			or item:IsA("Sound")
			or item:IsA("ParticleEmitter")
			or item:IsA("Light")
			or item:IsA("Fire")
			or item:IsA("Sparkles")
			or item:IsA("Smoke")
			or item:IsA("BodyColors")
			or item:IsA("HumanoidDescription")
			or item:IsA("BillboardGui")
		then
			item:Destroy()
		end
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.Color = stone
			item.Material = Enum.Material.Slate
			item.Reflectance = 0
			item.CastShadow = true
			if item:IsA("MeshPart") then
				item.TextureID = ""
			end
			still(item)
			item.Anchored = item.Name == "HumanoidRootPart"
		elseif item:IsA("SpecialMesh") then
			item.TextureId = ""
			item.VertexColor = Vector3.new(1, 1, 1)
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
		humanoid.PlatformStand = true
		pcall(function()
			(humanoid :: any).EvaluateStateMachine = false
		end)
	end
end

-- Makes a figure of an R6 body: turned to stone, grown to `scale`, its feet on `feet` (facing its look
-- vector). Returns nil if the body has no R6 joints.
function StoneFigures.adopt(model: Model, parent: Instance, feet: CFrame, scale: number?, collide: boolean?): Figure?
	local size = scale or 1
	StoneFigures.petrify(model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	model.PrimaryPart = root
	if math.abs(size - 1) > 1e-3 then
		model:ScaleTo(size)
	end
	-- R6: the root's middle is a leg and half a torso above the feet.
	model:PivotTo(feet * CFrame.new(0, 3 * size, 0))
	local motors = Joints.find(model)
	local basis = {}
	local count = 0
	for name, motor in pairs(motors) do
		basis[name] = Joints.c0(motor).Rotation
		count += 1
	end
	if count < Joints.COUNT then
		return nil
	end
	if collide then
		Create("Part", {
			Name = "Body",
			Size = Vector3.new(2.6, 5, 1.8) * size,
			CFrame = feet * CFrame.new(0, 2.5 * size, 0),
			Transparency = 1,
			Anchored = true,
			CanCollide = true,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = model,
		})
	end
	model.Parent = parent
	return {
		model = model,
		root = root,
		scale = size,
		motors = motors,
		basis = basis,
		clip = nil,
		started = 0,
		cycle = nil,
		travel = true,
	}
end

-- A faceless stone figure standing on `feet`. Props: parent, feet, scale (1), collide (people cannot walk
-- through it), name.
function StoneFigures.new(
	props: { parent: Instance, feet: CFrame, scale: number?, collide: boolean?, name: string? }
): Figure
	local model = plainRig()
	model.Name = props.name or "StoneFigure"
	local figure = StoneFigures.adopt(model, props.parent, props.feet, props.scale, props.collide)
	assert(figure, "a plain rig has every joint")
	return figure
end

-- Something of stone fixed to one of the figure's parts ("Right Arm", "Head", "Torso"...): `offset` from that
-- part's middle and `size`, both for a life-size figure (they grow with it). Returns the part.
function StoneFigures.attach(figure: Figure, limb: string, size: Vector3, offset: CFrame, color: Color3?): BasePart?
	local home = figure.model:FindFirstChild(limb)
	if not home or not home:IsA("BasePart") then
		return nil
	end
	local s = figure.scale
	local scaled = CFrame.new(offset.Position * s) * offset.Rotation
	local part = Create("Part", {
		Name = "Prop",
		Size = size * s,
		CFrame = home.CFrame * scaled,
		Color = color or StoneFigures.STONE,
		Material = Enum.Material.Slate,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = figure.model,
	}) :: BasePart
	still(part)
	Create("WeldConstraint", { Part0 = home, Part1 = part, Parent = part })
	return part
end

local function write(figure: Figure, time: number)
	local clip = figure.clip
	if not clip then
		return
	end
	table.clear(scratch)
	local rotations, offset = ClipPlayer.sample(clip, time, scratch)
	local shift = if offset and figure.travel then offset * figure.scale else nil
	for joint, motor in pairs(figure.motors) do
		local basis = figure.basis[joint]
		motor.Transform =
			ClipPlayer.transform(basis, rotations[joint] or IDENTITY, if joint == "root" then shift else nil)
	end
end

local function timeOf(figure: Figure, now: number): number
	local elapsed = math.max(0, now - figure.started)
	local cycle = figure.cycle
	if cycle and cycle > 0 then
		return elapsed % cycle
	end
	return elapsed
end

local function step()
	local now = os.clock()
	for figure in pairs(playing) do
		if not figure.model.Parent then
			playing[figure] = nil
		else
			write(figure, timeOf(figure, now))
		end
	end
	if next(playing) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

-- One moment of a clip, held (`at` seconds into it).
function StoneFigures.pose(figure: Figure, clipId: string, at: number, options: Options?)
	local clip = ClipPlayer.get(clipId)
	if not clip then
		return
	end
	playing[figure] = nil
	figure.clip = clip
	figure.travel = not (options and options.travel == false)
	write(figure, at)
end

-- Plays a clip from now on: a looping clip loops; with `cycle`, any clip starts again every `cycle` seconds
-- and holds its last moment in between.
function StoneFigures.play(figure: Figure, clipId: string, options: Options?)
	local clip = ClipPlayer.get(clipId)
	if not clip then
		return
	end
	figure.clip = clip
	figure.cycle = if options then options.cycle else nil
	figure.travel = not (options and options.travel == false)
	figure.started = os.clock() - (if options and options.phase then options.phase else 0)
	playing[figure] = true
	if not connection then
		-- Joints take their Transform in the simulation step (as Anim/PoseController does).
		connection = RunService.PreSimulation:Connect(step)
	end
end

-- Stops moving, where it is.
function StoneFigures.hold(figure: Figure)
	playing[figure] = nil
end

function StoneFigures.isPlaying(figure: Figure): boolean
	return playing[figure] == true
end

function StoneFigures.destroy(figure: Figure)
	playing[figure] = nil
	figure.model:Destroy()
end

return StoneFigures
