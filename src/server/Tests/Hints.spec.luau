-- The tips name what to press for the input in the player's hands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Hints = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Hints"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Hints.resolve", function()
		it("leaves no key unnamed in any tip, for any input", function()
			for _, input in ipairs({ "keyboard", "gamepad", "touch" }) do
				for _, hint in ipairs(Hints.LIST) do
					local text = Hints.resolve(hint.text, input)
					expect(string.find(text, "{key", 1, true)).to.equal(nil)
					expect(string.find(hint.title, "{key", 1, true)).to.equal(nil)
				end
			end
		end)

		it("names the same things for every input", function()
			for name in pairs(Hints.KEYS.keyboard) do
				expect(type(Hints.KEYS.gamepad[name])).to.equal("string")
				expect(type(Hints.KEYS.touch[name])).to.equal("string")
			end
		end)

		it("tells a phone to tap, never to press a key", function()
			local work = Hints.resolve(Hints.BY_ID.phase_Investigation.text, "touch")
			expect(string.find(work, "Tap the prompt", 1, true)).to.equal(1)
			expect(string.find(work, "Press E", 1, true)).to.equal(nil)
			local keyboard = Hints.resolve(Hints.BY_ID.phase_Investigation.text, "keyboard")
			expect(string.find(keyboard, "Press E", 1, true)).to.equal(1)
			local pad = Hints.resolve(Hints.BY_ID.phase_Investigation.text, "gamepad")
			expect(string.find(pad, "Press X", 1, true)).to.equal(1)
		end)

		it("names the player's own keys where they rebound them", function()
			local saved =
				{ keyboard = { roleCard = { "L" }, interact = { "R" } }, gamepad = { interact = { "ButtonL3" } } }
			expect(
				string.find(Hints.resolve(Hints.BY_ID.role_TaskForce.text, "keyboard", saved), "Hold L", 1, true) ~= nil
			).to.equal(true)
			expect(
				string.find(Hints.resolve(Hints.BY_ID.phase_Investigation.text, "keyboard", saved), "Press R", 1, true)
			).to.equal(1)
			expect(
				string.find(Hints.resolve(Hints.BY_ID.phase_Investigation.text, "gamepad", saved), "Press L3", 1, true)
			).to.equal(1)
			-- the defaults read as they always did
			expect(
				string.find(Hints.resolve(Hints.BY_ID.role_TaskForce.text, "keyboard", nil), "Hold C", 1, true) ~= nil
			).to.equal(true)
		end)

		it("falls back to the keyboard for an input it does not know", function()
			local text = Hints.resolve(Hints.BY_ID.role_L.text, "mind")
			expect(string.find(text, "(R)", 1, true) ~= nil).to.equal(true)
		end)
	end)
end
