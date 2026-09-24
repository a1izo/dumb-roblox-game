-- Roblox core UI tweaks: no reset button (it would kill the character), and the player
-- list is hidden during a match so account names stay out of view next to aliases.

local StarterGui = game:GetService("StarterGui")

local ClientState = require(script.Parent.Parent.ClientState)

local CoreGuiController = {}

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
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, not ClientState.isParticipant())
	end)
end

function CoreGuiController.init()
	task.spawn(setCore, "ResetButtonCallback", false)
	ClientState.PublicChanged:Connect(update)
	update()
end

return CoreGuiController
