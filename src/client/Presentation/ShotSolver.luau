-- Finds camera positions that can actually see their subject. Every cutscene camera goes
-- through here, so no shot ends up inside a wall, above a ceiling or on the far side of a roof:
--   * the path from the subject to the eye must be clear (a small sphere cast against anything
--     that collides: walls, ceilings, the Blender scenes' invisible colliders, their greyboxes)
--   * the eye stays at least a stud under whatever roof is above the subject
-- Preferred angles are tried first, then the rest of the circle, then closer distances.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local ShotSolver = {}

local RADIUS = 0.6
local CEILING_MARGIN = 1.2

-- Things a cutscene camera may see through: characters and the stage's own clones.
local function ignoreList(extra: { Instance }?): { Instance }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("LBotCharacter")) do
		table.insert(list, model)
	end
	local stage = workspace:FindFirstChild("DeathsGambitStage")
	if stage then
		table.insert(list, stage)
	end
	local camera = workspace.CurrentCamera
	if camera then
		table.insert(list, camera)
	end
	if extra then
		for _, item in ipairs(extra) do
			table.insert(list, item)
		end
	end
	return list
end

local function params(extra: { Instance }?): RaycastParams
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = ignoreList(extra)
	p.RespectCanCollide = true
	p.IgnoreWater = true
	return p
end

-- Height of the roof above `point` (math.huge when open sky within `up` studs).
function ShotSolver.ceiling(point: Vector3, up: number?, extra: { Instance }?): number
	local hit = workspace:Raycast(point, Vector3.new(0, up or 80, 0), params(extra))
	return if hit then hit.Position.Y else math.huge
end

-- True when a camera at `eye` sees `target` with nothing solid in between.
function ShotSolver.clear(target: Vector3, eye: Vector3, extra: { Instance }?): boolean
	local offset = eye - target
	if offset.Magnitude < 0.5 then
		return true
	end
	local hit = workspace:Spherecast(target, RADIUS, offset, params(extra))
	return hit == nil
end

export type Framing = {
	distance: number?, -- studs from the target (default 8)
	height: number?, -- studs above the target (default 1)
	angle: number?, -- degrees around the subject from its facing (0 = in front)
	lookHeight: number?, -- aim this far above the subject's root (default: the head)
	fov: number?,
}

-- Where to look at on a model: its head, or its middle.
function ShotSolver.focus(subject: Model | Vector3): Vector3
	if typeof(subject) == "Vector3" then
		return subject
	end
	local model = subject :: Model
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	return model:GetPivot().Position + Vector3.new(0, 1.5, 0)
end

local function facing(subject: Model | Vector3): Vector3
	if typeof(subject) == "Vector3" then
		return Vector3.new(0, 0, -1)
	end
	local look = (subject :: Model):GetPivot().LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	return if flat.Magnitude > 1e-3 then flat.Unit else Vector3.new(0, 0, -1)
end

-- A camera CFrame looking at the subject from the preferred framing, or the nearest safe one.
-- Always returns something usable (right above the subject's head as a last resort).
function ShotSolver.frame(subject: Model | Vector3, framing: Framing?, extra: { Instance }?): CFrame
	local f = framing or {}
	local target = ShotSolver.focus(subject)
	if f.lookHeight and typeof(subject) ~= "Vector3" then
		target = (subject :: Model):GetPivot().Position + Vector3.new(0, f.lookHeight, 0)
	end
	local forward = facing(subject)
	local roof = ShotSolver.ceiling(target, 60, extra) - CEILING_MARGIN
	local base = f.angle or 0
	local distance = f.distance or 8
	local height = f.height or 1
	local angles = { 0, 25, -25, 50, -50, 80, -80, 115, -115, 150, -150, 180 }
	for _, scale in ipairs({ 1, 0.75, 0.5, 0.3 }) do
		for _, delta in ipairs(angles) do
			local yaw = math.rad(base + delta)
			local dir = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(forward)
			local eye = target + dir * distance * scale + Vector3.new(0, height * scale, 0)
			if eye.Y > roof then
				eye = Vector3.new(eye.X, math.max(target.Y + 0.2, roof), eye.Z)
			end
			if ShotSolver.clear(target, eye, extra) then
				return CFrame.lookAt(eye, target)
			end
		end
	end
	local eye = target + forward * 2 + Vector3.new(0, 0.5, 0)
	return CFrame.lookAt(eye, target)
end

-- A wide shot of a place (a room or a street) from inside it: the longest clear view across
-- `center` at about eye height (never above the ceiling).
function ShotSolver.establish(center: Vector3, preferredHeight: number?, extra: { Instance }?): (CFrame, CFrame)
	local ground = center
	local down = workspace:Raycast(center + Vector3.new(0, 4, 0), Vector3.new(0, -30, 0), params(extra))
	if down then
		ground = down.Position
	end
	local roof = ShotSolver.ceiling(ground + Vector3.new(0, 1, 0), 80, extra)
	local height = math.min(preferredHeight or 8, roof - ground.Y - CEILING_MARGIN)
	height = math.max(height, 3.5)
	local target = ground + Vector3.new(0, 3, 0)
	local best, bestDistance = nil, -1
	for step = 0, 11 do
		local dir = Vector3.new(math.cos(step * math.pi / 6), 0, math.sin(step * math.pi / 6))
		local p = params(extra)
		local hit = workspace:Spherecast(target, RADIUS, dir * 40, p)
		local reach = if hit then hit.Distance - 1.5 else 40
		if reach > bestDistance then
			best, bestDistance = dir, reach
		end
	end
	local dir = best or Vector3.new(0, 0, 1)
	local distance = math.clamp(bestDistance, 6, 30)
	local eye = ground + dir * distance + Vector3.new(0, height, 0)
	if not ShotSolver.clear(target, eye, extra) then
		eye = ground + dir * distance * 0.6 + Vector3.new(0, math.min(height, 4), 0)
	end
	local from = CFrame.lookAt(eye, target)
	-- The camera drifts a third of the way in.
	local to = CFrame.lookAt(eye:Lerp(target, 0.3), target)
	return from, to
end

-- The floor under a point (or the point itself when nothing is there).
function ShotSolver.floor(point: Vector3, extra: { Instance }?): Vector3
	local hit = workspace:Raycast(point + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params(extra))
	return if hit then hit.Position else point
end

return ShotSolver
