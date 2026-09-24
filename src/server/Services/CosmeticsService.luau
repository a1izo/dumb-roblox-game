-- Puts equipped cosmetics on players: hats and trails on the character, the tie, notebook
-- cover, victory pose and Specter outline as player attributes (read wherever they show),
-- and the title tag over the head in the lobby (never inside a match, where it would give
-- away who is behind an alias).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticBuild = require(Shared:WaitForChild("CosmeticBuild"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local Create = require(Shared:WaitForChild("Create"))

local CharacterService = require(script.Parent.CharacterService)
local DataService = require(script.Parent.DataService)
local Match = require(script.Parent.Match)
local PassService = require(script.Parent.PassService)

local CosmeticsService = {}

local HAT = "LCosmeticHat"
local TITLE_TAG = "LTitleTag"
local TRAIL_NAMES = { "LCosmeticTrail", "LTrailTop", "LTrailBottom" }

-- True when the player may use the item (bought, earned, or free with VIP).
function CosmeticsService.owns(player: Player, item: Cosmetics.Item): boolean
	if item.source == "vip" then
		return PassService.owns(player, "vip")
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
		TextColor3 = if vip then Color3.fromRGB(255, 200, 90) else Color3.fromRGB(244, 241, 234),
		TextStrokeTransparency = 0.4,
		Font = Enum.Font.Oswald,
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
	local victory = equipped(player, data, "victory")
	local specter = equipped(player, data, "specter")
	player:SetAttribute("LTieColor", if tie then tie.color else nil)
	player:SetAttribute("LGrimoireColor", if book then book.color else nil)
	player:SetAttribute("LVictoryPose", if victory then victory.pose else nil)
	player:SetAttribute("LSpecterColor", if specter then specter.color else nil)

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
end

function CosmeticsService.init()
	CharacterService.CharacterSpawned:Connect(function(player)
		CosmeticsService.apply(player)
	end)
	DataService.ProfileLoaded:Connect(function(player)
		CosmeticsService.apply(player)
	end)
	PassService.Changed:Connect(function(player)
		CosmeticsService.apply(player)
		DataService.push(player)
	end)
end

return CosmeticsService
