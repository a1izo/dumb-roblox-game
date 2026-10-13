-- Roblox core UI tweaks: no reset button (it would kill the character), and the player
-- list is hidden during a match so account names stay out of view next to aliases. It also makes room
-- while the Trial runs: the Trial's step sits in the top right corner, where the list is.

local StarterGui = game:GetService("StarterGui")

local ClientState = require(script.Parent.Parent.ClientState)

local CoreGuiController = {}

local trialRunning = false

local function setCore(name: string, value: any)
	for _ = 1, 30 do
		local ok = pcall(function()
			StarterGui:SetCore(name, value)
		end)
		if ok then
			return
		end
		task.wait(0.5)
	end
end

local function update()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not ClientState.isParticipant() and not trialRunning)
	end)
end

-- The Trial is showing its steps (true) or has ended (false).
function CoreGuiController.setTrialRunning(on: boolean)
	if trialRunning ~= on then
		trialRunning = on
		update()
	end
end

function CoreGuiController.init()
	task.spawn(setCore, "ResetButtonCallback", false)
	ClientState.PublicChanged:Connect(update)
	update()
end

return CoreGuiController
