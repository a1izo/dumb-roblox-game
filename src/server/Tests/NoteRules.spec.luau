-- Passing a note hand to hand: every reason an offer or an acceptance is refused.

local Services = script.Parent.Parent:WaitForChild("Services")
local NoteRules = require(Services:WaitForChild("NoteRules"))

local function with(base: { [string]: any }, changes: { [string]: any }?): { [string]: any }
	local facts = table.clone(base)
	for key, value in pairs(changes or {}) do
		facts[key] = value
	end
	return facts
end

local OFFER = {
	phase = "Investigation",
	self = false,
	giverCarrying = "note",
	burning = false,
	receiverLiving = true,
	distance = 3,
	height = 0,
	giverPending = false,
	receiverIncoming = false,
	cooldown = 0,
}

local ACCEPT = {
	phase = "Investigation",
	expired = false,
	noteMoved = false,
	receiverLiving = true,
	giverLiving = true,
	distance = 3,
	height = 0,
}

local function offer(changes: { [string]: any }?): string?
	return NoteRules.offerProblem(with(OFFER, changes) :: any)
end

local function accept(changes: { [string]: any }?): string?
	return NoteRules.acceptProblem(with(ACCEPT, changes) :: any)
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("NoteRules.offerProblem", function()
		it("lets a written note go to a living player close by", function()
			expect(offer()).to.equal(nil)
		end)
		it("refuses outside the investigation", function()
			expect(offer({ phase = "DeathNote" })).to.equal("phase")
			expect(offer({ phase = "Meeting" })).to.equal("phase")
		end)
		it("refuses blank sheets and burning notes", function()
			expect(offer({ giverCarrying = "blank" })).to.equal("notCarrying")
			expect(offer({ burning = true })).to.equal("burning")
		end)
		it("refuses yourself and anyone out of the living", function()
			expect(offer({ self = true })).to.equal("self")
			expect(offer({ receiverLiving = false })).to.equal("gone")
		end)
		it("measures reach on the floor and across floors", function()
			expect(offer({ distance = NoteRules.RANGE - 0.01 })).to.equal(nil)
			expect(offer({ distance = NoteRules.RANGE + 0.01 })).to.equal("tooFar")
			expect(offer({ height = NoteRules.HEIGHT + 0.5 })).to.equal("tooFar")
		end)
		it("refuses full hands, a second offer and a quick repeat", function()
			expect(offer({ receiverCarrying = "blank" })).to.equal("handsFull")
			expect(offer({ giverPending = true })).to.equal("giverBusy")
			expect(offer({ receiverIncoming = true })).to.equal("receiverBusy")
			expect(offer({ cooldown = 1.5 })).to.equal("cooldown")
		end)
		it("has a message for every problem", function()
			local codes = { "phase", "self", "notCarrying", "burning", "gone", "tooFar", "handsFull" }
			for _, code in ipairs({ "giverBusy", "receiverBusy", "cooldown", "expired", "noteMoved" }) do
				table.insert(codes, code)
			end
			for _, code in ipairs(codes) do
				expect(type(NoteRules.MESSAGE[code])).to.equal("string")
			end
		end)
	end)

	describe("NoteRules.acceptProblem", function()
		it("lets the receiver take a note still offered", function()
			expect(accept()).to.equal(nil)
		end)
		it("gives the receiver a little slack while deciding", function()
			expect(accept({ distance = NoteRules.ACCEPT_RANGE - 0.01 })).to.equal(nil)
			expect(accept({ distance = NoteRules.ACCEPT_RANGE + 0.01 })).to.equal("tooFar")
			expect(NoteRules.ACCEPT_RANGE > NoteRules.RANGE).to.equal(true)
		end)
		it("refuses late, moved, gone and full-handed acceptances", function()
			expect(accept({ phase = "DeathNote" })).to.equal("phase")
			expect(accept({ expired = true })).to.equal("expired")
			expect(accept({ noteMoved = true })).to.equal("noteMoved")
			expect(accept({ giverLiving = false })).to.equal("gone")
			expect(accept({ receiverLiving = false })).to.equal("gone")
			expect(accept({ receiverCarrying = "note" })).to.equal("handsFull")
		end)
	end)
end
