-- Spawning, placement, freezing and the visible props that hang on characters
-- (paper in hand, hood, notebook, red shinigami eyes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Create = require(Shared:WaitForChild("Create"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local Match = require(script.Parent.Match)

local SpectateRemote = Net.event("Spectate")

local CharacterService = {}

-- Fired as (player, character) once a new character is ready.
CharacterService.CharacterSpawned = Signal.new()

local glowTokens = setmetatable({}, { __mode = "k" })

local function getHumanoid(character: Model): Humanoid?
	return character:FindFirstChildOfClass("Humanoid")
end

local function getRoot(character: Model): BasePart?
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function findBodyPart(character: Model, names: { string }): BasePart?
	for _, name in ipairs(names) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

function CharacterService.load(player: Player)
	task.spawn(function()
		if player.Parent ~= Players then
			return
		end
		local ok, err = pcall(function()
			player:LoadCharacterAsync()
		end)
		if not ok then
			warn("[Inkbound] Could not load character for " .. player.Name .. ": " .. tostring(err))
		end
	end)
end

-- Height of the root part above the floor for this rig.
local function groundOffset(character: Model): number
	local humanoid = getHumanoid(character)
	local root = getRoot(character)
	if humanoid and root and humanoid.RigType == Enum.HumanoidRigType.R15 then
		return humanoid.HipHeight + root.Size.Y / 2
	end
	return 3
end

-- floorCFrame sits on the floor surface and faces the wanted direction.
function CharacterService.placeAt(player: Player, floorCFrame: CFrame)
	local character = player.Character
	if not character then
		return
	end
	character:PivotTo(floorCFrame + Vector3.new(0, groundOffset(character), 0))
end

function CharacterService.setFrozen(player: Player, frozen: boolean)
	local character = player.Character
	if not character then
		return
	end
	local root = getRoot(character)
	if root then
		root.Anchored = frozen
	end
	local humanoid = getHumanoid(character)
	if humanoid then
		humanoid.WalkSpeed = if frozen then 0 else 16
		humanoid.JumpPower = if frozen then 0 else 50
		humanoid.JumpHeight = if frozen then 0 else 7.2
	end
end

function CharacterService.setDisplayName(player: Player, name: string)
	local character = player.Character
	local humanoid = character and getHumanoid(character)
	if humanoid then
		humanoid.DisplayName = name
	end
end

-- Puts a living player where the current phase expects them.
function CharacterService.placeForPhase(ps)
	local map = Match.map
	if not map or not ps.alive then
		return
	end
	local phase = Match.phase
	local seated = phase == "Meeting" or phase == "Vote" or phase == "Verdict" or phase == "Outro"
	if seated and ps.seatCFrame then
		CharacterService.placeAt(ps.player, ps.seatCFrame)
		CharacterService.setFrozen(ps.player, true)
	else
		local spawnCFrame = map.spawns[Match.rng:NextInteger(1, #map.spawns)]
		CharacterService.placeAt(ps.player, spawnCFrame)
		CharacterService.setFrozen(ps.player, phase ~= "Investigation")
	end
end

-- Props --------------------------------------------------------------------------

-- Builds decorative parts relative to a body part and welds each one to it.
-- build(anchorCFrame, anchorPart) must return a list of parts placed in world space.
function CharacterService.attachBuilt(player: Player, name: string, bodyParts: { string }, build)
	local character = player.Character
	if not character then
		return
	end
	CharacterService.detach(player, name)
	local anchor = findBodyPart(character, bodyParts)
	if not anchor then
		return
	end
	local holder = Create("Model", { Name = name })
	for _, part in ipairs(build(anchor.CFrame, anchor)) do
		part.Anchored = false
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Massless = true
		part.CastShadow = false
		Create("WeldConstraint", { Part0 = anchor, Part1 = part, Parent = part })
		part.Parent = holder
	end
	holder.Parent = character
end

function CharacterService.detach(player: Player, name: string)
	local character = player.Character
	if not character then
		return
	end
	local existing = character:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
end

local HAND = { "RightHand", "Right Arm" }
local HEAD = { "Head" }
local TORSO = { "UpperTorso", "Torso" }

-- A sheet of paper in the right hand. Everyone can see who carries paper.
function CharacterService.setCarry(player: Player, kind: string?)
	if not kind then
		CharacterService.detach(player, "LCarry")
		return
	end
	CharacterService.attachBuilt(player, "LCarry", HAND, function(anchor: CFrame)
		local sheet = Create("Part", {
			Size = Vector3.new(0.8, 1.05, 0.05),
			Color = if kind == "note" then Color3.fromRGB(245, 240, 220) else Color3.fromRGB(252, 252, 252),
			Material = Enum.Material.SmoothPlastic,
			CFrame = anchor * CFrame.new(0, -0.9, -0.35) * CFrame.Angles(math.rad(-20), 0, 0),
		})
		local parts = { sheet }
		if kind == "note" then
			table.insert(
				parts,
				Create("Part", {
					Size = Vector3.new(0.6, 0.05, 0.06),
					Color = Color3.fromRGB(30, 30, 30),
					Material = Enum.Material.SmoothPlastic,
					CFrame = sheet.CFrame * CFrame.new(0, 0.2, -0.02),
				})
			)
		end
		return parts
	end)
end

-- The hood blocks the shinigami eyes. It is plainly visible on the character.
function CharacterService.setHood(player: Player, on: boolean)
	if not on then
		CharacterService.detach(player, "LHood")
		return
	end
	CharacterService.attachBuilt(player, "LHood", HEAD, function(anchor: CFrame, head: BasePart)
		local size = math.max(head.Size.X, head.Size.Z) + 0.45
		local shell = Create("Part", {
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Color = Color3.fromRGB(28, 26, 32),
			Material = Enum.Material.Fabric,
			CFrame = anchor * CFrame.new(0, 0.15, 0.22),
		})
		local drape = Create("Part", {
			Size = Vector3.new(size * 0.9, 0.9, size * 0.55),
			Color = Color3.fromRGB(28, 26, 32),
			Material = Enum.Material.Fabric,
			CFrame = anchor * CFrame.new(0, -0.55, 0.35),
		})
		return { shell, drape }
	end)
end

-- Everyone holds the same notebook during the Death Note phase, so the screens look
-- identical from the outside.
function CharacterService.setWriting(player: Player, on: boolean)
	if not on then
		CharacterService.detach(player, "LWriting")
		return
	end
	CharacterService.attachBuilt(player, "LWriting", TORSO, function(anchor: CFrame)
		local cover = Create("Part", {
			Size = Vector3.new(1.3, 0.12, 0.95),
			Color = Color3.fromRGB(22, 22, 26),
			Material = Enum.Material.SmoothPlastic,
			CFrame = anchor * CFrame.new(0, -0.35, -1.05) * CFrame.Angles(math.rad(35), 0, 0),
		})
		local pages = Create("Part", {
			Size = Vector3.new(1.2, 0.06, 0.88),
			Color = Color3.fromRGB(240, 236, 225),
			Material = Enum.Material.SmoothPlastic,
			CFrame = cover.CFrame * CFrame.new(0, 0.09, 0),
		})
		return { cover, pages }
	end)
end

-- The visible tell of a shinigami eyes read: red glowing eyes for a few seconds.
function CharacterService.glowEyes(player: Player, duration: number)
	local token = (glowTokens[player] or 0) + 1
	glowTokens[player] = token
	CharacterService.attachBuilt(player, "LEyesGlow", HEAD, function(anchor: CFrame, head: BasePart)
		local parts = {}
		for _, side in ipairs({ -0.2, 0.2 }) do
			table.insert(
				parts,
				Create("Part", {
					Size = Vector3.new(0.2, 0.12, 0.06),
					Color = Color3.fromRGB(255, 25, 25),
					Material = Enum.Material.Neon,
					CFrame = anchor * CFrame.new(side, 0.12, -head.Size.Z / 2 - 0.03),
				})
			)
		end
		Create("PointLight", {
			Color = Color3.fromRGB(255, 40, 40),
			Range = 8,
			Brightness = 4,
			Parent = parts[1],
		})
		return parts
	end)
	task.delay(duration, function()
		if glowTokens[player] == token then
			CharacterService.detach(player, "LEyesGlow")
		end
	end)
end

-- Elimination ---------------------------------------------------------------------

function CharacterService.onEliminated(ps, kind: string)
	local player = ps.player
	if kind == "dead" then
		local character = player.Character
		if not character then
			return
		end
		local root = getRoot(character)
		if root then
			root.Anchored = false
		end
		local humanoid = getHumanoid(character)
		if humanoid then
			humanoid.Health = 0
		else
			CharacterService.load(player)
		end
	elseif kind == "voted" or kind == "arrested" then
		local character = player.Character
		task.delay(2.5, function()
			if player.Parent == Players and player.Character == character then
				CharacterService.load(player)
			end
		end)
	end
end

-- Spawning ---------------------------------------------------------------------------

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)
	humanoid.BreakJointsOnDeath = false
	humanoid.NameOcclusion = Enum.NameOcclusion.OccludeAll
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 60

	local ps = Match.getLiving(player)
	if ps then
		humanoid.DisplayName = ps.alias
	else
		humanoid.DisplayName = player.DisplayName
	end

	humanoid.Died:Connect(function()
		local stillPlaying = Match.getLiving(player) ~= nil
		task.delay(if stillPlaying then 2 else 5, function()
			if player.Parent == Players and player.Character == character then
				CharacterService.load(player)
			end
		end)
	end)

	if ps then
		-- Wait a frame so the default spawn positioning has finished.
		RunService.Heartbeat:Wait()
		if player.Character == character and Match.getLiving(player) == ps then
			CharacterService.placeForPhase(ps)
		end
	end

	if player.Character == character then
		CharacterService.CharacterSpawned:Fire(player, character)
	end
end

-- Spectators (dead or lobby players during a match) stream the area around the
-- player they watch. Living players cannot spectate.
local function onSpectate(player: Player, targetUserId)
	if Match.getLiving(player) then
		return
	end
	local target = if type(targetUserId) == "number" then Match.getByUserId(targetUserId) else nil
	local root = if target and target.alive then Match.rootPart(target) else nil
	player.ReplicationFocus = root
end

function CharacterService.init()
	Players.CharacterAutoLoads = false
	SpectateRemote.OnServerEvent:Connect(onSpectate)
	local function setup(player: Player)
		player.CharacterAdded:Connect(function(character)
			onCharacterAdded(player, character)
		end)
		CharacterService.load(player)
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in ipairs(Players:GetPlayers()) do
		setup(player)
	end
end

return CharacterService
