--!strict
-- The lobby's fixtures, built at the scene's anchors (art/scripts/maps/venues/lobby):
--
--   * the candles on the twelve stones at the plaza's middle (ready<n>): each a Model tagged LReadyCandle
--     with its number (attribute Index), holding the wax ("Wax") and an unlit flame ("Flame", with a
--     PointLight). Every client lights as many as there are players ready (client World/ReadyCircle);
--   * marks for what each client builds for itself, in stone: the five tableaux (tableau<n>: a part tagged
--     LTableau, attributes Index and Radius, at the base's top, facing the plaza) and the throne's seat
--     (throne: a part tagged LThroneSeat at the seat's top, facing the way the throne does). See client
--     World/Tableaux and World/Champion;
--   * the spot under the Academy's gate where the Trial can be begun (a part tagged LTrialStart; client
--     Onboarding/TrialController puts the prompt on it);
--   * the shop window: a stone plinth on the spawn terrace, east of where players appear, its top marked
--     (a part tagged LShopWindow, facing the terrace) for the mannequin each client puts on it showing the
--     day's emote (client World/ShopWindow).
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
LobbyFixtures.SHOP_WINDOW_TAG = "LShopWindow"

local WAX = Color3.fromRGB(206, 200, 186)
local PLINTH = Color3.fromRGB(88, 88, 94)
-- The shop window from where players appear: across the terrace to the east (clear of the spawn ring, the
-- braziers by the steps, the pillars and the balustrade), and the height of its plinth.
local WINDOW_OFFSET = Vector2.new(15, -2)
local WINDOW_HEIGHT = 1.4
local FLAME = Color3.fromRGB(205, 222, 245)

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
	local spawn = anchors.spawn
	if spawn then
		local x, z = spawn.x + WINDOW_OFFSET.X, spawn.z + WINDOW_OFFSET.Y
		-- Facing back across the terrace, a little towards the steps.
		local dx, dz = spawn.x - x, (spawn.z - 5) - z
		local rot = math.deg(math.atan2(-dx, -dz))
		local plinth = Create("Part", {
			Name = "ShopWindowPlinth",
			Size = Vector3.new(3.2, WINDOW_HEIGHT, 3.2),
			CFrame = b:world(b:cf(x, spawn.y + WINDOW_HEIGHT / 2, z, rot)),
			Color = PLINTH,
			Material = Enum.Material.Slate,
			TopSurface = Enum.SurfaceType.Smooth,
			BottomSurface = Enum.SurfaceType.Smooth,
			Anchored = true,
			Parent = folder,
		}) :: BasePart
		plinth.CanCollide = true
		mark(
			b,
			folder,
			"ShopWindow",
			LobbyFixtures.SHOP_WINDOW_TAG,
			{ x = x, y = spawn.y + WINDOW_HEIGHT, z = z, rot = rot }
		)
	end
	return folder
end

return LobbyFixtures
