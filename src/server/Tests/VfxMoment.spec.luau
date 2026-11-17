-- The VFX kit's envelope (Presentation/Vfx/Moment): the moments of an effect run gather, hit, body, residue round one hit
-- time, and cancelling stops the later ones. Only the order and the times are read; nothing is drawn and no time is waited for
-- (a part due at once runs before play returns).

local StarterPlayer = game:GetService("StarterPlayer")

local function kitModule(name: string): ModuleScript?
	local node: Instance? = StarterPlayer:FindFirstChild("StarterPlayerScripts")
	for _, part in ipairs({ "Client", "Presentation", "Vfx", name }) do
		node = if node then node:FindFirstChild(part) else nil
	end
	return if node and node:IsA("ModuleScript") then node else nil
end

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local module = kitModule("Moment")
	if not module then
		return
	end
	local ok, Moment = pcall(require, module)

	describe("Effect moments", function()
		it("loads on the server", function()
			expect(ok).to.equal(true)
		end)
		if not ok then
			return
		end

		local function noop() end

		it("puts the gather before the hit by the lead, then the body and the residue after it", function()
			local list = Moment.timeline({ gather = noop, hit = noop, body = noop, residue = noop, lead = 0.3 })
			expect(#list).to.equal(4)
			expect(list[1].name).to.equal("gather")
			expect(list[1].at).to.equal(0)
			expect(list[2].name).to.equal("hit")
			expect(math.abs(list[2].at - 0.3) < 1e-6).to.equal(true)
			expect(list[3].name).to.equal("body")
			expect(list[3].at > list[2].at).to.equal(true)
			expect(list[4].name).to.equal("residue")
			expect(list[4].at > list[3].at).to.equal(true)
		end)

		it("uses a lead of 0.2 seconds unless told otherwise", function()
			local list = Moment.timeline({ hit = noop })
			expect(#list).to.equal(1)
			expect(math.abs(list[1].at - 0.2) < 1e-6).to.equal(true)
		end)

		it("leaves out the parts it was not given", function()
			local list = Moment.timeline({ hit = noop, residue = noop })
			expect(#list).to.equal(2)
			expect(list[1].name).to.equal("hit")
			expect(list[2].name).to.equal("residue")
		end)

		it("keeps moments at the same time in the order gather, hit, body, residue", function()
			local list = Moment.timeline({
				residue = noop,
				body = noop,
				hit = noop,
				gather = noop,
				lead = 0,
				bodyAfter = 0,
				residueAfter = 0,
			})
			expect(#list).to.equal(4)
			expect(list[1].name).to.equal("gather")
			expect(list[2].name).to.equal("hit")
			expect(list[3].name).to.equal("body")
			expect(list[4].name).to.equal("residue")
		end)

		it("runs every part due at once, in order, with the point and the moment's name", function()
			local seen: { string } = {}
			local point = Vector3.new(1, 2, 3)
			local function note(at, name)
				expect(at).to.equal(point)
				table.insert(seen, name)
			end
			Moment.play(point, {
				residue = note,
				hit = note,
				gather = note,
				body = note,
				lead = 0,
				bodyAfter = 0,
				residueAfter = 0,
			})
			expect(table.concat(seen, ",")).to.equal("gather,hit,body,residue")
		end)

		it("goes on past a part that fails", function()
			local ran = false
			Moment.play(Vector3.zero, {
				gather = function()
					error("a recipe's mistake")
				end,
				hit = function()
					ran = true
				end,
				lead = 0,
			})
			expect(ran).to.equal(true)
		end)

		it("stops the later parts when cancelled", function()
			local later = 0
			local cancel = Moment.play(Vector3.zero, {
				gather = noop,
				hit = function()
					later += 1
				end,
				lead = 5,
			})
			cancel()
			expect(later).to.equal(0)
			cancel() -- (and cancelling twice is harmless)
		end)
	end)
end
