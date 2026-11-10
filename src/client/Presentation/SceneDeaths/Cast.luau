--!strict
-- The scene deaths' extra characters in real Roblox marketplace costumes (2026-11-10, the user: "I dont want you to
-- make these extra characters from nothing ... import clothing and things from the roblox marketplace as costumes").
-- Each costume is a HumanoidDescription (classic shirt and pants, rigid accessories, skin colours: what an R6 body
-- wears), built into an R6 model once on this client and kept as a template; a scene casts a copy. They are built in
-- the background as soon as this module loads, so a scene never waits: one not ready yet is played by the plain
-- figure. A player's own avatar can be dressed in a costume too (the patriot's saluter, a friend, as Snake).

local Players = game:GetService("Players")

local Cast = {}

export type Costume = {
	shirt: number?,
	pants: number?,
	-- accessory slots of HumanoidDescription ("HatAccessory", "HairAccessory", "FaceAccessory", ...) to their ids
	accessories: { [string]: { number } }?,
	-- skin: head, torso, arms, legs (Color3s); a dressed player keeps their own when nil
	skin: { [string]: Color3 }?,
	-- for a dressed player: which of their own accessory slots to empty first
	clear: { string }?,
}

local PURPLE = Color3.fromRGB(104, 84, 128)
local PALE = Color3.fromRGB(234, 206, 182)
local TAN = Color3.fromRGB(204, 160, 128)

Cast.COSTUMES = {
	-- requiem's killer: Giorno Giovanna in his pink suit, the Requiem hair
	giorno = {
		shirt = 7837252937,
		pants = 7836972770,
		accessories = { HairAccessory = { 107142249545136 } },
		skin = { head = PALE, torso = PALE, arms = PALE, legs = PALE },
	},
	-- Let's dance!'s killer: Raiden, cyborg armour, the white hair and visor
	raiden = {
		shirt = 12462940073,
		pants = 12462955150,
		accessories = { HairAccessory = { 132697257855291 } },
		skin = { head = PALE, torso = PALE, arms = PALE, legs = PALE },
	},
	-- the patriot's saluter: Snake's fatigues and the long-tailed bandana, on the friend's own head
	snake = {
		shirt = 12463194829,
		pants = 12463202877,
		accessories = { HatAccessory = { 137173363080914 } },
		clear = {
			"HatAccessory",
			"FaceAccessory",
			"NeckAccessory",
			"ShouldersAccessory",
			"FrontAccessory",
			"BackAccessory",
			"WaistAccessory",
		},
	},
	-- Walrider's soldiers: black tactical gear, the helmet with goggles
	soldier = {
		shirt = 6473316934,
		pants = 628933539,
		accessories = { HatAccessory = { 114472411314837 } },
		skin = { head = TAN, torso = TAN, arms = TAN, legs = TAN },
	},
	-- Walrider's old doctor in the wheelchair (Outlast's Wernicke: nothing of his on the marketplace, so the nearest:
	-- a white-haired old man's head, a black suit and tie, black slacks)
	doctor = {
		shirt = 6670832167,
		pants = 129459077,
		accessories = { HatAccessory = { 73279934935796 } },
		skin = { head = PALE, torso = PALE, arms = PALE, legs = PALE },
	},
	-- Iron Man's warlord: the armour, the head, the gold helmet, purple skin
	warlord = {
		shirt = 12270628952,
		pants = 4826948682,
		accessories = { HatAccessory = { 18771453410, 112127559333629 } },
		skin = { head = PURPLE, torso = PURPLE, arms = PURPLE, legs = PURPLE },
	},
	-- the army behind him: dark armour (seen far off, turning to ash)
	army = {
		shirt = 6473316934,
		pants = 628933539,
		skin = {
			head = Color3.fromRGB(40, 38, 46),
			torso = Color3.fromRGB(40, 38, 46),
			arms = Color3.fromRGB(40, 38, 46),
			legs = Color3.fromRGB(40, 38, 46),
		},
	},
	-- Blackwall's bystanders in plain clothes
	bystanderA = {
		shirt = 144076358,
		pants = 129458426,
		skin = { head = TAN, torso = TAN, arms = TAN, legs = TAN },
	},
	bystanderB = {
		shirt = 144076436,
		pants = 382537569,
		skin = { head = PALE, torso = PALE, arms = PALE, legs = PALE },
	},
} :: { [string]: Costume }

local templates: { [string]: Model | false } = {}
local loading: { [string]: boolean } = {}

local SKIN = {
	head = "HeadColor",
	torso = "TorsoColor",
	arms = { "LeftArmColor", "RightArmColor" },
	legs = { "LeftLegColor", "RightLegColor" },
}

local function describe(spec: Costume, base: HumanoidDescription?): HumanoidDescription
	local d = if base then base:Clone() else Instance.new("HumanoidDescription")
	if spec.shirt then
		d.Shirt = spec.shirt
		d.GraphicTShirt = 0
	end
	if spec.pants then
		d.Pants = spec.pants
	end
	for _, slot in ipairs(spec.clear or {}) do
		(d :: any)[slot] = ""
	end
	-- (a description built from nothing wears none of a player's layered clothing; a dressed one sheds it: an R6 body
	-- cannot show it)
	if base then
		pcall(function()
			d:SetAccessories({}, true)
		end)
	end
	for slot, ids in pairs(spec.accessories or {}) do
		local list = {}
		local had = (d :: any)[slot]
		if type(had) == "string" and had ~= "" then
			table.insert(list, had)
		end
		for _, id in ipairs(ids) do
			table.insert(list, tostring(id))
		end
		(d :: any)[slot] = table.concat(list, ",")
	end
	for part, field in pairs(SKIN) do
		local color = spec.skin and spec.skin[part]
		if color then
			for _, name in ipairs(if type(field) == "table" then field else { field }) do
				(d :: any)[name] = color
			end
		end
	end
	return d
end

local function make(description: HumanoidDescription): Model?
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if not ok or not model then
		return nil
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("Script") or item:IsA("LocalScript") then
			item:Destroy()
		end
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return model
end

local function load(key: string)
	if loading[key] or templates[key] ~= nil then
		return
	end
	local spec = Cast.COSTUMES[key]
	if not spec then
		templates[key] = false
		return
	end
	loading[key] = true
	local model = make(describe(spec))
	if model then
		model.Name = "Cast_" .. key
	end
	templates[key] = model or false
	loading[key] = nil
end

-- The costume's template if it is built (cast a copy of it: Stage.cast copies), or nil (still building, or failed).
function Cast.get(key: string): Model?
	local t = templates[key]
	if t == nil then
		task.spawn(load, key)
		return nil
	end
	return if t then t else nil
end

-- Builds every costume in the background (called once, as this module loads).
function Cast.warm()
	for key in pairs(Cast.COSTUMES) do
		task.spawn(load, key)
	end
end

-- A player's own avatar wearing a costume (yields while Roblox builds it; nil when it cannot).
function Cast.dressed(userId: number, key: string): Model?
	local spec = Cast.COSTUMES[key]
	if not spec then
		return nil
	end
	local ok, base = pcall(function()
		return Players:GetHumanoidDescriptionFromUserId(math.max(1, userId))
	end)
	local model = make(describe(spec, if ok then base else nil))
	if model then
		model.Name = "Cast_" .. key .. "_" .. tostring(userId)
	end
	return model
end

task.defer(Cast.warm)

return Cast
