-- The match suit (Shared/Suit, CharacterService.dressNoir): what of an avatar comes off under it (everything worn
-- below the head, its clothing and colours, never the suit's own pieces), and what lands on a dressed body later
-- comes off too: a coat that loaded after the body stood over the suit all case long (2026-10-26).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Suit = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Suit"))
local CharacterService = require(script.Parent.Parent:WaitForChild("Services"):WaitForChild("CharacterService"))

local function accessory(attachment: string, kind: Enum.AccessoryType?): Accessory
	local item = Instance.new("Accessory")
	item.AccessoryType = kind or Enum.AccessoryType.Unknown
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	local at = Instance.new("Attachment")
	at.Name = attachment
	at.Parent = handle
	handle.Parent = item
	return item
end

local SIZES = {
	HumanoidRootPart = Vector3.new(2, 2, 1),
	Torso = Vector3.new(2, 2, 1),
	Head = Vector3.new(2, 1, 1),
	["Left Arm"] = Vector3.new(1, 2, 1),
	["Right Arm"] = Vector3.new(1, 2, 1),
	["Left Leg"] = Vector3.new(1, 2, 1),
	["Right Leg"] = Vector3.new(1, 2, 1),
}

local function body(): Model
	local model = Instance.new("Model")
	for name, size in pairs(SIZES) do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = size
		part.Anchored = true
		part.Parent = model
	end
	Instance.new("Humanoid").Parent = model
	return model
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Suit", function()
		it("takes off what is worn below the head and keeps what the head wears", function()
			expect(Suit.offBody(accessory("BodyFrontAttachment"))).to.equal(true) -- a coat
			expect(Suit.offBody(accessory("BodyBackAttachment"))).to.equal(true) -- a cape, wings
			expect(Suit.offBody(accessory("WaistCenterAttachment"))).to.equal(true) -- a belt
			expect(Suit.offBody(accessory("NeckAttachment"))).to.equal(true) -- a scarf
			expect(Suit.offBody(accessory("HatAttachment"))).to.equal(false)
			expect(Suit.offBody(accessory("HairAttachment"))).to.equal(false)
			expect(Suit.offBody(accessory("FaceFrontAttachment"))).to.equal(false)
			-- (layered clothing comes off by its type, wherever it hangs)
			expect(Suit.offBody(accessory("HatAttachment", Enum.AccessoryType.Jacket))).to.equal(true)
		end)

		it("takes off the avatar's clothing and colours, never the suit's own pieces", function()
			for _, class in ipairs({ "Shirt", "Pants", "ShirtGraphic", "BodyColors" }) do
				expect(Suit.offBody(Instance.new(class))).to.equal(true)
			end
			local own = Instance.new("Shirt")
			own:SetAttribute(Suit.OWN, true)
			expect(Suit.offBody(own)).to.equal(false)
			expect(Suit.offBody(Instance.new("Model"))).to.equal(false) -- the cloth, the hands, the tie
		end)

		it("takes off what lands on a dressed body later and keeps late hair", function()
			local model = body()
			CharacterService.dressNoir(model, nil)
			expect(model:GetAttribute(Suit.DRESSED)).to.equal(true)
			local coat = accessory("BodyFrontAttachment")
			coat.Parent = model
			local hair = accessory("HairAttachment")
			hair.Parent = model
			local colours = Instance.new("BodyColors")
			colours.Parent = model
			local shirt = Instance.new("Shirt")
			shirt.Parent = model
			task.wait()
			expect(coat.Parent == nil).to.equal(true)
			expect(colours.Parent == nil).to.equal(true)
			expect(shirt.Parent == nil).to.equal(true)
			expect(hair.Parent == model).to.equal(true)
			expect(model:FindFirstChild("LNoirTie") ~= nil).to.equal(true)
			model:Destroy()
		end)
	end)
end
