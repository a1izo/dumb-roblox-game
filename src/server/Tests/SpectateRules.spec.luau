-- Who may watch a running case from the lobby, and how readying up pulls a watching party
-- member back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpectateRules = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SpectateRules"))

local function situation(overrides)
	local base = { active = true, phase = "Investigation", participant = false, queued = false }
	for key, value in pairs(overrides or {}) do
		base[key] = value
	end
	return base
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("SpectateRules.blocker", function()
		it("lets a lobby player watch a running case", function()
			expect(SpectateRules.blocker(situation())).to.equal(nil)
			expect(SpectateRules.blocker(situation({ phase = "Meeting" }))).to.equal(nil)
		end)
		it("needs a running case that is not closing", function()
			expect(SpectateRules.blocker(situation({ active = false }))).never.to.equal(nil)
			expect(SpectateRules.blocker(situation({ phase = "Reveal" }))).never.to.equal(nil)
		end)
		it("refuses players in the case", function()
			expect(SpectateRules.blocker(situation({ participant = true }))).never.to.equal(nil)
		end)
		it("refuses players queued for the next case", function()
			expect(SpectateRules.blocker(situation({ queued = true }))).to.equal("Leave the queue to watch.")
		end)
	end)

	describe("SpectateRules.pullOnReady", function()
		it("brings a watching party member back when someone else readies", function()
			expect(SpectateRules.pullOnReady("friend", "me", true)).to.equal(true)
		end)
		it("leaves members who are not watching alone", function()
			expect(SpectateRules.pullOnReady("friend", "me", false)).to.equal(false)
		end)
		it("never pulls the player who pressed READY", function()
			expect(SpectateRules.pullOnReady("me", "me", true)).to.equal(false)
		end)
	end)
end
