-- Characters by user id: players' characters, and the debug panel's test bots (tagged
-- LBotCharacter, with their user id in the BotUserId attribute).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Characters = {}

Characters.BOT_TAG = "LBotCharacter"

-- The character for a user id, if it is in the world.
function Characters.byUserId(userId: number?): Model?
	if type(userId) ~= "number" then
		return nil
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		local character = player.Character
		return if character and character.Parent then character else nil
	end
	if userId < 0 then
		for _, model in ipairs(CollectionService:GetTagged(Characters.BOT_TAG)) do
			if model:IsA("Model") and model:GetAttribute("BotUserId") == userId and model.Parent then
				return model
			end
		end
	end
	return nil
end

-- Calls callback(character) for every player and bot character, now and later.
function Characters.each(callback: (Model) -> ())
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(callback)
		if player.Character then
			task.spawn(callback, player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
	CollectionService:GetInstanceAddedSignal(Characters.BOT_TAG):Connect(function(model)
		if model:IsA("Model") then
			callback(model)
		end
	end)
	for _, model in ipairs(CollectionService:GetTagged(Characters.BOT_TAG)) do
		if model:IsA("Model") then
			task.spawn(callback, model)
		end
	end
end

return Characters
