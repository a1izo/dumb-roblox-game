-- Roblox core UI tweaks: no reset button (it would kill the character), and the player
-- list is hidden during a match so account names stay out of view next to aliases. It also makes room
-- while the Trial runs: the Trial's step sits in the top right corner, where the list is. And no backpack: the game
-- hands out no tools, and Roblox's own inventory opened over it on the ` key (2026-11-10, "it opens the roblox
-- inventory").

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

-- Roblox's backpack off (its hotbar and the inventory the ` key opens). Asked again a few times: the core scripts
-- may not be up yet when this first runs.
local function hideBackpack()
	for _ = 1, 30 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
		end)
		if ok and not StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Backpack) then
			return
		end
		task.wait(0.5)
	end
end

function CoreGuiController.init()
	task.spawn(setCore, "ResetButtonCallback", false)
	task.spawn(hideBackpack)
	ClientState.PublicChanged:Connect(update)
	update()
end

return CoreGuiController
