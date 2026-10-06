--!strict
-- Whether the player has hidden the lobby's UI ("Hide UI" in the lobby menu) to look at the world. The lobby
-- page, its pop-ups and chat follow it; a small eye button brings everything back, and so does being pulled
-- into a case.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Signal"))

local LobbyChrome = {}

-- Fired as (hidden).
LobbyChrome.Changed = Signal.new()

local hidden = false

function LobbyChrome.isHidden(): boolean
	return hidden
end

function LobbyChrome.setHidden(on: boolean)
	if hidden == on then
		return
	end
	hidden = on
	LobbyChrome.Changed:Fire(on)
end

return LobbyChrome
