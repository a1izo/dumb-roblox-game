-- Every control's binding (Shared/Bindings): the defaults never clash where two actions are live together, no
-- default takes a reserved key, every default is a real key, and a saved set is cleaned of anything unsafe.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Bindings = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Bindings"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Bindings", function()
		it("has no clashing defaults on either platform", function()
			for _, platform in ipairs(Bindings.PLATFORMS) do
				local clashes = Bindings.clashes(platform, nil)
				for _, clash in ipairs(clashes) do
					print("[Bindings] clash", platform, clash[1], clash[2], clash[3])
				end
				expect(#clashes).to.equal(0)
			end
		end)

		it("gives every default a real key that is not reserved", function()
			for _, action in ipairs(Bindings.ACTIONS) do
				for _, platform in ipairs(Bindings.PLATFORMS) do
					for _, key in ipairs((action :: any)[platform]) do
						expect(Bindings.keyAllowed(key)).to.equal(true)
					end
					expect(#(action :: any)[platform] <= Bindings.MAX_KEYS).to.equal(true)
				end
			end
		end)

		it("keeps movement, jump and the camera rebindable", function()
			for _, id in ipairs({ "moveForward", "moveBack", "moveLeft", "moveRight", "jump", "turnLeft", "look" }) do
				expect(Bindings.get(id) ~= nil).to.equal(true)
			end
		end)

		it("cleans a saved set", function()
			local clean = Bindings.clean({
				keyboard = {
					jump = { "K", "Escape", "K", "NotAKey", "L", "M" },
					nonsense = { "B" },
					help = "B",
				},
				gamepad = { jump = { "ButtonStart", "ButtonB" } },
				mouse = { jump = { "K" } },
			})
			expect(#clean.keyboard.jump).to.equal(2)
			expect(clean.keyboard.jump[1]).to.equal("K")
			expect(clean.keyboard.jump[2]).to.equal("L")
			expect(clean.keyboard.nonsense).to.equal(nil)
			expect(clean.keyboard.help).to.equal(nil)
			expect(clean.gamepad.jump[1]).to.equal("ButtonB")
			expect(#clean.gamepad.jump).to.equal(1)
			expect((clean :: any).mouse).to.equal(nil)
			expect(next(Bindings.clean("junk"))).to.equal(nil)
		end)

		it("reads a player's own keys before the defaults, and finds the clash they make", function()
			local saved = { keyboard = { help = { "N" } } }
			expect(Bindings.keys("help", "keyboard", saved)[1]).to.equal("N")
			expect(Bindings.keys("note", "keyboard", saved)[1]).to.equal("N")
			expect(#Bindings.clashes("keyboard", saved)).to.equal(1)
			-- a key two actions share is fine when they are never live together
			expect(Bindings.together("ghost", "jump")).to.equal(false)
			expect(Bindings.together("rally", "plate")).to.equal(false)
		end)

		it("lists every action in exactly one Settings section", function()
			local seen = {}
			for _, section in ipairs(Bindings.SECTIONS) do
				for _, id in ipairs(section.ids) do
					expect(Bindings.get(id) ~= nil).to.equal(true)
					expect(seen[id]).to.equal(nil)
					seen[id] = true
				end
			end
			for _, action in ipairs(Bindings.ACTIONS) do
				expect(seen[action.id]).to.equal(true)
			end
		end)

		it("names every default key in words", function()
			for _, action in ipairs(Bindings.ACTIONS) do
				for _, platform in ipairs(Bindings.PLATFORMS) do
					for _, key in ipairs((action :: any)[platform]) do
						local label = Bindings.label(key)
						expect(type(label) == "string" and label ~= "").to.equal(true)
					end
				end
			end
			expect(Bindings.label("ButtonL1")).to.equal("LB")
			expect(Bindings.label("One")).to.equal("1")
			expect(Bindings.label("LeftShift")).to.equal("Shift")
			expect(Bindings.text("moveForward", "keyboard", nil)).to.equal("W / Up")
			expect(Bindings.text("roleCard", "keyboard", { keyboard = { roleCard = { "L" } } })).to.equal("L")
		end)

		it("tells a changed set from the defaults", function()
			expect(Bindings.changed({ "jump" }, "keyboard", nil)).to.equal(false)
			expect(Bindings.changed({ "jump" }, "keyboard", { keyboard = { jump = { "Space" } } })).to.equal(false)
			expect(Bindings.changed({ "jump" }, "keyboard", { keyboard = { jump = { "J" } } })).to.equal(true)
			expect(Bindings.changed({ "look" }, "gamepad", { gamepad = { look = { "Thumbstick1" } } })).to.equal(true)
		end)

		it("keeps a touch layout inside its limits", function()
			local clean = Bindings.clean({
				touch = { side = "up", size = 9, height = 0.5, prompts = "big", hide = { note = true, nope = true } },
			})
			expect(clean.touch.side).to.equal(nil)
			expect(clean.touch.size).to.equal(Bindings.TOUCH_RANGE.size[2])
			expect(clean.touch.height).to.equal(0.5)
			expect(clean.touch.prompts).to.equal(nil)
			expect(clean.touch.hide.note).to.equal(true)
			expect(clean.touch.hide.nope).to.equal(nil)
			local layout = Bindings.touchLayout(clean)
			expect(layout.side).to.equal("right")
			expect(layout.prompts).to.equal(Bindings.TOUCH_DEFAULT.prompts)
			expect(Bindings.touchLayout(nil).size).to.equal(1)
		end)
	end)
end
