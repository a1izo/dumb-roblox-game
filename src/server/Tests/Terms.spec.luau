-- Every role, side, phase and status has a display name, and Terms.f fills placeholders.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local RoleLogic = require(Shared:WaitForChild("RoleLogic"))
local Terms = require(Shared:WaitForChild("Terms"))

-- Names from the source material that must never reach a player again.
local BANNED = {
	"Kira",
	"Death Note",
	"Shinigami",
	"Watari",
	"Task Force",
	"L's",
	-- The game's own retired names.
	"Inkbound",
	"Grimoire",
	"Specter",
	"Cultist",
	"Zero",
	"Agency",
	"the Hand",
}

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Terms coverage", function()
		it("names every role in every form", function()
			for _, roleId in ipairs(RoleLogic.ALL) do
				for _, form in ipairs({ "name", "Name", "title", "a", "plural" }) do
					local text = Terms.role(roleId, form)
					expect(type(text) == "string" and #text > 0).to.equal(true)
				end
			end
		end)
		it("names both sides", function()
			for _, sideId in ipairs({ "Team", "Kira" }) do
				expect(#Terms.side(sideId, "Name") > 0).to.equal(true)
			end
		end)
		it("names every phase", function()
			for phase in pairs(Config.PHASE_TIME) do
				expect(Terms.PHASE[phase] ~= nil).to.equal(true)
			end
			expect(Terms.PHASE.Lobby ~= nil).to.equal(true)
		end)
		it("names every status", function()
			for _, status in ipairs({ "alive", "dead", "voted", "arrested", "left" }) do
				expect(Terms.STATUS[status] ~= nil).to.equal(true)
			end
		end)
		it("never uses a banned source name", function()
			local texts = { Terms.GAME, Terms.TAGLINE }
			for _, names in pairs(Terms.ROLE) do
				for _, text in pairs(names) do
					table.insert(texts, text)
				end
			end
			for _, text in pairs(Terms.NAMES) do
				table.insert(texts, text)
			end
			for _, text in pairs(Terms.PHASE) do
				table.insert(texts, text)
			end
			for _, text in ipairs(texts) do
				for _, banned in ipairs(BANNED) do
					expect(text).never.to.contain(banned)
				end
			end
		end)
	end)

	describe("Terms.f", function()
		it("fills name placeholders", function()
			expect(Terms.f("{Hand} wins.")).to.equal("Diavolo wins.")
			expect(Terms.f("Read by {zero}.")).to.equal("Read by Ace.")
		end)
		it("prefers the variables that are passed in", function()
			expect(Terms.f("{alias} ({cultist})", { alias = "Raven" })).to.equal("Raven (Muerto)")
		end)
		it("formats numbers", function()
			expect(Terms.f("x{n}", { n = 3 })).to.equal("x3")
		end)
		it("errors on an unknown placeholder in Studio", function()
			expect(function()
				Terms.f("{nobody}")
			end).to.throw("unknown placeholder")
		end)
	end)
end
