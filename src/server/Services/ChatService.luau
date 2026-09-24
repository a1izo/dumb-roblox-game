-- Communication rules, enforced on the server with TextChatService:
--   * Living players cannot type outside meetings; they use quick-chat and emotes.
--   * During the meeting and the vote a separate channel opens for living players.
--     Messages containing the full real name of a living player are blocked.
--   * Dead, voted-out and lobby players chat among themselves; living players never
--     receive those messages (this also covers whispers).
--   * Voice input of match players is muted during the match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))
local Net = require(Shared:WaitForChild("Net"))
local QuickChat = require(Shared:WaitForChild("QuickChat"))

local Match = require(script.Parent.Match)
local RateLimit = require(script.Parent.RateLimit)

local QuickChatRemote = Net.event("QuickChat")
local QuickChatMsgRemote = Net.event("QuickChatMsg")

local ChatService = {}

local MEETING_CHANNEL = "LGameMeeting"

local meetingChannel: TextChannel? = nil
local otherChannels: { TextChannel } = {}
local meetingOpen = false
local blockedNotices: { [string]: boolean } = {}

-- Living players are cut off from normal chat until the reveal.
local function isLiving(userId: number): boolean
	return Match.phase ~= "Reveal" and Match.phase ~= "Outro" and Match.isLivingUserId(userId)
end

local function containsLivingRealName(text: string): boolean
	for _, ps in ipairs(Match.living()) do
		if NameUtil.containsFullName(text, ps.first, ps.last) then
			return true
		end
	end
	return false
end

local function applySource(channel: TextChannel, child: Instance)
	if not child:IsA("TextSource") then
		return
	end
	local source = child :: TextSource
	if channel == meetingChannel then
		source.CanSend = meetingOpen and isLiving(source.UserId)
	else
		source.CanSend = not isLiving(source.UserId)
	end
end

local function setVoiceMuted(player: Player, muted: boolean)
	local input = player:FindFirstChildOfClass("AudioDeviceInput")
	if input then
		pcall(function()
			input.Muted = muted
		end)
	end
end

-- Re-applies every rule. Called whenever the match state changes.
function ChatService.refresh()
	if meetingChannel then
		for _, child in ipairs(meetingChannel:GetChildren()) do
			applySource(meetingChannel, child)
		end
	end
	for _, channel in ipairs(otherChannels) do
		if channel.Parent then
			for _, child in ipairs(channel:GetChildren()) do
				applySource(channel, child)
			end
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		setVoiceMuted(player, Match.active and Match.get(player) ~= nil)
	end
end

-- Any non-meeting channel (general, system, whispers): living players are cut off.
local function hookChannel(child: Instance)
	if not child:IsA("TextChannel") or child == meetingChannel or table.find(otherChannels, child) then
		return
	end
	local channel = child :: TextChannel
	table.insert(otherChannels, channel)
	channel.ShouldDeliverCallback = function(message: TextChatMessage, recipient: TextSource)
		local sender = message.TextSource
		if not sender then
			return true
		end
		return not isLiving(sender.UserId) and not isLiving(recipient.UserId)
	end
	channel.ChildAdded:Connect(function(child)
		applySource(channel, child)
	end)
	for _, child in ipairs(channel:GetChildren()) do
		applySource(channel, child)
	end
end

local function onMeetingMessage(message: TextChatMessage, _recipient: TextSource): boolean
	local sender = message.TextSource
	if not sender then
		return true
	end
	if not meetingOpen or not isLiving(sender.UserId) then
		return false
	end
	if containsLivingRealName(message.Text) then
		if not blockedNotices[message.MessageId] then
			blockedNotices[message.MessageId] = true
			local player = Players:GetPlayerByUserId(sender.UserId)
			if player then
				Match.notify(player, "Message blocked: it contained a living player's full real name.", "bad")
			end
		end
		return false
	end
	return true
end

function ChatService.setMeetingOpen(open: boolean)
	meetingOpen = open
	if not open then
		blockedNotices = {}
	end
	ChatService.refresh()
end

function ChatService.onMatchStart()
	meetingOpen = false
	blockedNotices = {}
	local channel = meetingChannel
	if channel then
		for _, child in ipairs(channel:GetChildren()) do
			if child:IsA("TextSource") then
				child:Destroy()
			end
		end
		for _, ps in ipairs(Match.list) do
			task.spawn(function()
				local ok, err = pcall(function()
					channel:AddUserAsync(ps.userId)
				end)
				if not ok then
					warn("[Inkbound] Could not add a player to the meeting chat: " .. tostring(err))
				end
				ChatService.refresh()
			end)
		end
	end
	ChatService.refresh()
end

function ChatService.onMatchEnd()
	meetingOpen = false
	blockedNotices = {}
	if meetingChannel then
		for _, child in ipairs(meetingChannel:GetChildren()) do
			if child:IsA("TextSource") then
				child:Destroy()
			end
		end
	end
	ChatService.refresh()
end

-- Quick-chat: fixed phrases that anyone can send at any time.
local function onQuickChat(player: Player, index)
	if type(index) ~= "number" then
		return
	end
	local phrase = QuickChat.PHRASES[index]
	if not phrase or not RateLimit.allow(player, "quickchat", Config.QUICK_CHAT_COOLDOWN) then
		return
	end
	local ps = Match.getLiving(player)
	local payload = {
		userId = player.UserId,
		name = if ps then ps.alias else player.DisplayName,
		text = phrase,
	}
	if Match.active and not ps then
		-- Spectators and lobby players never reach the living.
		for _, other in ipairs(Players:GetPlayers()) do
			if not isLiving(other.UserId) then
				QuickChatMsgRemote:FireClient(other, payload)
			end
		end
	else
		QuickChatMsgRemote:FireAllClients(payload)
	end
end

local function setupChannels()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		warn("[Inkbound] Set TextChatService.ChatVersion to TextChatService; the chat rules need it.")
	end
	local folder = TextChatService:WaitForChild("TextChannels", 10)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "TextChannels"
		folder.Parent = TextChatService
	end

	local channel = Instance.new("TextChannel")
	channel.Name = MEETING_CHANNEL
	channel.ShouldDeliverCallback = onMeetingMessage
	channel.ChildAdded:Connect(function(child)
		applySource(channel, child)
	end)
	channel.Parent = folder
	meetingChannel = channel

	for _, child in ipairs(folder:GetChildren()) do
		hookChannel(child)
	end
	folder.ChildAdded:Connect(hookChannel)
end

function ChatService.init()
	task.spawn(setupChannels)
	Match.Eliminated:Connect(function()
		ChatService.refresh()
	end)
	Players.PlayerAdded:Connect(function(player)
		player.ChildAdded:Connect(function(child)
			if child:IsA("AudioDeviceInput") then
				setVoiceMuted(player, Match.active and Match.get(player) ~= nil)
			end
		end)
	end)
	QuickChatRemote.OnServerEvent:Connect(onQuickChat)
end

return ChatService
