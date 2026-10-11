--!strict
-- The lobby's fixtures, built at the scene's anchors (art/scripts/maps/venues/lobby):
--
--   * the candles on the twelve stones at the plaza's middle (ready<n>): each a Model tagged LReadyCandle
--     with its number (attribute Index), holding the wax ("Wax") and an unlit flame ("Flame", with a
--     PointLight). Every client lights as many as there are players ready (client World/ReadyCircle);
--   * the guard round the rift (anchor rift): an invisible wall just outside its rim. The scene leaves the
--     rim open, for the dive; until the dive is in the game, nobody may fall in;
--   * marks for what each client builds for itself, in stone: the five tableaux (tableau<n>: a part tagged
--     LTableau, attributes Index and Radius, at the base's top, facing the plaza) and the throne's seat
--     (throne: a part tagged LThroneSeat at the seat's top, facing the way the throne does). See client
--     World/Tableaux and World/Champion;
--   * the spot under the Academy's gate where the Trial can be begun (a part tagged LTrialStart; client
--     Onboarding/TrialController puts the prompt on it).
--
-- Nothing here has rules of its own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))

local LobbyFixtures = {}

LobbyFixtures.CANDLE_TAG = "LReadyCandle"
LobbyFixtures.TABLEAU_TAG = "LTableau"
LobbyFixtures.THRONE_TAG = "LThroneSeat"
LobbyFixtures.TRIAL_TAG = "LTrialStart"

local WAX = Color3.fromRGB(206, 200, 186)
local FLAME = Color3.fromRGB(205, 222, 245)
-- How far outside the rift's edge the guard stands, and how tall it is (well over a jump).
local GUARD_OUT = 3.5
local GUARD_HEIGHT = 26
local GUARD_SEGMENTS = 24
-- The rim wobbles by a few percent round the ellipse the anchor gives.
local RIM_WOBBLE = 1.08

type Anchor = { x: number, y: number, z: number, rot: number, w: number?, h: number?, rx: number?, rz: number? }

local function inert(part: BasePart)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
end

local function candle(b, folder: Instance, a: Anchor, index: number)
	local model = Create("Model", { Name = "Candle" .. index, Parent = folder })
	-- Each a little different in height, and turned its own way.
	local height = 0.9 + ((index * 7) % 5) * 0.12
	local base = b:world(b:cf(a.x, a.y, a.z, (index * 47) % 360))
	local wax = Create("Part", {
		Name = "Wax",
		Size = Vector3.new(0.46, height, 0.46),
		CFrame = base * CFrame.new(0, height / 2, 0),
		Color = WAX,
		Material = Enum.Material.SmoothPlastic,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = model,
	}) :: BasePart
	inert(wax)
	local flame = Create("Part", {
		Name = "Flame",
		Size = Vector3.new(0.22, 0.46, 0.22),
		CFrame = base * CFrame.new(0, height + 0.3, 0),
		Color = FLAME,
		Material = Enum.Material.Neon,
		Transparency = 1,
		TopSurface = Enum.SurfaceType.Smooth,
		BottomSurface = Enum.SurfaceType.Smooth,
		Parent = model,
	}) :: BasePart
	inert(flame)
	Create("PointLight", {
		Color = FLAME,
		Range = 9,
		Brightness = 0.9,
		Shadows = false,
		Enabled = false,
		Parent = flame,
	})
	model.PrimaryPart = wax
	model:SetAttribute("Index", index)
	model:AddTag(LobbyFixtures.CANDLE_TAG)
end

-- An invisible wall round the rift, GUARD_OUT outside its edge. The rift is an ellipse (radii rx, rz) turned
-- by `rot` degrees in the ground's plane (x east, z south), as the stone-toss reads it (Shared/LobbyGames/Toss).
local function riftGuard(b, folder: Instance, rift: Anchor)
	local rx = (rift.rx or 23) * RIM_WOBBLE + GUARD_OUT
	local rz = (rift.rz or 15) * RIM_WOBBLE + GUARD_OUT
	local turn = math.rad(rift.rot)
	local function at(k: number): Vector3
		local a = 2 * math.pi * k / GUARD_SEGMENTS
		local x, z = math.cos(a) * rx, math.sin(a) * rz
		return Vector3.new(
			rift.x + x * math.cos(turn) - z * math.sin(turn),
			0,
			rift.z + x * math.sin(turn) + z * math.cos(turn)
		)
	end
	for k = 1, GUARD_SEGMENTS do
		local p, q = at(k - 1), at(k)
		local mid = (p + q) / 2
		local wall = Create("Part", {
			Name = "RiftGuard",
			Size = Vector3.new(1, GUARD_HEIGHT, (q - p).Magnitude + 1),
			CFrame = b:world(
				CFrame.lookAt(
					mid + Vector3.new(0, GUARD_HEIGHT / 2 - 1, 0),
					q + Vector3.new(0, GUARD_HEIGHT / 2 - 1, 0)
				)
			),
			Transparency = 1,
			Anchored = true,
			CanCollide = true,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
			Parent = folder,
		}) :: BasePart
		wall:AddTag("LRiftGuard")
	end
end

-- An unseen part at an anchor, tagged, for the clients to build at.
local function mark(b, folder: Instance, name: string, tag: string, a: Anchor): BasePart
	local part = Create("Part", {
		Name = name,
		Size = Vector3.new(1, 0.2, 1),
		CFrame = b:world(b:cf(a.x, a.y, a.z, a.rot)),
		Transparency = 1,
		Parent = folder,
	}) :: BasePart
	inert(part)
	part:AddTag(tag)
	return part
end

function LobbyFixtures.build(b, anchors: { [string]: Anchor })
	local folder = Create("Folder", { Name = "Fixtures", Parent = b.parent })
	local index = 1
	while anchors["ready" .. index] do
		candle(b, folder, anchors["ready" .. index], index)
		index += 1
	end
	if index == 1 then
		warn("[DeathsGambit] The lobby scene has no candle stones (ready1, ready2...).")
	end
	if anchors.rift then
		riftGuard(b, folder, anchors.rift)
	end
	index = 1
	while anchors["tableau" .. index] do
		local a = anchors["tableau" .. index]
		local part = mark(b, folder, "Tableau" .. index, LobbyFixtures.TABLEAU_TAG, a)
		part:SetAttribute("Index", index)
		part:SetAttribute("Radius", (a :: any).r or 6)
		index += 1
	end
	if anchors.throne then
		mark(b, folder, "ThroneSeat", LobbyFixtures.THRONE_TAG, anchors.throne)
	end
	-- Where the Trial can be begun by anyone: under the Academy's gate (its sign's anchor is up on the lintel).
	local gate = anchors.academyGate
	if gate then
		mark(b, folder, "TrialStart", LobbyFixtures.TRIAL_TAG, { x = gate.x, y = 3, z = gate.z, rot = gate.rot })
	end
	return folder
end

return LobbyFixtures
