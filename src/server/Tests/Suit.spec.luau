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

		it("keeps every shell clear of the body's edges and of the shells it touches", function()
			-- (props_gameplay.CLOTH_BEVEL: the base box's rounded edges cut into the margin; a body edge must stay 0.02 off)
			local bevel = 0.02
			for name, pad in pairs(Suit.PAD) do
				local side = pad / 2
				expect(side >= 0.02).to.equal(true)
				expect((2 * side - bevel) / math.sqrt(2) >= 0.02 - 1e-6).to.equal(true)
				expect(name ~= "" and pad > 0).to.equal(true)
			end
			-- shells that touch never share a face's plane
			expect(Suit.PAD.Torso ~= Suit.PAD["Left Arm"]).to.equal(true)
			expect(Suit.PAD.Torso ~= Suit.PAD["Right Arm"]).to.equal(true)
			expect(Suit.PAD.Torso ~= Suit.PAD["Left Leg"]).to.equal(true)
			expect(Suit.PAD.Torso ~= Suit.PAD["Right Leg"]).to.equal(true)
			expect(Suit.PAD["Left Leg"] ~= Suit.PAD["Right Leg"]).to.equal(true)
		end)

		it("ends each sleeve in a white cuff and a hand in the player's skin within the arm's own end", function()
			local arm = Instance.new("Part")
			arm.Name = "Right Arm"
			arm.Size = Vector3.new(1, 2, 1)
			arm.CFrame = CFrame.new(10, 5, 0)
			local skin = Color3.fromRGB(120, 80, 50)
			local cuff
			local hands: { BasePart } = {}
			for _, item in ipairs(Suit.hand(arm, skin)) do
				if item.Name == "Cuff" then
					cuff = item
				elseif item.Name == "Hand" then
					table.insert(hands, item)
				end
			end
			expect(cuff ~= nil and #hands > 0).to.equal(true)
			expect(cuff.Color == Suit.SHIRT).to.equal(true)
			local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
			for _, hand in ipairs(hands) do
				expect(hand.Color == skin).to.equal(true)
				lo, hi = lo:Min(hand.Position - hand.Size / 2), hi:Max(hand.Position + hand.Size / 2)
			end
			-- the arm's last Suit.HAND, never hanging below it; the cuff round its top
			local armEnd = arm.Position.Y - 1
			expect(lo.Y >= armEnd - 0.03).to.equal(true)
			expect(math.abs(hi.Y - (armEnd + Suit.HAND)) < 0.03).to.equal(true)
			expect(math.abs(cuff.Position.Y - (armEnd + Suit.HAND)) < 0.06).to.equal(true)
			if arm.Transparency == 1 then
				-- the imported fist: a real hand's shape inside the arm's footprint, the arm see-through round it, the
				-- cuff round its wrist (narrower than the sleeve: no white plate standing out past the hand)
				expect(hi.X - lo.X < arm.Size.X and hi.Z - lo.Z < arm.Size.Z + 0.01).to.equal(true)
				expect(cuff.Size.X < hi.X - lo.X and cuff.Size.Z < arm.Size.Z).to.equal(true)
			else
				-- the classic hand: a skin shell a hair over the arm's faces, the cuff round it
				expect(cuff.Size.X > hi.X - lo.X).to.equal(true)
				expect(hi.X - lo.X > arm.Size.X and hi.Z - lo.Z > arm.Size.Z).to.equal(true)
			end
			-- a late skin repaints the hand, never the cuff
			local holder = Instance.new("Model")
			cuff.Parent = holder
			for _, hand in ipairs(hands) do
				hand.Parent = holder
			end
			Suit.reskin(holder, Color3.fromRGB(240, 200, 170))
			for _, hand in ipairs(hands) do
				expect(hand.Color == Color3.fromRGB(240, 200, 170)).to.equal(true)
			end
			expect(cuff.Color == Suit.SHIRT).to.equal(true)
			holder:Destroy()
			arm:Destroy()
		end)

		it("dyes the tie in the look's colour and lays it on the front of the torso", function()
			local torso = Instance.new("Part")
			torso.Name = "Torso"
			torso.Size = Vector3.new(2, 2, 1)
			torso.CFrame = CFrame.new(0, 3, 0)
			local blue = Color3.fromRGB(30, 60, 160)
			local dyed = false
			for _, item in ipairs(Suit.tie(torso, blue)) do
				local at = torso.CFrame:PointToObjectSpace(item.Position)
				expect(at.Z < -0.5).to.equal(true) -- in front of the body
				if item.Color == blue then
					dyed = true
				end
				item:Destroy()
			end
			expect(dyed).to.equal(true)
			torso:Destroy()
		end)
	end)
end
