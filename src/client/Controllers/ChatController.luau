-- Client side of the communication rules. The server enforces them; this controller
-- keeps the chat bar in the right state:
--   living, free roam        -> chat bar sends to the living's channel; the server only delivers it
--                               to players close by. No chat window: what is said shows as a bubble
--                               over the speaker's head, so you have to be next to them to read it.
--   living, meeting or vote  -> chat bar sends to the same channel, heard by the whole table (window on)
--   living, cutscene phases  -> no chat bar
--   (Config.CASE_CHAT off: no chat bar for anyone in a case)
--   everyone else            -> normal chat (living players never receive it)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Terms = require(Shared:WaitForChild("Terms"))

local ClientState = require(script.Parent.Parent.ClientState)
local Kit = require(script.Parent.Parent.UI.Kit)
local LobbyChrome = require(script.Parent.Parent.UI.Core.LobbyChrome)

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
	-- The lobby's Hide UI hides chat as well (window, bubbles and the bar).
	local hidden = LobbyChrome.isHidden()
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	local bubbles = TextChatService:FindFirstChildOfClass("BubbleChatConfiguration")
	-- The living in free roam read bubbles only: there is no window to scroll back through.
	local roaming = ClientState.isLiving() and ClientState.phase() == "Investigation"
	if window then
		window.Enabled = not hidden and not roaming
	end
	if bubbles then
		bubbles.Enabled = not hidden
	end
	if hidden then
		inputBar.Enabled = false
		return
	end
	local phase = ClientState.phase()
	local me = ClientState.me()
	if not Config.CASE_CHAT and ClientState.public.active and me ~= nil and me.status ~= "left" then
		inputBar.Enabled = false
	elseif ClientState.isSpecter() or ClientState.isAway() then
		-- Specters talk among themselves only (in the lobby too, while they wait there hidden).
		local specters = channel(SPECTER_CHANNEL)
		inputBar.Enabled = specters ~= nil
		if specters then
			inputBar.TargetTextChannel = specters
		end
	elseif ClientState.isLiving() and phase ~= "Reveal" and phase ~= "Outro" then
		local meeting = channel(MEETING_CHANNEL)
		local open = phase == "Investigation" or phase == "Meeting" or phase == "Vote" or phase == "Verdict"
		if open and meeting then
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
		then string.format('<font color="#A3AAB5">[%s] %s:</font>', Terms.NAMES.Specter, alias)
		else string.format('<font color="#F4F5F7">%s:</font>', alias)
	return properties
end

-- The chat window, the input bar and the speech bubbles in the Notch style: near-black panels, white
-- Montserrat text. The layout stays Roblox's (on phones the window stays where thumbs are not). Each
-- property is set on its own and guarded, so one a Studio version lacks cannot stop the rest.
local function setProps(config: Instance?, props: { [string]: any })
	if not config then
		return
	end
	for name, value in pairs(props) do
		pcall(function()
			(config :: any)[name] = value
		end)
	end
end

local function inLobby(): boolean
	return not ClientState.isParticipant() and not ClientState.isWatching()
end

-- Where the chat window sits, by where you are. In a case: the middle of the left edge on a desktop (the objectives
-- sit top left and your role card bottom left; it covered the card, 2026-10-25), top left on a phone (Roblox's
-- default). In the lobby the left of the screen is the READY button and the menu, from a quarter of the way down to
-- about seven tenths (chat lay over the menu, 2026-10-26), and your card and the daily streak hang bottom right (the
-- streak covered the chat there, 2026-10-27): on a desktop the window goes to the bottom left corner, under the menu,
-- a little shorter, so the chat is on the left in the lobby and in a case alike; on a phone, top right.
local placed: string? = nil

local function placeChat()
	local phone = Kit.Layout.isPhone()
	local lobby = inLobby()
	local key = (if phone then "phone" else "desk") .. (if lobby then "Lobby" else "Case")
	local window = TextChatService:FindFirstChildOfClass("ChatWindowConfiguration")
	if not window or key == placed then
		return
	end
	placed = key
	setProps(window, {
		HeightScale = if phone then (if lobby then 0.32 else 0.4) else (if lobby then 0.2 else 0.3),
		WidthScale = if phone then 0.5 else (if lobby then 0.26 else 0.32),
		HorizontalAlignment = if lobby and phone then Enum.HorizontalAlignment.Right else Enum.HorizontalAlignment.Left,
		VerticalAlignment = if phone
			then Enum.VerticalAlignment.Top
			elseif lobby then Enum.VerticalAlignment.Bottom
			else Enum.VerticalAlignment.Center,
	})
end

local function styleChat()
	local font = Kit.Tokens.font.body
	local C = Kit.color
	local phone = Kit.Layout.isPhone()
	setProps(TextChatService:FindFirstChildOfClass("ChatWindowConfiguration"), {
		FontFace = font,
		TextSize = if phone then 13 else 15,
		TextColor3 = C.white,
		TextStrokeTransparency = 1,
		BackgroundColor3 = C.g0,
		BackgroundTransparency = 0.25,
	})
	placed = nil
	placeChat()
	setProps(TextChatService:FindFirstChildOfClass("ChatInputBarConfiguration"), {
		FontFace = font,
		TextSize = 15,
		TextColor3 = C.white,
		PlaceholderColor3 = C.g5,
		TextStrokeTransparency = 1,
		BackgroundColor3 = C.g0,
		BackgroundTransparency = 0.2,
	})
	setProps(TextChatService:FindFirstChildOfClass("BubbleChatConfiguration"), {
		FontFace = Kit.Tokens.font.bodyBold,
		TextSize = 16,
		TextColor3 = C.white,
		BackgroundColor3 = C.g0,
		BackgroundTransparency = 0.1,
	})
end

function ChatController.init()
	styleChat()
	TextChatService.ChildAdded:Connect(function()
		task.defer(styleChat)
	end)
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		TextChatService.OnIncomingMessage = onIncomingMessage
	end
	ClientState.PublicChanged:Connect(update)
	ClientState.PrivateChanged:Connect(update)
	-- (into the case and back out to the lobby, watching and not: the window moves with you)
	ClientState.PublicChanged:Connect(placeChat)
	ClientState.PrivateChanged:Connect(placeChat)
	ClientState.WatchChanged:Connect(placeChat)
	LobbyChrome.Changed:Connect(update)
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
