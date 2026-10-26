-- Spawning, placement, freezing, the look of characters in a match (the noir suit and the
-- game-wide movement set) and the visible props that hang on them (paper in hand,
-- notebook and pen, handcuffs, red glowing eyes, the burning Manual).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared:WaitForChild("Assets"))
local Create = require(Shared:WaitForChild("Create"))
local Models = require(Shared:WaitForChild("Models"))
local Net = require(Shared:WaitForChild("Net"))
local Signal = require(Shared:WaitForChild("Signal"))

local CollisionGroups = require(script.Parent.CollisionGroups)
local CrispAccessories = require(script.Parent.CrispAccessories)
local DynamicHeads = require(script.Parent.DynamicHeads)
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
			warn("[DeathsGambit] Could not load character for " .. player.Name .. ": " .. tostring(err))
		end
	end)
end

-- Height of the root part above the floor for this rig.
local function groundOffset(character: Model): number
	local humanoid = getHumanoid(character)
	local root = getRoot(character)
	if humanoid and root and humanoid.RigType == Enum.HumanoidRigType.R6 then
		-- The root hangs half its height plus a leg above the floor (R6 HipHeight is 0).
		local leg = character:FindFirstChild("Right Leg")
		return humanoid.HipHeight + root.Size.Y / 2 + (if leg and leg:IsA("BasePart") then leg.Size.Y else 2)
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

-- Nobody jumps during the investigation: no hopping onto props, walls or roofs and out of the
-- map. (Climbing is switched off on each client, which owns its character: World/MovementRules.)
local function canJump(): boolean
	return Match.phase ~= "Investigation"
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
		local jumps = not frozen and canJump()
		humanoid.WalkSpeed = if frozen then 0 else 16
		humanoid.JumpPower = if jumps then 50 else 0
		humanoid.JumpHeight = if jumps then 7.2 else 0
	end
end

-- Why each character's name tag is hidden: "ghost", "away", "crowd" (the Tokyo crowd around a
-- player), "blackout" (Bureau HQ). The tag shows again only when no reason is left.
local hiddenWhy: { [Model]: { [string]: boolean } } = setmetatable({}, { __mode = "k" }) :: any

function CharacterService.setNameHidden(character: Model, reason: string, hidden: boolean)
	local reasons = hiddenWhy[character]
	if not reasons then
		reasons = {}
		hiddenWhy[character] = reasons
	end
	reasons[reason] = if hidden then true else nil
	local any = next(reasons) ~= nil
	if character:GetAttribute("NameHidden") ~= any then
		character:SetAttribute("NameHidden", any)
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
		-- (sitting in their chair again, when they were: Shared/Seating)
		local character = ps.player.Character
		if character and ps.seatClip then
			character:SetAttribute("Seat", ps.seatClip)
		end
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
	if character then
		CharacterService.attachBuiltTo(character, name, bodyParts, build)
	end
end

-- The same on any character model (the Tokyo crowd's dressed templates, too).
function CharacterService.attachBuiltTo(character: Model, name: string, bodyParts: { string }, build)
	local existing = character:FindFirstChild(name)
	if existing then
		existing:Destroy()
	end
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

local HAND = { "Right Arm" }
local HEAD = { "Head" }
local TORSO = { "Torso" }

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

-- Death's Manual held open with its pen, while Diavolo writes in it.
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
		-- Death's Manual, held open (Models.heldManual); a cover cosmetic colours its board.
		local coverColor = player:GetAttribute("LGrimoireColor")
		local coverStyle = player:GetAttribute("LGrimoireStyle")
		local held = anchor * CFrame.new(0, -0.35, -1.05) * CFrame.Angles(math.rad(35), 0, 0)
		local book = Models.heldManual(
			held,
			if typeof(coverColor) == "Color3" then coverColor else nil,
			if type(coverStyle) == "string" then coverStyle else nil
		)
		return modelParts(book, book:GetPivot())
	end)
end

-- Death's Manual written in free roam: the open book burns with a red light anyone nearby can see.
-- LManualOpen on the character lets every client add the sound and the red fire off its pages (WorldFx).
function CharacterService.setManualGlow(player: Player, on: boolean)
	local character = player.Character
	if character then
		character:SetAttribute("LManualOpen", if on then true else nil)
	end
	if not on then
		CharacterService.detach(player, "LManualGlow")
		return
	end
	CharacterService.attachBuilt(player, "LManualGlow", TORSO, function(anchor: CFrame)
		local core = Create("Part", {
			Size = Vector3.new(0.4, 0.4, 0.4),
			Transparency = 1,
			CanCollide = false,
			CanQuery = false,
			CFrame = anchor * CFrame.new(0, -0.1, -1.2),
		})
		Create("PointLight", {
			Color = Color3.fromRGB(255, 50, 40),
			Range = 16,
			Brightness = 6,
			Shadows = false,
			Parent = core,
		})
		return { core }
	end)
end

-- The visible tell of a stare or an Oculus read: red glowing eyes for a few seconds.
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

-- Every body is animated on each client from the clips made in Blender (src/client/Anim), so
-- Roblox's default Animate script (which Studio and the avatar loader add to characters)
-- would fight them. It is removed as soon as it appears.
function CharacterService.removeDefaultAnimate(character: Model)
	local function strip(item: Instance)
		if item.Name == "Animate" and (item:IsA("LocalScript") or item:IsA("Script")) then
			(item :: any).Enabled = false
			item:Destroy()
		end
	end
	for _, item in ipairs(character:GetChildren()) do
		strip(item)
	end
	local connection = character.ChildAdded:Connect(function(item)
		task.defer(strip, item)
	end)
	task.delay(10, function()
		connection:Disconnect()
	end)
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

-- The attachments of the head: an accessory held by one of these (a hat, hair, glasses, a mask) stays on in a
-- match; anything worn on the body (a coat, a cape, wings, a belt, a scarf, a shoulder pet) comes off, whatever
-- its type says (old ones say Unknown). A rigid coat left on lay over the suit's cloth and the two cut through
-- each other at every move (2026-10-26).
local HEAD_ATTACHMENTS = {
	HatAttachment = true,
	HairAttachment = true,
	FaceFrontAttachment = true,
	FaceCenterAttachment = true,
}

local function onHead(accessory: Accessory): boolean
	local handle = accessory:FindFirstChild("Handle")
	if not handle then
		return false
	end
	for _, child in ipairs(handle:GetChildren()) do
		if child:IsA("Attachment") and HEAD_ATTACHMENTS[child.Name] then
			return true
		end
	end
	return false
end

local SUIT = Color3.fromRGB(30, 30, 34)
local TROUSERS = Color3.fromRGB(24, 24, 28)
local SUIT_PARTS = { "Torso", "Left Arm", "Right Arm" }
local TROUSER_PARTS = { "Left Leg", "Right Leg" }
-- The cloth shells are this much larger than the part they cover, and the trousers' this much darker.
local CLOTH_PAD = 0.03
-- Each shell's base box, the body part it is cut for (its lapels, pockets and seams stand off this box): the game
-- sizes the box to the part, so the details keep their depth instead of shrinking the cloth into the body.
local SHELL_BASE = { SuitTorso = Vector3.new(2, 2, 1), SuitLimb = Vector3.new(1, 2, 1) }
local TROUSER_TINT = Color3.new(0.8, 0.8, 0.82)

-- The match look: a dark suit, white collar and red tie over the player's own face, hair and
-- body shape. Clothing (classic and layered) is removed so outfits cannot give anyone away.
function CharacterService.applyOutfit(player: Player)
	local character = player.Character
	if not character or character:GetAttribute("LNoirOutfit") then
		return
	end
	CharacterService.dressNoir(character, nil)
end

-- Dresses any R6 model in the match suit (players, and the Tokyo crowd that must look like them).
function CharacterService.dressNoir(character: Model, tie: Color3?)
	if character:GetAttribute("LNoirOutfit") then
		return
	end
	character:SetAttribute("LNoirOutfit", true)
	local head = character:FindFirstChild("Head")
	local skin = if head and head:IsA("BasePart") then head.Color else Color3.fromRGB(200, 170, 140)
	for _, item in ipairs(character:GetChildren()) do
		local clothing = item:IsA("Shirt") or item:IsA("Pants") or item:IsA("ShirtGraphic") or item:IsA("BodyColors")
		if clothing or (item:IsA("Accessory") and (CLOTHING_ACCESSORIES[item.AccessoryType] or not onHead(item))) then
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
	-- Real cloth over the painted parts when the Core import carries it (Models.suit): a shell sized
	-- to each part, a hair larger. Before the import the painted parts stand as they are.
	local function clothe(names: { string }, tint: Color3?)
		for _, name in ipairs(names) do
			local holder = "LSuit" .. (string.gsub(name, " ", ""))
			CharacterService.attachBuiltTo(character, holder, { name }, function(anchor: CFrame, part: BasePart)
				local key = if name == "Torso" then "SuitTorso" else "SuitLimb"
				local shell = Models.suit(key)
				if not shell then
					return {}
				end
				local fit = part.Size / SHELL_BASE[key]
				local pad = Vector3.new(CLOTH_PAD, CLOTH_PAD, CLOTH_PAD)
				local parts = {}
				for _, item in ipairs(shell:GetDescendants()) do
					if item:IsA("MeshPart") then
						local ok, native = pcall(function()
							return item.MeshSize
						end)
						item.Size = if ok and native.Magnitude > 0 then native * fit + pad else part.Size + pad
						item.CFrame = anchor
						local look = item:FindFirstChildWhichIsA("SurfaceAppearance")
						if look and tint then
							look.Color = tint
						end
						table.insert(parts, item)
					end
				end
				for _, item in ipairs(parts) do
					item.Parent = nil
				end
				shell:Destroy()
				return parts
			end)
		end
	end
	clothe(SUIT_PARTS, nil)
	clothe(TROUSER_PARTS, TROUSER_TINT)
	-- R6 arms are one part, so the hands are skin-coloured cuffs welded over the arm ends.
	for _, side in ipairs({ "Left", "Right" }) do
		CharacterService.attachBuiltTo(character, "LHand" .. side, { side .. " Arm" }, function(anchor: CFrame)
			return {
				Create("Part", {
					Size = Vector3.new(1.08, 0.55, 1.08),
					Color = skin,
					Material = Enum.Material.SmoothPlastic,
					CFrame = anchor * CFrame.new(0, -0.74, 0),
				}),
			}
		end)
	end
	if Assets.outfit.shirt ~= "" then
		Create("Shirt", { ShirtTemplate = Assets.contentId(Assets.outfit.shirt), Parent = character })
	end
	if Assets.outfit.pants ~= "" then
		Create("Pants", { PantsTemplate = Assets.contentId(Assets.outfit.pants), Parent = character })
	end
	local tieColour = tie or Color3.fromRGB(190, 22, 36)
	CharacterService.attachBuiltTo(character, "LNoirTie", TORSO, function(anchor: CFrame, torso: BasePart)
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
				Color = tieColour:Lerp(Color3.new(0, 0, 0), 0.15),
				Material = Enum.Material.Fabric,
				CFrame = anchor * CFrame.new(0, top - 0.2, front - 0.05),
			}),
			Create("Part", {
				Name = "Tie",
				Size = Vector3.new(0.18, 0.95, 0.05),
				Color = tieColour,
				Material = Enum.Material.Fabric,
				CFrame = anchor * CFrame.new(0, top - 0.75, front - 0.05),
			}),
		}
	end)
end

-- Hats hide under a cosmetic hat, so nothing pokes through.
function CharacterService.refreshAccessories(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local hat = character:FindFirstChild("LCosmeticHat") ~= nil
	for _, item in ipairs(character:GetChildren()) do
		if item:IsA("Accessory") then
			local kind = item.AccessoryType
			local hide = kind == Enum.AccessoryType.Hat and hat
			local handle = item:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.Transparency = if hide then 1 else 0
			end
		end
	end
end

-- Spawning ---------------------------------------------------------------------------

local warnedR6 = false

-- Every animation is made for R6. A place whose avatar setting still allows R15 would give
-- those players bodies the animator cannot pose, so an R15 character is rebuilt as R6 from the
-- same avatar (clothes, face and accessories carry over; R6 has no body shapes).
-- Returns true when the character was replaced (CharacterAdded fires again for the new one).
local function replaceWithR6(player: Player, character: Model, humanoid: Humanoid): boolean
	if humanoid.RigType == Enum.HumanoidRigType.R6 or typeof(player) ~= "Instance" then
		return false
	end
	if not warnedR6 and RunService:IsStudio() then
		warnedR6 = true
		warn(
			"[DeathsGambit] An avatar loaded as R15 and was rebuilt as R6. Set Game Settings > Avatar > R6 to skip this."
		)
	end
	local okDescription, description = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(math.max(player.UserId, 1))
	end)
	if not okDescription or not description then
		description = Instance.new("HumanoidDescription")
	end
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model or player.Character ~= character then
		return false
	end
	model.Name = player.Name
	-- (the avatar's own painted head in place of R6's plain one and its default smile, and its accessories
	-- rebuilt as MeshParts, before anyone sees it: the old kind leave the whole body blocky)
	DynamicHeads.fit(model, description)
	CrispAccessories.sharpen(model)
	if player.Character ~= character or player.Parent ~= Players then
		model:Destroy()
		return false
	end
	-- Roblox's R6 models pivot on the Head; everything that places a body (spawns, cutscenes) means its root.
	local newRoot = model:FindFirstChild("HumanoidRootPart")
	if newRoot and newRoot:IsA("BasePart") then
		model.PrimaryPart = newRoot
	end
	local pivot = character:GetPivot()
	player.Character = model
	model:PivotTo(pivot)
	model.Parent = workspace
	character:Destroy()
	return true
end

local function onCharacterAdded(player: Player, character: Model)
	-- A Specter waiting in the lobby is hidden from the very first frame (GhostService finishes the job).
	local anyPs = if Match.active then Match.get(player) else nil
	local away = anyPs ~= nil and anyPs.away == true
	if away then
		character:SetAttribute("Away", true)
		CharacterService.setNameHidden(character, "away", true)
	end
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	if replaceWithR6(player, character, humanoid) then
		return
	end
	-- (an R6 body Roblox spawned itself, or a test bot: its accessories rebuilt as MeshParts as they come; a body the
	-- game rebuilt from R15 has had them rebuilt already)
	CrispAccessories.watch(character)
	character:WaitForChild("HumanoidRootPart", 10)
	-- Bodies have a group of their own, so a hidden (away) body can pass through them.
	CollisionGroups.body(character, CollisionGroups.CHARACTERS)
	humanoid.BreakJointsOnDeath = false
	humanoid.NameOcclusion = Enum.NameOcclusion.OccludeAll
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.NameDisplayDistance = 60
	-- Roblox's own tag is off for everyone: the client draws the Notch tag (World/NameTags) from DisplayName.
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local ps = Match.getLiving(player)
	if ps then
		humanoid.DisplayName = ps.alias
	elseif away then
		humanoid.DisplayName = ""
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

	CharacterService.removeDefaultAnimate(character)

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
