-- Puts equipped cosmetics on players: the hat on the character, the notebook
-- cover and Deathsinger form (its outline colour and what it wears) as player attributes (read
-- wherever they show), and the title tag over the head in the lobby (never inside a match, where it
-- would give away who is behind an alias). Styles (writing, verdict, death) are never attributes:
-- the services that play them read them here and send them in their cues (Shared/Cosmetics).
-- A complete matching set earns its title (Shared/Sets), and owning so many emotes pays coins and a title
-- once (Progression/Collection).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))
local Collection = require(Shared:WaitForChild("Progression"):WaitForChild("Collection"))
local Mastery = require(Shared:WaitForChild("Progression"):WaitForChild("Mastery"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Seating = require(Shared:WaitForChild("Seating"))
local Sets = require(Shared:WaitForChild("Sets"))
local TitleFonts = require(Shared:WaitForChild("TitleFonts"))

local Analytics = require(script.Parent.Analytics)
local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)
local PassService = require(script.Parent.PassService)

local CosmeticsService = {}

local TITLE_TAG = "LTitleTag"

-- True when the player may use the item (everyone's, bought, earned, free with VIP, or an emote that came
-- with the Emote Pack).
function CosmeticsService.owns(player: Player, item: Cosmetics.Item): boolean
	if item.source == "free" then
		return true
	end
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

-- What the player wears of a kind (or in a slot: a win cutscene's side, "winCoven" / "winBureau").
local function equipped(player: Player, data, kind: string): Cosmetics.Item?
	local item = Cosmetics.byId(data.equipped[kind])
	if item and Cosmetics.slotOf(item) == kind and CosmeticsService.owns(player, item) then
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

-- Pays the collection milestones now reached (coins and a title, once each). Returns them (a toast each).
function CosmeticsService.grantMilestones(player: Player): { Collection.Milestone }
	local data = DataService.get(player)
	if not data then
		return {}
	end
	local count = Collection.count(function(item: Cosmetics.Item): boolean
		return CosmeticsService.owns(player, item)
	end)
	local due = Collection.due(count, function(id: string): boolean
		local title = Cosmetics.byId(id)
		return title ~= nil and CosmeticsService.owns(player, title)
	end)
	for _, milestone in ipairs(due) do
		data.owned[milestone.title] = true
		data.coins += milestone.coins
		Analytics.coins(player, milestone.coins, data.coins, "Gameplay", milestone.title)
		local title = Cosmetics.byId(milestone.title)
		Match.notify(
			player,
			string.format(
				"%d emotes: +%d coins and the title %s.",
				milestone.count,
				milestone.coins,
				if title then title.name else milestone.title
			),
			"good"
		)
	end
	return due
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
	if #CosmeticsService.grantMilestones(player) > 0 then
		changed = true
	end
	if changed then
		DataService.push(player)
		DataService.saveSoon(player)
	end
end

-- The seat clip this player sits in at the war table (the seat they wear, or everyone's).
function CosmeticsService.seatClip(player: Player): string
	local data = DataService.get(player)
	local seat = if data then equipped(player, data, "seat") else nil
	return if seat and type(seat.clip) == "string" then seat.clip else Seating.DEFAULT
end

-- The win cutscene this player wears for a side ("coven" or "bureau"): its cutscene (Shared/Cinema/WinCuts), or nil
-- for the ending as it always was.
function CosmeticsService.winCut(player: Player, side: string): string?
	local data = DataService.get(player)
	local item = if data then equipped(player, data, if side == "coven" then "winCoven" else "winBureau") else nil
	return if item and type(item.cut) == "string" then item.cut else nil
end

-- The chair this player's place at the war table becomes, or nil for the war chair.
function CosmeticsService.chairOf(player: Player): Cosmetics.Item?
	local data = DataService.get(player)
	return if data then equipped(player, data, "chair") else nil
end

-- The title to show on the results screen (its name and tier), or nil.
function CosmeticsService.titleOf(player: Player): Cosmetics.Item?
	local data = DataService.get(player)
	if not data then
		return nil
	end
	return equipped(player, data, "title")
end

local TAG_GREY = Color3.fromRGB(163, 170, 181)
local TAG_WHITE = Color3.fromRGB(244, 245, 247)

-- The title over the head, in its tier's look (Shared/Rarity.titleText): its marks in the tier's colour, Condemned
-- letters leaning amber; a VIP's "VIP" before it in white.
local function titleTag(player: Player, character: Model, title: Cosmetics.Item?)
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
		Size = UDim2.fromOffset(250, 22), -- (wide enough that the marks leave a long title its letters)
		StudsOffset = Vector3.new(0, 3.4, 0),
		MaxDistance = 60,
		LightInfluence = 0,
		Parent = head,
	})
	local text, letters = "", if vip then TAG_WHITE else TAG_GREY
	if title then
		text, letters = Rarity.titleText(title.name, title.rarity, TAG_GREY, title.id)
	end
	if vip then
		text = if text ~= ""
			then string.format('<font color="#%s">VIP</font>  ·  ', TAG_WHITE:ToHex()) .. text
			else "VIP"
	end
	Create("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Text = text,
		RichText = true,
		TextScaled = true,
		TextColor3 = letters,
		TextStrokeColor3 = Color3.fromRGB(8, 9, 11),
		TextStrokeTransparency = 0.4,
		-- (in the title's own face, Shared/TitleFonts; the tag's bold sans for a VIP with none)
		FontFace = TitleFonts.face(if title then title.id else nil),
		Parent = gui,
	})
end

function CosmeticsService.apply(player: Player)
	local data = DataService.get(player)
	if not data then
		return
	end
	local book = equipped(player, data, "grimoire")
	local specter = equipped(player, data, "specter")
	player:SetAttribute("LGrimoireColor", if book then book.color else nil)
	player:SetAttribute("LGrimoireStyle", if book then book.style else nil)
	player:SetAttribute("LSpecterColor", if specter then specter.color else nil)
	-- (Only Deathsingers and spectators ever see a form: GhostVisibility.)
	player:SetAttribute("LSpecterForm", if specter then specter.form else nil)

	local character = player.Character
	if not character then
		return
	end
	CharacterService.refreshAccessories(player)
	local title = equipped(player, data, "title")
	titleTag(player, character, title)
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
		-- Back in the lobby after a case: what it earned (a mastery emote) may finish a set or a milestone.
		if not Match.get(player) and DataService.get(player) then
			local sets = CosmeticsService.grantSets(player)
			local milestones = CosmeticsService.grantMilestones(player)
			if #sets + #milestones > 0 then
				DataService.push(player)
				DataService.saveSoon(player)
			end
		end
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
