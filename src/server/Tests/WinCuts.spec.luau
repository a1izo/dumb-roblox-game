-- The paid win cutscenes (Shared/Cinema/WinCuts, shop overhaul 2026-10-21): each one's clip exists and is as long as the
-- cutscene, its shots and beats run in order inside it, every event is one WinCinema knows and names something on
-- the set, every sound is a slot; and the shop sells three per side, the free one first, each pointing at its own,
-- each paid one told for the other side too (its `cross`).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Index = require(Shared:WaitForChild("Anim"):WaitForChild("Clips"):WaitForChild("Index")) :: any
local Assets = require(Shared:WaitForChild("Assets"))
local Cosmetics = require(Shared:WaitForChild("Cosmetics"))
local WinCuts = require(Shared:WaitForChild("Cinema"):WaitForChild("WinCuts")) :: any

-- (Presentation/WinCinema's ACTS: the client's, so named here)
local ACTS = {
	show = true,
	close = true,
	dim = true,
	lean = true,
	out = true,
	flash = true,
	pages = true,
	cityOut = true,
	snap = true,
	hold = true,
	drop = true,
	stamp = true,
	tip = true,
	shatter = true,
	glow = true,
	ignite = true,
	char = true,
	fling = true,
	text = true,
	scorch = true,
}
local NAMELESS = { pages = true, cityOut = true, snap = true, glow = true, scorch = true }

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	local function vec(v: any): boolean
		return type(v) == "table" and #v == 3 and type(v[1]) == "number"
	end

	describe("WinCuts", function()
		it("gives every cutscene its clip, its shots and beats in order inside it", function()
			for name, cut in pairs(WinCuts) do
				local entry = Index[cut.clip]
				expect(entry ~= nil).to.equal(true)
				expect(math.abs((entry and entry.length or 0) - cut.length) < 0.01).to.equal(true)
				expect(cut.side == "coven" or cut.side == "bureau").to.equal(true)
				local last = -1
				for _, shot in ipairs(cut.shots) do
					expect(shot.at >= last and shot.at < cut.length).to.equal(true)
					last = shot.at
					expect(vec(shot.eye) and vec(shot.look)).to.equal(true)
					expect(shot.fov >= 10 and shot.fov <= 90).to.equal(true)
				end
				for _, beat in ipairs(cut.beats or {}) do
					expect(beat.at >= 0 and beat.at < cut.length).to.equal(true)
				end
				expect(type(name)).to.equal("string")
			end
		end)
		it("makes every event one the player knows, about something on the set", function()
			for name, cut in pairs(WinCuts) do
				local named = {}
				for _, spec in ipairs(cut.parts or {}) do
					if spec.name then
						named[spec.name] = true
					end
				end
				for _, spec in ipairs(cut.props or {}) do
					if spec.name then
						named[spec.name] = true
					end
				end
				for _, event in ipairs(cut.events or {}) do
					if not ACTS[event.act] then
						error(name .. ": an unknown act " .. tostring(event.act))
					end
					expect(event.at >= 0 and event.at < cut.length).to.equal(true)
					if not NAMELESS[event.act] then
						local targets = event.targets or { event.target }
						for _, target in ipairs(targets) do
							if not named[target] then
								error(
									name
										.. ": "
										.. tostring(event.act)
										.. " names nothing on the set: "
										.. tostring(target)
								)
							end
						end
					end
					if event.act == "snap" or event.act == "scorch" then
						expect(cut.strings[event.index] ~= nil).to.equal(true)
						if event.act == "snap" then
							expect(named[event.toward] == true).to.equal(true)
						end
					end
				end
				for _, cue in ipairs(cut.sounds or {}) do
					expect((Assets.sfx :: any)[cue.slot] ~= nil).to.equal(true)
				end
			end
		end)
		it("sells three a side, the free one the ending as it was, each pointing at its own cutscene", function()
			local sides = { coven = { free = 0, paid = 0 }, bureau = { free = 0, paid = 0 } }
			for _, item in ipairs(Cosmetics.ofKind("win")) do
				local side = sides[item.side]
				expect(side ~= nil).to.equal(true)
				expect(Cosmetics.slotOf(item)).to.equal(if item.side == "coven" then "winCoven" else "winBureau")
				if item.source == "free" then
					side.free += 1
					expect(item.cut).to.equal(nil)
				else
					side.paid += 1
					local cut = WinCuts[item.cut]
					expect(cut ~= nil).to.equal(true)
					expect(cut and cut.side).to.equal(item.side)
					expect(cut and cut.clip).to.equal(item.clip)
					-- (and the same scene told for the other side: its own cutscene, of that side)
					local cross = WinCuts[item.cross]
					expect(cross ~= nil).to.equal(true)
					expect(cross and cross.side ~= item.side).to.equal(true)
				end
			end
			expect(sides.coven.free == 1 and sides.coven.paid == 2).to.equal(true)
			expect(sides.bureau.free == 1 and sides.bureau.paid == 2).to.equal(true)
		end)
	end)
end
