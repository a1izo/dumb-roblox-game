-- Communication rules, enforced on the server with TextChatService:
--   * Config.CASE_CHAT off turns typing off inside a case altogether (no one in it can send anywhere).
--   * The living share one channel of their own. In free roam it is proximity chat: a message only
--     reaches players within PROXIMITY_CHAT_RANGE studs (bubbles over their heads). During the
--     meeting and the vote it reaches the whole table. It is closed in the cutscene phases.
--   * Full real names of living players are blocked in every chat, so only paper notes carry them.
--   * Specters (players out of the match who stay as ghosts) chat in their own channel,
--     which only Specters receive. They can read the meeting but not speak in it, and they
--     cannot use general chat until the match ends.
--   * Lobby players chat among themselves; living players never receive those messages
--     (this also covers whispers).
--   * Voice input of match players is muted during the match.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local NameUtil = require(Shared:WaitForChild("NameUtil"))

local Match = require(script.Parent.Match)

local ChatService = {}

-- The living's channel (named for the meeting it began as).
local MEETING_CHANNEL = "LGameMeeting"
local SPECTER_CHANNEL = "LGameSpecters"

local meetingChannel: TextChannel? = nil
local specterChannel: TextChannel? = nil
local otherChannels: { TextChannel } = {}
local meetingOpen = false
local blockedNotices: { [string]: boolean } = {}
-- Lobby players watching the match (userId -> true): they read the meeting like Specters.
local watchers: { [number]: boolean } = {}

-- In the case (living, a Specter, or away in the lobby as one): with Config.CASE_CHAT off they type nowhere.
local function inCase(userId: number): boolean
	if not Match.active then
		return false
	end
	local ps = Match.getByUserId(userId)
	return ps ~= nil and ps.status ~= "left"
end

local function typingOff(userId: number): boolean
	return not Config.CASE_CHAT and inCase(userId)
end

-- Living players are cut off from normal chat until the reveal.
local function isLiving(userId: number): boolean
	return Match.phase ~= "Reveal" and Match.phase ~= "Outro" and Match.isLivingUserId(userId)
end

-- The living's channel is open in free roam (proximity), and in the meeting and vote (the table).
local function livingChannelOpen(): boolean
	return meetingOpen or Match.phase == "Investigation"
end

-- In free roam a message reaches only the living close to the sender (Specters and watchers, who
-- never speak in it, read everything).
local function inEarshot(senderId: number, recipientId: number): boolean
	if Match.phase ~= "Investigation" or meetingOpen or senderId == recipientId then
		return true
	end
	local recipient = Match.getByUserId(recipientId)
	if not recipient or not recipient.alive then
		return true
	end
	local sender = Match.getByUserId(senderId)
	local from = if sender then Match.position(sender) else nil
	local to = Match.position(recipient)
	return from ~= nil and to ~= nil and (from - to).Magnitude <= Config.PROXIMITY_CHAT_RANGE
end

-- Out of the match but still in it as a Specter (players who left are not Specters).
local function isSpecter(userId: number): boolean
	if not Match.active or Match.phase == "Reveal" then
		return false
	end
	local ps = Match.getByUserId(userId)
	return ps ~= nil and not ps.alive and ps.status ~= "left"
end

local function containsLivingRealName(texts: { string }): boolean
	for _, ps in ipairs(Match.living()) do
		if NameUtil.containsAcross(texts, ps.first, ps.last) then
			return true
		end
	end
	return false
end

-- What each of the living said lately: a real name typed a word at a time across messages is still the name
-- (2026-10-27). A message that was blocked is left out of what follows it.
local RECENT_SECONDS = 45
local RECENT_COUNT = 4
type Said = { id: string, text: string, at: number, blocked: boolean }
local recent: { [number]: { Said } } = {}

-- The sender's last few messages up to this one (it is remembered the first time a recipient asks about it).
local function saidUpTo(senderId: number, message: TextChatMessage): ({ string }, Said)
	local list = recent[senderId] or {}
	recent[senderId] = list
	local now = os.clock()
	for i = #list, 1, -1 do
		if now - list[i].at > RECENT_SECONDS then
			table.remove(list, i)
		end
	end
	local this: Said? = nil
	for _, entry in ipairs(list) do
		if entry.id == message.MessageId then
			this = entry
		end
	end
	if not this then
		this = { id = message.MessageId, text = message.Text, at = now, blocked = false }
		table.insert(list, this :: Said)
		while #list > RECENT_COUNT do
			table.remove(list, 1)
		end
	end
	local texts = {}
	for _, entry in ipairs(list) do
		if entry == this then
			table.insert(texts, entry.text)
			break
		elseif not entry.blocked then
			table.insert(texts, entry.text)
		end
	end
	return texts, this :: Said
end

local function applySource(channel: TextChannel, child: Instance)
	if not child:IsA("TextSource") then
		return
	end
	local source = child :: TextSource
	if typingOff(source.UserId) then
		source.CanSend = false
	elseif channel == meetingChannel then
		source.CanSend = livingChannelOpen() and isLiving(source.UserId)
	elseif channel == specterChannel then
		source.CanSend = isSpecter(source.UserId)
	else
		source.CanSend = not isLiving(source.UserId) and not isSpecter(source.UserId)
	end
end

-- Everyone in the match, and anyone watching it: Roblox voice is heard by whoever is near,
-- so a spectator flying past the living must not be heard either.
local function shouldMute(player: Player): boolean
	return Match.active and (Match.get(player) ~= nil or watchers[player.UserId] == true)
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
	for _, channel in ipairs({ meetingChannel, specterChannel }) do
		if channel then
			for _, child in ipairs(channel:GetChildren()) do
				applySource(channel, child)
			end
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
		setVoiceMuted(player, shouldMute(player))
	end
end

-- Any non-meeting channel (general, system, whispers): living players are cut off.
local function hookChannel(child: Instance)
	if
		not child:IsA("TextChannel")
		or child == meetingChannel
		or child == specterChannel
		or table.find(otherChannels, child)
	then
		return
	end
	local channel = child :: TextChannel
	table.insert(otherChannels, channel)
	channel.ShouldDeliverCallback = function(message: TextChatMessage, recipient: TextSource)
		local sender = message.TextSource
		if not sender then
			return true
		end
		if typingOff(sender.UserId) then
			return false
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

local function onMeetingMessage(message: TextChatMessage, recipient: TextSource): boolean
	local sender = message.TextSource
	if not sender then
		return true
	end
	if typingOff(sender.UserId) or not livingChannelOpen() or not isLiving(sender.UserId) then
		return false
	end
	if not inEarshot(sender.UserId, recipient.UserId) then
		return false
	end

	local texts, said = saidUpTo(sender.UserId, message)
	if said.blocked or containsLivingRealName(texts) then
		said.blocked = true
		if not blockedNotices[message.MessageId] then
			blockedNotices[message.MessageId] = true
			local player = Players:GetPlayerByUserId(sender.UserId)
			if player then
				Match.notify(player, "Blocked. Real names aren't allowed in chat.", "bad")
			end
		end
		return false
	end
	return true
end

-- Adds a new Specter to the Specters' channel.
function ChatService.addSpecter(userId: number)
	local channel = specterChannel
	if not channel or channel:FindFirstChild(tostring(userId)) then
		return
	end
	task.spawn(function()
		pcall(function()
			channel:AddUserAsync(userId)
		end)
		ChatService.refresh()
	end)
end

-- A lobby player starts watching: they read the meeting (never send) and their voice is off.
function ChatService.addWatcher(userId: number)
	watchers[userId] = true
	local channel = meetingChannel
	if channel and not channel:FindFirstChild(tostring(userId)) then
		task.spawn(function()
			pcall(function()
				channel:AddUserAsync(userId)
			end)
			ChatService.refresh()
		end)
	end
	ChatService.refresh()
end

function ChatService.removeWatcher(userId: number)
	watchers[userId] = nil
	local channel = meetingChannel
	if channel then
		for _, child in ipairs(channel:GetChildren()) do
			if child:IsA("TextSource") and child.UserId == userId then
				child:Destroy()
			end
		end
	end
	ChatService.refresh()
end

local function clearChannel(channel: TextChannel?)
	if channel then
		for _, child in ipairs(channel:GetChildren()) do
			if child:IsA("TextSource") then
				child:Destroy()
			end
		end
	end
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
			if Match.isBot(ps) then
				continue -- test bots never chat
			end
			task.spawn(function()
				local ok, err = pcall(function()
					channel:AddUserAsync(ps.userId)
				end)
				if not ok then
					warn("[DeathsGambit] Could not add a player to the meeting chat: " .. tostring(err))
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
	recent = {}
	watchers = {}
	clearChannel(meetingChannel)
	clearChannel(specterChannel)
	ChatService.refresh()
end

local function setupChannels()
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		warn("[DeathsGambit] Set TextChatService.ChatVersion to TextChatService; the chat rules need it.")
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

	local specters = Instance.new("TextChannel")
	specters.Name = SPECTER_CHANNEL
	specters.ShouldDeliverCallback = function(message: TextChatMessage, recipient: TextSource): boolean
		local sender = message.TextSource
		return sender ~= nil
			and not typingOff(sender.UserId)
			and isSpecter(sender.UserId)
			and isSpecter(recipient.UserId)
	end
	specters.ChildAdded:Connect(function(child)
		applySource(specters, child)
	end)
	specters.Parent = folder
	specterChannel = specters

	for _, child in ipairs(folder:GetChildren()) do
		hookChannel(child)
	end
	folder.ChildAdded:Connect(hookChannel)
end

function ChatService.init()
	task.spawn(setupChannels)
	Match.Eliminated:Connect(function(ps, kind)
		if kind ~= "left" then
			ChatService.addSpecter(ps.userId)
		end
		ChatService.refresh()
	end)
	Players.PlayerAdded:Connect(function(player)
		player.ChildAdded:Connect(function(child)
			if child:IsA("AudioDeviceInput") then
				setVoiceMuted(player, shouldMute(player))
			end
		end)
	end)
end

return ChatService
