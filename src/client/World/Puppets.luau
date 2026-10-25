--!strict
-- The Academy's three practice puppets and the hand that holds their strings (the owner's reference of
-- 2026-10-13: a wooden artist's mannequin on strings, a hand above it; the game's tagline, the fate Diavolo
-- chose for you). Built on this client only, over the server's marks (Maps/Lobby): each practice figure's
-- torso (tag LDummy, attribute Feet: where its feet stand) and the hand's mark (tag LPuppeteer: the middle
-- of the fingertips, facing the way the three face).
--
-- Once the Lobby models are imported (ModelLibrary "Puppet" and "PuppeteerHand", see
-- art/scripts/props_lobby.py) each figure becomes a puppet hanging a hand's width over its stone, five
-- strings (head, wrists, knees) up to the fingers, and the server's grey stand-in turns invisible here; its
-- name tag rides on the puppet's chest. Without the import the stand-ins stay, and nothing moves.
--
-- The puppets sway on their strings and the fingers drift; under reduced motion (or low graphics) they
-- hang still. A drill's reaction plays on this screen only (UI/PracticePanel): drop (a name written in the
-- Manual: the strings go slack, it falls in a heap on its stone, and is hauled back up) and jerk (a
-- warrant: yanked upright by a sharp pull of the finger).
--
-- Each piece of a puppet turns about the ball at its top (the catalog's `hinge`), pieces hanging from
-- pieces (the pelvis is the prop itself); each finger turns about its knuckle.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local ModelLibrary = require(Shared:WaitForChild("ModelLibrary"))

local Settings = require(script.Parent.Parent.UI.Core.Settings)
local Vfx = require(script.Parent.Parent.Presentation.Vfx)

local Puppets = {}

local PUPPET, HAND = "Puppet", "PuppeteerHand"
local DUMMY_TAG, HAND_TAG = "LDummy", "LPuppeteer"
local HANG = 0.4 -- a hand's width between the stone and the puppet's feet
local NEAR = 140 -- they move while the camera is this near
local DOWN = Vector3.new(0, -1, 0)
local STRING_COLOR = Color3.fromRGB(204, 200, 190)

-- Each piece and the piece it hangs from, parents first (the pelvis is the prop's own mesh).
local CHAIN: { { string } } = {
	{ "Chest", "Pelvis" },
	{ "Head", "Chest" },
	{ "UpperArmL", "Chest" },
	{ "ForearmL", "UpperArmL" },
	{ "HandL", "ForearmL" },
	{ "UpperArmR", "Chest" },
	{ "ForearmR", "UpperArmR" },
	{ "HandR", "ForearmR" },
	{ "ThighL", "Pelvis" },
	{ "ShinL", "ThighL" },
	{ "FootL", "ShinL" },
	{ "ThighR", "Pelvis" },
	{ "ShinR", "ThighR" },
	{ "FootR", "ShinR" },
}
-- Where the five strings are tied (a point of the catalog's hinge, and the piece it moves with). The head's
-- goes to a fingertip; the others to whichever finger point is nearest above.
local TIES: { { string } } = {
	{ "HeadTop", "Head" },
	{ "HandL", "HandL" },
	{ "HandR", "HandR" },
	{ "ShinL", "ShinL" },
	{ "ShinR", "ShinR" },
}
local FINGERS = { "Thumb", "Index", "Middle", "Ring", "Little" }

type Pose = { root: CFrame, turns: { [string]: CFrame } }

type Puppet = {
	torso: BasePart,
	model: Model,
	pivot: CFrame, -- where the puppet's pivot (the middle under its feet) rests
	pieces: { [string]: { BasePart } }, -- "Pelvis" for the prop's own parts
	rest: { [BasePart]: CFrame }, -- each part from the pivot, at rest
	hinge: { [string]: Vector3 }, -- the joints (and tie points) from the pivot
	tag: BasePart?,
	tagRest: CFrame,
	hidden: { [BasePart]: number }, -- the stand-in's parts, with their own transparency
	ties: { [string]: Attachment },
	beams: { Beam },
	phase: number,
	-- A reaction: what plays, since when.
	act: string?,
	actAt: number,
}

type Hand = {
	mark: BasePart,
	model: Model,
	pivot: CFrame,
	fingers: { [string]: { BasePart } },
	rest: { [BasePart]: CFrame },
	joints: { [string]: Vector3 },
	points: { [Attachment]: string },
	pull: { [string]: number }, -- a finger's extra curl now (a reaction's pull), radians
	pullAt: { [string]: number },
	used: { [string]: number }, -- strings tied to each finger point
}

local folder: Folder? = nil
local puppets: { [BasePart]: Puppet } = {}
local hand: Hand? = nil

local function still(): boolean
	return Settings.get("reduceMotion") == true or Settings.get("lowGraphics") == true
end

local function vector(values: { number }?): Vector3
	if not values then
		return Vector3.zero
	end
	return Vector3.new(values[1], values[2], values[3])
end

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- A model's parts, by the piece they belong to (the meshes <key>_<piece>; the rest is "main").
local function piecesOf(model: Model, key: string, names: { string }): { [string]: { BasePart } }
	local found: { [string]: { BasePart } } = { main = {} }
	local owner: { [BasePart]: string } = {}
	for _, name in ipairs(names) do
		local instance = model:FindFirstChild(key .. "_" .. name, true)
		if instance then
			local list = if instance:IsA("BasePart") then { instance } else {}
			for _, item in ipairs(instance:GetDescendants()) do
				if item:IsA("BasePart") then
					table.insert(list, item)
				end
			end
			found[name] = list
			for _, part in ipairs(list) do
				owner[part] = name
			end
		end
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and not owner[item] then
			table.insert(found.main, item)
		end
	end
	return found
end

-- The catalog's named points (joints, string ties...), from the prop's pivot, in studs (every copy
-- ModelLibrary hands out is the catalog's size).
local function pointsOf(info: ModelLibrary.Info): { [string]: Vector3 }
	local points = {}
	for name, at in pairs(info.hinge or {}) do
		points[name] = vector(at)
	end
	return points
end

-- The hand -------------------------------------------------------------------------------------------------

local function buildHand(mark: BasePart)
	if hand or not folder then
		return
	end
	local info = ModelLibrary.info(HAND)
	local model = ModelLibrary.get(HAND)
	if not info or not model then
		return
	end
	local points = pointsOf(info)
	-- The middle of the fingertips goes on the mark.
	local pivot = mark.CFrame * CFrame.new(-points.Anchor)
	model.Name = "PuppeteerHand"
	model:PivotTo(pivot)
	model.Parent = folder
	local pieces = piecesOf(model, HAND, FINGERS)
	local rest = {}
	for _, list in pairs(pieces) do
		for _, part in ipairs(list) do
			rest[part] = pivot:ToObjectSpace(part.CFrame)
			part.CastShadow = false
		end
	end
	local made: Hand = {
		mark = mark,
		model = model,
		pivot = pivot,
		fingers = pieces,
		rest = rest,
		joints = {},
		points = {},
		pull = {},
		pullAt = {},
		used = {},
	}
	for _, finger in ipairs(FINGERS) do
		made.joints[finger] = points[finger] or Vector3.zero
		made.pull[finger] = 0
		made.pullAt[finger] = -math.huge
		-- The string points: the tip, and the middle joint.
		local carrier = (pieces[finger] or {})[1]
		if carrier then
			for _, where in ipairs({ "Tip", "Mid" }) do
				local at = points[finger .. where]
				if at then
					local attachment = Create("Attachment", {
						Name = finger .. where,
						CFrame = carrier.CFrame:ToObjectSpace(pivot * CFrame.new(at)),
						Parent = carrier,
					}) :: Attachment
					made.points[attachment] = finger
				end
			end
		end
	end
	-- Lit from above, and the arm lost in the haze behind.
	local main = pieces.main[1]
	if main and points.Above then
		local lamp = Create("Attachment", {
			Name = "Lamp",
			CFrame = main.CFrame:ToObjectSpace(pivot * CFrame.new(points.Above)),
			Parent = main,
		})
		Create("SpotLight", {
			Face = Enum.NormalId.Bottom,
			Angle = 70,
			Range = 34,
			Brightness = 1.6,
			Color = Color3.fromRGB(222, 226, 234),
			Shadows = false,
			Parent = lamp,
		})
		lamp.WorldCFrame = CFrame.new(lamp.WorldPosition)
	end
	if main and points.ArmEnd then
		for _, share in ipairs({ 1, 0.62 }) do
			local haze = Create("Attachment", {
				Name = "Haze",
				CFrame = main.CFrame:ToObjectSpace(pivot * CFrame.new(points.ArmEnd * share)),
				Parent = main,
			})
			-- (the kit's smoke, each cloud slowly coming apart over its long life)
			Vfx.Emit.make(haze, {
				tex = "VfxSmoke",
				grid = 8,
				mode = "OneShot",
				color = Color3.fromRGB(36, 38, 44),
				light = 0,
				lit = 0.3,
				size = { { 0, 9 }, { 1, 16 } },
				alpha = { { 0, 1 }, { 0.25, 0.45 }, { 0.75, 0.55 }, { 1, 1 } },
				life = { 6, 9 },
				speed = { 0.3, 0.9 },
				spread = 180,
				rot = { 0, 360 },
				spin = { -8, 8 },
				rate = if share == 1 then 2.4 else 1.2,
			})
		end
	end
	hand = made
end

local function poseHand(now: number)
	local h = hand
	if not h then
		return
	end
	local moving = not still()
	local parts, places = {}, {}
	for index, finger in ipairs(FINGERS) do
		local drift = if moving then 0.035 * math.sin(now * 0.45 + index * 1.7) else 0
		-- A reaction's pull: sharp, then let go over a second.
		local since = now - h.pullAt[finger]
		local pull = h.pull[finger] * math.max(0, 1 - since / 1.1)
		local joint = h.joints[finger]
		local turn = CFrame.new(joint) * CFrame.Angles(drift - pull, 0, 0) * CFrame.new(-joint)
		for _, part in ipairs(h.fingers[finger] or {}) do
			table.insert(parts, part)
			table.insert(places, h.pivot * turn * h.rest[part])
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, places, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

-- Pulls the fingers a puppet's strings are tied to (radians of curl).
local function pullFingers(p: Puppet, amount: number)
	local h = hand
	if not h then
		return
	end
	local now = os.clock()
	for _, beam in ipairs(p.beams) do
		local top = beam.Attachment0
		local finger = if top then h.points[top] else nil
		if finger then
			h.pull[finger] = amount
			h.pullAt[finger] = now
		end
	end
end

-- Puppets ---------------------------------------------------------------------------------------------------

local function newPose(): Pose
	return { root = CFrame.identity, turns = {} }
end

local function turn(pose: Pose, piece: string, x: number, y: number?, z: number?)
	pose.turns[piece] = CFrame.Angles(x, y or 0, z or 0)
end

-- Hanging on its strings: a slow pendulum and a twist about the strings, limbs swinging a little behind.
local function hangPose(p: Puppet, now: number, moving: boolean): Pose
	local pose = newPose()
	local t = now + p.phase
	local swing = if moving then 1 else 0
	local top = (p.hinge.HeadTop or Vector3.new(0, 6.4, 0)) + Vector3.new(0, 8, 0)
	pose.root = CFrame.new(top)
		* CFrame.Angles(
			0.02 * swing * math.sin(t * 0.9),
			0.07 * swing * math.sin(t * 0.37),
			0.026 * swing * math.sin(t * 0.7)
		)
		* CFrame.new(-top)
	local lag = math.sin(t * 0.7 - 0.6)
	turn(pose, "Head", -0.05 + 0.04 * swing * math.sin(t * 0.8 + 1))
	turn(pose, "UpperArmL", 0.05 + 0.05 * swing * math.sin(t * 0.9 + 0.4), 0, -0.06 - 0.04 * swing * lag)
	turn(pose, "UpperArmR", 0.05 + 0.05 * swing * math.sin(t * 0.9 + 2.1), 0, 0.06 + 0.04 * swing * lag)
	turn(pose, "ForearmL", 0.12 + 0.04 * swing * math.sin(t * 1.1))
	turn(pose, "ForearmR", 0.12 + 0.04 * swing * math.sin(t * 1.1 + 1.3))
	turn(pose, "ThighL", 0.04 + 0.04 * swing * math.sin(t * 0.8 + 0.5))
	turn(pose, "ThighR", 0.04 + 0.04 * swing * math.sin(t * 0.8 + 2.4))
	turn(pose, "ShinL", -0.08)
	turn(pose, "ShinR", -0.08)
	-- A hanging puppet's feet point down.
	turn(pose, "FootL", -0.3)
	turn(pose, "FootR", -0.3)
	return pose
end

-- In a heap on its stone, the strings slack: sat down, slumped forward, the arms gone limp.
local function heapPose(p: Puppet): Pose
	local pose = newPose()
	local pelvis = p.hinge.Chest or Vector3.new(0, 3.97, 0)
	-- The pelvis comes down onto the stone (its joint balls rest on it).
	pose.root = CFrame.new(0, -(HANG + pelvis.Y - 0.75), 0) * CFrame.Angles(0, 0, 0.08)
	turn(pose, "Chest", -0.55, 0, 0.12)
	turn(pose, "Head", -0.6, 0.2, 0)
	turn(pose, "UpperArmL", 0.25, 0, 0.12)
	turn(pose, "UpperArmR", 0.1, 0, -0.18)
	turn(pose, "ForearmL", 0.35)
	turn(pose, "ForearmR", 0.15)
	turn(pose, "ThighL", 1.45, 0.18, 0)
	turn(pose, "ThighR", 1.4, -0.22, 0)
	turn(pose, "ShinL", -0.55)
	turn(pose, "ShinR", -0.35)
	turn(pose, "FootL", 0.2)
	turn(pose, "FootR", 0.1)
	return pose
end

-- Yanked up: lifted, arms flung up and out, head up.
local function jerkPose(): Pose
	local pose = newPose()
	pose.root = CFrame.new(0, 0.7, 0)
	turn(pose, "Head", 0.2)
	turn(pose, "UpperArmL", 0.5, 0, -0.75)
	turn(pose, "UpperArmR", 0.5, 0, 0.75)
	turn(pose, "ForearmL", 0.45)
	turn(pose, "ForearmR", 0.45)
	turn(pose, "ThighL", 0.1)
	turn(pose, "ThighR", -0.05)
	turn(pose, "FootL", -0.45)
	turn(pose, "FootR", -0.45)
	return pose
end

local function blend(a: Pose, b: Pose, t: number): Pose
	local pose = newPose()
	pose.root = a.root:Lerp(b.root, t)
	for _, link in ipairs(CHAIN) do
		local piece = link[1]
		local from, to = a.turns[piece] or CFrame.identity, b.turns[piece] or CFrame.identity
		pose.turns[piece] = from:Lerp(to, t)
	end
	return pose
end

-- The pose now, with any reaction playing over the hanging one. Returns the pose and how slack the strings
-- are (studs of sag).
local function current(p: Puppet, now: number, moving: boolean): (Pose, number)
	local hang = hangPose(p, now, moving)
	local since = now - p.actAt
	if p.act == "drop" then
		local heap = heapPose(p)
		if since < 0.4 then
			-- Falls, gathering speed.
			local t = since / 0.4
			return blend(hang, heap, t * t), 3 * t
		elseif since < 3.4 then
			-- A small bounce as it lands, then it lies there.
			local bounce = 0.12 * math.sin(math.min(1, (since - 0.4) / 0.25) * math.pi)
			heap.root = heap.root * CFrame.new(0, bounce, 0)
			return heap, 3
		elseif since < 4.9 then
			-- Hauled back up.
			local t = smooth((since - 3.4) / 1.5)
			return blend(heap, hang, t), 3 * (1 - t)
		end
		p.act = nil
	elseif p.act == "jerk" then
		local jerk = jerkPose()
		if since < 0.14 then
			return blend(hang, jerk, smooth(since / 0.14)), 0
		elseif since < 1.1 then
			local t = (since - 0.14) / 0.96
			-- Settles back with a bounce on the strings.
			local back = 1 - math.exp(-4 * t) * math.cos(t * 9)
			return blend(jerk, hang, math.clamp(back, 0, 1)), 0
		end
		p.act = nil
	end
	return hang, 0
end

local function poseOne(p: Puppet, pose: Pose, sag: number, parts: { BasePart }, places: { CFrame })
	local frames: { [string]: CFrame } = { Pelvis = pose.root }
	for _, link in ipairs(CHAIN) do
		local piece, parent = link[1], link[2]
		local joint = p.hinge[piece] or Vector3.zero
		frames[piece] = frames[parent] * CFrame.new(joint) * (pose.turns[piece] or CFrame.identity) * CFrame.new(-joint)
	end
	for piece, list in pairs(p.pieces) do
		local frame = p.pivot * (frames[if piece == "main" then "Pelvis" else piece] or pose.root)
		for _, part in ipairs(list) do
			table.insert(parts, part)
			table.insert(places, frame * p.rest[part])
		end
	end
	if p.tag then
		table.insert(parts, p.tag)
		table.insert(places, p.pivot * frames.Chest * p.tagRest)
	end
	for _, beam in ipairs(p.beams) do
		beam.CurveSize0 = sag
		beam.CurveSize1 = -sag * 0.6
	end
end

local function hideStandIn(p: Puppet)
	local model = p.torso.Parent
	if not model then
		return
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") and item ~= p.tag and (item.Name == "Figure" or item.Name == "Torso") then
			p.hidden[item] = item.Transparency
			item.Transparency = 1
		end
	end
end

local function connectStrings(p: Puppet)
	local h = hand
	if not h or #p.beams > 0 then
		return
	end
	local candidates = {}
	for attachment, finger in pairs(h.points) do
		table.insert(candidates, { attachment = attachment, finger = finger, tip = attachment.Name == finger .. "Tip" })
	end
	local across = h.mark.CFrame.RightVector
	local mine: { [Attachment]: number } = {}
	for _, tie in ipairs(TIES) do
		local low = p.ties[tie[1]]
		if low then
			local best, bestScore = nil, math.huge
			for _, candidate in ipairs(candidates) do
				if tie[1] ~= "HeadTop" or candidate.tip then
					local offset = candidate.attachment.WorldPosition - low.WorldPosition
					-- Nearest across the line of the three, a string never shared by more than two of one puppet.
					local score = math.abs(offset:Dot(across)) + (mine[candidate.attachment] or 0) * 1.5
					if score < bestScore then
						best, bestScore = candidate.attachment, score
					end
				end
			end
			if best then
				mine[best] = (mine[best] or 0) + 1
				local beam = Create("Beam", {
					Name = "String",
					Attachment0 = best,
					Attachment1 = low,
					Color = ColorSequence.new(STRING_COLOR),
					Width0 = 0.035,
					Width1 = 0.035,
					FaceCamera = true,
					Segments = 12,
					LightInfluence = 1,
					Transparency = NumberSequence.new(0.1),
					Parent = folder,
				}) :: Beam
				table.insert(p.beams, beam)
			end
		end
	end
end

local function buildPuppet(torso: BasePart)
	if puppets[torso] or not folder then
		return
	end
	local info = ModelLibrary.info(PUPPET)
	local model = ModelLibrary.get(PUPPET)
	if not info or not model then
		return
	end
	local feet = torso:GetAttribute("Feet")
	local pivot = torso.CFrame
		* (if typeof(feet) == "CFrame" then feet else CFrame.new(0, -3.8, 0))
		* CFrame.new(0, HANG, 0)
	model.Name = "Puppet_" .. tostring(torso:GetAttribute("Alias") or "")
	model:PivotTo(pivot)
	model.Parent = folder
	local names = {}
	for _, link in ipairs(CHAIN) do
		table.insert(names, link[1])
	end
	local found = piecesOf(model, PUPPET, names)
	local rest = {}
	for _, list in pairs(found) do
		for _, part in ipairs(list) do
			rest[part] = pivot:ToObjectSpace(part.CFrame)
		end
	end
	local hinge = pointsOf(info)
	local tag = torso.Parent and torso.Parent:FindFirstChild("Tag")
	local p: Puppet = {
		torso = torso,
		model = model,
		pivot = pivot,
		pieces = found,
		rest = rest,
		hinge = hinge,
		tag = if tag and tag:IsA("BasePart") then tag else nil,
		tagRest = CFrame.new((hinge.Tag or Vector3.new(0, 4.62, -0.39)) + Vector3.new(0, 0, -0.03))
			* CFrame.Angles(0, 0, math.rad(-4)),
		hidden = {},
		ties = {},
		beams = {},
		phase = (torso.Position.X + torso.Position.Z) * 0.37,
		act = nil,
		actAt = -math.huge,
	}
	for _, tie in ipairs(TIES) do
		local carrier = (found[tie[2]] or {})[1]
		local at = hinge[tie[1]]
		if carrier and at then
			p.ties[tie[1]] = Create("Attachment", {
				Name = "Tie" .. tie[1],
				CFrame = carrier.CFrame:ToObjectSpace(pivot * CFrame.new(at)),
				Parent = carrier,
			}) :: Attachment
		end
	end
	hideStandIn(p)
	puppets[torso] = p
	connectStrings(p)
end

local function removePuppet(torso: BasePart)
	local p = puppets[torso]
	if not p then
		return
	end
	puppets[torso] = nil
	for part, transparency in pairs(p.hidden) do
		if part.Parent then
			part.Transparency = transparency
		end
	end
	for _, beam in ipairs(p.beams) do
		beam:Destroy()
	end
	p.model:Destroy()
end

local function step()
	if not hand and next(puppets) == nil then
		return
	end
	local camera = workspace.CurrentCamera
	local h = hand
	local near = true
	if camera and h then
		near = (camera.CFrame.Position - h.mark.Position).Magnitude < NEAR
	end
	local now = os.clock()
	local anyActing = false
	for _, p in pairs(puppets) do
		if p.act then
			anyActing = true
		end
	end
	if not near and not anyActing then
		return
	end
	poseHand(now)
	local moving = not still()
	local parts, places = {}, {}
	for _, p in pairs(puppets) do
		local pose, sag = current(p, now, moving)
		poseOne(p, pose, sag, parts, places)
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, places, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for _, p in pairs(puppets) do
		for _, beam in ipairs(p.beams) do
			local top, low = beam.Attachment0, beam.Attachment1
			if top and low then
				top.WorldAxis = DOWN
				low.WorldAxis = DOWN
			end
		end
	end
end

-- Whether a puppet hangs in place of this practice figure (its torso, tag LDummy).
function Puppets.has(torso: BasePart): boolean
	return puppets[torso] ~= nil
end

-- The puppet's head (for whatever looks at it), or nil.
function Puppets.headOf(torso: BasePart): BasePart?
	local p = puppets[torso]
	local list = if p then p.pieces.Head else nil
	return if list then list[1] else nil
end

-- A name written in the Manual: the strings go slack, the puppet drops in a heap, and is hauled back up.
-- Returns false when no puppet hangs there (the caller plays its own).
function Puppets.drop(torso: BasePart): boolean
	local p = puppets[torso]
	if not p then
		return false
	end
	p.act = "drop"
	p.actAt = os.clock()
	task.delay(3.4, function()
		if p.act == "drop" then
			pullFingers(p, 0.35)
		end
	end)
	return true
end

-- A warrant served: the puppet is yanked upright by a sharp pull of the finger.
function Puppets.jerk(torso: BasePart): boolean
	local p = puppets[torso]
	if not p then
		return false
	end
	p.act = "jerk"
	p.actAt = os.clock()
	pullFingers(p, 0.45)
	return true
end

function Puppets.init()
	folder = Create("Folder", { Name = "DeathsGambitPuppets", Parent = workspace }) :: Folder
	local function tryHand(item: Instance)
		if item:IsA("BasePart") then
			buildHand(item)
			for _, p in pairs(puppets) do
				connectStrings(p)
			end
		end
	end
	local function tryPuppet(item: Instance)
		if item:IsA("BasePart") then
			buildPuppet(item)
		end
	end
	CollectionService:GetInstanceAddedSignal(HAND_TAG):Connect(tryHand)
	CollectionService:GetInstanceRemovedSignal(HAND_TAG):Connect(function(item: Instance)
		if hand and hand.mark == item then
			for _, p in pairs(puppets) do
				for _, beam in ipairs(p.beams) do
					beam:Destroy()
				end
				table.clear(p.beams)
			end
			hand.model:Destroy()
			hand = nil
		end
	end)
	CollectionService:GetInstanceAddedSignal(DUMMY_TAG):Connect(tryPuppet)
	CollectionService:GetInstanceRemovedSignal(DUMMY_TAG):Connect(function(item: Instance)
		if item:IsA("BasePart") then
			removePuppet(item)
		end
	end)
	for _, item in ipairs(CollectionService:GetTagged(HAND_TAG)) do
		tryHand(item)
	end
	for _, item in ipairs(CollectionService:GetTagged(DUMMY_TAG)) do
		tryPuppet(item)
	end
	RunService.Heartbeat:Connect(step)
end

return Puppets
