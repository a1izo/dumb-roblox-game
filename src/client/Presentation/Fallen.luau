--!strict
-- Which body to film for a death: the player's own character. (Death styles, which once stood a copy in for the body
-- and acted on it, were taken out on 2026-11-10, the user's call: "remove Death styles completely".)
--
--   Fallen.bodyOf(userId)        -- the dying player's character (a debug bot's too)
--   Fallen.waitFor(userId, _)    -- the same (kept for the callers that waited for a stand-in)
--
-- Found 2026-11-15: this once read Players:GetPlayerByUserId, which has no one for a test bot (a negative user id).
-- A bot's death then had no body to film: the table cutscene (Presenters/Death) fell through to a bare wait, the
-- camera went back to the player after the book, and the "body from above" card after a scene never came. Characters
-- knows players and bots alike.

local Characters = require(script.Parent.Parent.Characters)

local Fallen = {}

function Fallen.bodyOf(userId: number?): Model?
	return Characters.byUserId(userId)
end

function Fallen.waitFor(userId: number, _timeout: number): Model?
	return Fallen.bodyOf(userId)
end

return Fallen
