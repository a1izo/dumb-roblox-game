--!strict
-- A lab machine with a blinking light (graphics plan, phase 13): the University's fume hoods each get an airflow
-- alarm lamp on the front of the oak lintel above the sash, a small red light that blinks slowly, with a faint halo.
-- It is a plain small part (Neon, never solid, in no ray) set on the lintel's surface: a ray is cast at the lintel
-- from both sides and the lamp goes on whichever face is open to the room, so a hood standing against a wall gets it
-- on its front. Only lamps near the camera blink; under Reduce motion they stay lit and steady.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Util = require(script.Parent.Util)
local LifePatterns = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("LifePatterns"))

local LabLight = {}

local HOOD = "SoapstoneHood"
local LINTEL = { 2.05, 7.7 } -- on the hood (in studs at scale 1): how far right of its middle, and how high
local NEAR = 60
local LIT = Color3.fromRGB(255, 56, 40)
local DIM = Color3.fromRGB(70, 12, 10)
local PERIOD = 2.2
local DUTY = 0.3

type Lamp = { part: Part, halo: ImageLabel, phase: number, lit: boolean? }

-- Where on the lintel the lamp goes: the surface point and the way it faces, or nil.
local function surface(model: Model, world: RaycastParams): (Vector3, Vector3)?
	local scale = model:GetScale()
	local pivot = model:GetPivot()
	local own = RaycastParams.new()
	own.FilterType = Enum.RaycastFilterType.Include
	own.FilterDescendantsInstances = { model }
	local x, y = LINTEL[1] * scale, LINTEL[2] * scale
	for _, side in ipairs({ -1, 1 }) do
		local from = pivot * Vector3.new(x, y, side * 3 * scale)
		local to = pivot * Vector3.new(x, y, 0)
		local hit = workspace:Raycast(from, to - from, own)
		if hit then
			-- (open to the room: nothing within a stud and a half in front of it)
			local blocked = workspace:Raycast(hit.Position + hit.Normal * 0.05, hit.Normal * 1.5, world)
			if not blocked then
				return hit.Position + hit.Normal * 0.05, hit.Normal
			end
		end
	end
	return nil
end

function LabLight.build(index: Util.Index, _mapId: string): Util.Built?
	local glow = Util.glow()
	local world = Util.rayParams()
	local lamps: { Lamp } = {}
	local made: { Instance } = {}
	for _, model in ipairs(index.props[HOOD] or {}) do
		local at, normal = surface(model, world)
		if at and normal then
			local part = Util.solid(
				CFrame.lookAt(at, at + normal),
				Vector3.new(0.16, 0.16, 0.08),
				LIT,
				Enum.Material.Neon,
				"HoodLamp"
			)
			part.Parent = Util.folder()
			table.insert(made, part)
			local gui = Instance.new("BillboardGui")
			gui.Size = UDim2.fromScale(1, 1) -- (a billboard's scale is studs)
			gui.LightInfluence = 0
			gui.AlwaysOnTop = false
			gui.Adornee = part
			gui.Parent = part
			local halo = Instance.new("ImageLabel")
			halo.BackgroundTransparency = 1
			halo.Size = UDim2.fromScale(1, 1)
			halo.Image = glow
			halo.ImageColor3 = LIT
			halo.ImageTransparency = 0.7
			halo.Parent = gui
			table.insert(
				lamps,
				{ part = part, halo = halo, phase = LifePatterns.phaseOf(at.X, at.Z, PERIOD), lit = nil }
			)
		end
	end
	if #lamps == 0 then
		return nil
	end
	return {
		step = function(env: Util.Env)
			for _, lamp in ipairs(lamps) do
				local lit = if env.reduced then true else LifePatterns.blink(env.now, PERIOD, DUTY, lamp.phase) == 1
				if (lamp.part.Position - env.eye).Magnitude > NEAR then
					lit = true
				end
				if lit ~= lamp.lit then
					lamp.lit = lit
					lamp.part.Color = if lit then LIT else DIM
					lamp.halo.ImageTransparency = if lit then 0.7 else 1
				end
			end
		end,
		destroy = function()
			for _, piece in ipairs(made) do
				piece:Destroy()
			end
		end,
	}
end

local kind: Util.Kind = { name = "labLight", maps = { "UniversityCampus" }, build = LabLight.build }
return kind
