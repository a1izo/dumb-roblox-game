-- Client side of the communication rules. The server enforces them; this controller
-- keeps the chat bar in the right state:
--   living, outside meetings -> no chat bar (quick-chat only)
--   living, meeting or vote  -> chat bar sends to the meeting channel
--   everyone else            -> normal chat (living players never receive it)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("Net"))

local ClientState = require(script.Parent.Parent.ClientState)

local ChatController = {}

local MEETING_CHANNEL = "LGameMeeting"
local SPECTER_CHANNEL = "LGameSpecters"

local function channel(name: string): TextChannel?
	local folder = TextChatService:FindFirstChild("TextChannels")
	local found = if folder then folder:FindFirstChild(name) else nil
	if found and found:IsA("TextChannel") then
		return found
	end
	return nil
end

local function update()
	local inputBar = TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration")
	if not inputBar then
		return
	end
	local phase = ClientState.phase()
	if ClientState.isSpecter() then
		-- Specters talk among themselves only.
		local specters = channel(SPECTER_CHANNEL)
		inputBar.Enabled = specters ~= nil
		if specters then
			inputBar.TargetTextChannel = specters
		end
	elseif ClientState.isLiving() and phase ~= "Reveal" and phase ~= "Outro" then
		local meeting = channel(MEETING_CHANNEL)
		if (phase == "Meeting" or phase == "Vote" or phase == "Verdict") and meeting then
			inputBar.TargetTextChannel = meeting
			inputBar.Enabled = true
		else
			inputBar.Enabled = false
		end
	else
		inputBar.Enabled = true
		local general = channel("RBXGeneral")
		if general then
			inputBar.TargetTextChannel = general
		end
	end
end

-- Meeting messages show the speaker's alias instead of their account name.
local function onIncomingMessage(message: TextChatMessage)
	local source = message.TextSource
	local textChannel = message.TextChannel
	if not source or not textChannel then
		return nil
	end
	local specters = textChannel.Name == SPECTER_CHANNEL
	if textChannel.Name ~= MEETING_CHANNEL and not specters then
		return nil
	end
	local alias = ClientState.aliasOf(source.UserId)
	if not alias then
		return nil
	end
	local properties = Instance.new("TextChatMessageProperties")
	properties.PrefixText = if specters
		then string.format('<font color="#9AA7C7">[Specter] %s:</font>', alias)
		else string.format('<font color="#E6C36E">%s:</font>', alias)
	return properties
end

-- Quick-chat phrases appear as a speech bubble and in the chat window.
local function onQuickChat(payload)
	if type(payload) ~= "table" or type(payload.text) ~= "string" then
		return
	end
	local speaker = Players:GetPlayerByUserId(tonumber(payload.userId) or 0)
	local character = if speaker then speaker.Character else nil
	local head = if character then character:FindFirstChild("Head") else nil
	if head then
		pcall(function()
			TextChatService:DisplayBubble(head, payload.text)
		end)
	end
	local system = channel("RBXSystem") or channel("RBXGeneral")
	if system then
		pcall(function()
			local tag = if payload.specter then "[Specter]" else "[Quick]"
			system:DisplaySystemMessage(string.format("%s %s: %s", tag, tostring(payload.name), payload.text))
		end)
	end
end

function ChatController.init()
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		TextChatService.OnIncomingMessage = onIncomingMessage
	end
	ClientState.PublicChanged:Connect(update)
	ClientState.PrivateChanged:Connect(update)
	Net.event("QuickChatMsg").OnClientEvent:Connect(onQuickChat)
	task.spawn(function()
		-- Channels are created by the server shortly after start.
		local folder = TextChatService:WaitForChild("TextChannels", 30)
		if folder then
			folder.ChildAdded:Connect(update)
		end
		update()
	end)
end

return ChatController
