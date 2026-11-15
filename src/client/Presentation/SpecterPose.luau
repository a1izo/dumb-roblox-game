-- The Deathsinger's (Ryuk's) head and the two things that hang off him, moved on their own (the owner, 2026-11-14:
-- "head turn, no import"). The model is eight rigid MeshParts with no joints (docs/handoff/ryuk-specter-findings-2026-11-14.md),
-- but four of them are not the body: the head (Specter_Face, Specter_Hair and the two eye glows), the mane
-- (Specter_Collar) and the gear (Specter_Gear: belt, skirt, chain). Each frame this turns the head about his neck, and
-- lets the mane and the gear trail a beat behind the body's own turning, by writing those parts' CFrames. Nothing here
-- changes the model or needs an import. Client only; it does nothing to a model without those parts (the stand-in).
--
--   local pose = SpecterPose.new(model)               -- nil when the parts are not there
--   SpecterPose.apply(pose, pitch, yaw, roll)         -- degrees, every frame, before or after the model is moved
--
-- pitch + looks down, yaw + turns to his left, roll + tilts his head to his left. The turn is kept to what the neck
-- hides (checked on the exported model in Blender, 2026-11-14: no gap at the neck up to 25 degrees of yaw, 15 down and
-- 10 up of pitch, 10 of roll); more is cut off at those.
--
-- Moving the model afterwards (PivotTo) carries these parts with it, so the order within a frame does not matter: each
-- call sets the parts from the model's pivot as it is then, never from the last call.

local SpecterPose = {}

-- Where the pieces turn about, in the model's own frame (x right, y up, z back, the way it faces -z) as an offset from
-- the middle of the face piece, in studs at the size the model was made (read off the exported model: the face piece's
-- middle at (0.156, -0.889, 6.999) in Blender, the neck at (0, -0.70, 6.45), the shoulders at (0, -0.2, 6.0), the hips
-- at (0, 0.12, 3.9)); scaled by how big the face piece is now.
local FACE_DIAGONAL = 2.4776 -- the face piece's size, as made, corner to corner
local NECK = Vector3.new(0.156, -0.549, 0.189)
local SHOULDERS = Vector3.new(0.156, -0.999, 0.689)
local HIPS = Vector3.new(0.156, -3.099, 1.009)

local HEAD_PARTS = { "Specter_Face", "Specter_Hair", "Specter_Glow", "Specter_Glow2" }
local MANE_PARTS = { "Specter_Collar" }
local GEAR_PARTS = { "Specter_Gear" }

local PITCH_DOWN, PITCH_UP, YAW, ROLL = 15, 10, 25, 10 -- degrees
-- How long the mane and the gear take to catch up with the body's turning (seconds), and how far behind they may fall
-- (the gear holds the wrists' bracelets too: past about 5 degrees about the hips they would float off the arms).
local MANE_LAG, GEAR_LAG = 0.2, 0.3
local MAX_TRAIL = math.rad(5)

type Piece = { part: BasePart, rest: CFrame } -- (rest: where it sits in the model's frame)
export type Pose = {
	model: Model,
	flip: CFrame, -- the model's frame is its pivot's, turned half way round when it came in facing +z
	head: { Piece },
	mane: { Piece },
	gear: { Piece },
	neck: Vector3,
	shoulders: Vector3,
	hips: Vector3,
	lagMane: CFrame?, -- the body's turning, a beat late (the mane's, and the gear's a longer beat)
	lagGear: CFrame?,
	last: number,
}

local function part(model: Model, name: string): BasePart?
	local found = model:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

local function pieces(model: Model, names: { string }, frame: CFrame): { Piece }
	local list: { Piece } = {}
	for _, name in ipairs(names) do
		local found = part(model, name)
		if found then
			table.insert(list, { part = found, rest = frame:ToObjectSpace(found.CFrame) })
		end
	end
	return list
end

-- The pose for `model` as it stands now (call it after it is scaled and set up, before it is moved or turned by a
-- pose of its own). nil when it has no head piece or no body: the hand-built stand-in has neither.
function SpecterPose.new(model: Model): Pose?
	local face = part(model, "Specter_Face")
	local body = model.PrimaryPart
	if not face or not body then
		return nil
	end
	local pivot = model:GetPivot()
	-- (the head is thrust forward of the body's middle: if it is on the +z side of it, the model came in backwards)
	local flip = CFrame.identity
	if pivot:PointToObjectSpace(face.Position).Z > pivot:PointToObjectSpace(body.Position).Z then
		flip = CFrame.Angles(0, math.pi, 0)
	end
	local frame = pivot * flip
	local scale = face.Size.Magnitude / FACE_DIAGONAL
	local middle = frame:PointToObjectSpace(face.Position)
	return {
		model = model,
		flip = flip,
		head = pieces(model, HEAD_PARTS, frame),
		mane = pieces(model, MANE_PARTS, frame),
		gear = pieces(model, GEAR_PARTS, frame),
		neck = middle + NECK * scale,
		shoulders = middle + SHOULDERS * scale,
		hips = middle + HIPS * scale,
		lagMane = nil,
		lagGear = nil,
		last = os.clock(),
	}
end

local function about(point: Vector3, turn: CFrame): CFrame
	return CFrame.new(point) * turn * CFrame.new(-point)
end

-- Turns the pieces: the head by the angles given (degrees), the mane and the gear by how far the body's own turning
-- has run ahead of them.
function SpecterPose.apply(pose: Pose?, pitch: number?, yaw: number?, roll: number?)
	if not pose or not pose.model.Parent then
		return
	end
	local frame = pose.model:GetPivot() * pose.flip
	local nod = math.clamp(pitch or 0, -PITCH_UP, PITCH_DOWN)
	local turn = CFrame.fromEulerAnglesYXZ(
		-math.rad(nod),
		math.rad(math.clamp(yaw or 0, -YAW, YAW)),
		math.rad(math.clamp(roll or 0, -ROLL, ROLL))
	)
	local head = about(pose.neck, turn)
	for _, piece in ipairs(pose.head) do
		piece.part.CFrame = frame * head * piece.rest
	end

	-- (the body's turning, followed a beat late: the mane and the gear fall behind it by the difference)
	local now = os.clock()
	local dt = math.clamp(now - pose.last, 0, 0.1)
	pose.last = now
	local rotation = frame.Rotation
	local function trail(lagging: CFrame?, seconds: number): (CFrame, CFrame)
		local caught = (lagging or rotation):Lerp(rotation, 1 - math.exp(-dt / seconds))
		local behind = rotation:Inverse() * caught
		local _, angle = behind:ToAxisAngle()
		if angle > MAX_TRAIL then
			behind = CFrame.new():Lerp(behind, MAX_TRAIL / angle)
		end
		return caught, behind
	end
	local caughtMane, behindMane = trail(pose.lagMane, MANE_LAG)
	pose.lagMane = caughtMane
	local mane = about(pose.shoulders, behindMane)
	for _, piece in ipairs(pose.mane) do
		piece.part.CFrame = frame * mane * piece.rest
	end
	-- (the gear is heavier: it takes longer to catch up with the same turning)
	local caughtGear, behindGear = trail(pose.lagGear, GEAR_LAG)
	pose.lagGear = caughtGear
	local gear = about(pose.hips, behindGear)
	for _, piece in ipairs(pose.gear) do
		piece.part.CFrame = frame * gear * piece.rest
	end
end

return SpecterPose
