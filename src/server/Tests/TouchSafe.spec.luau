-- Keeping the HUD off Roblox's jump button on touch screens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TouchSafe = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("UI"):WaitForChild("TouchSafe"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("TouchSafe", function()
		it("puts the small button where the engine does on a phone", function()
			local jump = TouchSafe.defaultJump(Vector2.new(812, 375))
			expect(jump.Min.X).to.equal(812 - 95)
			expect(jump.Min.Y).to.equal(375 - 90)
			expect(jump.Width).to.equal(70)
			expect(jump.Height).to.equal(70)
		end)

		it("puts the large button where the engine does on a tablet", function()
			local jump = TouchSafe.defaultJump(Vector2.new(1024, 768))
			expect(jump.Min.X).to.equal(1024 - 170)
			expect(jump.Min.Y).to.equal(768 - 210)
			expect(jump.Width).to.equal(120)
		end)

		it("goes by the short side, so a phone held upright still gets the small button", function()
			expect(TouchSafe.defaultJump(Vector2.new(375, 812)).Width).to.equal(70)
			expect(TouchSafe.defaultJump(Vector2.new(500, 900)).Width).to.equal(70)
			expect(TouchSafe.defaultJump(Vector2.new(501, 900)).Width).to.equal(120)
		end)

		it("tells overlapping rectangles from ones that only touch", function()
			local a = Rect.new(0, 0, 10, 10)
			expect(TouchSafe.overlaps(a, Rect.new(5, 5, 15, 15))).to.equal(true)
			expect(TouchSafe.overlaps(a, Rect.new(10, 0, 20, 10))).to.equal(false)
			expect(TouchSafe.overlaps(a, Rect.new(0, 10, 10, 20))).to.equal(false)
			expect(TouchSafe.overlaps(a, Rect.new(2, 2, 4, 4))).to.equal(true)
		end)

		it("keeps a card that ends on the floor clear of the button, whatever its size", function()
			for _, screen in ipairs({ Vector2.new(568, 320), Vector2.new(812, 375), Vector2.new(1024, 768) }) do
				local jump = TouchSafe.defaultJump(screen)
				local floor = TouchSafe.floorAbove(jump)
				expect(floor).to.equal(jump.Min.Y - TouchSafe.GAP)
				-- The old place: 32 px in from the corner, covering the button.
				local old = Rect.new(screen.X - 32 - 195, screen.Y - 32 - 170, screen.X - 32, screen.Y - 32)
				expect(TouchSafe.overlaps(old, jump)).to.equal(true)
				for _, height in ipairs({ 60, 96, 240 }) do
					local card = Rect.new(screen.X - 32 - 255, floor - height, screen.X - 32, floor)
					expect(TouchSafe.overlaps(card, jump)).to.equal(false)
				end
			end
		end)
	end)
end
