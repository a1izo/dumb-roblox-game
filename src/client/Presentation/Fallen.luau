--!strict
-- Which body to film for a death: the player's own character. (Death styles, which once stood a copy in for the body
-- and acted on it, were taken out on 2026-11-10, the user's call: "remove Death styles completely".)
--
--   Fallen.bodyOf(userId)        -- the dying player's character
--   Fallen.waitFor(userId, _)    -- the same (kept for the callers that waited for a stand-in)

local Players = game:GetService("Players")

local Fallen = {}

function Fallen.bodyOf(userId: number?): Model?
	if not userId then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	return if player then player.Character else nil
end

function Fallen.waitFor(userId: number, _timeout: number): Model?
	return Fallen.bodyOf(userId)
end

return Fallen
