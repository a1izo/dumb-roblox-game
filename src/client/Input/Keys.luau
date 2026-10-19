--!strict
-- The player's keys in words, for the input in their hands: hints, the help book, the role card's lines and
-- the objectives all name what to press through here, so a rebound key shows as the player set it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Bindings = require(Shared:WaitForChild("Bindings"))
local Hints = require(Shared:WaitForChild("Hints"))

local ClientState = require(script.Parent.Parent.ClientState)

local Keys = {}

-- "keyboard", "gamepad" or "touch": what the player last used.
function Keys.input(): string
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then
		return "touch"
	elseif string.find(last.Name, "Gamepad") then
		return "gamepad"
	end
	return "keyboard"
end

-- The player's saved set (their profile's `keybinds`), nil for the defaults.
function Keys.saved(): any
	local profile = ClientState.profile
	return if profile then profile.keybinds else nil
end

-- An action's keys as words for the current input ("E", "LB"; "" on touch or when it has none).
function Keys.text(id: string, joiner: string?): string
	local input = Keys.input()
	if input == "touch" then
		return ""
	end
	return Bindings.text(id, input, Keys.saved(), joiner)
end

-- A text with its {key.<name>} words filled in (Shared/Hints) for the current input and the player's keys.
function Keys.resolve(text: string): string
	return Hints.resolve(text, Keys.input(), Keys.saved())
end

return Keys
