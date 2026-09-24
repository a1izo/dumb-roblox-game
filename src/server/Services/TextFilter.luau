-- Roblox text filtering for every piece of player-typed text that another player
-- will read (paper notes, tips, reports, L's screen). Filtering failures never show
-- the raw text, except in Studio where the filter service is not available.

local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local TextFilter = {}

local IS_STUDIO = RunService:IsStudio()

function TextFilter.forUser(text: string, fromUserId: number, toUserId: number): string?
	local ok, result = pcall(function()
		local filterResult = TextService:FilterStringAsync(text, fromUserId, Enum.TextFilterContext.PrivateChat)
		return filterResult:GetNonChatStringForUserAsync(toUserId)
	end)
	if ok and type(result) == "string" then
		return result
	end
	if IS_STUDIO then
		return text
	end
	warn("[Inkbound] Text filtering failed: " .. tostring(result))
	return nil
end

function TextFilter.broadcast(text: string, fromUserId: number): string?
	local ok, result = pcall(function()
		local filterResult = TextService:FilterStringAsync(text, fromUserId, Enum.TextFilterContext.PublicChat)
		return filterResult:GetNonChatStringForBroadcastAsync()
	end)
	if ok and type(result) == "string" then
		return result
	end
	if IS_STUDIO then
		return text
	end
	warn("[Inkbound] Text filtering failed: " .. tostring(result))
	return nil
end

return TextFilter
