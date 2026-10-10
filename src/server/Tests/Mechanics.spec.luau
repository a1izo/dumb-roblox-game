-- Each map's own mechanic runs behind one door (Maps/Mechanics): a map without one does nothing, a
-- mechanic that breaks never ends a match, stopping puts every sight rule back, and the Tokyo crowd
-- adds nobody to the match.

local Players = game:GetService("Players")

local Server = script.Parent.Parent
local Mechanics = require(Server:WaitForChild("Maps"):WaitForChild("Mechanics"))
local Services = Server:WaitForChild("Services")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Match = require(Services:WaitForChild("Match"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect

	describe("Mechanics", function()
		it("does nothing on a map without a mechanic", function()
			Mechanics.start({ id = "Nowhere" })
			expect(Mechanics.currentId()).to.equal("Nowhere")
			Mechanics.onPhase("Investigation")
			Mechanics.onPhaseEnd("Investigation")
			Mechanics.stageMarks({})
			expect(Mechanics.debug("status")).to.equal(nil)
			Mechanics.stop()
			expect(Mechanics.currentId()).to.equal(nil)
		end)
		it("ignores a map that is no map", function()
			Mechanics.start(nil)
			Mechanics.start({})
			expect(Mechanics.currentId()).to.equal(nil)
		end)
		it("knows the three maps' mechanics", function()
			local folder = Server.Maps.Mechanics
			for _, id in ipairs({ "TokyoDistrict", "UniversityCampus", "TaskForceHQ" }) do
				local module = folder:FindFirstChild(id)
				expect(module ~= nil and module:IsA("ModuleScript")).to.equal(true)
			end
		end)
		it("passes every hook to the running mechanic", function()
			local seen = {}
			Mechanics.adopt("Spec", {
				start = function(ctx)
					table.insert(seen, "start:" .. ctx.map.id)
				end,
				stop = function()
					table.insert(seen, "stop")
				end,
				onPhase = function(phase)
					table.insert(seen, "phase:" .. phase)
				end,
				onPhaseEnd = function(phase)
					table.insert(seen, "end:" .. phase)
				end,
				stageMarks = function(cast)
					table.insert(seen, "marks:" .. #cast)
				end,
				debug = function(command)
					return "did " .. command
				end,
			})
			Mechanics.onPhase("Investigation")
			Mechanics.onPhaseEnd("Investigation")
			Mechanics.stageMarks({ 1, 2 })
			expect(Mechanics.debug("x")).to.equal("did x")
			Mechanics.stop()
			expect(table.concat(seen, " ")).to.equal("start:Spec phase:Investigation end:Investigation marks:2 stop")
		end)
		it("catches a mechanic that breaks in any hook", function()
			local function broken()
				error("a bug in the map's mechanic")
			end
			Mechanics.adopt("Broken", {
				start = broken,
				stop = broken,
				onPhase = broken,
				onPhaseEnd = broken,
				stageMarks = broken,
				action = broken,
				debug = broken,
			})
			Mechanics.onPhase("Investigation")
			Mechanics.onPhaseEnd("Investigation")
			Mechanics.stageMarks({})
			expect(Mechanics.debug("x")).to.equal(nil)
			Mechanics.stop()
			expect(Mechanics.currentId()).to.equal(nil)
		end)
		it("puts sight back to normal when it stops", function()
			Mechanics.adopt("Dark", {
				start = function()
					Match.occluder = function()
						return true
					end
					Match.sightScale.flash = 0.5
					Match.sightScale.witness = 0.4
				end,
				stop = function() end,
			})
			expect(Match.sightRange("flash")).to.be.near(Config.FLASH_RANGE * 0.5)
			expect(Match.sightRange("witness")).to.be.near(Config.WITNESS_RANGE * 0.4)
			expect(Match.sightRange("eyes")).to.be.near(Config.EYES_RANGE)
			Mechanics.stop()
			expect(Match.occluder).to.equal(nil)
			expect(Match.sightRange("flash")).to.be.near(Config.FLASH_RANGE)
			expect(Match.sightRange("witness")).to.be.near(Config.WITNESS_RANGE)
		end)
	end)

	describe("Tokyo's crowd", function()
		it("adds nobody to the match: walkers are never players", function()
			local Crowd = require(Server.Maps.Mechanics.TokyoDistrict.Crowd)
			local listed, players = #Match.list, #Players:GetPlayers()
			local living = #Match.living()
			Crowd.start({
				map = {
					origin = Vector3.zero,
					layout = {
						crowd = {
							nodes = { { x = 0, y = 0, z = 0, kind = "walk" }, { x = 40, y = 0, z = 0, kind = "walk" } },
							links = { { a = 1, b = 2, kind = "walk", width = 2 } },
							posts = { { x = 5, y = 0, z = 9, rot = 0 } },
						},
					},
				},
				rng = Random.new(1),
			})
			local walkers = Crowd.record(1)
			expect(#walkers).to.equal(Crowd.WALKERS + 1)
			Crowd.step(1 / 30, 15, false, {})
			expect(#Match.list).to.equal(listed)
			expect(#Match.living()).to.equal(living)
			expect(#Players:GetPlayers()).to.equal(players)
			-- Its bodies stand in sight lines while it is out, and in none once it is gone.
			expect(type(Match.occluder)).to.equal("function")
			Crowd.stop()
			Match.occluder = nil
			expect(#Crowd.record(2)).to.equal(0)
		end)
	end)
end
