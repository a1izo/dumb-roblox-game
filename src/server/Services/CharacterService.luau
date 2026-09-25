-- Spawning, placement, freezing, the look of characters in a match (the noir suit and the
-- game-wide movement set) and the visible props that hang on them (paper in hand, hood,
-- notebook and pen, handcuffs, red Specter's Eyes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local Models = require(Shared:WaitForChild("Models"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local Match = require(script.Parent.Match)
local RagdollService = require(script.Parent.RagdollService)

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
		CharacterService.refreshAccessories(player)
		return
	end
	CharacterService.attachBuilt(player, "LHood", HEAD, function(anchor: CFrame, head: BasePart)
		local hood = Models.hood()
		if hood then
			-- The Blender hood, scaled to this head.
			local width = hood:GetExtentsSize().X
			hood:ScaleTo(hood:GetScale() * (head.Size.X * 1.4) / math.max(width, 0.1))
			local pivot = hood:GetPivot()
			local placed = anchor * CFrame.new(0, -0.05 * head.Size.Y, 0.12 * head.Size.Z)
			local parts = {}
			for _, item in ipairs(hood:GetDescendants()) do
				if item:IsA("BasePart") then
					item.CFrame = placed * pivot:ToObjectSpace(item.CFrame)
					table.insert(parts, item)
				end
			end
			for _, part in ipairs(parts) do
				part.Parent = nil
			end
			hood:Destroy()
			return parts
		end
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
	CharacterService.refreshAccessories(player)
end

-- The parts of a model moved so its pivot sits at `placed`, taken out of the model (for
-- attachBuilt, which welds them).
local function modelParts(model: Model, placed: CFrame): { BasePart }
	local pivot = model:GetPivot()
	local parts = {}
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CFrame = placed * pivot:ToObjectSpace(item.CFrame)
			table.insert(parts, item)
		end
	end
	for _, part in ipairs(parts) do
		part.Parent = nil
	end
	model:Destroy()
	return parts
end

-- Everyone holds the same notebook during the Death Note phase, so the screens look
-- identical from the outside.
function CharacterService.setWriting(player: Player, on: boolean)
	if not on then
		CharacterService.detach(player, "LWriting")
		CharacterService.detach(player, "LWritingPen")
		return
	end
	CharacterService.attachBuilt(player, "LWritingPen", HAND, function(anchor: CFrame)
		local pen = Models.pen()
		if pen then
			return modelParts(pen, anchor * CFrame.new(0, -0.35, -0.2) * CFrame.Angles(math.rad(-55), 0, 0))
		end
		return {
			Create("Part", {
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.9, 0.09, 0.09),
				Color = Color3.fromRGB(14, 14, 16),
				Material = Enum.Material.Metal,
				CFrame = anchor * CFrame.new(0, -0.2, -0.2) * CFrame.Angles(0, math.rad(90), math.rad(-60)),
			}),
		}
	end)
	CharacterService.attachBuilt(player, "LWriting", TORSO, function(anchor: CFrame)
		local coverColor = player:GetAttribute("LGrimoireColor")
		local held = anchor * CFrame.new(0, -0.35, -1.05) * CFrame.Angles(math.rad(35), 0, 0)
		local notebook = Models.notebook()
		if notebook then
			local parts = modelParts(notebook, held)
			if typeof(coverColor) == "Color3" then
				-- A cover cosmetic: a coloured plate over the front cover.
				table.insert(
					parts,
					Create("Part", {
						Size = Vector3.new(1.26, 0.02, 0.9),
						Color = coverColor,
						Material = Enum.Material.SmoothPlastic,
						CFrame = held * CFrame.new(0, 0.115, 0),
					})
				)
			end
			return parts
		end
		local cover = Create("Part", {
			Size = Vector3.new(1.3, 0.12, 0.95),
			Color = if typeof(coverColor) == "Color3" then coverColor else Color3.fromRGB(22, 22, 26),
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

-- Handcuffs on the wrists of an arrested player (their arms go behind the back on every
-- client).
function CharacterService.cuff(player: Player)
	CharacterService.attachBuilt(player, "LCuffs", HAND, function(anchor: CFrame)
		local placed = anchor * CFrame.new(-0.35, -0.2, 0.1) * CFrame.Angles(0, math.rad(90), 0)
		return modelParts(Models.handcuffs(), placed)
	end)
end

function CharacterService.onEliminated(ps, kind: string)
	local player = ps.player
	if kind == "dead" then
		RagdollService.collapse(player, ps.alias, CharacterService.load, ps.cause)
	elseif kind == "voted" or kind == "arrested" then
		local character = player.Character
		if kind == "arrested" then
			CharacterService.cuff(player)
		end
		task.delay(if kind == "arrested" then 3.5 else 2.5, function()
			if player.Parent == Players and player.Character == character then
				CharacterService.load(player)
			end
		end)
	end
end

-- Looks -----------------------------------------------------------------------------

-- Roblox's own R15 set, used for every slot of Assets.locomotion left empty. Owned
-- animation packs never show: a player's pack could give away who is behind an alias.
local DEFAULT_LOCOMOTION = {
	idle = "507766666",
	idleAlt = "507766951",
	walk = "507777826",
	run = "507767714",
	jump = "507765000",
	fall = "507767968",
	climb = "507765644",
	swim = "507784897",
	swimIdle = "507785072",
}

-- slot -> { folder in the Animate script, animation name }
local ANIMATE_PATHS = {
	idle = { "idle", "Animation1" },
	idleAlt = { "idle", "Animation2" },
	walk = { "walk", "WalkAnim" },
	run = { "run", "RunAnim" },
	jump = { "jump", "JumpAnim" },
	fall = { "fall", "FallAnim" },
	climb = { "climb", "ClimbAnim" },
	swim = { "swim", "Swim" },
	swimIdle = { "swimidle", "SwimIdle" },
}

-- Gives the character the game-wide movement set.
function CharacterService.applyLocomotion(character: Model)
	local humanoid = getHumanoid(character)
	local animate = character:FindFirstChild("Animate")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 or not animate then
		return
	end
	for slot, path in pairs(ANIMATE_PATHS) do
		local id = Assets.locomotion[slot]
		if id == nil or id == "" then
			id = DEFAULT_LOCOMOTION[slot]
		end
		local folder = animate:FindFirstChild(path[1])
		local animation = if folder then folder:FindFirstChild(path[2]) else nil
		if animation and animation:IsA("Animation") then
			local contentId = Assets.contentId(id)
			if animation.AnimationId ~= contentId then
				animation.AnimationId = contentId
			end
		end
	end
end

local CLOTHING_ACCESSORIES = {
	[Enum.AccessoryType.Shirt] = true,
	[Enum.AccessoryType.TShirt] = true,
	[Enum.AccessoryType.Pants] = true,
	[Enum.AccessoryType.Jacket] = true,
	[Enum.AccessoryType.Sweater] = true,
	[Enum.AccessoryType.Shorts] = true,
	[Enum.AccessoryType.LeftShoe] = true,
	[Enum.AccessoryType.RightShoe] = true,
	[Enum.AccessoryType.DressSkirt] = true,
}

local SUIT = Color3.fromRGB(30, 30, 34)
local TROUSERS = Color3.fromRGB(24, 24, 28)
local SHOES = Color3.fromRGB(12, 12, 13)
local SUIT_PARTS = { "UpperTorso", "LowerTorso", "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm" }
local TROUSER_PARTS = { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg" }
local SHOE_PARTS = { "LeftFoot", "RightFoot" }

-- The match look: a dark suit, white collar and red tie over the player's own face, hair and
-- body shape. Clothing (classic and layered) is removed so outfits cannot give anyone away.
function CharacterService.applyOutfit(player: Player)
	local character = player.Character
	if not character or character:GetAttribute("LNoirOutfit") then
		return
	end
	character:SetAttribute("LNoirOutfit", true)
	local head = character:FindFirstChild("Head")
	local skin = if head and head:IsA("BasePart") then head.Color else Color3.fromRGB(200, 170, 140)
	for _, item in ipairs(character:GetChildren()) do
		local clothing = item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("BodyColors")
		if clothing or (item:IsA("Accessory") and CLOTHING_ACCESSORIES[item.AccessoryType]) then
			item:Destroy()
		end
	end
	local function paint(names: { string }, color: Color3)
		for _, name in ipairs(names) do
			local part = character:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Color = color
				part.Material = Enum.Material.Fabric
			end
		end
	end
	paint(SUIT_PARTS, SUIT)
	paint(TROUSER_PARTS, TROUSERS)
	paint(SHOE_PARTS, SHOES)
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		local hand = character:FindFirstChild(name)
		if hand and hand:IsA("BasePart") then
			hand.Color = skin
		end
	end
	if Assets.outfit.shirt ~= "" then
		Create("Shirt", { ShirtTemplate = Assets.contentId(Assets.outfit.shirt), Parent = character })
	end
	if Assets.outfit.pants ~= "" then
		Create("Pants", { PantsTemplate = Assets.contentId(Assets.outfit.pants), Parent = character })
	end
	local tieColor = player:GetAttribute("LTieColor")
	local tie = if typeof(tieColor) == "Color3" then tieColor else Color3.fromRGB(190, 22, 36)
	CharacterService.attachBuilt(player, "LNoirTie", TORSO, function(anchor: CFrame, torso: BasePart)
		local front = -torso.Size.Z / 2
		local top = torso.Size.Y / 2
		local white = Color3.fromRGB(236, 233, 226)
		return {
			Create("Part", {
				Size = Vector3.new(0.55, 0.75, 0.05),
				Color = white,
				Material = Enum.Material.SmoothPlastic,
				CFrame = anchor * CFrame.new(0, top - 0.4, front - 0.01),
			}),
			Create("Part", {
				Size = Vector3.new(0.9, 0.16, 0.08),
				Color = white,
				Material = Enum.Material.SmoothPlastic,
				CFrame = anchor * CFrame.new(0, top - 0.06, front - 0.02),
			}),
			Create("Part", {
				Name = "Knot",
				Size = Vector3.new(0.2, 0.16, 0.08),
				Color = tie:Lerp(Color3.new(0, 0, 0), 0.15),
				Material = Enum.Material.Fabric,
				CFrame = anchor * CFrame.new(0, top - 0.2, front - 0.05),
			}),
			Create("Part", {
				Name = "Tie",
				Size = Vector3.new(0.18, 0.95, 0.05),
				Color = tie,
				Material = Enum.Material.Fabric,
				CFrame = anchor * CFrame.new(0, top - 0.75, front - 0.05),
			}),
		}
	end)
end

-- Recolours the noir tie after the player changes their tie cosmetic.
function CharacterService.recolorTie(player: Player)
	local character = player.Character
	local holder = if character then character:FindFirstChild("LNoirTie") else nil
	if not holder then
		return
	end
	local tieColor = player:GetAttribute("LTieColor")
	local tie = if typeof(tieColor) == "Color3" then tieColor else Color3.fromRGB(190, 22, 36)
	for _, part in ipairs(holder:GetChildren()) do
		if part:IsA("BasePart") and part.Name == "Tie" then
			part.Color = tie
		elseif part:IsA("BasePart") and part.Name == "Knot" then
			part.Color = tie:Lerp(Color3.new(0, 0, 0), 0.15)
		end
	end
end

-- Hats hide under the hood or a cosmetic hat, and hair hides under the hood, so nothing
-- pokes through.
function CharacterService.refreshAccessories(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local hood = character:FindFirstChild("LHood") ~= nil
	local hat = character:FindFirstChild("LCosmeticHat") ~= nil
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accessory") then
			local kind = item.AccessoryType
			local hide = (kind == Enum.AccessoryType.Hat and (hood or hat))
				or (kind == Enum.AccessoryType.Hair and hood)
			local handle = item:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = if hide then 1 else 0
			end
		end
	end
end

-- Spawning ---------------------------------------------------------------------------

local warnedR6 = false

-- Every animation is made for R15. A place whose avatar setting still allows R6 would give
-- those players stiff bodies, so an R6 character is rebuilt as R15 from the same avatar.
-- Returns true when the character was replaced (CharacterAdded fires again for the new one).
local function replaceWithR15(player: Player, character: Model, humanoid: Humanoid): boolean
	if humanoid.RigType == Enum.HumanoidRigType.R15 or typeof(player) ~= "Instance" then
		return false
	end
	if not warnedR6 and RunService:IsStudio() then
		warnedR6 = true
		warn("[Inkbound] An avatar loaded as R6 and was rebuilt as R15. Set Game Settings > Avatar > R15 to skip this.")
	end
	local okDescription, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(math.max(player.UserId, 1))
	end)
	if not okDescription or not description then
		description = Instance.new("HumanoidDescription")
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R15)
	end)
	if not ok or not model or player.Character ~= character then
		return false
	end
	model.Name = player.Name
	local pivot = character:GetPivot()
	player.Character = model
	model:PivotTo(pivot)
	model.Parent = workspace
	character:Destroy()
	return true
end

local function onCharacterAdded(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	if replaceWithR15(player, character, humanoid) then
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
		-- A body that is still playing out its death respawns when RagdollService is done.
		if character:GetAttribute("LHeldBody") then
			return
		end
		local stillPlaying = Match.getLiving(player) ~= nil
		task.delay(if stillPlaying then 2 else 5, function()
			if player.Parent == Players and player.Character == character then
				CharacterService.load(player)
			end
		end)
	end)

	CharacterService.applyLocomotion(character)
	task.delay(1, function()
		if character.Parent then
			CharacterService.applyLocomotion(character)
		end
	end)

	if ps then
		-- Wait a frame so the default spawn positioning has finished.
		RunService.Heartbeat:Wait()
		if player.Character == character and Match.getLiving(player) == ps then
			CharacterService.applyOutfit(player)
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

-- Starts handling a player's characters and loads the first one. Players are tracked when
-- they join; the debug panel's test bots are tracked when they are added.
function CharacterService.track(player: Player)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	CharacterService.load(player)
end

function CharacterService.init()
	Players.CharacterAutoLoads = false
	SpectateRemote.OnServerEvent:Connect(onSpectate)
	Players.PlayerAdded:Connect(CharacterService.track)
	for _, player in ipairs(Players:GetPlayers()) do
		CharacterService.track(player)
	end
end

return CharacterService
