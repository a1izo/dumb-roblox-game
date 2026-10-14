-- Puts equipped cosmetics on players: hats and trails on the character, the tie, notebook
-- cover and Deathsinger form (its outline colour and what it wears) as player attributes (read
-- wherever they show), and the title tag over the head in the lobby (never inside a match, where it
-- would give away who is behind an alias). Styles (writing, verdict, death) are never attributes:
-- the services that play them read them here and send them in their cues (Shared/Cosmetics).
-- A complete matching set earns its title (Shared/Sets).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticBuild = require(Shared:WaitForChild("CosmeticBuild"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))
local Mastery = require(Shared:WaitForChild("Progression"):WaitForChild("Mastery"))
local Sets = require(Shared:WaitForChild("Sets"))

local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)
local PassService = require(script.Parent.PassService)

local CosmeticsService = {}

local HAT = "LCosmeticHat"
local TITLE_TAG = "LTitleTag"
local TRAIL_NAMES = { "LCosmeticTrail", "LTrailTop", "LTrailBottom" }

-- True when the player may use the item (bought, earned, free with VIP, or an emote that came with
-- the Emote Pack).
function CosmeticsService.owns(player: Player, item: Cosmetics.Item): boolean
	if item.source == "vip" then
		return PassService.owns(player, "vip")
	end
	if item.pass and PassService.owns(player, item.pass) then
		return true
	end
	local data = DataService.get(player)
	if not data then
		return false
	end
	if item.kind == "title" then
		local key = string.gsub(item.id, "^title_", "")
		if data.titles[key] then
			return true
		end
	end
	return data.owned[item.id] == true
end

local function equipped(player: Player, data, kind: string): Cosmetics.Item?
	local item = Cosmetics.byId(data.equipped[kind])
	if item and item.kind == kind and CosmeticsService.owns(player, item) then
		return item
	end
	return nil
end

-- The style a player has on for a kind ("writing", "verdict" or "death"): the item's style name, or
-- nil (the plain one). Bots and players without a profile have none.
function CosmeticsService.style(player: any, kind: string): string?
	if typeof(player) ~= "Instance" then
		return nil
	end
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local item = equipped(player, data, kind)
	return if item then item.style else nil
end

-- Hands out the titles of the sets now complete. Returns the sets completed (a toast each).
function CosmeticsService.grantSets(player: Player): { Sets.Set }
	local data = DataService.get(player)
	if not data then
		return {}
	end
	local done = Sets.completed(function(id: string): boolean
		local item = Cosmetics.byId(id)
		return item ~= nil and CosmeticsService.owns(player, item)
	end)
	for _, set in ipairs(done) do
		data.owned[set.title] = true
		Match.notify(player, "Set complete: " .. set.name .. ". Its title is yours.", "good")
	end
	return done
end

-- On arriving: what was earned before it existed (a mastery level's unlock, a set's title).
local function catchUp(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local changed = false
	for role, unlocks in pairs(Mastery.UNLOCKS) do
		local level = Mastery.level(tonumber(data.mastery and data.mastery[role]) or 0)
		for at, id in pairs(unlocks) do
			if at <= level and not data.owned[id] then
				data.owned[id] = true
				changed = true
			end
		end
	end
	-- (all seven grey apples found before Apple Toss came with them)
	if data.titles.realmwalker and not data.owned.emote_apple_toss then
		data.owned.emote_apple_toss = true
		changed = true
	end
	if #CosmeticsService.grantSets(player) > 0 then
		changed = true
	end
	if changed then
		DataService.push(player)
		DataService.saveSoon(player)
	end
end

-- The title to show on the results screen, or nil.
function CosmeticsService.titleOf(player: Player): string?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	local title = equipped(player, data, "title")
	return if title then title.name else nil
end

local function clearTrail(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, name in ipairs(TRAIL_NAMES) do
		local existing = root:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end
end

local function titleTag(player: Player, character: Model, title: string?)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local old = head:FindFirstChild(TITLE_TAG)
	if old then
		old:Destroy()
	end
	local vip = PassService.owns(player, "vip")
	if Match.get(player) or (not title and not vip) then
		return
	end
	local gui = Create("BillboardGui", {
		Name = TITLE_TAG,
		Size = UDim2.fromOffset(220, 22),
		StudsOffset = Vector3.new(0, 3.4, 0),
		MaxDistance = 60,
		LightInfluence = 0,
		Parent = head,
	})
	local text = title or ""
	if vip then
		text = if text ~= "" then "VIP  ·  " .. text else "VIP"
	end
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = string.upper(text),
		TextScaled = true,
		TextColor3 = if vip then Color3.fromRGB(244, 245, 247) else Color3.fromRGB(163, 170, 181),
		TextStrokeColor3 = Color3.fromRGB(8, 9, 11),
		TextStrokeTransparency = 0.4,
		FontFace = Font.new("rbxasset://fonts/families/Montserrat.json", Enum.FontWeight.Bold),
		Parent = gui,
	})
end

function CosmeticsService.apply(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local tie = equipped(player, data, "tie")
	local book = equipped(player, data, "grimoire")
	local specter = equipped(player, data, "specter")
	player:SetAttribute("LTieColor", if tie then tie.color else nil)
	player:SetAttribute("LGrimoireColor", if book then book.color else nil)
	player:SetAttribute("LSpecterColor", if specter then specter.color else nil)
	-- (Only Deathsingers and spectators ever see a form: GhostVisibility.)
	player:SetAttribute("LSpecterForm", if specter then specter.form else nil)

	local character = player.Character
	if not character then
		return
	end
	CharacterService.detach(player, HAT)
	clearTrail(character)
	local hat = equipped(player, data, "hat")
	if hat then
		CharacterService.attachBuilt(player, HAT, { "Head" }, function(anchor: CFrame, head: BasePart)
			return CosmeticBuild.hat(hat, anchor, head)
		end)
	end
	local trail = equipped(player, data, "trail")
	local root = character:FindFirstChild("HumanoidRootPart")
	if trail and root and root:IsA("BasePart") then
		CosmeticBuild.trail(trail, root)
	end
	CharacterService.refreshAccessories(player)
	CharacterService.recolorTie(player)
	local title = equipped(player, data, "title")
	titleTag(player, character, if title then title.name else nil)
	-- The stance the body settles into when it stands still (LocomotionController).
	local stance = Cosmetics.byId(data.stance)
	character:SetAttribute(
		"Stance",
		if stance and stance.stance and CosmeticsService.owns(player, stance) then stance.emote else nil
	)
end

function CosmeticsService.init()
	CharacterService.CharacterSpawned:Connect(function(player)
		CosmeticsService.apply(player)
	end)
	DataService.ProfileLoaded:Connect(function(player)
		catchUp(player)
		CosmeticsService.apply(player)
	end)
	PassService.Changed:Connect(function(player)
		CosmeticsService.apply(player)
		DataService.push(player)
	end)
end

return CosmeticsService
