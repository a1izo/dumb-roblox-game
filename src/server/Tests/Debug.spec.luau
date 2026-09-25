-- The debug tools' plumbing: remotes wrapped for test bots, messages to bots routed to the bot
-- service, and simulated requests reaching the server's own handlers.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	-- Remotes are only wrapped when the debug tools are on (Config.STUDIO_DEBUG).
	if type(Net.event("Debug")) ~= "table" then
		return
	end

	describe("Debug plumbing", function()
		it("hands out one wrapper per remote", function()
			expect(Net.event("Debug") == Net.event("Debug")).to.equal(true)
			expect(Net.event("Debug").Name).to.equal("Debug")
		end)
		it("sends messages for a test bot to the bot sink, not the network", function()
			local fake = { IsBot = true, Parent = Players, UserId = -999999, Name = "SpecBot" }
			local previous = Net.botSink
			local received = nil
			Net.botSink = function(bot, remoteName, payload)
				if bot == fake then
					received = { remoteName, payload }
				end
			end
			Net.event("Notify"):FireClient(fake, { text = "hi" })
			Net.botSink = previous
			expect(received ~= nil).to.equal(true)
			expect(received[1]).to.equal("Notify")
			expect(received[2].text).to.equal("hi")
		end)
		it("runs a remote's handlers for a simulated request", function()
			local fake = { IsBot = true, Parent = Players, UserId = -999998, Name = "SpecBot2" }
			local seen = nil
			Net.event("Debug").OnServerEvent:Connect(function(player, command)
				if player == fake then
					seen = command
				end
			end)
			Net.simulate("Debug", fake, "specPing")
			task.wait()
			expect(seen).to.equal("specPing")
		end)
	end)

	describe("Test bots", function()
		it("stand in for players", function()
			local Bots = require(script.Parent.Parent:WaitForChild("Debug"):WaitForChild("Bots"))
			expect(Bots.is({ IsBot = true })).to.equal(true)
			expect(Bots.is(Players)).to.equal(false)
		end)
	end)
end
