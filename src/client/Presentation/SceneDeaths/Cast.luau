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
	-- face accessories worn one over another: how far out each one's mesh is grown (by a word of its name), so the
	-- head never shows through the face and the next layer never through the last (default FACE_LIFT)
	lift: { [string]: number }?,
}

-- (2026-11-15, the user: "fix Snakes head glitching": the marketplace face sat on the head's own surface, so the head
-- broke through it in patches and the plain face under it showed; a face accessory now stands a little proud of the
-- head, on a head with no face of its own)
local FACE_LIFT = 1.035

local PURPLE = Color3.fromRGB(104, 84, 128)
local PALE = Color3.fromRGB(234, 206, 182)
local TAN = Color3.fromRGB(204, 160, 128)

Cast.COSTUMES = {
	-- requiem's killer: Giorno Giovanna in his pink suit, the Requiem hair, and his face (a marketplace face
	-- accessory; 2026-11-14, the user: "add an actual face to giorno ... use the marketplace for a head accessory",
	-- not a face drawn here)
	giorno = {
		shirt = 7837252937,
		pants = 7836972770,
		accessories = { HairAccessory = { 107142249545136 }, FaceAccessory = { 108476297699904 } },
		skin = { head = PALE, torso = PALE, arms = PALE, legs = PALE },
	},
	-- Let's dance!'s killer: Raiden, cyborg armour, the white hair and visor
	raiden = {
		shirt = 12462940073,
		pants = 12462955150,
		accessories = { HairAccessory = { 132697257855291 } },
		skin = { head = PALE, torso = PALE, arms = PALE, legs = PALE },
	},
	-- the patriot's saluter: Snake's fatigues, the long-tailed bandana, his weathered skin, and his face from the
	-- marketplace (2026-11-14, the user: the drawn one "isnt accurate and sucks ... use the marketplace for a head
	-- accessory"): the classic Snake face with its beard, and the eyepatch on its strap over it. His hair under the
	-- bandana (2026-11-16, the user: "give snake his hat and hair": the bandana sat on a bald head and read as a flat
	-- cap): the MGS3 mullet, base and addon, from the bandana's own set
	snake = {
		skin = { head = TAN, torso = TAN, arms = TAN, legs = TAN },
		shirt = 12463194829,
		pants = 12463202877,
		accessories = {
			HatAccessory = { 137173363080914 },
			HairAccessory = { 80668929398586, 99280018149729 },
			FaceAccessory = { 111744462200963, 74484209898344 },
		},
		-- (the face, then the eyepatch and its strap over it)
		lift = { face = 1.035, eyepatch = 1.075 },
		clear = {
			"HatAccessory",
			-- (a player dressed as Snake wears his hair, not their own under it)
			"HairAccessory",
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
	-- (a face accessory is made for the classic head: a player's own head goes for it)
	if spec.accessories and spec.accessories.FaceAccessory then
		d.Head = 0
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

-- A costume with a face accessory: no face decal under it, and each face mesh grown out from the head a little (the
-- costume's `lift` by a word of the accessory's name, else FACE_LIFT) so nothing under it breaks through.
local function fitFace(model: Model, spec: Costume)
	local head = model:FindFirstChild("Head")
	if not head or not (spec.accessories and spec.accessories.FaceAccessory) then
		return
	end
	for _, item in ipairs(head:GetChildren()) do
		if item:IsA("Decal") then
			item:Destroy()
		end
	end
	for _, accessory in ipairs(model:GetChildren()) do
		if accessory:IsA("Accessory") and accessory.AccessoryType == Enum.AccessoryType.Face then
			local lift = FACE_LIFT
			local name = string.lower(accessory.Name)
			for word, value in pairs(spec.lift or {}) do
				if string.find(name, string.lower(word), 1, true) then
					lift = math.max(lift, value)
				end
			end
			local handle = accessory:FindFirstChild("Handle")
			local mesh = handle and handle:FindFirstChildOfClass("SpecialMesh")
			if mesh then
				mesh.Scale *= lift
			elseif handle and handle:IsA("MeshPart") then
				handle.Size *= lift
			end
		end
	end
end

local function make(description: HumanoidDescription, spec: Costume): Model?
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
	fitFace(model, spec)
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
	local model = make(describe(spec), spec)
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
	local model = make(describe(spec, if ok then base else nil), spec)
	if model then
		model.Name = "Cast_" .. key .. "_" .. tostring(userId)
	end
	return model
end

task.defer(Cast.warm)

return Cast
