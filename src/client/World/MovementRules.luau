-- Movement during the investigation: no jumping and no climbing (trusses, ladders, ledges), so
-- nobody gets onto props, walls or roofs and out of the map. The server also zeroes the jump
-- (CharacterService.setFrozen); climbing is a state only the client that owns the character can
-- switch off. Everything comes back when the phase ends.

local Players = game:GetService("Players")

local ClientState = require(script.Parent.Parent.ClientState)

local LocalPlayer = Players.LocalPlayer

local MovementRules = {}

local LOCKED_STATES = { Enum.HumanoidStateType.Jumping, Enum.HumanoidStateType.Climbing }

local function restricted(): boolean
	return ClientState.phase() == "Investigation" and ClientState.isLiving()
end

local function apply()
	local character = LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local allowed = not restricted()
	for _, state in ipairs(LOCKED_STATES) do
		humanoid:SetStateEnabled(state, allowed)
	end
end

function MovementRules.init()
	-- Every state push (phase changes, and dying) can change what is allowed.
	ClientState.PublicChanged:Connect(apply)
	LocalPlayer.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		apply()
	end)
	apply()
end

return MovementRules
